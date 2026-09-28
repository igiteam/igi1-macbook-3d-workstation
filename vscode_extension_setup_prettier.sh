#!/bin/bash
# ============================================================
# VS Code Prettier Auto-Formatter - One-Shot Setup
# ============================================================
# This script:
#   1. Enables the `code` command in your terminal PATH
#   2. Installs the Prettier extension in VS Code
#   3. Adds the two required settings to settings.json
#
# USAGE:
#   chmod +x setup-prettier.sh
#   ./setup-prettier.sh
# ============================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()    { echo -e "${BLUE}[i]${NC} $1"; }

# ============= STEP 1: Verify VS Code is installed =============
if [ ! -d "/Applications/Visual Studio Code.app" ]; then
    error "VS Code not found. Install it first from https://code.visualstudio.com"
fi
log "VS Code found"

# ============= STEP 2: Check if `code` command is available =============
CODE_CMD=""
if command -v code &> /dev/null; then
    CODE_CMD="code"
elif [ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
    CODE_CMD="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    info "`code` not in PATH — using full path"
else
    error "Could not find the `code` binary. Open VS Code and run: Shell Command: Install 'code' command in PATH"
fi
log "Using: $CODE_CMD"

# ============= STEP 3: Install Prettier extension =============
info "Installing Prettier extension..."
if "$CODE_CMD" --list-extensions 2>/dev/null | grep -q "esbenp.prettier-vscode"; then
    log "Prettier already installed"
else
    "$CODE_CMD" --install-extension esbenp.prettier-vscode 2>&1 | tail -2
    log "Prettier installed"
fi

# ============= STEP 4: Locate settings.json =============
# macOS locations:
#   ~/Library/Application Support/Code/User/settings.json
SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

if [ ! -d "$SETTINGS_DIR" ]; then
    info "Creating settings directory..."
    mkdir -p "$SETTINGS_DIR"
fi

# ============= STEP 5: Create settings.json if it doesn't exist =============
if [ ! -f "$SETTINGS_FILE" ]; then
    info "settings.json not found — creating it"
    echo "{}" > "$SETTINGS_FILE"
fi

# ============= STEP 6: Add the two settings if not already present =============
# Check if formatOnSave is already there
if grep -q '"editor.formatOnSave"' "$SETTINGS_FILE"; then
    log "editor.formatOnSave already configured"
else
    info "Adding editor.formatOnSave..."
    # Use a temp file to do the JSON edit safely
    TMP_FILE=$(mktemp)
    
    # Use Python to do the JSON edit — more reliable than sed/jq on macOS
    python3 - "$SETTINGS_FILE" "$TMP_FILE" << 'PYEOF'
import json
import sys

settings_file = sys.argv[1]
tmp_file = sys.argv[2]

with open(settings_file, 'r') as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        data = {}

data["editor.formatOnSave"] = True
data["editor.defaultFormatter"] = "esbenp.prettier-vscode"

with open(tmp_file, 'w') as f:
    json.dump(data, f, indent=4)
PYEOF

    mv "$TMP_FILE" "$SETTINGS_FILE"
    log "Added editor.formatOnSave"
fi

# Check if defaultFormatter is already there
if grep -q '"editor.defaultFormatter"' "$SETTINGS_FILE"; then
    log "editor.defaultFormatter already configured"
else
    info "Adding editor.defaultFormatter..."
    # Already handled in the Python block above, but we check again
    # in case only one of the two was present
    TMP_FILE=$(mktemp)
    python3 - "$SETTINGS_FILE" "$TMP_FILE" << 'PYEOF'
import json
import sys

settings_file = sys.argv[1]
tmp_file = sys.argv[2]

with open(settings_file, 'r') as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        data = {}

data["editor.formatOnSave"] = True
data["editor.defaultFormatter"] = "esbenp.prettier-vscode"

with open(tmp_file, 'w') as f:
    json.dump(data, f, indent=4)
PYEOF
    mv "$TMP_FILE" "$SETTINGS_FILE"
    log "Added editor.defaultFormatter"
fi

# ============= DONE =============
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        PRETTIER SETUP COMPLETE                                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
log "Prettier is installed and configured"
log "Format on save is enabled"
log "Default formatter is set to Prettier"
echo ""
info "Restart VS Code for changes to take effect"
info "Then open any .html file and press Cmd+S to test"
echo ""