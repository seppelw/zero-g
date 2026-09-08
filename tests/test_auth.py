#!/usr/bin/env python3
"""
Unit tests for agy-auth.sh.
Tests URL generation, PKCE verifier persistence, code sanitization, and token checking.
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AUTH_SCRIPT = REPO_ROOT / "zero-g" / "rootfs" / "usr/bin" / "agy-auth.sh"


class TestAgyAuth(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.data_dir = Path(self.test_dir.name) / "data"
        self.gemini_dir = self.data_dir / ".gemini"
        self.gemini_dir.mkdir(parents=True, exist_ok=True)
        self.verifier_file = self.gemini_dir / "pkce_verifier.txt"
        self.token_file = self.gemini_dir / "jetski-standalone-oauth-token"
        self.last_code_file = self.gemini_dir / "last_exchanged_code.txt"

    def tearDown(self):
        self.test_dir.cleanup()

    def run_auth(self, *args):
        env = os.environ.copy()
        env["DATA_DIR"] = str(self.data_dir)
        env["GEMINI_DIR"] = str(self.gemini_dir)
        env["VERIFIER_FILE"] = str(self.verifier_file)
        env["TOKEN_FILE"] = str(self.token_file)
        env["LAST_CODE_FILE"] = str(self.last_code_file)

        return subprocess.run(
            ["bash", str(AUTH_SCRIPT)] + list(args),
            capture_output=True,
            text=True,
            env=env
        )

    def test_generate_url_creates_verifier(self):
        """Verify generate_url creates pkce_verifier.txt and outputs valid Google Auth URL."""
        res = self.run_auth("generate_url")
        self.assertEqual(res.returncode, 0, f"Failed: {res.stderr}")
        url = res.stdout.strip()

        self.assertTrue(url.startswith("https://accounts.google.com/o/oauth2/auth"))
        self.assertIn("state=zero-g", url)
        self.assertIn("code_challenge=", url)
        self.assertIn("code_challenge_method=S256", url)
        self.assertTrue(self.verifier_file.exists())

        verifier = self.verifier_file.read_text().strip()
        self.assertGreater(len(verifier), 20)

    def test_generate_url_persists_across_calls(self):
        """Multiple generate_url invocations must reuse existing verifier so restart doesn't invalidate codes."""
        res1 = self.run_auth("generate_url")
        url1 = res1.stdout.strip()
        v1 = self.verifier_file.read_text().strip()

        res2 = self.run_auth("generate_url")
        url2 = res2.stdout.strip()
        v2 = self.verifier_file.read_text().strip()

        self.assertEqual(url1, url2)
        self.assertEqual(v1, v2)

    def test_sanitize_code(self):
        """Verify sanitize removes whitespace, extracts code from redirect URL, and decodes %2F."""
        # Bare code
        res1 = self.run_auth("sanitize", "4/0AfgeX123   \t")
        self.assertEqual(res1.stdout.strip(), "4/0AfgeX123")

        # Full redirect URL with URL-encoded code
        res2 = self.run_auth("sanitize", "https://antigravity.google/oauth-callback?code=4%2F0AfgeX456&state=zero-g")
        self.assertEqual(res2.stdout.strip(), "4/0AfgeX456")

        # URL with plain code
        res3 = self.run_auth("sanitize", "https://antigravity.google/oauth-callback?code=4/0AfgeX789&state=zero-g")
        self.assertEqual(res3.stdout.strip(), "4/0AfgeX789")

    def test_check_token_missing_or_empty(self):
        """check_token returns non-zero when token file is missing or invalid."""
        res = self.run_auth("check_token")
        self.assertNotEqual(res.returncode, 0)

        # Empty file
        self.token_file.write_text("")
        res = self.run_auth("check_token")
        self.assertNotEqual(res.returncode, 0)

        # Invalid JSON
        self.token_file.write_text("invalid json")
        res = self.run_auth("check_token")
        self.assertNotEqual(res.returncode, 0)

    def test_reset_verifier(self):
        """reset_verifier deletes pending pkce_verifier.txt."""
        self.verifier_file.write_text("test_verifier")
        self.assertTrue(self.verifier_file.exists())

        res = self.run_auth("reset_verifier")
        self.assertEqual(res.returncode, 0)
        self.assertFalse(self.verifier_file.exists())


if __name__ == "__main__":
    unittest.main()
