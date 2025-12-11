#!/usr/bin/env bash

# setup-git-autocommit.sh
# Setup script for git-autocommit.sh
# Configures git-autocommit as a global git alias

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOCOMMIT_SCRIPT="${SCRIPT_DIR}/git-autocommit.sh"

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Git Auto-Commit Setup                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Check if git-autocommit.sh exists
if [[ ! -f "${AUTOCOMMIT_SCRIPT}" ]]; then
    echo -e "${RED}[ERROR]${NC} git-autocommit.sh not found at ${AUTOCOMMIT_SCRIPT}"
    exit 1
fi

# Make git-autocommit.sh executable
echo -e "${BLUE}[INFO]${NC} Making git-autocommit.sh executable..."
chmod +x "${AUTOCOMMIT_SCRIPT}"

# Check for required commands
echo -e "${BLUE}[INFO]${NC} Checking prerequisites..."
missing_cmds=()
for cmd in git curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
        missing_cmds+=("$cmd")
    fi
done

if [[ ${#missing_cmds[@]} -gt 0 ]]; then
    echo -e "${YELLOW}[WARN]${NC} Missing required commands: ${missing_cmds[*]}"
    echo "Please install these commands before using git-autocommit"
fi

# Configure git alias
echo -e "${BLUE}[INFO]${NC} Configuring global git alias..."
if git config --global alias.ac "!${AUTOCOMMIT_SCRIPT}"; then
    echo -e "${GREEN}[SUCCESS]${NC} Git alias configured successfully"
else
    echo -e "${RED}[ERROR]${NC} Failed to configure git alias"
    exit 1
fi

# Create default config file if it doesn't exist
CONFIG_FILE="${SCRIPT_DIR}/.git-autocommit.conf"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo -e "${BLUE}[INFO]${NC} Creating default configuration file..."
    cat > "${CONFIG_FILE}" << 'EOF'
# git-autocommit configuration file
# Customize these values to fit your preferences

# Ollama model to use for commit message generation
MODEL="qwen2.5-coder:14b"

# Maximum number of diff lines to process
MAX_DIFF_LINES=500

# Maximum number of characters in diff context
MAX_CONTEXT_CHARS=8000

# Ollama API URL
OLLAMA_API_URL="http://localhost:11434/api/generate"

# API timeout in seconds
OLLAMA_TIMEOUT=30

# Commit message formatting
COMMIT_SUBJECT_MAX_LENGTH=50
COMMIT_BODY_WRAP_LENGTH=72

# AI generation parameters
TEMPERATURE=0.7
MAX_TOKENS=200

# Fallback message configuration
FALLBACK_MESSAGE_PREFIX="Auto-commit"
FALLBACK_MESSAGE_FORMAT="%Y-%m-%d %H:%M:%S"
EOF
    echo -e "${GREEN}[SUCCESS]${NC} Configuration file created at ${CONFIG_FILE}"
    echo -e "${YELLOW}[INFO]${NC} You can edit this file to customize the behavior"
else
    echo -e "${BLUE}[INFO]${NC} Configuration file already exists at ${CONFIG_FILE}"
fi

# Display success information
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installation Complete!                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Usage:${NC}"
echo "  git ac                      # Generate and commit staged changes"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  ${CONFIG_FILE}"
echo ""
echo -e "${BLUE}Requirements:${NC}"
echo "  - Ollama must be running (http://localhost:11434)"
echo "  - Model '${MODEL:-qwen2.5-coder:14b}' must be installed"
echo ""
echo -e "${BLUE}To test:${NC}"
echo "  1. Stage some changes: git add <files>"
echo "  2. Run: git ac"
echo ""
