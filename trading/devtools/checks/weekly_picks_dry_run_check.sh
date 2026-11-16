#!/bin/sh
# weekly_picks_dry_run_check.sh -- pins dev/weekly-picks/weekly.sh, the weekly live-picks
# runner, through its --dry-run on a fixture checkout (copies of the scripts plus a fake
# trading-results dir, a fake `docker` and a planted fake EODHD key). What it pins:
#   - the step order, and that a step marker under the work dir skips its step;
#   - EODHD terms: every `writes[private]` path is under $TR, the only `writes[public]` is
#     <sysver>/<friday>-picks.md, every other write is the gitignored work dir or the data
#     store, and no .sexp/.md/.html/.txt/.log path in the output falls outside those;
#   - the fake key never reaches stdout or stderr, docker is never called, nothing is created;
#   - usage errors exit 2; a real run without a key stops in preflight, before any step.
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
for f in weekly.sh fetch_buckets.sh; do
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
cp "$ROOT/dev/weekly-picks/weekly.sh" "$ROOT/dev/weekly-picks/fetch_buckets.sh" "$FIX/dev/weekly-picks/"
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
          (cls == "local" && (index(p, dd) == 1 || index(p, data) == 1)))) bad++ }
  END { printf "%s %d %d\n", (n > 8 ? "many" : n), bad + 0, npub + 0 }' "$TMP/out" > "$TMP/writes"
expect_eq "declared writes: many, none misplaced, exactly one public" "many 0 1" "$(cat "$TMP/writes")"

# No artifact-looking path anywhere else in the output may sit outside those places.
grep -v '^  writes\[' "$TMP/out" | tr ' ' '\n' | grep -E '\.(sexp|md|html|txt|log)$' |
  sed "s|^/workspaces/trading-1|$FIX|" |
  awk -v tr="$TR/" -v dd="$FIX/dev/data/" -v data="$FIX/data/" -v pub="$PUB" '
    index($0, tr) == 1 || index($0, dd) == 1 || index($0, data) == 1 || $0 == pub ||
    $0 ~ /^\.\.\/dev\/weekly-picks\/(record-config-overrides|portfolio)\.sexp$/ { ok++; next }
    { bad++ }
    END { printf "%d\n", bad + 0 }' > "$TMP/stray"
expect_eq "no artifact path outside \$TR / dev/data / the public file" 0 "$(cat "$TMP/stray")"

expect_eq "fake key absent from stdout and stderr" 0 "$(cat "$TMP/out" "$TMP/err" | grep -c -F "$KEY" || true)"
expect_eq "docker never called" no "$([ -e "$TMP/docker.calls" ] && echo yes || echo no)"
expect_eq "dry run created nothing" "" \
  "$(ls "$FIX/dev/data" "$FIX/dev/weekly-picks" "$TR" | grep -v -e '^$' -e ':$' -e '^snapshots$' -e '\.sh$' || true)"
expect_eq "publish block present" 2 \
  "$(grep -c -e "git -C $TR commit" -e "^  2. public summary $PUB" "$TMP/out")"

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

# The work dir holds bar-derived files: it must stay gitignored in the real repo.
grep -qE '^/?dev/data/?$' "$ROOT/.gitignore" || { echo "FAIL: weekly_picks_dry_run_check: dev/data/ is not in .gitignore" >&2; FAILED=$((FAILED + 1)); }

if [ "$FAILED" -ne 0 ]; then
  echo "FAIL: weekly_picks_dry_run_check: $FAILED assertion(s) failed, $PASS passed" >&2
  exit 1
fi
echo "OK: weekly_picks_dry_run_check -- $PASS assertions passed"
