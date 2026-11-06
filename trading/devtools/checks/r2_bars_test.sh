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
#   - credentials missing from env and env file are an error naming the var;
#   - the env file is parsed, never run, and the environment wins over it;
#   - a failed bucket listing exits 2 instead of reading as empty;
#   - R2_MAX_BYTES makes push refuse an oversized archive and store nothing;
#   - push-dir/pull-dir round-trip a warehouse directory under warehouse/,
#     not bars/ (issue #3535);
#   - pull-dir refuses a corrupted and a missing file (exit 1, names the
#     file, destination left absent); push-dir refuses overwrite and a file over
#     the limit (the limit is per file, not total); verify-dir flags an extra
#     file in an existing copy;
#   - --jobs N round-trips in parallel with progress lines; a failing transfer
#     exits non-zero, names the file and uploads no SHA256SUMS; push-dir
#     --resume completes an interrupted upload (skips same-size objects,
#     re-sends a wrong-size one) and pull-dir then verifies.
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

expect_eq "size limit refuses a large archive" 2 \
  "$(rc_of env R2_MAX_BYTES=10 sh "$SCRIPT" push --data-dir "$TMP/src" --name data-20200301)"
expect_eq "size limit stores nothing" no \
  "$([ -e "$R2_LOCAL_STORE/bars/data-20200301.tar.gz" ] && echo yes || echo no)"

# Env-file credentials: these run without R2_LOCAL_STORE, so the real loader
# reads the file. Endpoints point at a closed localhost port; nothing leaves
# the machine.
cat >"$TMP/three.env" <<EOF
export R2_ACCESS_KEY_ID="id-from-file"
R2_SECRET_ACCESS_KEY="\$(touch $TMP/PWNED)"
R2_ENDPOINT="http://127.0.0.1:19"
EOF
no_store() {
  env -u R2_LOCAL_STORE -u R2_ACCESS_KEY_ID -u R2_SECRET_ACCESS_KEY \
    -u R2_ENDPOINT -u R2_BUCKET "$@"
}
expect_eq "env file missing a var names it" yes "$(
  rc=0
  no_store R2_ENV="$TMP/three.env" sh "$SCRIPT" ls >"$TMP/out" 2>&1 || rc=$?
  [ "$rc" = 2 ] && grep -q 'R2_BUCKET is not set' "$TMP/out" && echo yes || echo no)"
expect_eq "env file values are never run" no "$([ -e "$TMP/PWNED" ] && echo yes || echo no)"

printf 'R2_BUCKET=b\n' >>"$TMP/three.env"
expect_eq "environment wins over the env file" yes "$(
  rc=0
  no_store R2_ENV="$TMP/three.env" R2_ENDPOINT=http://127.0.0.1:9 \
    sh "$SCRIPT" ls >"$TMP/out" 2>&1 || rc=$?
  [ "$rc" = 2 ] && grep -q "port 9 " "$TMP/out" && ! grep -q 'port 19' "$TMP/out" \
    && echo yes || echo no)"
expect_eq "failed listing is an error, not empty" yes "$(
  grep -q 'cannot list the bucket' "$TMP/out" && echo yes || echo no)"
expect_eq "quotes around env-file values are dropped" yes "$(
  rc=0
  no_store R2_ENV="$TMP/three.env" sh "$SCRIPT" ls >"$TMP/out" 2>&1 || rc=$?
  [ "$rc" = 2 ] && grep -q "port 19 " "$TMP/out" && echo yes || echo no)"
expect_eq "env file still never run after a full load" no \
  "$([ -e "$TMP/PWNED" ] && echo yes || echo no)"

# Snapshot warehouse directory (issue #3535): per-file objects under
# warehouse/<name>/ plus SHA256SUMS. Invented fixture, not market data.
mkdir -p "$TMP/wh"
printf 'snap-a' >"$TMP/wh/AAA.snap"
printf 'snap-z' >"$TMP/wh/ZED.snap"
printf '(manifest)' >"$TMP/wh/manifest.sexp"
expect_eq "push-dir exits 0" 0 "$(rc_of sh "$SCRIPT" push-dir --dir "$TMP/wh" --name wh1)"
expect_eq "push-dir stores under warehouse/, not bars/" yes \
  "$([ -f "$R2_LOCAL_STORE/warehouse/wh1/AAA.snap" ] && [ -f "$R2_LOCAL_STORE/warehouse/wh1/SHA256SUMS" ] \
     && [ ! -e "$R2_LOCAL_STORE/bars/wh1" ] && echo yes || echo no)"
expect_eq "push-dir refuses to overwrite" 2 \
  "$(rc_of sh "$SCRIPT" push-dir --dir "$TMP/wh" --name wh1)"
expect_eq "push-dir size limit refuses" 2 \
  "$(rc_of env R2_MAX_BYTES=3 sh "$SCRIPT" push-dir --dir "$TMP/wh" --name whbig)"
# Limit 11 sits between the largest file (10 bytes) and the total (22): only a
# per-file check lets this through.
expect_eq "push-dir limit is per file, not total" 0 \
  "$(rc_of env R2_MAX_BYTES=11 sh "$SCRIPT" push-dir --dir "$TMP/wh" --name whmid)"
expect_eq "pull-dir exits 0" 0 "$(rc_of sh "$SCRIPT" pull-dir --dest "$TMP/whd1" --name wh1)"
expect_eq "pull-dir restores the tree" "" "$(diff -r "$TMP/wh" "$TMP/whd1" || echo differs)"
expect_eq "pull-dir refuses a non-empty destination" 2 \
  "$(rc_of sh "$SCRIPT" pull-dir --dest "$TMP/whd1" --name wh1)"
