#!/usr/bin/env bash
# PostToolUse hook — receives JSON on stdin, runs after a tool completes
# Log each tool call to a simple audit file

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null)
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log_file="${HOME}/.claude/jose-plugin-audit.log"
echo "${timestamp} [jose-plugin] tool_used=${tool_name}" >> "$log_file"

exit 0
