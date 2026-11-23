#!/bin/sh
# weekly_picks_dry_run_check.sh -- pins dev/weekly-picks/weekly.sh, the weekly live-picks
# runner, through its --dry-run on a fixture checkout (copies of the scripts plus a fake
# trading-results dir, a fake `docker` and a planted fake EODHD key). What it pins:
#   - the step order, and that a step marker under the work dir skips its step;
#   - EODHD terms: every `writes[private]` path is under $TR, the only `writes[public]` is
#     <sysver>/<friday>-picks.md, every other write is the gitignored work dir or the data
#     store, and no .sexp/.md/.html/.txt/.log path in the output falls outside those;
#   - the fake key never reaches stdout or stderr, docker is never called, nothing is created;
#   - the profiles (#3693): record keeps the $5 / $1M universe floors and the record config;
#     WEEKLY_MIN_PRICE / WEEKLY_MIN_ADV override the floors; WEEKLY_PROFILE=live-size takes a
#     $100k ADV floor, generates on record + live-size-overrides.sexp layered in its work dir, and
#     writes its superset, private records and public file under -live-size / live-size/ names;
#     the live-size file sets exactly the three lines test_participation_gate.ml pins;
#   - no container argument holds whitespace (run-in-env.sh re-splits them, #3698): the helper
#     refuses one, and crun / crun_log / crun_out each call it;
#   - usage errors exit 2; a real run without a key stops in preflight, before any step;
#   - the guarded helpers, which a dry run never reaches (sourced from weekly_lib.sh and called
#     on fixtures): bucket_shards puts every shard key (first + last letter, upper-cased) in
#     exactly one bucket and loses no symbol (#3645); check_public_price_free refuses a table
#     row with a two-decimal number; fetch_buckets.sh, run against a fake fetch_symbols.exe,
#     exits 0 only when every process exited 0 and every log ends in a Done: line, and hands
#     the exe the key without printing it;
#   - the call sites of those two helpers in weekly.sh, which a dry run never executes
#     (`run` only echoes, and the price check is skipped): `run bucket_shards` and
#     `[ "$DRY" = 1 ] || check_public_price_free` must each appear on a non-comment line,
#     so deleting or commenting out a call turns this red.
# Run:  sh trading/devtools/checks/weekly_picks_dry_run_check.sh
set -eu

. "$(dirname "$0")/_check_lib.sh"

PASS=0
FAILED=0
expect_eq() { # label expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else
    printf 'FAIL: weekly_picks_dry_run_check: %s: expected "%s", got "%s"\n' "$1" "$2" "$3" >&2
    FAILED=$((FAILED + 1))
  fi
}

ROOT="$(repo_root)"
for f in weekly.sh weekly_lib.sh fetch_buckets.sh; do
  [ -f "$ROOT/dev/weekly-picks/$f" ] || die "weekly_picks_dry_run_check: dev/weekly-picks/$f not found"
  sh -n "$ROOT/dev/weekly-picks/$f" || die "weekly_picks_dry_run_check: dev/weekly-picks/$f does not parse"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
FIX="$TMP/repo"
TR="$TMP/trading-results"
KEY="FAKE-EODHD-KEY-7f3a9c41"
FRI=2026-11-20
SYSVER=feedface0
mkdir -p "$FIX/dev/weekly-picks" "$FIX/dev/data/snapshots" "$TMP/bin" "$TR"
cp "$ROOT/dev/weekly-picks/weekly.sh" "$ROOT/dev/weekly-picks/weekly_lib.sh" "$ROOT/dev/weekly-picks/fetch_buckets.sh" \
  "$FIX/dev/weekly-picks/"
: > "$FIX/dev/data/snapshots/universe-superset-2026-11-13.sexp"
printf '#!/bin/sh\necho "$@" >> "%s/docker.calls"\nexit 1\n' "$TMP" > "$TMP/bin/docker"
chmod +x "$TMP/bin/docker"

weekly() { PATH="$TMP/bin:$PATH" TR="$TR" SYSVER="$SYSVER" sh "$FIX/dev/weekly-picks/weekly.sh" "$@"; }
dry() { EODHD_API_KEY="$KEY" weekly --dry-run "$FRI" > "$TMP/out" 2> "$TMP/err"; }
steps() { grep '^== step' "$TMP/out" | sed 's/^== step [0-9]*\/[0-9]* \([a-z-]*\).*/\1/' | tr '\n' ' '; }

