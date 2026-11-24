#!/bin/sh
# universe-depth-2026-11-23: one tie seed's four arms (S3 / U4 / N3 / UN4) plus the build tripwire, in a Claude cloud
# session (docs/howtos/claude_cloud_sessions.md). Five sessions, one per seed, run side by side. Pre-registration and
# decision rule: PREREG.md beside this file; run notes: README.md. NOT run by its author.
#
#   ud-S3-kK   NAV-scale ns-P-100k-kK (record rk-kK at initial_cash 1e5 + the live-size lines appended last) on the
#              pit-v13 top-3000 schedule
#   ud-U4-kK   S3 on pit-v13 top-4000, universe_size 4000                  V6 vs S3
#   ud-N3-kK   S3 + ((require_structural_stop false)) appended last       V6 vs S3
#   ud-UN4-kK  U4 + the same line                                         V6 vs U4
# Specs are written by make_specs.sh; every relation is re-checked here (sh chain.sh check K) before anything runs.
#
# Two data stages, one per step (the tripwire keeps NAV-scale's; the arms use the new universe):
#   tripwire  v12: warehouse v12wk-9236, corpact-2026-10-27, bars data-20261102 (the record's stage, #3535)
#   arms      v13: warehouse v13pit-12710 (12,710 manifest entries, #3712), corpact-2026-11-23, bars data-20261123
# The tripwire runs first, on its own stage; once it MATCHes, the v12 stage is deleted (KEEP_V12=1 keeps it) and the
# v13 stage is pulled, so the session never holds both bar stores.
#
# Runs on the session host (POSIX sh) from the session's checkout at SC_SHA, the one main SHA all five sessions use
# (named in the launch brief). Every OCaml step runs in ghcr.io/dayfine/trading-ci:latest with the checkout mounted at
# /w. Everything is written under .sweep-output/universe-depth/ (gitignored, inside the mount); TMPDIR points there too.
# Launch (a session's background task is killed at 2 h, so detach):
#   SC_SHA=<sha> setsid nohup sh dev/experiments/universe-depth-2026-11-23/chain.sh run K \
#     >> .sweep-output/universe-depth/run.out 2>&1 < /dev/null &
#
# Subcommands:
#   sh chain.sh dry-run [K]     print every cell of seed K (all seeds without K): spec path, universe, stop gate, V6
#                               pair, stage, run order and batches, and the publish split; runs the spec checks. No
#                               guards, no container, no network, writes nothing.
#   sh chain.sh run K           lock -> guards -> spec checks -> build -> TRIPWIRE (v12 stage, ns-P-100k-k0 alone,
#                               md5 against TRIP_MD5: hard gate) -> drop v12 -> v13 stage -> preflight of the four arms
#                               -> seed K's cells PAR at a time -> extracts -> V6 x3 -> liveness -> collect
#   sh chain.sh trip            only the tripwire step (guards, build, v12 stage, the cell); a later `run K` skips it
#   sh chain.sh stage v12|v13   only that stage's R2 pulls and data dir (resumable; each step leaves a .done marker)
#   sh chain.sh check K         only the spec checks of seed K (no guards, no container)
#   sh chain.sh collect K       split seed K's files into results/kK/public (mark-free: commit to this repo under
#                               $EXP/results/kK/) and results/kK/private (price-bearing: dayfine/trading-results)
#   sh chain.sh publish K       commit and push results/kK/private into the trading-results checkout at TR (default
#                               ../trading-results). The public half is committed by the dispatcher in a results PR.
#   sh chain.sh entries AUDIT   the placed/skipped extract of one trade_audit.sexp (no guards)
#   sh chain.sh nss AUDIT       No_structural_stop skips per year from the audit's weekly decision record (no guards)
#   sh chain.sh depth SPEC ENTRIES TRADES   per round trip: list year, pit-v13 rank band, initial-stop kind (no guards)
#
# The tripwire runs in EVERY session: NAV-scale's own spec ns-P-100k-k0 (../nav-scale-participation-2026-11-23/specs/,
# unchanged since that run, guarded) on NAV-scale's own stage and env, whose trades.csv md5 must equal the committed
# ../nav-scale-participation-2026-11-23/results/k0/ns-P-100k-k0-s0-trades.md5.txt. It checks each session's build, image
# and R2 pulls before any of its cells counts. Its mark-free files are kept as public evidence under trip/.
# TRIPWIRE_WAIVE="<reason>" continues past a mismatch and logs it (PREREG: a mismatch means stop; waive only on the
# dispatcher's word).
#
# Resume: re-running `run K` skips the tripwire once MATCH or WAIVED is logged, each preflight whose PREFLIGHT_OK is
# logged, each cell with an .ok marker, each extract and V6 log once written. A failed cell keeps only its .log and .rss,
# so the relaunch re-runs it. The lock is an flock on a descriptor, so a killed run leaves no stale lock.
#
# Derived from ../nav-scale-participation-2026-11-23/chain.sh (guards, SHA pin, stage, build, preflight, PAR cells, V6,
# entries extract, the public/private split, the trading-results push). What is new: the two-stage tripwire, the v13
# stage, the pit-v13 checks, and two extracts the PREREG liveness rules need (README "Liveness, from the artifacts"):
#   -depth.tsv  one row per trades.csv round trip: position_id, symbol, decision date (the audit's, joined on
#               position_id; the fill date if unjoined), list year (the spec's own schedule), band (1-3000 / 3001-4000 /
#               off-list, from the pit-v13 lists of that year), stop_floor_kind (the audit's). No prices: public.
#   -nss.tsv    year, No_structural_stop skips in the weekly decision record (metric 6). Public.
# entries.tsv gains a 7th column, the placed entry's stop_floor_kind (Support_floor / Buffer_fallback; "-" on skips).
#
# Cell guard: CELL_TIMEOUT 28,000 s = 2.5 x (the slowest v12 cloud cell of this spec, 8,058 s, #3595, scaled by the
# U4 universe's 12,345 / 9,200 symbols). Peak RSS on v12 was 5.7-5.9 GB per cell (it counts mapped warehouse pages);
# scaled the same way ~7.7 GB, so CELL_GB 7 and PAR = (MemTotal - 3) / 7: 1 on the 15 GB VM (PAR=2 overrides, at the
# risk of an OOM kill that the relaunch would repair). A session at PAR 1: stage ~0.3 h x 2, build, tripwire ~2.2 h,
# four preflights ~0.3 h, four cells ~2.5-3 h each: about 13-15 h.
# R2 credentials (R2_*) come from the environment and are never printed (dev/scripts/r2_bars.sh header).
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
REPO=${REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}   # the checkout this script sits in
EXP=dev/experiments/universe-depth-2026-11-23
NS=dev/experiments/nav-scale-participation-2026-11-23
REC=dev/experiments/record-kseed-2026-10-27/specs
LIVE=dev/weekly-picks/live-size-overrides.sexp
PIT=trading/test_data/backtest_scenarios/pit-v13
OUT=${OUT:-$REPO/.sweep-output/universe-depth}
TR=${TR:-$REPO/../trading-results}                    # the session's checkout of dayfine/trading-results
IMG=${IMG:-ghcr.io/dayfine/trading-ci:latest}
RUNNER=${RUNNER:-run}       # run: docker run $IMG, checkout at /w (cloud). exec: docker exec into $CTR (local smoke)
CTR=${CTR:-trading-1-dev}
if [ "$RUNNER" = exec ]; then CROOT=${CROOT:-/workspaces/trading-1}; else CROOT=/w; fi
ART=$OUT/art; WORK=$OUT/work; LOG=$OUT/chain.log
TRIP_SPEC=$NS/specs/ns-P-100k-k0.sexp
TRIP_MD5_FILE=$NS/results/k0/ns-P-100k-k0-s0-trades.md5.txt
TRIP_MD5=f7746eb838618c9eac4aed7f969e63af            # = $TRIP_MD5_FILE (NAV-scale P-100k k0 at 44f1ba28e, #3704)
NS_HEAD=44f1ba28e                                    # NAV-scale's run build: the tripwire spec is unchanged since
CELL_TIMEOUT=${CELL_TIMEOUT:-28000}
CELL_GB=7; MEM_RESERVE_GB=3
DISK_MIN_GB=${DISK_MIN_GB:-8}
# NAV-scale's NEED (#3510 shards, #3547 relocatable warehouse, #3695 participation gate, #3697 initial_cash) + #3712
NEED="20824663d 8ee1ed797 e8e047ff9 c649c6dbf 6a6f89de8"
ARMS="S3 U4 N3 UN4"
KINDS="actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp"

