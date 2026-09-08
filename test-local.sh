#!/usr/bin/env bash
# ==============================================================================
# Local Test & Validation Runner for Zero-G Home Assistant Add-on
#
# Runs all checks locally before pushing to GitHub:
#   1. YAML syntax & Home Assistant Add-on Schema validation
#   2. Bash syntax checks (bash -n) & ShellCheck (if available)
#   3. Python Unit Tests for MCP setup & configuration
#   4. HTML validation for Onboarding UI
#   5. Executable permission checks
# ==============================================================================
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TOTAL_STEPS=5
CURRENT_STEP=0
FAILURES=0

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "\n${BLUE}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} $1"
}

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAILURES=$((FAILURES + 1))
}

warn() {
    echo -e "  ${YELLOW}!${NC} $1"
}

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  Running Local Validation & Test Suite (Zero-G)      ${NC}"
echo -e "${BLUE}======================================================${NC}"

# ------------------------------------------------------------------------------
# 1. YAML Validation & HA Schema Check
# ------------------------------------------------------------------------------
step "Validating YAML files and schema integrity..."

python3 - << 'EOF'
import sys
import yaml

files = ['repository.yaml', 'zero-g/config.yaml', 'zero-g/build.yaml', '.github/workflows/lint.yaml']
for f in files:
    try:
        with open(f, 'r') as fp:
            data = yaml.safe_load(fp)
            if not isinstance(data, dict):
                print(f"FAILED:{f}: Root must be a dictionary")
                sys.exit(1)
        print(f"OK:{f}")
    except Exception as e:
        print(f"FAILED:{f}:{e}")
        sys.exit(1)

# Verify Home Assistant config.yaml structure
with open('zero-g/config.yaml') as fp:
    cfg = yaml.safe_load(fp)

assert cfg.get('name') == "Zero-G", "name must be Zero-G"
assert cfg.get('slug') == "zero-g", "slug must be zero-g"
assert cfg.get('ingress') is True, "ingress must be True"
assert cfg.get('homeassistant_api') is True, "homeassistant_api must be True"
assert cfg.get('ingress_port') == 8099, "ingress_port must be 8099"

schema = cfg.get('schema', {})
options = cfg.get('options', {})
for opt in options:
    assert opt in schema, f"Option '{opt}' is missing from schema"

print("OK:HA_SCHEMA")
EOF
if [[ $? -eq 0 ]]; then
    pass "All YAML files are well-formed and match Home Assistant specifications."
else
    fail "YAML validation failed."
fi

# ------------------------------------------------------------------------------
# 2. Bash Syntax & ShellCheck
# ------------------------------------------------------------------------------
step "Checking Shell Script syntax..."

SCRIPTS=(
    "zero-g/rootfs/usr/bin/run.sh"
    "zero-g/rootfs/usr/bin/ha-mcp-setup.sh"
    "zero-g/rootfs/usr/bin/agy-auth.sh"
    "test-local.sh"
)

for s in "${SCRIPTS[@]}"; do
    if bash -n "$s"; then
        pass "Bash syntax OK: $s"
    else
        fail "Bash syntax error in: $s"
    fi
done

if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -x zero-g/rootfs/usr/bin/*.sh; then
        pass "ShellCheck passed with zero warnings."
    else
        fail "ShellCheck reported issues."
    fi
else
    warn "ShellCheck not installed locally (will run automatically in GitHub Actions CI)."
fi

# ------------------------------------------------------------------------------
# 3. Python Unit Tests (MCP Setup Suite)
# ------------------------------------------------------------------------------
step "Running Python Unit Test Suite..."

if python3 -m unittest discover -s tests -p "test_*.py" -v; then
    pass "All MCP setup unit tests passed."
else
    fail "One or more Python unit tests failed."
fi

# ------------------------------------------------------------------------------
# 4. HTML Validation
# ------------------------------------------------------------------------------
step "Validating Onboarding Web Interface..."

python3 - << 'EOF'
from html.parser import HTMLParser
import sys

class HTMLValidator(HTMLParser):
    pass

try:
    with open('zero-g/rootfs/var/www/onboarding/index.html', 'r', encoding='utf-8') as f:
        content = f.read()
        validator = HTMLValidator()
        validator.feed(content)
        assert 'checkStatus' in content, "Missing checkStatus in index.html"
        assert '/_health' in content, "Missing /_health endpoint call in index.html"
        assert 'Zero-G' in content, "Missing Zero-G branding in index.html"
    print("OK:HTML")
except Exception as e:
    print(f"FAILED:HTML:{e}")
    sys.exit(1)
EOF
if [[ $? -eq 0 ]]; then
    pass "Onboarding HTML & Ingress health polling scripts are valid."
else
    fail "Onboarding HTML validation failed."
fi

if command -v nginx >/dev/null 2>&1; then
    NGINX_TEST_TMP="$(mktemp --suffix=.conf)"
    cat << EOF > "$NGINX_TEST_TMP"
events { worker_connections 1024; }
http {
    include ${PWD}/zero-g/rootfs/etc/nginx/servers/ingress.conf;
}
EOF
    if nginx -t -c "$NGINX_TEST_TMP" >/dev/null 2>&1; then
        pass "Nginx ingress.conf configuration syntax is valid."
    else
        fail "Nginx ingress.conf configuration syntax check failed."
    fi
    rm -f "$NGINX_TEST_TMP"
else
    warn "Nginx not installed locally; skipping nginx configuration test."
fi

# ------------------------------------------------------------------------------
# 5. File Permissions Check
# ------------------------------------------------------------------------------
step "Verifying file permissions..."

PERM_SCRIPTS=(
    "zero-g/rootfs/usr/bin/run.sh"
    "zero-g/rootfs/usr/bin/ha-mcp-setup.sh"
    "zero-g/rootfs/usr/bin/agy-auth.sh"
    "test-local.sh"
)

for ps in "${PERM_SCRIPTS[@]}"; do
    if [[ -x "$ps" ]]; then
        pass "Executable permission present: $ps"
    else
        fail "Missing executable permission: $ps (run 'chmod +x $ps')"
    fi
done

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}======================================================${NC}"
if [[ $FAILURES -eq 0 ]]; then
    echo -e "  ${GREEN}SUCCESS: All local checks and unit tests passed!${NC}"
    echo -e "  The repository is ready to push to GitHub."
    echo -e "${BLUE}======================================================${NC}"
    exit 0
else
    echo -e "  ${RED}FAILED: $FAILURES issue(s) detected. Please fix them.${NC}"
    echo -e "${BLUE}======================================================${NC}"
    exit 1
fi
