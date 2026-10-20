#!/usr/bin/env bash
# mutate.sh <file> <sed-expression> <test command...>
#
# Applies the mutation FIRST, then runs the tests, then restores the file
# byte-for-byte (always, even on Ctrl-C).
#   exit 0  KILLED    tests failed with the mutation: they guard this line
#   exit 1  SURVIVED  tests still pass: they do NOT guard this line
#   exit 3  REFUSED   the expression changed nothing: not a mutation
#   exit 4  BROKEN    could not restore the file (look at it now)
# Portable sed: no `sed -i`, which differs between macOS and Linux.
set -uo pipefail
[ $# -ge 3 ] || { echo "usage: mutate.sh <file> <sed-expr> <test cmd...>" >&2; exit 64; }
file="$1"; expr="$2"; shift 2
[ -f "$file" ] || { echo "mutate: no such file: $file" >&2; exit 64; }

backup="$(mktemp)"; mutated="$(mktemp)"
cp -p "$file" "$backup"
restore() {
  cat "$backup" > "$file"
  if ! cmp -s "$backup" "$file"; then
    echo "mutate: BROKEN — $file was not restored" >&2; exit 4
  fi
  rm -f "$backup" "$mutated"
}
trap restore EXIT INT TERM

sed -e "$expr" "$backup" > "$mutated" || { echo "mutate: bad sed expression" >&2; exit 64; }
if cmp -s "$backup" "$mutated"; then
  echo "mutate: REFUSED — '$expr' changed nothing in $file"
  exit 3
fi
cat "$mutated" > "$file"
echo "mutate: applied to $file:"
diff "$backup" "$file" | sed -n 's/^[<>] /  /p'

"$@" > /dev/null 2>&1
rc=$?
if [ $rc -eq 0 ]; then
  echo "mutate: SURVIVED — tests passed with the mutation in place"
  exit 1
fi
echo "mutate: KILLED — tests failed (exit $rc) with the mutation"
exit 0