rc=0; dry || rc=$?
expect_eq "dry run exits 0" 0 "$rc"
expect_eq "step order" \
  "preflight build fetch-set fetch inventory eligible universe warehouse generate validate render stage " "$(steps)"

# Every declared write: private under $TR, one public file, the rest local to the checkout's
# gitignored dev/data/ or data/. Prints "<writes> <misplaced> <public>".
PUB="$FIX/dev/weekly-picks/$SYSVER/$FRI-picks.md"
awk -v tr="$TR" -v pub="$PUB" -v dd="$FIX/dev/data/" -v data="$FIX/data" '
  /^  writes\[/ {
    cls = $0; sub(/^  writes\[/, "", cls); sub(/\].*/, "", cls)
    p = $0; sub(/^  writes\[[a-z]*\]: /, "", p); n++
    if (cls == "public") npub++
    if (!((cls == "private" && index(p, tr "/") == 1) || (cls == "public" && p == pub) ||
          (cls == "local" && (index(p, dd) == 1 || p == data || index(p, data "/") == 1)))) bad++ }
  END { printf "%s %d %d\n", (n > 8 ? "many" : n), bad + 0, npub + 0 }' "$TMP/out" > "$TMP/writes"
expect_eq "declared writes: many, none misplaced, exactly one public" "many 0 1" "$(cat "$TMP/writes")"

# No artifact-looking path anywhere else in the output may sit outside those places.
grep -v '^  writes\[' "$TMP/out" | tr ' ' '\n' | grep -E '\.(sexp|md|html|txt|log)$' |
  sed "s|^/workspaces/trading-1|$FIX|" |
  awk -v tr="$TR/" -v dd="$FIX/dev/data/" -v data="$FIX/data/" -v pub="$PUB" '
    index($0, tr) == 1 || index($0, dd) == 1 || index($0, data) == 1 || $0 == pub ||
    $0 ~ /^(\.\.\/)?dev\/weekly-picks\/(record-config-overrides(\+live-size-overrides)?|live-size-overrides|portfolio)\.sexp$/ { ok++; next }
    { bad++ }
    END { printf "%d\n", bad + 0 }' > "$TMP/stray"
expect_eq "no artifact path outside \$TR / dev/data / the public file" 0 "$(cat "$TMP/stray")"

expect_eq "fake key absent from stdout and stderr" 0 "$(cat "$TMP/out" "$TMP/err" | grep -c -F "$KEY" || true)"
expect_eq "docker never called" no "$([ -e "$TMP/docker.calls" ] && echo yes || echo no)"
expect_eq "dry run created nothing" "" \
  "$(ls "$FIX/dev/data" "$FIX/dev/weekly-picks" "$TR" | grep -v -e '^$' -e ':$' -e '^snapshots$' -e '\.sh$' || true)"
expect_eq "publish block present" 2 \
  "$(grep -c -e "git -C $TR commit" -e "^  2. public summary $PUB" "$TMP/out")"

# Profiles and universe floors (issue #3693). floors: the -min-price / -min-adv pair of each
# eligible-universe call (fetch-set and eligible), one line each.
floors() { grep -o -e '-min-price [^ ]* -min-adv [^ ]*' "$TMP/out" | tr '\n' '|'; }
expect_eq "record profile: the \$5 / \$1M universe floors, unchanged" \
  "-min-price 5.0 -min-adv 1000000.0|-min-price 5.0 -min-adv 1000000.0|" "$(floors)"
expect_eq "record profile: generates on the record config" 1 \
  "$(grep -c -- '--config-overrides \.\./dev/weekly-picks/record-config-overrides\.sexp ' "$TMP/out")"
rc=0; (export WEEKLY_MIN_PRICE=2.5 WEEKLY_MIN_ADV=250000; EODHD_API_KEY="$KEY" weekly --dry-run "$FRI") > "$TMP/out" 2> "$TMP/err" || rc=$?
expect_eq "WEEKLY_MIN_PRICE / WEEKLY_MIN_ADV set both floors" \
  "0 -min-price 2.5 -min-adv 250000|-min-price 2.5 -min-adv 250000|" "$rc $(floors)"
rc=0; (export WEEKLY_PROFILE=live-size; EODHD_API_KEY="$KEY" weekly --dry-run "$FRI") > "$TMP/out" 2> "$TMP/err" || rc=$?
LWORK="$FIX/dev/data/weekly-picks-$FRI-live-size"
expect_eq "live-size profile: exits 0 with the \$100k ADV floor" \
  "0 -min-price 5.0 -min-adv 100000.0|-min-price 5.0 -min-adv 100000.0|" "$rc $(floors)"
expect_eq "live-size profile: layers its overrides on the record's and generates on the result" "1 1" \
  "$(grep -c "layer_config $FIX/dev/weekly-picks/record-config-overrides.sexp $FIX/dev/weekly-picks/live-size-overrides.sexp $LWORK/config-overrides.sexp\$" "$TMP/out") \
$(grep -c -- "--config-overrides /workspaces/trading-1/dev/data/weekly-picks-$FRI-live-size/config-overrides.sexp " "$TMP/out")"
expect_eq "live-size profile: its own superset, private dir and public file" "1 5 1" \
  "$(grep -c "^  writes\[local\]: $FIX/dev/data/snapshots/universe-superset-$FRI-live-size.sexp\$" "$TMP/out") \
$(grep -c "^  writes\[private\]: $TR/dev/weekly-picks/$SYSVER/live-size/" "$TMP/out") \
$(grep -c "^  writes\[public\]: $FIX/dev/weekly-picks/$SYSVER/live-size/$FRI-picks.md\$" "$TMP/out")"
expect_eq "live-size profile: the public summary names both layered files, as one token" 1 \
  "$(grep -c -- "-config-path dev/weekly-picks/record-config-overrides.sexp+live-size-overrides.sexp > " "$TMP/out")"
expect_eq "live-size profile: every other write is under its own work dir" 0 \
  "$(grep '^  writes\[local\]' "$TMP/out" | grep -v -e "$LWORK" -e "universe-superset-$FRI-live-size" -e ": $FIX/data\$" -e ": $FIX/data/" -c || true)"
# The three live-size overlay lines, as test_participation_gate.ml "live-size layering" loads them.
expect_eq "live-size-overrides.sexp sets exactly the three fields the layering test pins" \
  "((liquidity_config ((max_entry_adv_participation (0.10)))))|((liquidity_config ((min_entry_dollar_adv 100000.0))))|((liquidity_config ((min_hold_dollar_adv 50000.0))))|" \
  "$(grep -v '^;' "$ROOT/dev/weekly-picks/live-size-overrides.sexp" | grep -v '^$' | tr '\n' '|')"
rc=0; (export WEEKLY_PROFILE=bogus; weekly --dry-run "$FRI") > /dev/null 2>&1 || rc=$?
expect_eq "an unknown WEEKLY_PROFILE is a usage error" 2 "$rc"
rc=0; (export WEEKLY_MIN_ADV=1e6; weekly --dry-run "$FRI") > /dev/null 2>&1 || rc=$?
expect_eq "a universe floor that is not a plain number is a usage error" 2 "$rc"

mkdir -p "$FIX/dev/data/weekly-picks-$FRI/done"
: > "$FIX/dev/data/weekly-picks-$FRI/done/build"
rc=0; dry || rc=$?
expect_eq "marker run exits 0" 0 "$rc"
expect_eq "a done marker skips its step, the rest still run" "12 skipped no-docker_dune" \
  "$(printf '%s %s %s' "$(grep -c '^== step' "$TMP/out")" \
    "$(grep -q '^== step 2/12 build (marker present: skipped)$' "$TMP/out" && echo skipped)" \
    "$(grep -q 'docker_dune' "$TMP/out" && echo ran || echo no-docker_dune)")"

rc=0; weekly --dry-run 2026-11-21 > /dev/null 2>&1 || rc=$?
expect_eq "a Saturday is a usage error" 2 "$rc"
rc=0; weekly > /dev/null 2>&1 || rc=$?
expect_eq "no date is a usage error" 2 "$rc"
rc=0; weekly --dry-run 20261120 > /dev/null 2>&1 || rc=$?
expect_eq "a malformed date is a usage error" 2 "$rc"
rc=0; WEEKLY_ANY_DAY=1 weekly --dry-run 2026-11-21 > /dev/null 2>&1 || rc=$?
expect_eq "WEEKLY_ANY_DAY=1 allows a Saturday" 0 "$rc"

rc=0; EODHD_API_KEY="" weekly 2026-11-27 > "$TMP/real.out" 2> "$TMP/real.err" || rc=$?
expect_eq "a real run without a key fails" 1 "$rc"
expect_eq "... in preflight, before any step runs or docker is called" "yes no" \
  "$(grep -q 'EODHD_API_KEY is not set' "$TMP/real.err" && echo yes) $([ -e "$TMP/docker.calls" ] && echo yes || echo no)"

# --- The guarded helpers. The dry run never reaches them (`run` only echoes), so they are
# sourced from weekly_lib.sh and called on fixtures; fetch_buckets.sh runs against a fake exe.
LIB="$FIX/dev/weekly-picks/weekly_lib.sh"

# bucket_shards (#3645): a shard key (first + last letter, upper-cased) lives in exactly one
# bucket. AAL/AAPL share a key; COMP_old and msft_x have lower-case suffixes that upper-case
# onto CAD's and MAX's keys.
BK="$TMP/buckets"
mkdir -p "$BK"
printf '%s\n' AAL AAPL AMZN COMP COMP_old CAD BRK.B GSPC.INDX MSFT msft_x MAX X XOM Z ABBV IBM > "$BK/symbols.txt"
sh -c '. "$1"; bucket_shards "$2" "$3" "$4"' _ "$LIB" "$BK/symbols.txt" "$BK/batch" 4
expect_eq "buckets are named batch_NN.txt, as fetch_buckets.sh globs them" 0 \
  "$(ls "$BK" | grep -v '^symbols.txt$' | grep -vc '^batch_[0-9][0-9]\.txt$' || true)"
expect_eq "buckets: no shard key in two buckets" 0 "$(awk '
  { k = toupper(substr($1, 1, 1)) toupper(substr($1, length($1), 1))
    if (k in own && own[k] != FILENAME) bad++
    own[k] = FILENAME }
  END { print bad + 0 }' "$BK"/batch_??.txt)"
expect_eq "buckets: their union is the input, each symbol once" \
  "$(sort "$BK/symbols.txt" | tr '\n' ' ')" "$(cat "$BK"/batch_??.txt | sort | tr '\n' ' ')"

# check_public_price_free: the one tripwire on the file that reaches the public repo.
PF="$TMP/price-free"
mkdir -p "$PF"
printf '%s\n' '# Weekly picks' '' '| Rank | Symbol | Grade | Score | Sector |' '|---|---|---|---|---|' \
  '| 1 | KPLT | A+ | 120 | Information Technology |' > "$PF/clean.md"
printf '%s\n' '# Weekly picks' '' '| Rank | Symbol | Entry | Score |' '|---|---|---|---|' \
  '| 1 | KPLT | 123.45 | 120 |' > "$PF/priced.md"
price_free() { sh -c '. "$1"; die() { echo "die: $1" >&2; exit 1; }; check_public_price_free "$2"' _ "$LIB" "$1"; }
rc=0; price_free "$PF/clean.md" > /dev/null 2>&1 || rc=$?
expect_eq "price-free: a summary without a priced row passes" 0 "$rc"
rc=0; price_free "$PF/priced.md" > "$PF/out" 2>&1 || rc=$?
expect_eq "price-free: a table row with a two-decimal number is refused" "1 yes" \
  "$rc $(grep -q 'two decimals' "$PF/out" && echo yes || echo no)"

# check_container_args (#3698): run-in-env.sh re-splits container arguments on whitespace, so
# crun / crun_log / crun_out refuse one, in the dry run too.
cargs() { sh -c '. "$1"; die() { echo "die: $1" >&2; exit 1; }; shift; check_container_args "$@"' _ "$LIB" "$@"; }
rc=0; cargs -config-path dev/weekly-picks/record-config-overrides.sexp+live-size-overrides.sexp > /dev/null 2>&1 || rc=$?
expect_eq "container args: single tokens pass" 0 "$rc"
rc=0; cargs -config-path "a.sexp + b.sexp" > "$TMP/cargs.out" 2>&1 || rc=$?
expect_eq "container args: an argument with a space is refused" "1 yes" \
  "$rc $(grep -q 'with whitespace' "$TMP/cargs.out" && echo yes || echo no)"

# fetch_buckets.sh against a fake fetch_symbols.exe: it must receive the key, and the run
# exits 0 only when every process exited 0 and every log ends in a Done: line.
cat > "$TMP/fake_fetch" <<'FAKE'
#!/bin/sh
syms=""; key=""
while [ $# -gt 0 ]; do
  case "$1" in -symbols) syms=$2; shift ;; -api-key) key=$2; shift ;; esac
  shift
