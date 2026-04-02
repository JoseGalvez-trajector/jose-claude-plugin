#!/usr/bin/env bash
set -euo pipefail

# Git commit-msg hook — $1 is the commit message temp file
MARKETPLACE_FILE="$(git rev-parse --show-toplevel)/.claude-plugin/marketplace.json"

# Guard: jq required
command -v jq >/dev/null 2>&1 || exit 0

[[ ! -f "$1" ]] && exit 0
[[ ! -f "$MARKETPLACE_FILE" ]] && exit 0

COMMIT_MSG=$(grep -v '^#' "$1" | head -1)
[[ -z "$COMMIT_MSG" ]] && exit 0

# Enforce conventional commit format
CONVENTIONAL_PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: .+'
if ! printf '%s' "$COMMIT_MSG" | grep -qE "$CONVENTIONAL_PATTERN"; then
  echo "" >&2
  echo "❌ Invalid commit message format." >&2
  echo "" >&2
  echo "   Expected: <type>[optional scope]: <description>" >&2
  echo "   Example:  feat(auth): add login support" >&2
  echo "" >&2
  echo "   Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert" >&2
  echo "   Breaking change: append '!' after type/scope, e.g. feat!: drop Node 16 support" >&2
  echo "" >&2
  echo "   Your message: $COMMIT_MSG" >&2
  echo "" >&2
  exit 1
fi

# Detect BREAKING CHANGE — covers both feat!: and feat(scope)!:
IS_BREAKING=0
if printf '%s' "$COMMIT_MSG" | grep -qE '^[a-z]+(\(.+\))?!:'; then
  IS_BREAKING=1
fi
if grep -qE '^BREAKING CHANGE:' "$1" 2>/dev/null; then
  IS_BREAKING=1
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
