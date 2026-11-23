#!/bin/sh
# weekly.sh -- one command for the weekly live picks (local Saturday slot, user 2026-11-16).
#
#   sh dev/weekly-picks/weekly.sh [--dry-run] <friday YYYY-MM-DD>
#
# Steps, each marked under the work dir so a re-run resumes at the first unfinished one:
#   preflight  inputs, key and git-ignore checks (never marked)
#   build      dune build of the executables used below, in the dev container
#   fetch-set  eligible list from the current inventory + last week's warehouse superset,
#              bucketed by shard key (first + last letter) so no two fetchers share a shard
#   fetch      one fetch_symbols.exe per bucket, in parallel (fetch_buckets.sh)
#   inventory  build_inventory (rewrites the tracked data/inventory.sexp: never commit it)
#   eligible   eligible universe at the Friday (price >= MIN_PRICE, 30d ADV >= MIN_ADV, fresh bars)
#   universe   the picks universe (eligible minus the csv-only names) and this week's superset
#   warehouse  build_snapshots through the Friday
#   generate   generate_weekly_snapshot on the profile's config (record, or record + live-size)
#   validate   validate_weekly_snapshot; errors do not stop the run (README "Weekly cadence")
#   render     full .md/.html and the price-free public summary
#   stage      full records -> $TR/dev/weekly-picks/<sysver>/, summary -> dev/weekly-picks/<sysver>/
#
# EODHD terms (user decisions 2026-11-14): bars and anything printing prices (closes, entries,
# stops, tickets) stay in the work dir (gitignored, dev/data/) and the private trading-results
# checkout $TR. Besides the price-free data/inventory.sexp (rewritten by the inventory step;
# never commit it), the only file written inside this repo's tracked tree is the public
# <friday>-picks.md. The key comes from $EODHD_API_KEY and is never printed.
# The script never commits, pushes or opens a PR: it ends by printing the publish commands.
#
# --dry-run prints every command and every output path, runs nothing, touches no network.
#
# Environment: EODHD_API_KEY (required unless --dry-run); TR (trading-results checkout,
# default <main checkout>/../trading-results); SYSVER (default: short HEAD sha of this
# checkout, which a jj workspace has not: set it there); WEEKLY_PUBLIC_ROOT (checkout the
# public summary is written into, default this one); WEEKLY_WORK (work dir, default
# <main checkout>/dev/data/weekly-picks-<friday>); WEEKLY_PRIOR_SUPERSET (default: newest
# dev/data/snapshots/universe-superset-<date>.sexp before the Friday); WEEKLY_CSV_ONLY
# (default $TR/dev/weekly-picks/89a08b1fe/controls/csv-only-excluded.txt);
# WEEKLY_ANY_DAY=1 (allow a non-Friday date, e.g. a holiday-shortened week).
#
# Profiles (issue #3693): WEEKLY_PROFILE=record (default) screens a $5 / $1M-ADV universe on
# record-config-overrides.sexp. WEEKLY_PROFILE=live-size layers live-size-overrides.sexp on
# the record config (written to <work>/config-overrides.sexp) and lowers the universe ADV floor
# to $100k; its work dir, superset, private records and public summary carry a -live-size
# suffix, so both profiles can run for one Friday. WEEKLY_MIN_PRICE / WEEKLY_MIN_ADV override
# the profile's universe floors (defaults: 5.0, and 1000000.0 record / 100000.0 live-size).
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)

die() { printf 'weekly.sh: %s\n' "$1" >&2; exit 1; }
usage() { printf 'usage: weekly.sh [--dry-run] <friday YYYY-MM-DD>\n' >&2; exit 2; }
# bucket_shards and check_public_price_free: guarded helpers, pinned directly by the check.
. "$HERE/weekly_lib.sh"

DRY=0
FRIDAY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    -h | --help) sed -n '2,/^set -eu/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    -*) usage ;;
    *) [ -z "$FRIDAY" ] || usage; FRIDAY=$1 ;;
  esac
  shift