done
[ "$key" = "$FAKE_EXPECT_KEY" ] || { echo "fake_fetch: wrong key"; exit 9; }
case "$syms" in
  *DIES*) echo "Fetching $syms"; exit 0 ;;
  *EXIT3*) printf '\nDone: 1 fetched, 0 errors.\n'; exit 3 ;;
  *) printf 'Fetching %s\n\nDone: 2 fetched, 1 errors.\n' "$syms" ;;
esac
FAKE
chmod +x "$TMP/fake_fetch"
fetch_case() { # <name> <symbols in batch_01>: runs fetch_buckets.sh, leaves rc in $FB_RC, output in $TMP/fb-<name>.out
  mkdir -p "$TMP/fb-$1/b"
  printf 'AAA\nBBB\n' > "$TMP/fb-$1/b/batch_00.txt"
  printf '%s\n' "$2" > "$TMP/fb-$1/b/batch_01.txt"
  FB_RC=0
  FAKE_EXPECT_KEY="$KEY" EODHD_API_KEY="$KEY" sh "$FIX/dev/weekly-picks/fetch_buckets.sh" "$TMP/fake_fetch" \
    "$TMP/fb-$1/data" "$TMP/fb-$1/b" "$TMP/fb-$1/logs" > "$TMP/fb-$1.out" 2>&1 || FB_RC=$?
}
fetch_case ok CCC
expect_eq "fetch_buckets: every bucket finished: exit 0 and the key reached the exe" \
  "0 fetch_buckets: 2 buckets, 0 without a Done line, 2 per-symbol errors" "$FB_RC $(cat "$TMP/fb-ok.out")"
