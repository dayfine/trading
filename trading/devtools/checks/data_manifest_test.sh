#!/bin/sh
# data_manifest_test.sh -- regression test for dev/scripts/data_manifest.sh
# (issue #3476). The fixture is generated here from invented numbers (three
# made-up symbols); no market data is read or committed.
#
# What it pins:
#   - the same data in different number formatting gives the same root;
#   - a changed close makes `compare` exit 1 and name exactly that symbol;
#   - rows after the cutoff, adjusted_close and active_through do not move a
#     leaf; a row at or before the cutoff does;
#   - a missing splits file equals a header-only one;
#   - symbols present on one side only are listed under only-in-A / only-in-B;
#   - --symbols restricts the manifest; output is LC_ALL=C sorted.
#
# Run:
#   sh trading/devtools/checks/data_manifest_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="data_manifest_test"
PASS=0
FAILED=0

expect_eq() {
  if [ "$2" = "$3" ]; then
    printf 'OK: %s\n' "$1"; PASS=$((PASS + 1))
  else
    printf 'FAIL: %s: expected '\''%s'\'', got '\''%s'\''\n' "$1" "$2" "$3" >&2; FAILED=$((FAILED + 1))
  fi
}

SCRIPT="$(repo_root)/dev/scripts/data_manifest.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/data_manifest_test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

CUTOFF=2020-01-03
HDR='date,open,high,low,close,adjusted_close,volume,active_through'

# mk_symbol DIR L1 L2 SYM: invented rows, one after the cutoff.
mk_symbol() {
  d="$1/$2/$3/$4"
  mkdir -p "$d"
  {
    echo "$HDR"
    echo "2020-01-01,10.5,11.0,10.0,10.75,10.1,1000,2020-01-03"
    echo "2020-01-02,10.75,12.25,10.5,12.0,11.5,2500,2020-01-03"
    echo "2020-01-03,12.0,12.5,11.5,12.125,11.9,1800,2020-01-03"
    echo "2020-01-06,12.1,13.0,12.0,12.9,12.7,900,2020-01-03"
  } >"$d/data.csv"
  printf 'date,factor\n2020-01-02,2.0/1.0\n' >"$d/splits.csv"
  printf 'ex_date,unadjusted_amount,adjusted_amount\n2020-01-02,0.25,0.125\n' >"$d/dividends.csv"
}

mk_fixture() {
  mk_symbol "$1" A A AAA
  mk_symbol "$1" A Z ABZ
  mk_symbol "$1" Z D ZED
}

build() { # build FIXTURE OUT [extra args]
  fx=$1; out=$2; shift 2
  sh "$SCRIPT" build --data-dir "$fx" --cutoff "$CUTOFF" --out "$out" "$@" >/dev/null
}

root_of() { awk '$1 == "#" && $2 == "root" { print $3 }' "$1"; }
leaf_of() { awk -v s="$2" '$1 == s { print $2 }' "$1"; }

cmp_rc() { # cmp_rc A B -> sets rc and writes $TMP/cmp.out
  rc=0; sh "$SCRIPT" compare "$1" "$2" >"$TMP/cmp.out" 2>&1 || rc=$?
}

mk_fixture "$TMP/base"
build "$TMP/base" "$TMP/base.txt"
build "$TMP/base" "$TMP/base2.txt"
expect_eq "build is deterministic" "$(cat "$TMP/base.txt")" "$(cat "$TMP/base2.txt")"
expect_eq "header holds cutoff" "# cutoff $CUTOFF" "$(sed -n 2p "$TMP/base.txt")"
expect_eq "header holds symbol count" "# symbols 3" "$(grep '^# symbols' "$TMP/base.txt")"
expect_eq "leaves are sorted by symbol" "AAA ABZ ZED" "$(grep -v '^#' "$TMP/base.txt" | cut -d' ' -f1 | tr '\n' ' ' | sed 's/ $//')"

# Same data, different number formatting + irrelevant columns changed.
cp -R "$TMP/base" "$TMP/fmt"
sed -i.bak -e 's/10\.5,/10.500000,/; s/12\.0,/12,/; s/,1000,/,01000,/; s/,10\.1,/,99.9,/; s/2020-01-03$/2021-05-05/' "$TMP/fmt/A/A/AAA/data.csv"
sed -i.bak -e 's/2\.0\/1\.0/2.000000\/1.000000/' "$TMP/fmt/A/A/AAA/splits.csv"
sed -i.bak -e 's/0\.25,0\.125/0.250000,7.0/' "$TMP/fmt/A/A/AAA/dividends.csv"
find "$TMP/fmt" -name '*.bak' -exec rm -f {} +
build "$TMP/fmt" "$TMP/fmt.txt"
expect_eq "number format, adjusted_close, active_through, adjusted_amount do not move the root" "$(root_of "$TMP/base.txt")" "$(root_of "$TMP/fmt.txt")"
cmp_rc "$TMP/base.txt" "$TMP/fmt.txt"
expect_eq "compare exits 0 on equal roots" 0 "$rc"