done
[ -n "$FRIDAY" ] || usage
printf '%s' "$FRIDAY" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || usage
# Day of week by Sakamoto's method (0 = Sunday), so no GNU/BSD `date` flags are needed.
weekday=$(printf '%s\n' "$FRIDAY" | awk -F- '{
  split("0 3 2 5 0 3 5 1 4 6 2 4", t, " "); y = $1 + 0; m = $2 + 0
  if (m < 3) y--
  print (y + int(y / 4) - int(y / 100) + int(y / 400) + t[m] + $3) % 7 }')
if [ "$weekday" != 5 ] && [ "${WEEKLY_ANY_DAY:-}" != 1 ]; then
  printf 'weekly.sh: %s is not a Friday (WEEKLY_ANY_DAY=1 allows it)\n' "$FRIDAY" >&2
  exit 2
fi

# MAIN is the checkout holding the gitignored data/ and dev/data/ (the container mount); a
# jj workspace under .claude/worktrees/ resolves to its parent checkout.
case "$ROOT" in
  */.claude/worktrees/*) MAIN=${ROOT%%/.claude/worktrees/*} ;;
  *) MAIN=$ROOT ;;
esac
CROOT=${REPO_IN_CONTAINER:-/workspaces/trading-1}
TR=${TR:-$(dirname "$MAIN")/trading-results}
if [ "$ROOT" = "$MAIN" ]; then BUILD_DIR=trading; else BUILD_DIR=${ROOT#"$MAIN"/}/trading; fi

SYSVER=${SYSVER:-}
if [ -z "$SYSVER" ] && [ -e "$ROOT/.git" ]; then SYSVER=$(git -C "$ROOT" rev-parse --short=9 HEAD 2>/dev/null || true); fi
if [ -z "$SYSVER" ]; then
  if [ "$DRY" = 1 ]; then SYSVER='<sysver>'; else die "no git HEAD in this checkout (a jj workspace): set SYSVER=<short sha of this code>"; fi
fi

# Profile (issue #3693): the config layering, the universe floors and the suffix that keeps a
# live-size run's work dir, superset and records apart from the record run of the same Friday.
PROFILE=${WEEKLY_PROFILE:-record}
case "$PROFILE" in
  record) SFX=""; SUBDIR=""; DEFAULT_MIN_ADV=1000000.0 ;;
  live-size) SFX=-live-size; SUBDIR=/live-size; DEFAULT_MIN_ADV=100000.0 ;;
  *) printf 'weekly.sh: WEEKLY_PROFILE=%s: expected record or live-size\n' "$PROFILE" >&2; exit 2 ;;
esac

WORK=${WEEKLY_WORK:-$MAIN/dev/data/weekly-picks-$FRIDAY$SFX}
DONE=$WORK/done
SNAP=$MAIN/dev/data/snapshots
SUPERSET=$SNAP/universe-superset-$FRIDAY$SFX.sexp
OUTDIR=$WORK/out/$SYSVER
PICKS=$OUTDIR/$FRIDAY.sexp
WAREHOUSE=$WORK/warehouse
CSV_ONLY=${WEEKLY_CSV_ONLY:-$TR/dev/weekly-picks/89a08b1fe/controls/csv-only-excluded.txt}
TR_OUT=$TR/dev/weekly-picks/$SYSVER$SUBDIR
PUBLIC=${WEEKLY_PUBLIC_ROOT:-$ROOT}/dev/weekly-picks/$SYSVER$SUBDIR/$FRIDAY-picks.md
CONFIG=dev/weekly-picks/record-config-overrides.sexp
LIVE_SIZE_CONFIG=dev/weekly-picks/live-size-overrides.sexp
LAYERED_CONFIG=$WORK/config-overrides.sexp
PORTFOLIO=dev/weekly-picks/portfolio.sexp
# What the public summary names as its config: the record file, or the two layered files.
SUMMARY_CONFIG=$CONFIG${SFX:+ + $LIVE_SIZE_CONFIG}

# The newest superset of either profile dated before the Friday (a live-size superset holds the
# record one, so either serves as last week's warehouse universe).
PRIOR=${WEEKLY_PRIOR_SUPERSET:-$(ls "$SNAP" 2>/dev/null | grep -E '^universe-superset-[0-9]{4}-[0-9]{2}-[0-9]{2}(-live-size)?\.sexp$' |
  sort | awk -v dir="$SNAP" -v cut="$FRIDAY" 'substr($0, 19, 10) < cut { last = $0 } END { if (last != "") print dir "/" last }')}
[ -n "$PRIOR" ] || PRIOR="$SNAP/universe-superset-<none before $FRIDAY: set WEEKLY_PRIOR_SUPERSET>.sexp"

# Recipe constants: eligibility gates, the pre-fetch staleness allowance, the warehouse start,
# the shard-bucket count, and the validator's armed values (README "2026-11 backfill").
MIN_PRICE=${WEEKLY_MIN_PRICE:-5.0}
MIN_ADV=${WEEKLY_MIN_ADV:-$DEFAULT_MIN_ADV}
for v in "$MIN_PRICE" "$MIN_ADV"; do
  printf '%s' "$v" | grep -Eq '^[0-9]+(\.[0-9]+)?$' || { printf 'weekly.sh: universe floor %s is not a number\n' "$v" >&2; exit 2; }
done
PRE_FETCH_STALENESS_DAYS=10
WAREHOUSE_START=2024-06-01
FETCH_BUCKETS=10
RISK_BUDGET=1000
THROUGH_BAND=0.0
EXTENSION_MAX=2.0

# Container-side paths (the container mounts $MAIN at $CROOT) and executables, relative to the
# dune root that run-in-env.sh cd's to.
cpath() { printf '%s%s' "$CROOT" "${1#"$MAIN"}"; }
CDATA=$CROOT/data
CWORK=$(cpath "$WORK")
CWAREHOUSE=$(cpath "$WAREHOUSE")
CPICKS=$(cpath "$PICKS")
COUT=$(cpath "$OUTDIR")
B=./_build/default
RUNENV=$ROOT/dev/lib/run-in-env.sh
TARGETS="analysis/scripts/fetch_symbols/fetch_symbols.exe analysis/scripts/build_inventory/build_inventory.exe
analysis/data/universe/bin/build_eligible_universe_runner.exe analysis/scripts/build_snapshots/build_snapshots.exe
trading/weinstein/snapshot/gen/bin/generate_weekly_snapshot.exe trading/weinstein/snapshot/bin/validate_weekly_snapshot.exe
trading/weinstein/snapshot/bin/render_weekly_report.exe trading/weinstein/snapshot/bin/public_picks_summary.exe"

say() { printf '  + %s\n' "$*"; }
writes() { printf '  writes[%s]: %s\n' "$1" "$2"; } # class: private ($TR), public (the -picks.md), local (gitignored)
run() { say "$*"; [ "$DRY" = 1 ] || "$@"; }
crun() { say "[container] $*"; [ "$DRY" = 1 ] || sh "$RUNENV" "$@"; }
crun_log() { _f=$1; shift; say "[container] $* > $_f 2>&1"; [ "$DRY" = 1 ] || sh "$RUNENV" "$@" > "$_f" 2>&1; }
crun_out() { _o=$1; _e=$2; shift 2; say "[container] $* > $_o 2> $_e"; [ "$DRY" = 1 ] || sh "$RUNENV" "$@" > "$_o" 2> "$_e"; }

# Symbols (one per line) of a universe / eligible / superset sexp.
syms() { tr '\n' ' ' < "$1" | awk '{ n = split($0, p, "\\(symbol "); for (i = 2; i <= n; i++) print substr(p[i], 1, index(p[i], ")") - 1) }'; }
make_fetch_set() { { syms "$1"; syms "$2"; } | sort -u > "$3"; }

# pinned_universe <eligible> <exclude-list> <out>: a (Pinned ...) universe of the eligible
# symbols and sectors, minus the names in the exclude list.
pinned_universe() {
  { echo "(Pinned ("
    tr '\n' ' ' < "$1" | awk -v excl="$2" '
      BEGIN { while ((getline s < excl) > 0) skip[s] = 1 }
      { n = split($0, p, "\\(symbol ")
        for (i = 2; i <= n; i++) {
          sym = substr(p[i], 1, index(p[i], ")") - 1); sec = "\"\""
          if (match(p[i], /\(sector ("[^"]*"|[^ )]*)\)/)) sec = substr(p[i], RSTART + 8, RLENGTH - 9)
          gsub(/"/, "", sec)
          if (!(sym in skip)) printf "  ((symbol %s) (sector \"%s\"))\n", sym, sec } }'
    echo "))"; } > "$3"
}

# layer_config <record> <profile> <out>: the record overrides, then the profile's, as one file.
# Overlays apply in order, so each profile line replaces just the field it names.
layer_config() { cat "$1" "$2" > "$3"; }

# pinned_superset <prior-superset> <eligible> <out>: the warehouse universe, symbols only.
pinned_superset() {
  { echo "(Pinned ("
    { syms "$1"; syms "$2"; } | sort -u | awk '{ printf "  ((symbol %s) (sector \"\"))\n", $1 }'
    echo "))"; } > "$3"
}

step_preflight() {
  if [ "$DRY" = 1 ]; then
    say "would check: EODHD_API_KEY is set (never printed); $TR is a git checkout; $WORK is git-ignored;"
    say "would check: $CONFIG, $PORTFOLIO,${SFX:+ $LIVE_SIZE_CONFIG,} the csv-only list and the prior superset exist; the dev container is up"
    return 0
  fi
  [ -n "${EODHD_API_KEY:-}" ] || die "EODHD_API_KEY is not set"
  [ -e "$TR/.git" ] || die "TR=$TR is not a git checkout of dayfine/trading-results"
  case "$WORK" in "$MAIN"/*) ;; *) die "WEEKLY_WORK must be under $MAIN (the container mount)" ;; esac
  git -C "$MAIN" check-ignore -q "$WORK/x" || die "$WORK is not git-ignored; refusing to write bar-derived files there"
  for f in "$ROOT/$CONFIG" "$ROOT/$PORTFOLIO" "$CSV_ONLY" "$PRIOR"; do [ -f "$f" ] || die "missing input: $f"; done
  [ "$PROFILE" = record ] || [ -f "$ROOT/$LIVE_SIZE_CONFIG" ] || die "missing input: $ROOT/$LIVE_SIZE_CONFIG"
  grep -q "(symbol GSPC.INDX)" "$PRIOR" || die "$PRIOR has no GSPC.INDX: it is not a warehouse superset"
  mkdir -p "$DONE" "$WORK/fetch/logs" "$WORK/logs" "$OUTDIR"
}

step_build() {
  # shellcheck disable=SC2086 # TARGETS is a word list
  run sh "$ROOT/dev/scripts/docker_dune.sh" --dir "$BUILD_DIR" -- build $TARGETS
}

step_fetch_set() {
  crun $B/analysis/data/universe/bin/build_eligible_universe_runner.exe -inventory-path "$CDATA/inventory.sexp" \
    -csv-data-dir "$CDATA" -date "$FRIDAY" -min-price "$MIN_PRICE" -min-adv "$MIN_ADV" \
    -max-staleness-trading-days "$PRE_FETCH_STALENESS_DAYS" -output-path "$CWORK/eligible-pre.sexp"
  writes local "$WORK/eligible-pre.sexp"
  run make_fetch_set "$PRIOR" "$WORK/eligible-pre.sexp" "$WORK/fetch-set.txt"
  writes local "$WORK/fetch-set.txt"
  run bucket_shards "$WORK/fetch-set.txt" "$WORK/fetch/batch" "$FETCH_BUCKETS"
  writes local "$WORK/fetch/batch_NN.txt"
}

step_fetch() {
  say "EODHD_API_KEY is forwarded into the container by run-in-env.sh (not on a host command line); fetch_buckets.sh passes it as argv to fetch_symbols.exe inside the container (the exe takes no env var)"
  crun sh ../dev/weekly-picks/fetch_buckets.sh $B/analysis/scripts/fetch_symbols/fetch_symbols.exe "$CDATA" \
    "$CWORK/fetch" "$CWORK/fetch/logs"
  writes local "$MAIN/data"
}

step_inventory() {
  crun $B/analysis/scripts/build_inventory/build_inventory.exe -data-dir "$CDATA"
  writes local "$MAIN/data/inventory.sexp"
}

step_eligible() {
  crun $B/analysis/data/universe/bin/build_eligible_universe_runner.exe -inventory-path "$CDATA/inventory.sexp" \
    -csv-data-dir "$CDATA" -date "$FRIDAY" -min-price "$MIN_PRICE" -min-adv "$MIN_ADV" -output-path "$CWORK/eligible.sexp"
  writes local "$WORK/eligible.sexp"
}

step_universe() {
  run pinned_universe "$WORK/eligible.sexp" "$CSV_ONLY" "$WORK/universe.sexp"
  writes local "$WORK/universe.sexp"
  run pinned_superset "$PRIOR" "$WORK/eligible.sexp" "$SUPERSET"
  writes local "$SUPERSET"
}

step_warehouse() {
  crun mkdir -p "$CWAREHOUSE"
  crun_log "$WORK/logs/warehouse.log" $B/analysis/scripts/build_snapshots/build_snapshots.exe \
    -universe-path "$(cpath "$SUPERSET")" -csv-data-dir "$CDATA" -output-dir "$CWAREHOUSE" \
    -benchmark-symbol GSPC.INDX -start-date "$WAREHOUSE_START" -end-date "$FRIDAY" -emit-weekly-sidetable -progress-every 200
  writes local "$WAREHOUSE"
  if [ "$DRY" = 0 ]; then grep -q 'failed=0' "$WORK/logs/warehouse.log" || die "warehouse verify did not report failed=0: $WORK/logs/warehouse.log"; fi
}

step_generate() {
  gen_config=../$CONFIG
  if [ "$PROFILE" = live-size ]; then
    run layer_config "$ROOT/$CONFIG" "$ROOT/$LIVE_SIZE_CONFIG" "$LAYERED_CONFIG"
    writes local "$LAYERED_CONFIG"
    gen_config=$(cpath "$LAYERED_CONFIG")
  fi
  crun_log "$WORK/logs/generate.log" $B/trading/weinstein/snapshot/gen/bin/generate_weekly_snapshot.exe \
    --as-of "$FRIDAY" --universe "$CWORK/universe.sexp" --bars-snapshot-dir "$CWAREHOUSE" \
    --snapshot-dir "$CWORK/out" --system-version "$SYSVER" --config-overrides "$gen_config" --portfolio "../$PORTFOLIO"
  writes local "$PICKS"
}

step_validate() {
  # Exit 1 = findings at Error level: a result to read, not a failed run. Anything above is a failure.
  vrc=0
  crun_out "$OUTDIR/$FRIDAY.validation.txt" "$WORK/logs/validate.err" $B/trading/weinstein/snapshot/bin/validate_weekly_snapshot.exe \
    "$CPICKS" -bars-snapshot-dir "$CWAREHOUSE" -risk-budget "$RISK_BUDGET" -through-band "$THROUGH_BAND" \
    -extension-max "$EXTENSION_MAX" || vrc=$?
  [ "$vrc" -le 1 ] || die "validate_weekly_snapshot exited $vrc (see $WORK/logs/validate.err)"
  writes local "$OUTDIR/$FRIDAY.validation.txt"
}

step_render() {
  crun_out "$OUTDIR/$FRIDAY.md" "$WORK/logs/render.err" $B/trading/weinstein/snapshot/bin/render_weekly_report.exe \
    "$CPICKS" -bars-snapshot-dir "$CWAREHOUSE" -html-out "$COUT/$FRIDAY.html"
  writes local "$OUTDIR/$FRIDAY.md"
  writes local "$OUTDIR/$FRIDAY.html"
  crun_out "$OUTDIR/$FRIDAY-picks.md" "$WORK/logs/summary.err" $B/trading/weinstein/snapshot/bin/public_picks_summary.exe "$CPICKS" -config-path "$SUMMARY_CONFIG"
  writes local "$OUTDIR/$FRIDAY-picks.md"
  [ "$DRY" = 1 ] || check_public_price_free "$OUTDIR/$FRIDAY-picks.md"
}

step_stage() {
  run mkdir -p "$TR_OUT"
  for f in "$FRIDAY.sexp" "$FRIDAY.md" "$FRIDAY.html" "$FRIDAY.validation.txt"; do
    run cp "$OUTDIR/$f" "$TR_OUT/$f"
    writes private "$TR_OUT/$f"
  done
  run cp "$WORK/universe.sexp" "$TR_OUT/universe-$FRIDAY.sexp"
  writes private "$TR_OUT/universe-$FRIDAY.sexp"
  run mkdir -p "$(dirname "$PUBLIC")"
  run cp "$OUTDIR/$FRIDAY-picks.md" "$PUBLIC"
  writes public "$PUBLIC"
}

STEPS="preflight build fetch-set fetch inventory eligible universe warehouse generate validate render stage"
set -- $STEPS
TOTAL=$#
N=0
CURRENT=""
trap 'rc=$?; [ "$rc" -eq 0 ] || printf "weekly.sh: step %s failed (exit %s); fix it and re-run to resume there. Logs: %s/logs\n" "$CURRENT" "$rc" "$WORK" >&2' EXIT

step() {
  N=$((N + 1)); CURRENT=$1
  if [ "$1" != preflight ] && [ -f "$DONE/$1" ]; then
    printf '== step %d/%d %s (marker present: skipped)\n' "$N" "$TOTAL" "$1"
    return 0
  fi
  printf '== step %d/%d %s\n' "$N" "$TOTAL" "$1"
  "step_$(printf '%s' "$1" | tr - _)"
  if [ "$1" != preflight ] && [ "$DRY" = 0 ]; then : > "$DONE/$1"; fi
}

printf 'weekly.sh: friday=%s sysver=%s profile=%s (universe: price >= %s, 30d ADV >= %s) dry_run=%s\n  repo=%s\n  work=%s\n  trading-results=%s\n' \
  "$FRIDAY" "$SYSVER" "$PROFILE" "$MIN_PRICE" "$MIN_ADV" "$DRY" "$ROOT" "$WORK" "$TR"
for s in $STEPS; do step "$s"; done

if [ "$DRY" = 1 ]; then
  echo "== dry run: nothing was run, written or fetched"
else
  errors=$(grep -c '^ERROR' "$OUTDIR/$FRIDAY.validation.txt" || true)
  warnings=$(grep -c '^WARN' "$OUTDIR/$FRIDAY.validation.txt" || true)
  printf '== done: %s on %s; validation: %s error(s), %s warning(s) (%s)\n' "$FRIDAY" "$SYSVER" "$errors" "$warnings" \
    "$TR_OUT/$FRIDAY.validation.txt"
fi
cat <<EOF
== publish (this script does not commit, push or open PRs)
  1. private records:
       git -C $TR add dev/weekly-picks/$SYSVER && git -C $TR commit -m "weekly-picks $SYSVER: $FRIDAY ($PROFILE)" && git -C $TR push
  2. public summary $PUBLIC:
       from a docs branch off main@origin: commit that one file, push, open a docs PR; quote
       \$(git -C $TR rev-parse --short HEAD) in the PR body as the private record, and add the Friday
       and its profile ($PROFILE) to the README table of published weeks
EOF
