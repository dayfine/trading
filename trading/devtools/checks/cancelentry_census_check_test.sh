#!/bin/sh
# Fixture test for cancelentry_census_check.sh: GREEN on the real tree, RED on
# an added production site and on a removed one; arms/tests/.mli do not count.
. "$(dirname "$0")/_check_lib.sh"
here="$(cd "$(dirname "$0")" && pwd)"
chk="$here/cancelentry_census_check.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
expect() { # name want_rc root pattern
  out=$(sh "$chk" "$3" 2>&1); rc=$?
  if [ "$rc" != "$2" ]; then echo "FAIL: $1: rc=$rc want $2"; echo "$out"; fail=1; return; fi
  if [ -n "$4" ] && ! echo "$out" | grep -q "$4"; then
    echo "FAIL: $1: output lacks '$4'"; echo "$out"; fail=1; return
  fi
  echo "ok: $1"
}
expect "real tree" 0 "$(repo_root)"

mk() { # dir: one known site, plus noise that must not count
  mkdir -p "$1/trading/trading/a/lib" "$1/trading/trading/a/test"
  echo 'let t = { kind = Position.CancelEntry { reason = r } }' > "$1/trading/trading/a/lib/known.ml"
  echo '  | Position.CancelEntry { reason } -> reason' > "$1/trading/trading/a/lib/arm.ml"
  echo 'let t = CancelEntry { reason = r }' > "$1/trading/trading/a/test/test_x.ml"
  echo '(** [CancelEntry] docs *)' > "$1/trading/trading/a/lib/known.mli"
}
export CANCELENTRY_KNOWN='trading/trading/a/lib/known.ml:1'
mk "$tmp/ok"; expect "fixture green (arm, test, mli ignored)" 0 "$tmp/ok"
mk "$tmp/add"
echo 'let t = { kind = Position.CancelEntry { reason = r } }' > "$tmp/add/trading/trading/a/lib/third.ml"
expect "third production site" 1 "$tmp/add" 'NEW.*a/lib/third.ml:1'
mk "$tmp/gone"; rm "$tmp/gone/trading/trading/a/lib/known.ml"
expect "removed site" 1 "$tmp/gone" 'MISSING.*a/lib/known.ml:1'
mk "$tmp/multi"
printf 'let t =\n  { kind =\n      Position.CancelEntry\n        { reason = r } }\n' > "$tmp/multi/trading/trading/a/lib/third.ml"
expect "multi-line construction" 1 "$tmp/multi" 'NEW.*a/lib/third.ml:1'
mk "$tmp/rhs"
echo '  | A -> Position.CancelEntry { reason = r }' > "$tmp/rhs/trading/trading/a/lib/third.ml"
expect "arm-RHS construction" 1 "$tmp/rhs" 'NEW.*a/lib/third.ml:1'
mk "$tmp/lhs"
printf 'let f = function\n  | Position.CancelEntry\n      { reason } -> reason\n  | CancelEntry { reason } | Other { reason } -> reason\n(* CancelEntry { reason = c } *)\n' > "$tmp/lhs/trading/trading/a/lib/third.ml"
expect "arm-LHS pattern and comment ignored" 0 "$tmp/lhs"
mk "$tmp/rhs2"
printf 'let f = function\n  | A -> Position.CancelEntry { reason = r }\n  | B -> x\n' > "$tmp/rhs2/trading/trading/a/lib/third.ml"
expect "arm-RHS followed by another arm" 1 "$tmp/rhs2" 'NEW.*a/lib/third.ml:1'
mk "$tmp/pipe"
printf 'let f r = CancelEntry { reason = r } |> Option.some\n' > "$tmp/pipe/trading/trading/a/lib/third.ml"
expect "piped construction" 1 "$tmp/pipe" 'NEW.*a/lib/third.ml:1'
mk "$tmp/orpat"
printf 'let f = function\n  | Other _ | Position.CancelEntry { reason } -> reason\n  | B -> x\n' > "$tmp/orpat/trading/trading/a/lib/third.ml"
expect "or-pattern LHS ignored" 0 "$tmp/orpat"
mk "$tmp/arr"
printf 'let f r = [| CancelEntry { reason = r } |]\n' > "$tmp/arr/trading/trading/a/lib/third.ml"
expect "array-literal construction" 1 "$tmp/arr" 'NEW.*a/lib/third.ml:1'
mk "$tmp/arr2"
printf 'let f r =\n  [|\n    CancelEntry { reason = r }\n  |]\n' > "$tmp/arr2/trading/trading/a/lib/third.ml"
expect "array-literal, [| at end of previous line" 1 "$tmp/arr2" 'NEW.*a/lib/third.ml:1'
exit $fail