# One stage per data set. Sets the names, the expected counts and the directories of stage $1.
use_stage() {
  case $1 in
    v12) WH_NAME=v12wk-9236; CA_NAME=corpact-2026-10-27; BARS_NAME=data-20261102; EXPECT_WH=9236; EXPECT_DIV=11880
         MMAP_HANDLES=12000; DISK_STAGE_GB=${DISK_STAGE_GB_V12:-12} ;;   # NAV-scale's values, so the tripwire matches
    v13) WH_NAME=v13pit-12710; CA_NAME=corpact-2026-11-23; BARS_NAME=data-20261123; EXPECT_WH=12710; EXPECT_DIV=
         MMAP_HANDLES=16000; DISK_STAGE_GB=${DISK_STAGE_GB_V13:-16} ;;   # handles > the U4 universe's 12,345 symbols
    *) echo "unknown stage '$1' (v12 | v13)" >&2; exit 2 ;;
  esac
  SD=$OUT/$1; WH=$SD/warehouse; CA=$SD/corpact; BARS=$SD/bars; TD=$SD/td-full; STAGE=$1
}

DRY=0; [ "$CMD" = dry-run ] && DRY=1
case "$CMD" in run|trip|stage|collect|publish) mkdir -p "$OUT" "$ART/trip" "$WORK" "$OUT/tmp"; export TMPDIR=$OUT/tmp ;; esac
log() { if [ "$DRY" = 1 ] || [ ! -d "$OUT" ]; then echo "$*"; else echo "[$(date -u '+%m-%d %H:%M:%S')Z] $*" | tee -a "$LOG"; fi; }
die() { log "ABORT: $*"; exit 1; }
cpath() { echo "$1" | sed "s#^$REPO#$CROOT#"; }       # host path -> container path
hpath() { echo "$1" | sed "s#^$CROOT#$REPO#"; }       # container path -> host path
dk() {
  if [ "$RUNNER" = exec ]; then docker exec -w "$CROOT/trading" "$CTR" bash -c "eval \$(opam env) 2>/dev/null && $1"
  else docker run --rm --user 0 -e HOME=/home/opam -v "$REPO:/w" -w /w/trading "$IMG" bash -c "eval \$(opam env) 2>/dev/null && $1"; fi
}
disk_ok() { g=$(df -BG --output=avail "$REPO" 2>/dev/null | tail -1 | tr -dc 0-9)
  [ -n "$g" ] || { log "disk free unknown (no GNU df)"; return 0; }; log "disk free ${g}G"; [ "$g" -ge "${1:-$DISK_MIN_GB}" ]; }
seed_ok() { case "${1:-}" in 0|1|2|3|4) return 0 ;; *) return 1 ;; esac; }
md5_of() { { md5sum "$1" 2>/dev/null || md5 -q "$1" 2>/dev/null; } | cut -c1-32; }
logged() { grep -q "$1" "$LOG" 2>/dev/null; }
mem_gb() { awk '/^MemTotal/ { printf "%d", $2 / 1048576 }' /proc/meminfo 2>/dev/null; }
par_n() { m=$(mem_gb); p=$(( (${m:-0} - MEM_RESERVE_GB) / CELL_GB )); [ "$p" -ge 1 ] || p=1; echo "${PAR:-$p}"; }
G() { gd=$1; shift   # git in a checkout, with a fallback identity for a session that has none
  if git -C "$gd" config user.email > /dev/null; then git -C "$gd" "$@"
  else git -c user.name=universe-depth-chain -c user.email=noreply@anthropic.com -C "$gd" "$@"; fi; }
spec_of() { echo "$REPO/$EXP/specs/ud-$1-k$2.sexp"; }   # $1 arm, $2 seed
depth_of() { case $1 in S3|N3) echo 3000 ;; U4|UN4) echo 4000 ;; esac; }
nss_of() { case $1 in S3|U4) echo true ;; N3|UN4) echo false ;; esac; }
ctrl_of() { case $1 in U4|N3) echo S3 ;; UN4) echo U4 ;; *) echo - ;; esac; }   # PREREG paired reads
# PREREG "Run plan": price-bearing files to trading-results only; mark-free ones also to this repo.
classify() {
  case $1 in
    *-trade_audit.sexp) echo skip ;;   # ~0.3 GB; entries.tsv / nss.tsv carry what the read uses
    *-actual.sexp|*-summary.sexp|*-params.sexp|*-macro_trend.sexp|*-entries.tsv|*-depth.tsv|*-nss.tsv|*-absent.txt|*.rss|*.validator.log|*.v6diff-*.log|*-trades.md5.txt) echo public ;;
    *) echo private ;;   # trades, equity curve, open positions, splits, liquidations, validator reports, cell log
  esac
}

