#!/bin/bash

# Script to add a GitHub remote with custom SSH host and set personal git config
# Usage: git-setup-personal <github-ssh-url>

set -e

# Check if URL is provided
if [ -z "$1" ]; then
    echo "Error: GitHub SSH URL is required"
    echo "Usage: $0 git@github.com:username/repo.git"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

GITHUB_URL="$1"

# Validate it's a GitHub SSH URL
if [[ ! "$GITHUB_URL" =~ ^git@github\.com: ]]; then
    echo "Error: URL must be a GitHub SSH URL (git@github.com:...)"
    exit 1
fi

# Replace git@github.com: with git@github-personal:
PERSONAL_URL="${GITHUB_URL/git@github.com:/git@github-personal:}"

echo "Original URL: $GITHUB_URL"
echo "Modified URL: $PERSONAL_URL"

# Check if origin already exists
if git remote get-url origin > /dev/null 2>&1; then
    echo ""
    read -p "Remote 'origin' already exists. Replace it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote remove origin
        echo "Removed existing origin"
    else
        echo "Aborted"
        exit 1
    fi
fi

# Add the new remote
git remote add origin "$PERSONAL_URL"
echo "✓ Added remote 'origin': $PERSONAL_URL"

# Set local git config
git config --local user.name "68mschmitt"
git config --local user.email "68mschmitt@gmail.com"

echo "✓ Set local git config:"
echo "  user.name: $(git config --local user.name)"
echo "  user.email: $(git config --local user.email)"

echo ""
echo "Setup complete!"
