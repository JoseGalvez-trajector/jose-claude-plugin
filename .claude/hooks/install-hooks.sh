#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
chmod +x "$REPO_ROOT/.claude/hooks/auto-version.sh"
ln -sf "../../.claude/hooks/auto-version.sh" "$REPO_ROOT/.git/hooks/commit-msg"
echo "Git hooks installed: commit-msg -> .claude/hooks/auto-version.sh"