# Row after the cutoff: no change. Row on the cutoff date changed: change.
cp -R "$TMP/base" "$TMP/late"
echo "2020-02-01,1,2,3,4,5,6,2020-01-03" >>"$TMP/late/A/Z/ABZ/data.csv"
echo "2020-02-01,3.0" >>"$TMP/late/A/Z/ABZ/splits.csv"
build "$TMP/late" "$TMP/late.txt"
expect_eq "rows after the cutoff do not change the leaf" "$(leaf_of "$TMP/base.txt" ABZ)" "$(leaf_of "$TMP/late.txt" ABZ)"

# A changed close names that symbol only.
cp -R "$TMP/base" "$TMP/chg"
sed -i.bak 's/12\.125,11\.9/12.126,11.9/' "$TMP/chg/A/Z/ABZ/data.csv"
rm -f "$TMP/chg/A/Z/ABZ/data.csv.bak"
build "$TMP/chg" "$TMP/chg.txt"
cmp_rc "$TMP/base.txt" "$TMP/chg.txt"
expect_eq "changed close: compare exits 1" 1 "$rc"
expect_eq "changed close: names only that symbol under different leaf" "  ABZ" "$(sed -n '/^different leaf:/,$p' "$TMP/cmp.out" | sed 1d)"
expect_eq "changed close: other leaves unchanged" "$(leaf_of "$TMP/base.txt" AAA)" "$(leaf_of "$TMP/chg.txt" AAA)"

# Missing splits file == header-only splits file.
cp -R "$TMP/base" "$TMP/nosplit"
cp -R "$TMP/base" "$TMP/hdrsplit"
rm "$TMP/nosplit/Z/D/ZED/splits.csv"
echo 'date,factor' >"$TMP/hdrsplit/Z/D/ZED/splits.csv"
build "$TMP/nosplit" "$TMP/nosplit.txt"
build "$TMP/hdrsplit" "$TMP/hdrsplit.txt"
expect_eq "missing splits file equals header-only splits" "$(leaf_of "$TMP/nosplit.txt" ZED)" "$(leaf_of "$TMP/hdrsplit.txt" ZED)"
expect_eq "dropping splits rows changes the leaf" 1 "$([ "$(leaf_of "$TMP/nosplit.txt" ZED)" != "$(leaf_of "$TMP/base.txt" ZED)" ] && echo 1 || echo 0)"

# Symbol only on one side.
cp -R "$TMP/base" "$TMP/extra"
mk_symbol "$TMP/extra" Q Q QQQ
build "$TMP/extra" "$TMP/extra.txt"
cmp_rc "$TMP/base.txt" "$TMP/extra.txt"
expect_eq "extra symbol: compare exits 1" 1 "$rc"
expect_eq "extra symbol: listed only in B" "  QQQ" "$(sed -n '/^only in B:/,/^different leaf:/p' "$TMP/cmp.out" | sed '1d;$d')"
cmp_rc "$TMP/extra.txt" "$TMP/base.txt"
expect_eq "extra symbol: listed only in A when swapped" "  QQQ" "$(sed -n '/^only in A:/,/^only in B:/p' "$TMP/cmp.out" | sed '1d;$d')"

# --symbols restricts the manifest.
printf '# keep\nAAA\n\nZED\n' >"$TMP/syms.txt"
build "$TMP/base" "$TMP/sub.txt" --symbols "$TMP/syms.txt"
expect_eq "--symbols keeps only the listed symbols" "AAA ZED" "$(grep -v '^#' "$TMP/sub.txt" | cut -d' ' -f1 | tr '\n' ' ' | sed 's/ $//')"

# Usage error.
rc=0; sh "$SCRIPT" build --data-dir "$TMP/base" >/dev/null 2>&1 || rc=$?
expect_eq "missing build args is a usage error" 2 "$rc"

printf '=== Results: %s passed, %s failed ===\n' "$PASS" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  printf 'FAIL: %s -- %s assertion(s) failed.\n' "$LABEL" "$FAILED" >&2
  exit 1
fi
printf 'OK: %s -- all %s assertions passed.\n' "$LABEL" "$PASS"
