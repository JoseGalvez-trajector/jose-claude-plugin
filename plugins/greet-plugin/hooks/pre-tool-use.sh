#!/usr/bin/env bash
# PreToolUse hook — receives JSON on stdin
# Exit 0 = allow, Exit 2 = block (stderr message shown to user)

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)

# Warn if a Bash command contains rm -rf
if [ "$tool_name" = "Bash" ]; then
  command=$(echo "$input" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)
  if echo "$command" | grep -q "rm -rf"; then
    echo "⚠️  jose-plugin: Detected 'rm -rf' in command. Please confirm this is intentional." >&2
    exit 2
  fi
fi

exit 0
