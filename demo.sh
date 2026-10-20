#!/usr/bin/env bash
# demo.sh — the whole pattern in about 90 seconds.
#   bash demo.sh          all three parts
#   bash demo.sh 2        one part only (1, 2 or 3)
#   PAUSE=1 bash demo.sh  wait for Enter between steps (for a live talk)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
cd "$here" || exit 2
only="${1:-all}"
fails=0
expect() {  # expect <wanted-exit> <got-exit> <label>: a demo that lies is worse than none
  [ "$1" -eq "$2" ] && return 0
  printf '  %sDEMO FAILED: %s gave exit %s, expected %s%s\n' "$R" "$3" "$2" "$1" "$N"
  fails=$((fails + 1))
}
B=$'\033[1m'; R=$'\033[31m'; G=$'\033[32m'; D=$'\033[2m'; N=$'\033[0m'

title() { printf '\n%s━━ %s%s\n\n' "$B" "$1" "$N"; }
pause() { [ "${PAUSE:-0}" = "1" ] && { printf '%s  [enter]%s' "$D" "$N"; read -r _; }; return 0; }
want()  { [ "$only" = all ] || [ "$only" = "$1" ]; }

ask_guard() {  # show the agent's command, then what the hook says
  local json out reason
  json="$(python3 -c 'import json, sys; print(json.dumps({"tool_input": {"command": sys.argv[1]}}))' "$1")"
  out="$(printf '%s' "$json" | bash "$here/hooks/bash-guard.sh")"
  printf '  agent wants:  %s%s%s\n' "$B" "$1" "$N"
  if [ -z "$out" ]; then printf '  hook:         %sALLOWED%s\n\n' "$G" "$N"; return; fi
  reason="$(printf '%s' "$out" | python3 -c 'import json, sys
print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"])')"
  printf '  hook:         %sDENIED%s\n' "$R" "$N"
  printf '%s\n\n' "$reason" | fold -s -w 56 | sed 's/^/                /'
}

if want 1; then
  title "1. The hook says no, and says why"
  ask_guard 'git push --no-verify'
  ask_guard 'pytest -q | tail -5'
  ask_guard 'git push origin main'
  out="$(bash "$here/hooks/test-bash-guard.sh")"; rc=$?
  printf '  %s (exit %s)\n' "$(printf '%s\n' "$out" | tail -1)" "$rc"
  expect 0 "$rc" "guard tests"
  pause
fi

if want 2; then
  title "2. Prove the test guards the line: break it on purpose"
  printf '  the tests, as written:\n'
  bash "$here/run-tests.sh" > /dev/null 2>&1; rc=$?
  printf '    exit %s  %s\n\n' "$rc" "$([ $rc -eq 0 ] && echo "${G}green${N}" || echo "${R}red${N}")"
  expect 0 "$rc" "tests as written"
  pause
  printf '  one-character bug: store the name with a hyphen\n'
  bash mutate.sh toy/certs.py 's/^LEXICON = \["pmi acp"/LEXICON = ["pmi-acp"/' \
    bash run-tests.sh 2>&1 | sed 's/^/    /'
  expect 0 "${PIPESTATUS[0]}" "the real bug (should be KILLED)"
  printf '\n'
  pause
  printf '  a change no test can see:\n'
  bash mutate.sh toy/certs.py 's/"cka"\]/"cka", "zzz"]/' \
    bash run-tests.sh 2>&1 | sed 's/^/    /'
  expect 1 "${PIPESTATUS[0]}" "the invisible change (should SURVIVE)"
  printf '\n  %sSURVIVED = a line your tests do not guard.%s\n' "$D" "$N"
  pause
fi

if want 3; then
  title "3. The push gate: every push, whoever wrote the code"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  mkdir "$tmp/work"
  tar -C "$here" --exclude .git -cf - . | tar -C "$tmp/work" -xf -
  g() { git -C "$tmp/work" -c user.name=demo -c user.email=demo@localhost "$@"; }
  git init -q --bare "$tmp/remote.git"
  g init -q -b main && g config core.hooksPath githooks
  g remote add origin "$tmp/remote.git"
  g add toy githooks run-tests.sh PROOF.md && g commit -q -m "baseline"
  g push -q origin main 2>/dev/null

  printf '  an agent changes the code, with no proof entry:\n'
  printf '\n# refactor\n' >> "$tmp/work/toy/certs.py"
  g commit -q -am "refactor certs"
  g push -q origin main 2>&1 | sed 's/^/    /'
  rc=${PIPESTATUS[0]}; printf '    push exit %s\n\n' "$rc"
  [ "$rc" -ne 0 ] || expect 1 0 "push with no proof entry (should be REFUSED)"
  pause

  printf '  it adds a proof entry, but the code is broken:\n'
  sed 's/^LEXICON = \["pmi acp"/LEXICON = ["pmi-acp"/' "$tmp/work/toy/certs.py" > "$tmp/c.py"
  cat "$tmp/c.py" > "$tmp/work/toy/certs.py"
  printf '\n## refactor\n- mutation: none\n' >> "$tmp/work/PROOF.md"
  g commit -q -am "refactor certs, with proof"
  g push -q origin main 2>&1 | grep -E 'REFUSED|FAIL' | sed 's/^/    /'
  rc=${PIPESTATUS[0]}; printf '    push exit %s\n\n' "$rc"
  [ "$rc" -ne 0 ] || expect 1 0 "push with failing tests (should be REFUSED)"
  remote="$(git -C "$tmp/remote.git" log --format=%s -1)"
  printf '  remote still at: %s\n' "$remote"
  [ "$remote" = baseline ] || expect 0 1 "remote should still be at baseline"
fi

[ $fails -eq 0 ] || { printf '\n%sdemo.sh: %s check(s) failed%s\n' "$R" "$fails" "$N"; exit 1; }
