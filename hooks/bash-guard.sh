#!/usr/bin/env bash
# bash-guard.sh — a Claude Code PreToolUse hook for the Bash tool.
# Claude Code sends the tool call as JSON on stdin. To deny it, print a deny
# decision with the reason (the agent reads the reason and adjusts); print
# nothing to allow. Fails closed: input it cannot parse is denied.
set -uo pipefail

deny() {
  python3 -c 'import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
  "permissionDecision": "deny", "permissionDecisionReason": sys.argv[1]}}))' "$1"
  exit 0
}

cmd="$(python3 -c 'import json, sys
print(json.load(sys.stdin)["tool_input"]["command"])' 2>/dev/null)" \
  || deny "bash-guard: could not read the tool call, so it is refused (fail closed)."

# 1. Broad staging sweeps unrelated files into a commit.
if printf '%s' "$cmd" | grep -Eq '(^|[;&| ])git( +-C +[^ ]+)? +add( +[^ ]+)* +(-A|--all|\.)( |$)'; then
  deny "Stage named files (git add path/one path/two), not -A, --all or '.'."
fi

# 2. Skipping or re-pointing the hooks turns the push gate off.
if printf '%s' "$cmd" | grep -Eq '(^|[;&| ])git .*(--no-verify|core\.hooksPath)'; then
  deny "This skips the pre-push gate. A gate whose 'no' can be ignored is decoration: fix what it refused instead."
fi

# 3. 'check | tail' reports tail's exit code, so a failing check looks green.
if printf '%s' "$cmd" | grep -Eq '(pytest|unittest|run-tests|npm( run)? test|vitest|ruff|eslint|mypy|tsc)[^|;&]*\| *(tail|head)' \
   && ! printf '%s' "$cmd" | grep -q 'pipefail'; then
  deny "'<check> | tail' returns tail's exit code, so a failure reads as success. Redirect to a log, read \$?, then tail the log."
fi
exit 0