# ------------------------------------------------------------------------------------------------------------ guards
guards() {
  cd "$REPO" || exit 1
  [ "$(git rev-parse --is-shallow-repository)" = true ] && git fetch -q --unshallow origin main
  git fetch -q origin main
  [ -n "${SC_SHA:-}" ] || die "SC_SHA unset (the launch brief names the one SHA all five sessions run)"
  sc=$(git rev-parse --verify -q "$SC_SHA^{commit}") || die "SC_SHA $SC_SHA is not a commit here"
  [ "$(git rev-parse HEAD)" = "$sc" ] || die "HEAD $(git rev-parse --short HEAD) is not SC_SHA $SC_SHA (git checkout $SC_SHA first)"
  git merge-base --is-ancestor "$sc" origin/main || die "SC_SHA $SC_SHA is not on origin/main"
  prev=$(sed -n 's/.*\] HEAD=\([0-9a-f]*\) .*/\1/p' "$LOG" | head -1)
  [ -z "$prev" ] || [ "$prev" = "$(git rev-parse --short=9 HEAD)" ] || die "HEAD differs from this chain.log's earlier HEAD=$prev"
  for c in $NEED; do git merge-base --is-ancestor "$c" HEAD || die "HEAD lacks $c"; done
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "checkout dirty"
  [ -f "$EXP/PREREG.md" ] && [ -f "$EXP/README.md" ] || die "$EXP not in the checkout (run kit not merged?)"
  git diff --quiet "$NS_HEAD" HEAD -- "$TRIP_SPEC" || die "$TRIP_SPEC changed since NAV-scale's run ($NS_HEAD)"
  [ "$(cut -c1-32 "$TRIP_MD5_FILE")" = "$TRIP_MD5" ] || die "$TRIP_MD5_FILE is not $TRIP_MD5"
  m=$(mem_gb)
  log "HEAD=$(git rev-parse --short=9 HEAD) image=$IMG $(docker image inspect -f '{{.Id}}' "$IMG" 2>/dev/null | cut -c1-19) mem=${m:-?}G par=$(par_n)"
  [ "${m:-0}" -ge $((CELL_GB + MEM_RESERVE_GB)) ] || die "MemTotal ${m:-?} GB < $((CELL_GB + MEM_RESERVE_GB)) (a U4 cell is expected near 7.7 GB)"
}

# ------------------------------------------------------------------------------------------------------------- stage
stage() { # $1 v12|v13: NAV-scale's stage, parametrised by use_stage
  use_stage "$1"; cd "$REPO" || exit 1; R2="sh dev/scripts/r2_bars.sh"
  if [ ! -f "$WH.done" ] || [ ! -f "$CA/.done" ] || [ ! -f "$TD/.done" ]; then
    disk_ok "$DISK_STAGE_GB" || die "disk < ${DISK_STAGE_GB}G before an unfinished $STAGE stage"; fi
  if [ -f "$WH.done" ]; then $R2 verify-dir --dir "$WH" --name "$WH_NAME" >> "$WORK/r2.log" 2>&1 || die "warehouse $WH_NAME verify failed"
  else rm -rf "$WH"; mkdir -p "$SD"
    log "PULL warehouse $WH_NAME"; $R2 pull-dir --dest "$WH" --name "$WH_NAME" >> "$WORK/r2.log" 2>&1 || die "pull-dir $WH_NAME"
    touch "$WH.done"; fi
  n=$(grep -c '(symbol ' "$WH/manifest.sexp"); [ "$n" = "$EXPECT_WH" ] || die "$WH_NAME manifest has $n entries, expected $EXPECT_WH"
  if [ ! -f "$CA/.done" ]; then rm -rf "$CA"
    log "PULL corpact $CA_NAME"; $R2 pull-dir --dest "$CA" --name "$CA_NAME" >> "$WORK/r2.log" 2>&1 || die "pull-dir $CA_NAME"
    touch "$CA/.done"; fi
  ex=$WORK/td-ca-extra-$STAGE.txt
  if [ ! -f "$TD/.done" ]; then
    rm -rf "$BARS" "$TD"
    log "PULL bars $BARS_NAME"; $R2 pull --dest "$BARS" --name "$BARS_NAME" >> "$WORK/r2.log" 2>&1 || die "pull $BARS_NAME"
    root=$BARS; [ -d "$BARS/data/A" ] && root=$BARS/data
    [ -d "$root/A" ] || die "bars archive layout not recognised (no A/ shard under $BARS)"
    low=$(find "$root" -mindepth 2 -maxdepth 2 -type d -name '[a-z]' | head -3)
    [ -z "$low" ] || die "lower-case shard dirs in the bar store (e.g. $low): pre-#3510 layout"
    mv "$root" "$TD"; rm -rf "$BARS"
    (cd "$REPO/trading/test_data" && tar cf - .) | (cd "$TD" && tar xf -) || die "test_data overlay"
    # dividends and splits = exactly $CA_NAME: overwrite, then drop any file not in its list
    tar -xzf "$CA/corpact.tar.gz" -C "$TD" || die "corpact unpack"
    sed 's#^\./##' "$CA/files.txt" | LC_ALL=C sort > "$WORK/corpact-files-$STAGE.txt"
    (cd "$TD" && find . \( -name dividends.csv -o -name splits.csv \) | sed 's#^\./##' | LC_ALL=C sort) > "$WORK/td-ca-files-$STAGE.txt"
    LC_ALL=C comm -23 "$WORK/td-ca-files-$STAGE.txt" "$WORK/corpact-files-$STAGE.txt" > "$ex"
    (cd "$TD" && xargs rm -f < "$ex")
    log "TD $STAGE: removed $(wc -l < "$ex") dividends/splits files not in $CA_NAME"
    touch "$TD/.done"
  fi
  # v13 has no recorded count yet: after the overwrite-and-drop the TD set IS the corpact list, so check that.
  ed=${EXPECT_DIV:-$(sed 's#^\./##' "$CA/files.txt" | grep -c '/dividends\.csv$')}
  nd=$(find "$TD" -name dividends.csv | wc -l | tr -d ' ')
  [ "$nd" = "$ed" ] || die "TD $STAGE has $nd dividends.csv, expected $ed"
  for f in share_classes.sexp macro/tbill_3m_dtb3.csv breadth/nyse_advn.csv; do [ -s "$TD/$f" ] || die "TD $STAGE lacks $f"; done
  log "STAGE OK $STAGE: warehouse $WH_NAME $n entries, corpact $CA_NAME, bars $BARS_NAME, TD $nd dividends.csv"
}
drop_stage() { # $1 stage: delete its pulls (never anything outside $OUT/<stage>)
  case $1 in v12|v13) [ -d "$OUT/$1" ] && rm -rf "${OUT:?}/$1" && log "DROPPED stage $1 ($OUT/$1)" ;; esac; return 0; }

