#!/usr/bin/env bash
# mutate-guard.sh — tests the mutation tool itself, with a positive and a
# negative control. A checker you have never seen fail is not a checker.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
target="$here/toy/certs.py"
before="$(mktemp)"; cp -p "$target" "$before"
fails=0

expect() {  # expect <exit> <label> <sed-expr>
  bash "$here/mutate.sh" "$target" "$3" bash "$here/run-tests.sh" > /dev/null 2>&1
  local rc=$?
  if [ $rc -eq "$1" ]; then echo "ok    $2 (exit $rc)"
  else echo "FAIL  $2: expected exit $1, got $rc"; fails=$((fails + 1)); fi
  if ! cmp -s "$before" "$target"; then
    echo "FAIL  $2: certs.py was not restored"; cp -p "$before" "$target"; fails=$((fails + 1))
  fi
}

expect 0 "real mutation is KILLED"        's/^LEXICON = \["pmi acp"/LEXICON = ["pmi-acp"/'
expect 1 "invisible mutation SURVIVES"    's/"cka"\]/"cka", "zzz"]/'
expect 3 "no-op expression is REFUSED"    's/this-text-is-not-in-the-file//'

rm -f "$before"
[ $fails -eq 0 ] && echo "mutate-guard: all controls hold" && exit 0
echo "mutate-guard: $fails control(s) failed"; exit 1
