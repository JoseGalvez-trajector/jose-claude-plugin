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

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Detect which plugins have staged changes by looking at staged file paths
# Matches files under plugins/<plugin-name>/
AFFECTED_PLUGINS=$(git diff --cached --name-only | \
  grep '^plugins/' | \
  sed 's|^plugins/\([^/]*\)/.*|\1|' | \
  sort -u || true)

[[ -z "$AFFECTED_PLUGINS" ]] && exit 0

# Bump version for each affected plugin
BUMPED_ANY=0
while IFS= read -r PLUGIN_NAME; do
  CURRENT_VERSION=$(jq -r --arg name "$PLUGIN_NAME" \
    '.plugins[] | select(.name == $name) | .version' "$MARKETPLACE_FILE")

  [[ -z "$CURRENT_VERSION" || "$CURRENT_VERSION" == "null" ]] && continue

  case "$BUMP" in
    major) NEW_VERSION=$(printf '%s' "$CURRENT_VERSION" | awk -F. '{print $1+1".0.0"}') ;;
    minor) NEW_VERSION=$(printf '%s' "$CURRENT_VERSION" | awk -F. '{print $1"."$2+1".0"}') ;;
    patch) NEW_VERSION=$(printf '%s' "$CURRENT_VERSION" | awk -F. '{print $1"."$2"."$3+1}') ;;
  esac

  TMPFILE=$(mktemp)
  jq --arg name "$PLUGIN_NAME" --arg v "$NEW_VERSION" \
    '(.plugins[] | select(.name == $name) | .version) = $v' \
    "$MARKETPLACE_FILE" > "$TMPFILE"
  mv "$TMPFILE" "$MARKETPLACE_FILE"

  echo "auto-version: [$PLUGIN_NAME] $CURRENT_VERSION → $NEW_VERSION ($BUMP bump for '$COMMIT_TYPE')" >&2
  BUMPED_ANY=1
done <<< "$AFFECTED_PLUGINS"

# Stage the updated file if any plugin was bumped
if [[ "$BUMPED_ANY" -eq 1 ]]; then
  git add "$REPO_ROOT/.claude-plugin/marketplace.json"
fi