build() {
  log "BUILD"
  dk "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe > $(cpath "$WORK")/build.log 2>&1" \
    || die "build failed (work/build.log)"
  log "BUILD_DONE"
}

# ------------------------------------------------------------------------------------------------------- spec checks
# Normalised content: comments, the name and description lines and all whitespace dropped.
norm() { sed -e 's/;;.*$//' -e '/^((name "/d' -e '/^ (description "/d' "$1" | tr -d ' \t\n'; }
# The arm's transform of NAV-scale's ns-P-100k-kK, normalised: what make_specs.sh promises.
want_of() { # $1 arm, $2 seed
  d=$(depth_of "$1"); t=
  [ "$(nss_of "$1")" = false ] && t='((require_structural_stopfalse))'
  norm "$REPO/$NS/specs/ns-P-100k-k$2.sexp" | sed -e "s#pit-v12/composition/top-3000-#pit-v13/composition/top-$d-#g" \
    -e "s#(universe_size3000)#(universe_size$d)#" -e "s#((min_hold_dollar_adv50000.0))))#&$t#"
}
sched_lists() { sed -n 's#^  ([0-9-]* "\(pit-v13/composition/top-[0-9]*-[0-9]*\.sexp\)")$#\1#p' "$1"; }
spec_checks() { # $1 seed
  ns=$REPO/$NS/specs/ns-P-100k-k$1.sexp; [ -s "$ns" ] || die "missing $ns"
  # NAV-scale's spec is itself rk-kK + initial_cash + the live-size lines (its chain.sh check); re-check the parts used.
  n=$(norm "$ns"); r=$(norm "$REPO/$REC/rk-k$1.sexp" | sed 's#(universe_size3000)#&(initial_cash100000.0)#')
  po=$(grep -v '^;' "$REPO/$LIVE" | tr -d ' \t\n'); tb="((screening_config((tiebreak_seed$1))))"
  [ "$n" = "${r%%"$tb"*}$tb$po${r#*"$tb"}" ] || die "$ns is not rk-k$1 + initial_cash 1e5 + $LIVE appended after tiebreak_seed"
  case "$po" in '((liquidity_config((max_entry_adv_participation(0.10)))))((liquidity_config((min_entry_dollar_adv100000.0))))((liquidity_config((min_hold_dollar_adv50000.0))))') ;;
    *) die "$LIVE is not the three live-size lines (0.10, 100000.0, 50000.0): $po" ;; esac
  case "$r" in *'((require_structural_stoptrue))'*) ;; *) die "rk-k$1 lacks ((require_structural_stop true))" ;; esac
  for arm in $ARMS; do s=$(spec_of "$arm" "$1"); [ -s "$s" ] || die "missing $s"; d=$(depth_of "$arm")
    grep -q "^((name \"ud-$arm-k$1\")" "$s" || die "$s: name is not ud-$arm-k$1"
    [ "$(norm "$s")" = "$(want_of "$arm" "$1")" ] || die "$s is not ns-P-100k-k$1 with only the $arm changes (make_specs.sh)"
    ! grep -q 'pit-v12' "$s" || die "$s still names pit-v12"
    nl=$(sched_lists "$s" | grep -c "top-$d-"); [ "$nl" = 27 ] || die "$s: $nl pit-v13 top-$d schedule lines, expected 27"
    for l in $(sched_lists "$s"); do [ -s "$REPO/trading/test_data/backtest_scenarios/$l" ] || die "$s: $l not in the checkout"; done
  done
  log "SPEC CHECKS OK k$1 (ud-*-k$1 = ns-P-100k-k$1 on pit-v13; U* top-4000 / universe_size 4000; N* + require_structural_stop false last)"
}
# Symbols the runner should load for a spec: its schedule's lists' union (params universe_size), plus the 15
# warehouse extras (the n_symbols of the cache line). v12 check: 9,185 + 15 = 9,200, NAV-scale's logged values.
list_syms() { for l in $(sched_lists "$1"); do sed -n 's/.*(symbol \([^)]*\)).*/\1/p' "$REPO/trading/test_data/backtest_scenarios/$l"; done; }
universe_n() { list_syms "$1" | sort -u | wc -l | tr -d ' '; }
loaded_n() { { list_syms "$1"; cat "$REPO/$PIT/warehouse-extras.txt"; } | sort -u | wc -l | tr -d ' '; }
# Names the spec can load that the staged warehouse manifest lacks (pit-v13/quarantine.txt's four at least): the
# warehouse-coverage hole of the arm over all 27 lists, which bounds the preflight's n_symbols_absent from above.
absent_syms() { sed -n 's/.*(symbol *\([^) ]*\)).*/\1/p' "$WH/manifest.sexp" | LC_ALL=C sort -u > "$WORK/manifest-$STAGE.txt"
  { list_syms "$1"; cat "$REPO/$PIT/warehouse-extras.txt"; } | LC_ALL=C sort -u | LC_ALL=C comm -23 - "$WORK/manifest-$STAGE.txt"; }

# ------------------------------------------------------------------------------------------------------------- cells
runner() { # $1 spec dir, $2 log, $3 prefix (time and timeout); the stage set by use_stage
  dk "TRADING_DATA_DIR=$(cpath "$TD") TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES $3 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$1") --fixtures-root $CROOT/trading/test_data/backtest_scenarios --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --progress-every 26 --parallel 1 > $(cpath "$2") 2>&1; echo exit=\$? >> $(cpath "$2")"
}
out_of() { hpath "$(grep 'Output root' "$1" | tail -1 | sed 's/.*: //')"; }   # $1 runner log -> the output root
rm_root() { case $1 in */dev/backtest/scenarios-*) rm -rf "$1" ;; esac; }   # never anything but a runner's own root

