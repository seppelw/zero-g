#!/usr/bin/env python3
"""
Unit and integration tests for ha-mcp-setup.sh.
Tests configuration generation, token injection, URL resolution, and preservation of existing MCP servers.
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SETUP_SCRIPT = REPO_ROOT / "antigravity" / "rootfs" / "usr/bin" / "ha-mcp-setup.sh"


class TestHAMCPSetup(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.data_dir = Path(self.test_dir.name) / "data"
        self.config_dir = self.data_dir / ".gemini" / "config"
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.config_file = self.config_dir / "mcp_config.json"
        self.options_file = self.data_dir / "options.json"

    def tearDown(self):
        self.test_dir.cleanup()

    def run_setup(self, options=None, supervisor_token=None, existing_config=None):
        """Helper to run ha-mcp-setup.sh with a mock environment."""
        if options is not None:
            with open(self.options_file, "w") as f:
                json.dump(options, f)

        if existing_config is not None:
            with open(self.config_file, "w") as f:
                json.dump(existing_config, f)

        env = os.environ.copy()
        if supervisor_token is not None:
            env["SUPERVISOR_TOKEN"] = supervisor_token
        else:
            env.pop("SUPERVISOR_TOKEN", None)

        env["CONFIG_DIR"] = str(self.config_dir)
        env["CONFIG_FILE"] = str(self.config_file)
        env["OPTIONS_FILE"] = str(self.options_file)

        res = subprocess.run(
            ["bash", str(SETUP_SCRIPT)],
            capture_output=True,
            text=True,
            env=env
        )
        return res

    def read_config(self):
        self.assertTrue(self.config_file.exists(), "mcp_config.json was not created")
        with open(self.config_file, "r") as f:
            return json.load(f)

    def test_auto_mode_with_supervisor_token(self):
        """Test default auto mode: should use internal HA URL and injected SUPERVISOR_TOKEN."""
        options = {
            "ha_mcp_enabled": True,
            "ha_mcp_mode": "auto",
            "ha_mcp_url": "",
            "ha_mcp_token": "",
            "ha_mcp_history_enabled": False,
        }
        res = self.run_setup(options=options, supervisor_token="supervisor_secret_token_123")
        self.assertEqual(res.returncode, 0, f"Script failed: {res.stderr}")

        config = self.read_config()
        self.assertIn("mcpServers", config)
        self.assertIn("homeassistant", config["mcpServers"])
        ha_server = config["mcpServers"]["homeassistant"]

        self.assertEqual(ha_server["serverUrl"], "http://supervisor/core/api/mcp")
        self.assertEqual(ha_server["headers"]["Authorization"], "Bearer supervisor_secret_token_123")
        self.assertNotIn("homeassistant_history", config["mcpServers"])

    def test_manual_mode_custom_url_and_token(self):
        """Test manual mode with custom endpoint and long-lived token."""
        options = {
            "ha_mcp_enabled": True,
            "ha_mcp_mode": "manual",
            "ha_mcp_url": "https://ha.example.com/api/mcp",
            "ha_mcp_token": "manual_llat_token_456",
            "ha_mcp_history_enabled": False,
        }
        res = self.run_setup(options=options, supervisor_token="ignore_this_token")
        self.assertEqual(res.returncode, 0, f"Script failed: {res.stderr}")

        config = self.read_config()
        ha_server = config["mcpServers"]["homeassistant"]
        self.assertEqual(ha_server["serverUrl"], "https://ha.example.com/api/mcp")
        self.assertEqual(ha_server["headers"]["Authorization"], "Bearer manual_llat_token_456")

    def test_history_server_enabled(self):
        """Test activating optional history MCP server."""
        options = {
            "ha_mcp_enabled": True,
            "ha_mcp_mode": "auto",
            "ha_mcp_url": "",
            "ha_mcp_token": "",
            "ha_mcp_history_enabled": True,
            "ha_mcp_history_url": "http://supervisor/core/api/hass_mcp",
        }
        res = self.run_setup(options=options, supervisor_token="token_789")
        self.assertEqual(res.returncode, 0, f"Script failed: {res.stderr}")

        config = self.read_config()
        self.assertIn("homeassistant_history", config["mcpServers"])
        hist_server = config["mcpServers"]["homeassistant_history"]
        self.assertEqual(hist_server["serverUrl"], "http://supervisor/core/api/hass_mcp")
        self.assertEqual(hist_server["headers"]["Authorization"], "Bearer token_789")

    def test_disabled_ha_mcp_removes_entries(self):
        """Test disabling HA MCP removes homeassistant entries but preserves other tools."""
        existing = {
            "mcpServers": {
                "custom_database": {"command": "sqlite3"},
                "homeassistant": {"serverUrl": "http://old"},
                "homeassistant_history": {"serverUrl": "http://old"}
            }
        }
        options = {
            "ha_mcp_enabled": False
        }
        res = self.run_setup(options=options, existing_config=existing)
        self.assertEqual(res.returncode, 0, f"Script failed: {res.stderr}")

        config = self.read_config()
        self.assertIn("custom_database", config["mcpServers"])
        self.assertNotIn("homeassistant", config["mcpServers"])
        self.assertNotIn("homeassistant_history", config["mcpServers"])

    def test_existing_tools_preserved(self):
        """Verify that user-configured MCP servers are never lost during setup runs."""
        existing = {
            "mcpServers": {
                "proxmox": {
                    "command": "npx",
                    "args": ["-y", "@samik081/mcp-pve"]
                }
            }
        }
        options = {
            "ha_mcp_enabled": True,
            "ha_mcp_mode": "auto"
        }
        res = self.run_setup(options=options, existing_config=existing, supervisor_token="test_token")
        self.assertEqual(res.returncode, 0, f"Script failed: {res.stderr}")

        config = self.read_config()
        self.assertIn("proxmox", config["mcpServers"])
        self.assertEqual(config["mcpServers"]["proxmox"]["command"], "npx")
        self.assertIn("homeassistant", config["mcpServers"])


if __name__ == "__main__":
    unittest.main()
