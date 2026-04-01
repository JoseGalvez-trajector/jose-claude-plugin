#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE_FILE="$(git rev-parse --show-toplevel)/.claude-plugin/marketplace.json"

# Guard: jq required
command -v jq >/dev/null 2>&1 || exit 0

COMMIT_MSG=""

if [[ -n "${1:-}" && -f "$1" ]]; then
  # Mode 1: git commit-msg hook — $1 is the message temp file
  COMMIT_MSG=$(grep -v '^#' "$1" | head -1)
else
  # Mode 2: Claude Code PreToolUse — JSON on stdin
  if IFS= read -t 2 -r STDIN_LINE 2>/dev/null; then
    FULL_STDIN="$STDIN_LINE"
    while IFS= read -t 0.1 -r LINE 2>/dev/null; do
      FULL_STDIN+="$LINE"
    done
    BASH_CMD=$(printf '%s' "$FULL_STDIN" | jq -r '.tool_input.command // empty')
    if ! printf '%s' "$BASH_CMD" | grep -qE 'git commit'; then
      exit 0
    fi
    COMMIT_MSG=$(printf '%s' "$BASH_CMD" \
      | sed -n "s/.*-m '\([^']*\)'.*/\1/p; s/.*-m \"\([^\"]*\)\".*/\1/p" \
      | head -1)
  fi
fi

[[ -z "$COMMIT_MSG" ]] && exit 0
[[ ! -f "$MARKETPLACE_FILE" ]] && exit 0

# Detect BREAKING CHANGE
IS_BREAKING=0
if printf '%s' "$COMMIT_MSG" | grep -qE '^[a-z]+!:'; then
  IS_BREAKING=1
fi
if [[ -n "${1:-}" && -f "$1" ]]; then
  if grep -qE '^BREAKING CHANGE:' "$1" 2>/dev/null; then
    IS_BREAKING=1
  fi
fi

# Extract type
COMMIT_TYPE=$(printf '%s' "$COMMIT_MSG" | sed -n 's/^\([a-z]*\)[!:(].*/\1/p')

# Determine bump
BUMP=""
if [[ "$IS_BREAKING" -eq 1 ]]; then
  BUMP="major"
elif [[ "$COMMIT_TYPE" == "feat" ]]; then
  BUMP="minor"
elif [[ "$COMMIT_TYPE" =~ ^(fix|docs|perf|refactor)$ ]]; then
  BUMP="patch"
fi

[[ -z "$BUMP" ]] && exit 0

# Read current version
CURRENT_VERSION=$(jq -r '.plugins[0].version' "$MARKETPLACE_FILE")
[[ -z "$CURRENT_VERSION" || "$CURRENT_VERSION" == "null" ]] && exit 0

# Calculate new version
case "$BUMP" in
  major) NEW_VERSION=$(printf '%s' "$CURRENT_VERSION" | awk -F. '{print $1+1".0.0"}') ;;
  minor) NEW_VERSION=$(printf '%s' "$CURRENT_VERSION" | awk -F. '{print $1"."$2+1".0"}') ;;
  patch) NEW_VERSION=$(printf '%s' "$CURRENT_VERSION" | awk -F. '{print $1"."$2"."$3+1}') ;;
esac

# Write updated marketplace.json (safe in-place update)
TMPFILE=$(mktemp)
jq --arg v "$NEW_VERSION" '(.plugins[].version) = $v' "$MARKETPLACE_FILE" > "$TMPFILE"
mv "$TMPFILE" "$MARKETPLACE_FILE"

# Stage the updated file
git add "$(git rev-parse --show-toplevel)/.claude-plugin/marketplace.json"

echo "auto-version: $CURRENT_VERSION → $NEW_VERSION ($BUMP bump for '$COMMIT_TYPE')" >&2