# Three months of each arm (2000-01-03 .. 2000-03-31) on the v13 stage: the spec parses at this build, params.sexp
# carries the cash, the live-size lines, the stop gate's value last and the schedule's union, and the cache loads the
# expected symbol count; the names it may find absent are at most the arm's manifest hole (absent_syms), which is
# logged per arm and kept as public evidence (ud-<arm>-kK-absent.txt) because a list name the warehouse lacks cannot trade.
preflight() { # $1 seed
  for arm in $ARMS; do name=ud-$arm-k$1; pd=$WORK/preflight-$name; s=$(spec_of "$arm" "$1")
    if logged "PREFLIGHT_OK $name "; then log "SKIP preflight $name (done)"; continue; fi
    rm -rf "$pd"; mkdir -p "$pd"
    sed "s/(end_date 2026-06-26)/(end_date 2000-03-31)/" "$s" > "$pd/$name.sexp"
    grep -q "(end_date 2000-03-31)" "$pd/$name.sexp" || die "preflight $name: end_date not rewritten"
    log "PREFLIGHT $name (to 2000-03-31)"; t0=$(date +%s); runner "$pd" "$pd.log" "timeout 3600"
    po=$(out_of "$pd.log")
    [ -s "$po/$name/actual.sexp" ] || die "preflight $name wrote no actual.sexp (see $pd.log)"
    p=$(tr -d ' \t\n' < "$po/$name/params.sexp")
    ic=$(echo "$p" | sed -n 's/.*(initial_cash\([0-9.]*\)).*/\1/p')
    awk -v a="$ic" 'BEGIN { exit !(a + 0 == 100000) }' || die "preflight $name: params.sexp initial_cash '$ic', expected 100000"
    case "$p" in *'(max_entry_adv_participation(0.10))'*'(min_entry_dollar_adv100000.0)'*'(min_hold_dollar_adv50000.0)'*) ;;
      *) die "preflight $name: params.sexp lacks the live-size lines in order" ;; esac
    case "$(nss_of "$arm"):$p" in
      false:*'(min_hold_dollar_adv50000.0))))((require_structural_stopfalse))'*) ;;
      true:*require_structural_stopfalse*) die "preflight $name: S/U arm carries require_structural_stop false" ;;
      true:*) ;;
      *) die "preflight $name: require_structural_stop false is not the last override" ;; esac
    us=$(echo "$p" | sed -n 's/.*(universe_size\([0-9]*\)).*/\1/p'); ue=$(universe_n "$s")
    [ "$us" = "$ue" ] || die "preflight $name: params universe_size $us, expected the schedule's union $ue"
    cache=$(grep -h 'Panel_runner: snapshot cache hits' "$pd.log" | tail -1)
    nsy=$(echo "$cache" | sed -n 's/.* n_symbols=\([0-9]*\) .*/\1/p'); na=$(echo "$cache" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
    le=$(loaded_n "$s")
    t=ud-$arm-k$1; absent_syms "$s" > "$ART/$t-absent.txt"; ab=$(wc -l < "$ART/$t-absent.txt" | tr -d ' ')
    log "ABSENT $name: $ab of $le loadable names not in the $WH_NAME manifest (art/$t-absent.txt; quarantine: $(grep -v '^#' "$REPO/$PIT/quarantine.txt" | cut -d' ' -f1 | tr '\n' ' '))"
    [ "$nsy" = "$le" ] && [ -n "$na" ] && [ "$na" -le "$ab" ] \
      || die "preflight $name: n_symbols=$nsy n_symbols_absent=$na (expected $le and at most the $ab names of art/$t-absent.txt)"
    rm_root "$po"; log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s, initial_cash=$ic, universe_size=$us, n_symbols=$nsy absent=$na)"
  done
}

# One 26y cell. Its files land in $3 as <tag>-<kind>; the .ok marker is written last.
run_cell() { # $1 tag, $2 scenario name, $3 artifact dir, $4 spec file
  tag=$1; name=$2; a=$3; d=$WORK/cell-$tag
  [ -f "$a/$tag.ok" ] && { log "SKIP $tag (done)"; return 0; }
  rm -rf "$d"; mkdir -p "$d"; rm -f "$a/$tag"-* "$a/$tag".*; cp "$4" "$d/" || return 1
  log "RUN $tag (stage $STAGE)"; t0=$(date +%s)
  runner "$d" "$a/$tag.log" "/usr/bin/time -f 'peak_rss_kb=%M' -o $(cpath "$a")/$tag.rss timeout $CELL_TIMEOUT"
  root=$(out_of "$a/$tag.log"); ex=$(tail -1 "$a/$tag.log"); rss=$(tail -1 "$a/$tag.rss" 2>/dev/null)
  for f in $KINDS; do cp "$root/$name/$f" "$a/$tag-$f" 2>/dev/null; done
  if [ "$ex" != exit=0 ] || [ ! -s "$a/$tag-actual.sexp" ] || [ ! -s "$a/$tag-trades.csv" ]; then
    rm -f "$a/$tag"-*; log "CELL FAILED $tag: $ex ${rss:-no rss} (wall $(( $(date +%s) - t0 ))s)"; return 1; fi
  dk "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir $(cpath "$root/$name") -data-dir $(cpath "$TD") -share-classes $CROOT/trading/test_data/share_classes.sexp -out $(cpath "$a")/$tag-validator.sexp > $(cpath "$a")/$tag.validator.log 2>&1; echo exit=\$? >> $(cpath "$a")/$tag.validator.log"
  rm_root "$root"
  [ -s "$a/$tag-validator.sexp.sexp" ] || { log "CELL FAILED $tag: no validator report (see $tag.validator.log)"; return 1; }
  md5_of "$a/$tag-trades.csv" > "$a/$tag-trades.md5.txt"
  touch "$a/$tag.ok"
  r=$(sed -n 's/.*(total_return_pct \([-0-9.eE+]*\)).*/\1/p' "$a/$tag-actual.sexp" | head -1)
  dd=$(sed -n 's/.*(max_drawdown_pct \([-0-9.eE+]*\)).*/\1/p' "$a/$tag-actual.sexp" | head -1)
  lr=$(awk -v r="$r" 'BEGIN { if (r == "") print "?"; else printf "%.4f", log(1 + r / 100) }')
  log "RESULT $tag => log_nav_ratio $lr total_return_pct ${r:-?} max_drawdown_pct ${dd:-?} $rss (wall $(( $(date +%s) - t0 ))s)"
}
cell_ok() { [ -f "$ART/ud-$1-k$2-s0.ok" ]; }

