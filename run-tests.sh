#!/usr/bin/env bash
# Run the toy tests. Fails if they fail OR if zero tests ran (a green that
# tested nothing is not green). -B: never write .pyc, so a mutate-and-revert
# inside one second cannot leave stale bytecode behind.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
out="$(python3 -B -m unittest discover -s "$here/toy" -t "$here/toy" 2>&1)"
rc=$?
printf '%s\n' "$out" | tail -3
ran="$(printf '%s\n' "$out" | sed -n 's/^Ran \([0-9]*\) test.*/\1/p')"
if [ "${ran:-0}" -eq 0 ]; then
  echo "run-tests: REFUSED — zero tests ran" >&2
  exit 2
fi
exit $rc
