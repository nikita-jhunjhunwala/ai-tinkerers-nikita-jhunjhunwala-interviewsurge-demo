#!/usr/bin/env bash
# test-bash-guard.sh — every rule has a command it must deny AND a close
# neighbour it must allow, so a guard that denies everything also fails.
set -uo pipefail
guard="$(cd "$(dirname "$0")" && pwd -P)/bash-guard.sh"
fails=0

check() {  # check deny|allow <command>
  local json out got
  json="$(python3 -c 'import json, sys; print(json.dumps({"tool_input": {"command": sys.argv[1]}}))' "$2")"
  out="$(printf '%s' "$json" | bash "$guard")"
  case "$out" in *'"deny"'*) got=deny ;; '') got=allow ;; *) got="?" ;; esac
  if [ "$got" = "$1" ]; then printf 'ok    %-5s  %s\n' "$1" "$2"
  else printf 'FAIL  %-5s  %s   (got %s)\n' "$1" "$2" "$got"; fails=$((fails + 1)); fi
}

check deny  'git add -A'
check deny  'git add --all'
check deny  'git add .'
check allow 'git add toy/certs.py PROOF.md'
check deny  'git push --no-verify'
check deny  'git -C ../other push --no-verify origin main'
check deny  'git -c core.hooksPath=/dev/null push'
check allow 'git push origin main'
check deny  'pytest -q | tail -5'
check deny  'bash run-tests.sh | tail -3'
check allow 'pytest -q > test.log 2>&1; echo "exit=$?"; tail -5 test.log'
check allow 'set -o pipefail; pytest -q | tail -5'
check allow 'git log --oneline | head -5'
check allow 'git status'

out="$(printf 'not json' | bash "$guard")"
case "$out" in *'"deny"'*) echo "ok    deny   <unparseable input>  (fails closed)" ;;
  *) echo "FAIL  deny   <unparseable input>"; fails=$((fails + 1)) ;; esac

[ $fails -eq 0 ] && echo "bash-guard: all cases hold" && exit 0
echo "bash-guard: $fails case(s) failed"; exit 1