# PREREG "Tripwire and validity": NAV-scale P-100k k0 on NAV-scale's v12 stage reproduces its trades.csv. Hard gate.
tripwire() {
  t=ns-P-100k-k0-s0
  if logged "TRIPWIRE MATCH $t \|TRIPWIRE WAIVED for $t:"; then log "SKIP tripwire (done)"
    [ "${KEEP_V12:-0}" = 1 ] || drop_stage v12; return 0; fi   # a run killed between the MATCH line and the drop
  stage v12
  run_cell "$t" ns-P-100k-k0 "$ART/trip" "$REPO/$TRIP_SPEC" || die "CELL FAILED $t (the tripwire cell); a relaunch re-runs it"
  got=$(cat "$ART/trip/$t-trades.md5.txt")
  if [ "$got" = "$TRIP_MD5" ]; then log "TRIPWIRE MATCH $t trades.csv md5 $got ($(wc -l < "$ART/trip/$t-trades.csv" | tr -d ' ') lines)"
  else
    log "TRIPWIRE MISMATCH $t trades.csv md5 $got, expected $TRIP_MD5 ($TRIP_MD5_FILE)"
    [ -n "${TRIPWIRE_WAIVE:-}" ] || die "tripwire: ns-P-100k-k0 does not reproduce NAV-scale; stop (PREREG). Diagnose the build, image or stage."
    log "TRIPWIRE WAIVED for $t: $TRIPWIRE_WAIVE"
  fi
  [ "${KEEP_V12:-0}" = 1 ] || drop_stage v12
}

cells() { # $1 seed: seed K's four cells on the v13 stage, PAR at a time
  use_stage v13; todo=; for arm in $ARMS; do cell_ok "$arm" "$1" || todo="$todo $arm"; done
  par=$(par_n); n=0; log "CELLS k$1: to run:${todo:- none} (PAR $par)"
  for arm in $todo; do run_cell "ud-$arm-k$1-s0" "ud-$arm-k$1" "$ART" "$(spec_of "$arm" "$1")" & n=$((n + 1))
    [ "$n" -lt "$par" ] || { wait; n=0; disk_ok || die "disk < ${DISK_MIN_GB}G"; }; done
  wait
  for arm in $ARMS; do cell_ok "$arm" "$1" || die "CELL FAILED ud-$arm-k$1-s0 (art/ud-$arm-k$1-s0.log); a relaunch re-runs only unfinished cells"; done
}

# ---------------------------------------------------------------------------------------------------------- extracts
# The audit as one record per line (NAV-scale's, unchanged).
audit_records() { tr -s '\n\t ' '   ' < "$1" | awk '{ gsub(/\(\(entry \(/, "\n&"); print }'; }
# NAV-scale's placed/skipped extract, plus column 7: the placed entry's initial-stop kind (the entry record's
# stop_floor_kind; alternatives carry none, so the record's first match is the entry's own).
entries_extract() { # $1 trade_audit.sexp -> stdout TSV
  printf 'position_id\tsymbol\tdecision_date\tkind\tside\tskip_reason\tstop_floor_kind\n'
  audit_records "$1" | awk '
    /^\(\(entry \(/ {
      sym = ""; d = ""; id = ""; side = ""; sk = "?"
      if (match($0, /\(symbol [^ )]+\)/)) sym = substr($0, RSTART + 8, RLENGTH - 9)
      if (match($0, /\(entry_date [0-9-]+\)/)) d = substr($0, RSTART + 12, RLENGTH - 13)
      if (match($0, /\(position_id [^ )]+\)/)) id = substr($0, RSTART + 13, RLENGTH - 14)
      if (match($0, /\(side [A-Za-z]+\)/)) side = substr($0, RSTART + 6, RLENGTH - 7)
      if (match($0, /\(stop_floor_kind [A-Za-z_]+\)/)) sk = substr($0, RSTART + 17, RLENGTH - 18)
      print id "\t" sym "\t" d "\tplaced\t" side "\t-\t" sk
      s = $0; i = index(s, "(alternatives_considered"); if (i == 0) next; s = substr(s, i)
      while (match(s, /\(symbol [^ )]+\) \(side [A-Za-z]+\) \(score [^ )]+\) \(grade [A-Za-z_]+\) \(reason_skipped [A-Za-z_]+\)/)) {
        r = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        split(r, t, /[() ]+/)
        k = d "|" t[3] "|" t[11]
        if (!(k in seen)) { seen[k] = 1; print "-\t" t[3] "\t" d "\tskipped\t" t[5] "\t" t[11] "\t-" } } }' |
    LC_ALL=C sort -t "$(printf '\t')" -k3,3 -k4,4 -k1,1
}
# Metric 6: No_structural_stop skips per year, from the weekly decision record (cascade_summaries, #3139), which
# lists every top-N candidate of every screening Friday, not only Fridays with a buy.
nss_extract() { # $1 trade_audit.sexp -> stdout TSV
  printf 'year\tno_structural_stop_skips\tscreening_fridays\n'
  tr -s '\n\t ' '   ' < "$1" | awk '{ gsub(/\(\(date [0-9]+-[0-9]+-[0-9]+\) \(total_stocks /, "\n&"); gsub(/\(cascade_summaries /, "\n&"); print }' | awk '
    index($0, "(cascade_summaries ") == 1 { on = 1; next }
    on && /^\(\(date [0-9]+-/ { y = substr($0, 8, 4); f[y]++; s[y] += gsub(/\(Skipped No_structural_stop\)/, "&") }
    END { for (y in f) printf "%s\t%d\t%d\n", y, s[y] + 0, f[y] }' | LC_ALL=C sort
}
# Per round trip: the list year the spec's own schedule had in force on the decision date, and the pit-v13 band of
# the symbol in that year's lists (1-3000 = in top-3000; 3001-4000 = in top-4000 only; off-list = in neither, e.g.
# a hold carried across a rebalance does not occur here because the date is the ENTRY decision). The decision date is
# the audit's (entries.tsv, joined on position_id); a round trip the audit does not carry falls back to its fill date.
depth_extract() { # $1 spec, $2 entries.tsv, $3 trades.csv -> stdout TSV
  lists=; for y in $(seq 1999 2026); do for d in 3000 4000; do f=$REPO/$PIT/composition/top-$d-$y.sexp; [ -f "$f" ] && lists="$lists $f"; done; done
  printf 'position_id\tsymbol\tdecision_date\tdate_source\tlist_year\tband\tstop_floor_kind\n'
  # shellcheck disable=SC2086
  awk -v FS='\t' '
    FILENAME ~ /\/top-[0-9]+-[0-9]+\.sexp$/ {
      n = split(FILENAME, p, "/"); split(p[n], q, /[-.]/)   # top-DDDD-YYYY.sexp
      if (match($0, /\(symbol [^ )]+\)/)) { sym = substr($0, RSTART + 8, RLENGTH - 9); m[q[3], q[2], sym] = 1 }
      next }
    FILENAME == spec { if (match($0, /^  \([0-9-]+ "pit-v13\/composition\/top-[0-9]+-[0-9]+\.sexp"\)$/)) {
        ns++; sd[ns] = substr($0, 4, 10); sy[ns] = substr($0, length($0) - 10, 4) }; next }
    FILENAME == ent { if ($4 == "placed") { dd[$1] = $3; kk[$1] = (NF >= 7 ? $7 : "?") }; next }
    FNR == 1 { FS = ","; for (i = 1; i <= split($0, h, ","); i++) col[h[i]] = i; next }
    {
      split($0, c, ","); id = c[col["position_id"]]; sym = c[col["symbol"]]
      if (id in dd) { d = dd[id]; src = "audit"; k = kk[id] } else { d = c[col["entry_date"]]; src = "fill"; k = "?" }
      y = "-"; for (i = 1; i <= ns; i++) if (sd[i] <= d) y = sy[i]
      b = ((y, 3000, sym) in m) ? "1-3000" : (((y, 4000, sym) in m) ? "3001-4000" : "off-list")
      print id "\t" sym "\t" d "\t" src "\t" y "\t" b "\t" k }' spec="$1" ent="$2" $lists "$1" "$2" FS=, "$3"
}
# One line per arm: round trips by band and by stop kind; placed entries by stop kind (the PREREG liveness counts).
depth_line() { # $1 depth.tsv, $2 entries.tsv
  awk -F'\t' 'NR > 1 { n++; b[$6]++; k[$7]++ } END {
      printf "round_trips %d band_1-3000 %d band_3001-4000 %d off-list %d rt_Buffer_fallback %d rt_Support_floor %d",
        n, b["1-3000"], b["3001-4000"], b["off-list"], k["Buffer_fallback"], k["Support_floor"] }' "$1"
  awk -F'\t' '$4 == "placed" { n++; k[$7]++ } END {
      printf " | placed %d placed_Buffer_fallback %d (%.1f%%)", n, k["Buffer_fallback"], (n ? 100 * k["Buffer_fallback"] / n : 0) }' "$2"
}

