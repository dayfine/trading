#!/bin/sh
# r2_bars_test.sh -- regression test for dev/scripts/r2_bars.sh (issue #3476).
# Runs offline: R2_LOCAL_STORE swaps the bucket for a temp directory. The
# fixture is two invented symbols; no market data is read or committed.
#
# What it pins:
#   - push then pull restores the tree byte for byte;
#   - push refuses to overwrite an archive unless --force;
#   - pull without --name takes the newest archive by key;
#   - a corrupted archive fails the sha256 check (exit 2) and unpacks nothing;
#   - pull refuses a non-empty destination;
#   - pull --manifest exits 0 on a matching manifest and 1 on a changed one;
#   - credentials missing from env and env file are an error naming the var.
#
# Run:
#   sh trading/devtools/checks/r2_bars_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

PASS=0
FAILED=0

expect_eq() {
  if [ "$2" = "$3" ]; then
    printf 'OK: %s\n' "$1"; PASS=$((PASS + 1))
  else
    printf 'FAIL: %s: expected '\''%s'\'', got '\''%s'\''\n' "$1" "$2" "$3" >&2; FAILED=$((FAILED + 1))
  fi
}

SCRIPT="$(repo_root)/dev/scripts/r2_bars.sh"
MANIFEST="$(repo_root)/dev/scripts/data_manifest.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/r2_bars_test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
export R2_LOCAL_STORE="$TMP/bucket"

mk_symbol() { # mk_symbol DIR L1 L2 SYM CLOSE
  d="$1/$2/$3/$4"
  mkdir -p "$d"
  printf 'date,open,high,low,close,adjusted_close,volume\n2020-01-02,10,11,9,%s,%s,100\n' \
    "$5" "$5" >"$d/data.csv"
}

mk_symbol "$TMP/src" A A AAA 10.5
mk_symbol "$TMP/src" Z D ZED 20.25
printf 'name,sector\n' >"$TMP/src/sectors.csv"

rc_of() { rc=0; "$@" >"$TMP/out" 2>&1 || rc=$?; echo "$rc"; }

expect_eq "push exits 0" 0 "$(rc_of sh "$SCRIPT" push --data-dir "$TMP/src" --name data-20200101)"
expect_eq "push refuses to overwrite" 2 \
  "$(rc_of sh "$SCRIPT" push --data-dir "$TMP/src" --name data-20200101)"
expect_eq "push --force overwrites" 0 \
  "$(rc_of sh "$SCRIPT" push --data-dir "$TMP/src" --name data-20200101 --force)"
expect_eq "ls lists the archive" "bars/data-20200101.tar.gz" \
  "$(sh "$SCRIPT" ls | cut -d' ' -f1)"

expect_eq "pull exits 0" 0 "$(rc_of sh "$SCRIPT" pull --dest "$TMP/dst1")"
expect_eq "pull restores the tree" "" "$(diff -r "$TMP/src" "$TMP/dst1" || echo differs)"
expect_eq "pull refuses a non-empty destination" 2 \
  "$(rc_of sh "$SCRIPT" pull --dest "$TMP/dst1")"

mk_symbol "$TMP/src" B B BBB 30
sh "$SCRIPT" push --data-dir "$TMP/src" --name data-20200201 >/dev/null 2>&1
sh "$SCRIPT" pull --dest "$TMP/dst2" >/dev/null 2>&1
expect_eq "pull takes the newest archive" yes "$([ -d "$TMP/dst2/B/B/BBB" ] && echo yes || echo no)"

sh "$MANIFEST" build --data-dir "$TMP/src" --cutoff 2020-12-31 --out "$TMP/good.manifest" >/dev/null
expect_eq "pull --manifest matches" 0 \
  "$(rc_of sh "$SCRIPT" pull --dest "$TMP/dst3" --manifest "$TMP/good.manifest")"
mk_symbol "$TMP/src" A A AAA 99
sh "$MANIFEST" build --data-dir "$TMP/src" --cutoff 2020-12-31 --out "$TMP/bad.manifest" >/dev/null
expect_eq "pull --manifest mismatch exits 1" 1 \
  "$(rc_of sh "$SCRIPT" pull --dest "$TMP/dst4" --manifest "$TMP/bad.manifest")"
expect_eq "mismatch names the symbol" yes "$(grep -q AAA "$TMP/out" && echo yes || echo no)"

printf 'garbage' >>"$R2_LOCAL_STORE/bars/data-20200201.tar.gz"
expect_eq "corrupt archive fails sha256" 2 "$(rc_of sh "$SCRIPT" pull --dest "$TMP/dst5")"
expect_eq "corrupt archive unpacks nothing" no "$([ -e "$TMP/dst5" ] && echo yes || echo no)"

expect_eq "missing credential is an error" yes "$(
  rc=0
  env -u R2_LOCAL_STORE -u R2_ACCESS_KEY_ID R2_ENV="$TMP/none.env" \
    sh "$SCRIPT" ls >"$TMP/out" 2>&1 || rc=$?
  [ "$rc" = 2 ] && grep -q R2_ACCESS_KEY_ID "$TMP/out" && echo yes || echo no)"

printf 'r2_bars_test: %d passed, %d failed\n' "$PASS" "$FAILED"
[ "$FAILED" -eq 0 ]