expect_eq "verify-dir passes a good copy" 0 "$(rc_of sh "$SCRIPT" verify-dir --dir "$TMP/whd1" --name wh1)"
printf 'x' >"$TMP/whd1/EXTRA.snap"
expect_eq "verify-dir flags an extra file" 1 "$(rc_of sh "$SCRIPT" verify-dir --dir "$TMP/whd1" --name wh1)"
expect_eq "extra file is named" yes "$(grep -q 'extra: EXTRA.snap' "$TMP/out" && echo yes || echo no)"

printf 'bad' >"$R2_LOCAL_STORE/warehouse/wh1/ZED.snap"
expect_eq "pull-dir refuses a corrupted file" 1 "$(rc_of sh "$SCRIPT" pull-dir --dest "$TMP/whd2" --name wh1)"
expect_eq "corrupted file is named" yes "$(grep -q 'differs: ZED.snap' "$TMP/out" && echo yes || echo no)"
expect_eq "corrupted pull leaves no destination" no "$([ -e "$TMP/whd2" ] && echo yes || echo no)"
rm "$R2_LOCAL_STORE/warehouse/wh1/AAA.snap"
expect_eq "pull-dir refuses a missing file" 1 "$(rc_of sh "$SCRIPT" pull-dir --dest "$TMP/whd3" --name wh1)"
expect_eq "missing file is named" yes "$(grep -q 'missing: AAA.snap' "$TMP/out" && echo yes || echo no)"
expect_eq "missing-file pull leaves no destination" no "$([ -e "$TMP/whd3" ] && echo yes || echo no)"

# Parallel transfer and resume (this change). 12 files in a nested layout.
mkdir -p "$TMP/big/sub"
i=1
while [ "$i" -le 12 ]; do
  printf 'file-%s' "$i" >"$TMP/big/F$i.snap"
  i=$((i + 1))
done
printf 'nested' >"$TMP/big/sub/N.snap"
expect_eq "push-dir --jobs 4 exits 0" 0 \
  "$(rc_of sh "$SCRIPT" push-dir --dir "$TMP/big" --name big1 --jobs 4)"
expect_eq "push-dir prints a progress line" yes \
  "$(grep -q 'uploaded 13/13 files' "$TMP/out" && echo yes || echo no)"
expect_eq "pull-dir --jobs 4 exits 0" 0 \
  "$(rc_of sh "$SCRIPT" pull-dir --dest "$TMP/bigd1" --name big1 --jobs 4)"
expect_eq "parallel round trip restores the tree" "" "$(diff -r "$TMP/big" "$TMP/bigd1" || echo differs)"
expect_eq "--jobs 0 is refused" 2 "$(rc_of sh "$SCRIPT" push-dir --dir "$TMP/big" --name bigj --jobs 0)"

# A failing transfer: non-zero, names the file, no SHA256SUMS.
expect_eq "failing transfer exits non-zero" 2 \
  "$(rc_of env R2_LOCAL_FAIL_ON=F7.snap sh "$SCRIPT" push-dir --dir "$TMP/big" --name bigf --jobs 4)"
expect_eq "failing transfer names the file" yes "$(grep -q 'failed: F7.snap' "$TMP/out" && echo yes || echo no)"
expect_eq "failing transfer leaves no SHA256SUMS" no \
  "$([ -e "$R2_LOCAL_STORE/warehouse/bigf/SHA256SUMS" ] && echo yes || echo no)"
expect_eq "pull of the unfinished upload fails" 2 "$(rc_of sh "$SCRIPT" pull-dir --dest "$TMP/bigd2" --name bigf)"

# Interrupted push: some objects pre-seeded (one with the wrong size), no
# SHA256SUMS. --resume uploads only what is missing or wrong, then pull verifies.
mkdir -p "$R2_LOCAL_STORE/warehouse/bigr"
cp "$TMP/big/F1.snap" "$TMP/big/F2.snap" "$R2_LOCAL_STORE/warehouse/bigr/"
printf 'short' >"$R2_LOCAL_STORE/warehouse/bigr/F3.snap"
touch -t 200001010000 "$R2_LOCAL_STORE/warehouse/bigr/F1.snap"
expect_eq "resume push exits 0" 0 \
  "$(rc_of sh "$SCRIPT" push-dir --dir "$TMP/big" --name bigr --resume --jobs 4)"
expect_eq "resume keeps an intact object untouched" yes \
  "$([ "$(find "$R2_LOCAL_STORE/warehouse/bigr/F1.snap" -newer "$TMP/big/F1.snap" | wc -l | tr -d ' ')" = 0 ] && echo yes || echo no)"
expect_eq "resume fixes a wrong-size object" "file-3" "$(cat "$R2_LOCAL_STORE/warehouse/bigr/F3.snap")"
expect_eq "resumed upload pulls and verifies" 0 "$(rc_of sh "$SCRIPT" pull-dir --dest "$TMP/bigd3" --name bigr)"
expect_eq "resumed upload restores the tree" "" "$(diff -r "$TMP/big" "$TMP/bigd3" || echo differs)"
expect_eq "complete upload is still refused without --resume" 2 \
  "$(rc_of sh "$SCRIPT" push-dir --dir "$TMP/big" --name bigr)"

printf 'r2_bars_test: %d passed, %d failed\n' "$PASS" "$FAILED"
[ "$FAILED" -eq 0 ]