expect_eq "fetch_buckets: the key is not printed" 0 "$(grep -c -F "$KEY" "$TMP/fb-ok.out" || true)"
fetch_case dies DIES
expect_eq "fetch_buckets: a bucket that exits 0 without a Done line fails the run" \
  "1 fetch_buckets: 2 buckets, 1 without a Done line, 1 per-symbol errors" "$FB_RC $(cat "$TMP/fb-dies.out")"
fetch_case exit3 EXIT3
expect_eq "fetch_buckets: a bucket that exits non-zero fails the run" \
  "1 fetch_buckets: 2 buckets, 0 without a Done line, 1 per-symbol errors" "$FB_RC $(cat "$TMP/fb-exit3.out")"
rc=0; EODHD_API_KEY="" sh "$FIX/dev/weekly-picks/fetch_buckets.sh" "$TMP/fake_fetch" "$TMP/fb-ok/data" "$TMP/fb-ok/b" "$TMP/fb-ok/logs" \
  > /dev/null 2>&1 || rc=$?
expect_eq "fetch_buckets: without a key it fails before any fetch" 1 "$rc"

# The call sites in weekly.sh. The dry run does not execute either helper, so the pins above
# hold even when weekly.sh stops calling them; a name that survives only in a comment (or
# after a `#` on a code line) does not count as a call.
calls() { sed "s/#.*//" "$FIX/dev/weekly-picks/weekly.sh" | grep -q -w -e "$1" && echo yes || echo no; }
expect_eq "weekly.sh calls bucket_shards on a non-comment line" yes "$(calls bucket_shards)"
expect_eq "weekly.sh calls check_public_price_free on a non-comment line" yes "$(calls check_public_price_free)"
expect_eq "weekly.sh: crun, crun_log and crun_out each call check_container_args" 3 \
  "$(sed "s/#.*//" "$FIX/dev/weekly-picks/weekly.sh" | grep -E '^crun(_log|_out)?\(\)' | grep -c -w check_container_args)"

# The work dir holds bar-derived files: it must stay gitignored in the real repo.
grep -qE '^/?dev/data/?$' "$ROOT/.gitignore" || { echo "FAIL: weekly_picks_dry_run_check: dev/data/ is not in .gitignore" >&2; FAILED=$((FAILED + 1)); }

if [ "$FAILED" -ne 0 ]; then
  echo "FAIL: weekly_picks_dry_run_check: $FAILED assertion(s) failed, $PASS passed" >&2
  exit 1
fi
echo "OK: weekly_picks_dry_run_check -- $PASS assertions passed"