reads() { # $1 seed: extracts, V6 (U4 vs S3, N3 vs S3, UN4 vs U4) and liveness, each skipped once written
  for arm in $ARMS; do t=ud-$arm-k$1-s0
    [ -s "$ART/$t-entries.tsv" ] || { entries_extract "$ART/$t-trade_audit.sexp" > "$ART/$t-entries.tsv" || die "ENTRIES $t: extract FAILED"; }
    [ -s "$ART/$t-nss.tsv" ] || { nss_extract "$ART/$t-trade_audit.sexp" > "$ART/$t-nss.tsv" || die "NSS $t: extract FAILED"; }
    [ -s "$ART/$t-depth.tsv" ] || { depth_extract "$(spec_of "$arm" "$1")" "$ART/$t-entries.tsv" "$ART/$t-trades.csv" > "$ART/$t-depth.tsv" || die "DEPTH $t: extract FAILED"; }
    log "EXTRACT $t: $(depth_line "$ART/$t-depth.tsv" "$ART/$t-entries.tsv") | No_structural_stop skips $(awk -F'\t' 'NR > 1 { s += $2 } END { print s + 0 }' "$ART/$t-nss.tsv")"
  done
  for arm in U4 N3 UN4; do c=$(ctrl_of "$arm"); ct=ud-$c-k$1-s0; at=ud-$arm-k$1-s0; v=$ART/$at.v6diff-$c.log
    [ -s "$v" ] || dk "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$(cpath "$ART")/$ct-validator.sexp.sexp -report arm=$(cpath "$ART")/$at-validator.sexp.sexp > $(cpath "$v") 2>&1; echo exit=\$? >> $(cpath "$v")"
    same=differ; cmp -s "$ART/$ct-trades.csv" "$ART/$at-trades.csv" && same=IDENTICAL
    log "PAIR k$1 $arm vs $c: trades.csv $same; V6 $(tail -1 "$v")"
  done
  # PREREG liveness, per seed; applied over the five seeds at read time (>= 3 of 5).
  u=$(awk -F'\t' 'NR > 1 && $6 == "3001-4000"' "$ART/ud-U4-k$1-s0-depth.tsv" | wc -l | tr -d ' ')
  log "LIVE k$1 U4: $u round trips in top-4000-not-top-3000 names of their decision year (PREREG: >= 10)"
  log "LIVE k$1 N3: $(awk -F'\t' '$4 == "placed" { n++; if ($7 == "Buffer_fallback") b++ } END { printf "%d of %d placed entries Buffer_fallback = %.1f%%", b, n, (n ? 100 * b / n : 0) }' "$ART/ud-N3-k$1-s0-entries.tsv") (PREREG: >= 20 %)"
}

collect() { # $1 seed
  k=$1; pub=$OUT/results/k$k/public/$EXP/results/k$k; prv=$OUT/results/k$k/private/$EXP/results/k$k
  rm -rf "$OUT/results/k$k"; mkdir -p "$pub/trip" "$prv/trip"
  for f in "$ART"/ud-*-k"$k"-s0[.-]* "$ART"/ud-*-k"$k"-absent.txt "$ART"/trip/ns-P-100k-k0-s0[.-]*; do [ -f "$f" ] || continue; b=${f##*/}; c=$(classify "$b")
    case $f in "$ART"/trip/*) sub=/trip ;; *) sub= ;; esac
    [ "$c" = skip ] && continue; cp "$f" "$prv$sub/"; [ "$c" = private ] || cp "$f" "$pub$sub/"; done
  cp "$LOG" "$pub/chain-k$k.log"; cp "$WORK"/td-ca-extra-*.txt "$pub/" 2>/dev/null
  log "COLLECT k$k: public $(find "$pub" -type f | wc -l | tr -d ' ') files, private $(find "$prv" -type f | wc -l | tr -d ' ') files ($OUT/results/k$k)"
}

publish() { # $1 seed: the private half into trading-results main
  k=$1; src=$OUT/results/k$k/private
  [ -d "$src/$EXP" ] || die "nothing collected for k$k (sh chain.sh collect $k)"
  [ -d "$TR/.git" ] && git -C "$TR" remote get-url origin 2>/dev/null | grep -q trading-results || die "no dayfine/trading-results checkout at TR=$TR"
  { git -C "$TR" fetch -q origin main && git -C "$TR" checkout -q main && git -C "$TR" merge -q --ff-only origin/main; } \
    || die "trading-results at $TR does not fast-forward to origin/main"
  cp -R "$src"/. "$TR/"; git -C "$TR" add "$EXP"
  git -C "$TR" diff --cached --quiet || G "$TR" commit -q -m "universe-depth k$k: price-bearing cells" || die "trading-results commit"
  i=0; until git -C "$TR" push -q origin HEAD:main 2>/dev/null; do i=$((i + 1))
    [ "$i" -le 3 ] && G "$TR" pull -q --rebase origin main || die "push trading-results main"; done
  log "PUBLISH k$k private: dayfine/trading-results main at $(git -C "$TR" rev-parse --short=9 HEAD)"
}

dry_run() { # [$1 seed]
  seeds=${1:-0 1 2 3 4}; par=${PAR:-1}
  echo "universe-depth dry run: no guards, no container, no network, nothing written. PAR=$par (cloud: (MemTotal - 3) / $CELL_GB)"
  for k in $seeds; do seed_ok "$k" || { echo "usage: sh $0 dry-run [K]" >&2; exit 2; }
    echo "== session k$k (SC_SHA=<sha> sh $EXP/chain.sh run $k)"
    spec_checks "$k"
    use_stage v12
    echo "  1. TRIPWIRE alone, stage v12 ($WH_NAME, $CA_NAME, $BARS_NAME; mmap handles $MMAP_HANDLES): ns-P-100k-k0-s0  $TRIP_SPEC"
    echo "     trades.csv md5 must be $TRIP_MD5 ($TRIP_MD5_FILE); then the v12 stage is deleted"
    use_stage v13
    echo "  2. stage v13 ($WH_NAME, $CA_NAME, $BARS_NAME; mmap handles $MMAP_HANDLES)"
    echo "  3. preflight to 2000-03-31: $(for a in $ARMS; do printf 'ud-%s-k%s ' "$a" "$k"; done)"
    b=1; n=0; printf '  4. batch %d:' "$b"
    for a in $ARMS; do [ "$n" -lt "$par" ] || { b=$((b + 1)); n=0; printf '\n     batch %d:' "$b"; }; printf ' ud-%s-k%s' "$a" "$k"; n=$((n + 1)); done; echo
    for a in $ARMS; do s=$EXP/specs/ud-$a-k$k.sexp; c=$(ctrl_of "$a"); pr=-; [ "$c" = - ] || pr="V6 vs ud-$c-k$k-s0"
      printf '     cell ud-%s-k%s-s0  spec %s  pit-v13 top-%s (union %s, loads %s)  require_structural_stop %s  %s\n' \
        "$a" "$k" "$s" "$(depth_of "$a")" "$(universe_n "$REPO/$s")" "$(loaded_n "$REPO/$s")" "$(nss_of "$a")" "$pr"; done
    echo "  5. extracts (entries, nss, depth), V6 x3, LIVE U4 / N3 -> collect: public -> $EXP/results/k$k/ (this repo); private -> trading-results $EXP/results/k$k/"
  done
  echo "public kinds: actual.sexp summary.sexp params.sexp macro_trend.sexp entries.tsv depth.tsv nss.tsv trades.md5.txt .rss .validator.log .v6diff-*.log chain log (+ trip/)"
  echo "private kinds (trading-results only): trades.csv equity_curve.csv open_positions.csv splits.csv force_liquidations.sexp validator reports cell log"
  echo "not kept: trade_audit.sexp (size; entries.tsv and nss.tsv carry what the read uses)"
}

cmd_trip() {
  exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"
  rm -rf "$OUT/tmp"/r2_bars.* "$OUT"/v1[23]/warehouse.partial.*   # a restart mid-pull's leftovers, safe under the lock
  guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  build; tripwire
}

cmd_run() { # $1 seed
  seed_ok "${1:-}" || { echo "usage: sh $0 run K   (K in 0..4)" >&2; exit 2; }
  exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"
  rm -rf "$OUT/tmp"/r2_bars.* "$OUT"/v1[23]/warehouse.partial.*
  log "universe-depth run k$1; SC_SHA=${SC_SHA:-unset} CELL_TIMEOUT=${CELL_TIMEOUT}s"
  guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  spec_checks "$1"
  build
  tripwire
  stage v13
  preflight "$1"
  cells "$1"
  reads "$1"
  collect "$1"
  log "UNIVERSE-DEPTH k$1 DONE. Next: sh $EXP/chain.sh publish $1 (trading-results), then commit results/k$1/public into this repo."
}

case "$CMD" in
  dry-run) dry_run "${1:-}" ;;
  run) cmd_run "${1:-}" ;;
  trip) cmd_trip ;;
  stage) case "${1:-}" in v12|v13) guards; stage "$1" ;; *) echo "usage: sh $0 stage v12|v13" >&2; exit 2 ;; esac ;;
  check) seed_ok "${1:-}" || { echo "usage: sh $0 check K" >&2; exit 2; }; spec_checks "$1" ;;
  collect) seed_ok "${1:-}" || { echo "usage: sh $0 collect K" >&2; exit 2; }; collect "$1" ;;
  publish) seed_ok "${1:-}" || { echo "usage: sh $0 publish K" >&2; exit 2; }; publish "$1" ;;
  entries) entries_extract "${1:?usage: sh $0 entries AUDIT}" ;;
  nss) nss_extract "${1:?usage: sh $0 nss AUDIT}" ;;
  depth) [ $# -eq 3 ] || { echo "usage: sh $0 depth SPEC ENTRIES TRADES" >&2; exit 2; }; depth_extract "$1" "$2" "$3" ;;
  *) echo "usage: sh $0 {dry-run [K]|run K|trip|stage v12|v13|check K|collect K|publish K|entries AUDIT|nss AUDIT|depth SPEC ENTRIES TRADES}" >&2; exit 2 ;;
esac
