#!/bin/sh
# nav-scale-participation-2026-11-23: one tie seed's six arms (F/P x 100k/1M/10M) in a Claude cloud session
# (docs/howtos/claude_cloud_sessions.md). Five sessions, one per seed, run side by side. Pre-registration and read rule:
# README.md beside this file. NOT run by its author.
#
#   ns-F-<cash>-kK  rk-kK (../record-kseed-2026-10-27/specs/rk-kK.sexp) at initial_cash <cash>; F-1M IS rk-kK
#   ns-P-<cash>-kK  ns-F-<cash>-kK + the three lines of dev/weekly-picks/live-size-overrides.sexp, appended last;
#                   V6 against ns-F-<cash>-kK (same cash, same seed)
# Specs are written by make_specs.sh; every relation is re-checked here (sh chain.sh check K) before anything runs.
#
# Runs on the session host (POSIX sh) from the session's checkout at SC_SHA, the one main SHA all five sessions use
# (named in the launch brief). Every OCaml step runs in ghcr.io/dayfine/trading-ci:latest with the checkout mounted at
# /w. Everything is written under .sweep-output/nav-scale/ (gitignored, inside the mount); TMPDIR points there too.
# Launch (a session's background task is killed at 2 h, so detach):
#   SC_SHA=<sha> setsid nohup sh dev/experiments/nav-scale-participation-2026-11-23/chain.sh run K \
#     >> .sweep-output/nav-scale/run.out 2>&1 < /dev/null &
#
# Subcommands:
#   sh chain.sh dry-run [K]     print every cell of seed K (all seeds without K): spec path, cash, liquidity, V6 pair,
#                               run order and batches, and the publish split; runs the spec checks. No guards, no
#                               container, no network, writes nothing.
#   sh chain.sh run K           lock -> guards -> stage (R2 pulls, data dir) -> build -> spec checks -> preflight of the
#                               six arms -> TRIPWIRE cell ns-F-1M-k0 alone, md5 against TRIP_MD5 (hard gate) -> seed K's
#                               other cells PAR at a time -> extracts -> V6 (P vs F, same cash) -> liveness (information)
#                               -> collect into results/kK/{public,private}
#   sh chain.sh stage           only the R2 pulls and the data dir (resumable; each step leaves a .done marker)
#   sh chain.sh check K         only the spec checks of seed K (no guards, no container)
#   sh chain.sh collect K       split seed K's files into results/kK/public (mark-free: commit to this repo under
#                               $EXP/results/kK/) and results/kK/private (price-bearing: dayfine/trading-results, same path)
#   sh chain.sh publish K       commit and push results/kK/private into the trading-results checkout at TR (default
#                               ../trading-results). The public half is committed by the dispatcher in a results PR.
#   sh chain.sh entries AUDIT   print the placed/skipped extract of one trade_audit.sexp (no guards)
#
# The tripwire runs in EVERY session, not only seed 0's: each session first runs ns-F-1M-k0 alone and checks its
# trades.csv md5 against TRIP_MD5, the record's S k0 (../observatory/lane.sh TRIP_MD5). That checks each session's own
# build, image and data stage before any of its cells counts. In seed 0's session it is the F-1M k0 cell itself; in
# the others it is an extra cell, kept as public evidence under trip/. With PAR=2 it costs no wall time: one batch
# alone, then the six (k0: five) cells in three batches. TRIPWIRE_WAIVE="<reason>" continues past a mismatch and logs it.
#
# Resume: re-running `run K` skips each preflight whose PREFLIGHT_OK is logged, each cell with an .ok marker, the
# tripwire once MATCH or WAIVED is logged, each extract and V6 log once written. A failed cell keeps only its .log and
# .rss, so the relaunch re-runs it. The lock is an flock on a descriptor, so a killed run leaves no stale lock.
#
# Derived from ../stale-e-cap-k5-2026-11-14/chain.sh (guards, SHA pin, stage: warehouse v12wk-9236, corpact-2026-10-27,
# bars data-20261102, build, V6 diff, entries extract) and ../observatory/lane.sh (PAR cells with .ok markers, the
# public/private split, the trading-results push). The dividends and splits come from the corpact tarball, the cloud
# form of ../record-kseed-2026-10-27/chain.sh's `rsync ... dividends.csv ... splits.csv` from data/ (cloud howto,
# "Dividends and splits come separately").
#
# Measured here vs at read time (README "What is measured"): the chain logs per cell the final log NAV ratio
# ln(1 + total_return_pct/100), max DD, and the count of Adv_participation_cap skips in the trade audit's
# alternatives_considered (a LOWER BOUND: that list exists only on Fridays with a placed entry; the cascade's
# per-Friday candidates are not captured, capture_candidates is off). Metric 4's $1M-floor count and metric 5
# (position / 20-day dollar ADV at entry) are not in any artifact: Entry_liquidity_gate drops floor failures before
# the audit, and the audit carries no ADV. The read computes both from trades.csv and the bar store with the
# strategy's own Liquidity_metric (mean, trim, split divisor), not in this session.
#
# Cell guard: CELL_TIMEOUT 20,000 s = 2.5 x the slowest cloud cell of this spec (8,058 s, #3595), for PAR cells sharing
# a host (lane.sh). Peak RSS 5.7-5.9 GB per cell, so PAR = (MemTotal - 3) / 6: 2 on the 15 GB VM. A session: stage
# ~0.2 h, build, six preflights ~0.6 h, tripwire ~2.2 h, three batches ~6.6 h: about 10 h.
# R2 credentials (R2_*) come from the environment and are never printed (dev/scripts/r2_bars.sh header).
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
REPO=${REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}   # the checkout this script sits in
EXP=dev/experiments/nav-scale-participation-2026-11-23
REC=dev/experiments/record-kseed-2026-10-27/specs
LIVE=dev/weekly-picks/live-size-overrides.sexp
OUT=${OUT:-$REPO/.sweep-output/nav-scale}
TR=${TR:-$REPO/../trading-results}                    # the session's checkout of dayfine/trading-results
IMG=${IMG:-ghcr.io/dayfine/trading-ci:latest}
RUNNER=${RUNNER:-run}       # run: docker run $IMG, checkout at /w (cloud). exec: docker exec into $CTR (local smoke)
CTR=${CTR:-trading-1-dev}
if [ "$RUNNER" = exec ]; then CROOT=${CROOT:-/workspaces/trading-1}; else CROOT=/w; fi
BARS_NAME=${BARS_NAME:-data-20261102}; WH_NAME=v12wk-9236; CA_NAME=corpact-2026-10-27   # the record's stage (#3535)
WH=${WH:-$OUT/warehouse/snap_top3000_pit_v12wk}; CA=$OUT/warehouse/corpact; BARS=$OUT/bars; TD=${TD:-$OUT/td-full}
ART=$OUT/art; WORK=$OUT/work; LOG=$OUT/chain.log
EXPECT_WH=9236; EXPECT_DIV=11880; NSYM=9200; MMAP_HANDLES=12000
TRIP_MD5=3ee10dca319e54a85f5e0a7842d8c537             # ../observatory/lane.sh TRIP_MD5: rk-k0 trades.csv at the #3677 One_basis build
CELL_TIMEOUT=${CELL_TIMEOUT:-20000}
CELL_GB=6; MEM_RESERVE_GB=3
DISK_MIN_GB=${DISK_MIN_GB:-8}; DISK_STAGE_GB=${DISK_STAGE_GB:-12}
# #3510 (upper-case shards), #3547 (relocatable warehouse), #3695 (participation gate), #3697 (scenario initial_cash)
NEED="20824663d 8ee1ed797 e8e047ff9 c649c6dbf"
ARMS="F-1M F-100k F-10M P-100k P-1M P-10M"
KINDS="actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp"

DRY=0; [ "$CMD" = dry-run ] && DRY=1
if [ "$DRY" = 0 ] && [ "$CMD" != entries ] && [ -n "$CMD" ]; then
  mkdir -p "$OUT" "$ART" "$WORK" "$OUT/tmp"; export TMPDIR=$OUT/tmp; fi
log() { if [ "$DRY" = 1 ]; then echo "$*"; else echo "[$(date -u '+%m-%d %H:%M:%S')Z] $*" | tee -a "$LOG"; fi; }
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
  else git -c user.name=nav-scale-chain -c user.email=noreply@anthropic.com -C "$gd" "$@"; fi; }
cash_of() { case $1 in *-100k) echo 100000.0 ;; *-1M) echo 1000000.0 ;; *-10M) echo 10000000.0 ;; esac; }
spec_of() { echo "$REPO/$EXP/specs/ns-$1-k$2.sexp"; }   # $1 arm, $2 seed
# README "Run plan": price-bearing files to trading-results only; mark-free ones also to this repo.
classify() {
  case $1 in
    *-trade_audit.sexp) echo skip ;;   # ~0.3 GB; entries.tsv carries the skip reasons the read uses
    *-actual.sexp|*-summary.sexp|*-params.sexp|*-macro_trend.sexp|*-entries.tsv|*.rss|*.validator.log|*.v6diff-*.log|*.md5) echo public ;;
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
  [ -f "$EXP/README.md" ] || die "$EXP not in the checkout (pre-registration not merged?)"
  m=$(mem_gb)
  log "HEAD=$(git rev-parse --short=9 HEAD) image=$IMG $(docker image inspect -f '{{.Id}}' "$IMG" 2>/dev/null | cut -c1-19) mem=${m:-?}G par=$(par_n)"
  [ "${m:-0}" -ge $((CELL_GB + MEM_RESERVE_GB)) ] || die "MemTotal ${m:-?} GB < $((CELL_GB + MEM_RESERVE_GB)) (a cell peaks at ~5.9 GB)"
}

# ------------------------------------------------------------------------------------------------------------- stage
stage() { # ../stale-e-cap-k5-2026-11-14/chain.sh stage, unchanged
  cd "$REPO" || exit 1; R2="sh dev/scripts/r2_bars.sh"
  if [ ! -f "$WH.done" ] || [ ! -f "$CA/.done" ] || [ ! -f "$TD/.done" ]; then
    disk_ok "$DISK_STAGE_GB" || die "disk < ${DISK_STAGE_GB}G before an unfinished stage"; fi
  if [ -f "$WH.done" ]; then $R2 verify-dir --dir "$WH" --name "$WH_NAME" >> "$WORK/r2.log" 2>&1 || die "warehouse verify failed"
  else rm -rf "$WH"; mkdir -p "$(dirname "$WH")"
    log "PULL warehouse $WH_NAME"; $R2 pull-dir --dest "$WH" --name "$WH_NAME" >> "$WORK/r2.log" 2>&1 || die "pull-dir $WH_NAME"
    touch "$WH.done"; fi
  n=$(grep -c '(symbol ' "$WH/manifest.sexp"); [ "$n" = "$EXPECT_WH" ] || die "warehouse manifest has $n entries, expected $EXPECT_WH"
  if [ ! -f "$CA/.done" ]; then rm -rf "$CA"
    log "PULL corpact $CA_NAME"; $R2 pull-dir --dest "$CA" --name "$CA_NAME" >> "$WORK/r2.log" 2>&1 || die "pull-dir $CA_NAME"
    touch "$CA/.done"; fi
  if [ ! -f "$TD/.done" ]; then
    rm -rf "$BARS" "$TD"
    log "PULL bars $BARS_NAME"; $R2 pull --dest "$BARS" --name "$BARS_NAME" >> "$WORK/r2.log" 2>&1 || die "pull $BARS_NAME"
    root=$BARS; [ -d "$BARS/data/A" ] && root=$BARS/data
    [ -d "$root/A" ] || die "bars archive layout not recognised (no A/ shard under $BARS)"
    low=$(find "$root" -mindepth 2 -maxdepth 2 -type d -name '[a-z]' | head -3)
    [ -z "$low" ] || die "lower-case shard dirs in the bar store (e.g. $low): pre-#3510 layout"
    mv "$root" "$TD"; rm -rf "$BARS"
    (cd "$REPO/trading/test_data" && tar cf - .) | (cd "$TD" && tar xf -) || die "test_data overlay"
    # dividends and splits = exactly corpact-2026-10-27: overwrite, then drop any file not in its list
    tar -xzf "$CA/corpact.tar.gz" -C "$TD" || die "corpact unpack"
    sed 's#^\./##' "$CA/files.txt" | LC_ALL=C sort > "$WORK/corpact-files.txt"
    (cd "$TD" && find . \( -name dividends.csv -o -name splits.csv \) | sed 's#^\./##' | LC_ALL=C sort) > "$WORK/td-ca-files.txt"
    LC_ALL=C comm -23 "$WORK/td-ca-files.txt" "$WORK/corpact-files.txt" > "$WORK/td-ca-extra.txt"
    (cd "$TD" && xargs rm -f < "$WORK/td-ca-extra.txt")
    log "TD: removed $(wc -l < "$WORK/td-ca-extra.txt") dividends/splits files newer than $CA_NAME"
    touch "$TD/.done"
  fi
  nd=$(find "$TD" -name dividends.csv | wc -l | tr -d ' ')
  [ "$nd" = "$EXPECT_DIV" ] || die "TD has $nd dividends.csv, expected $EXPECT_DIV"
  for f in share_classes.sexp macro/tbill_3m_dtb3.csv breadth/nyse_advn.csv; do [ -s "$TD/$f" ] || die "TD lacks $f"; done
  log "STAGE OK: warehouse $n entries, TD $nd dividends.csv"
}

build() {
  log "BUILD"
  dk "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe > $(cpath "$WORK")/build.log 2>&1" \
    || die "build failed (work/build.log)"
  log "BUILD_DONE"
}

# ------------------------------------------------------------------------------------------------------- spec checks
# Normalised content: comments, the name and description lines, the initial_cash line and all whitespace dropped.
norm() { sed -e 's/;;.*$//' -e '/^((name "/d' -e '/^ (description "/d' -e '/^ (initial_cash /d' "$1" | tr -d ' \t\n'; }
p_ovr() { grep -v '^;' "$REPO/$LIVE" | tr -d ' \t\n'; }   # the three live-size lines, whitespace dropped
spec_checks() { # $1 seed
  r=$(norm "$REPO/$REC/rk-k$1.sexp"); po=$(p_ovr)
  case "$po" in '((liquidity_config((max_entry_adv_participation(0.10)))))((liquidity_config((min_entry_dollar_adv100000.0))))((liquidity_config((min_hold_dollar_adv50000.0))))') ;;
    *) die "$LIVE is not the three lines the README pre-registers (0.10, 100000.0, 50000.0): $po" ;; esac
  # The record's own liquidity lines, which F keeps and P overrides by appending (a later overlay wins).
  case "$r" in *'((liquidity_config((min_entry_dollar_adv1000000.0))))((liquidity_config((min_hold_dollar_adv500000.0))))'*) ;;
    *) die "rk-k$1 lacks the record's 1e6 / 5e5 liquidity lines" ;; esac
  tb="((screening_config((tiebreak_seed$1))))"; pre=${r%%"$tb"*}; suf=${r#*"$tb"}
  case "$suf" in '))(expected'*) ;; *) die "rk-k$1's last override is not tiebreak_seed $1" ;; esac
  for arm in $ARMS; do s=$(spec_of "$arm" "$1"); [ -s "$s" ] || die "missing $s"
    grep -q "^((name \"ns-$arm-k$1\")" "$s" || die "$s: name is not ns-$arm-k$1"
    ic=$(sed -n 's/^ (initial_cash \([0-9.]*\))$/\1/p' "$s"); n=$(norm "$s")
    case $arm in
      *-1M) ! grep -v '^;;' "$s" | grep -q initial_cash || die "$s sets initial_cash (1M arms omit it: the default)" ;;
      *) [ "$ic" = "$(cash_of "$arm")" ] || die "$s: initial_cash '$ic', expected $(cash_of "$arm")" ;; esac
    case $arm in
      F-*) [ "$n" = "$r" ] || die "$s differs from rk-k$1 by more than name, description and initial_cash" ;;
      P-*) want="$pre$tb$po$suf"
           [ "$n" = "$want" ] || die "$s is not rk-k$1 + the three live-size lines appended after tiebreak_seed" ;; esac
  done
  log "SPEC CHECKS OK k$1 (ns-F-*-k$1 = rk-k$1 at 1e5 / default / 1e7 cash; ns-P-*-k$1 = the same + $LIVE appended last)"
}

# ------------------------------------------------------------------------------------------------------------- cells
runner() { # $1 spec dir, $2 log, $3 prefix (time and timeout): one scenario_runner call on the record's stage
  dk "TRADING_DATA_DIR=$(cpath "$TD") TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES $3 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$1") --fixtures-root $CROOT/trading/test_data/backtest_scenarios --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --progress-every 26 --parallel 1 > $(cpath "$2") 2>&1; echo exit=\$? >> $(cpath "$2")"
}
out_of() { hpath "$(grep 'Output root' "$1" | tail -1 | sed 's/.*: //')"; }   # $1 runner log -> the output root
rm_root() { case $1 in */dev/backtest/scenarios-*) rm -rf "$1" ;; esac; }   # never anything but a runner's own root

# Three months of each arm (2000-01-03 .. 2000-03-31): the spec parses at this build, params.sexp carries the arm's cash
# and liquidity lines, and the cache line is the record's.
preflight() { # $1 seed
  for arm in $ARMS; do name=ns-$arm-k$1; pd=$WORK/preflight-$name
    if logged "PREFLIGHT_OK $name "; then log "SKIP preflight $name (done)"; continue; fi
    rm -rf "$pd"; mkdir -p "$pd"
    sed "s/(end_date 2026-06-26)/(end_date 2000-03-31)/" "$(spec_of "$arm" "$1")" > "$pd/$name.sexp"
    grep -q "(end_date 2000-03-31)" "$pd/$name.sexp" || die "preflight $name: end_date not rewritten"
    log "PREFLIGHT $name (to 2000-03-31)"; t0=$(date +%s); runner "$pd" "$pd.log" "timeout 3600"
    po=$(out_of "$pd.log")
    [ -s "$po/$name/actual.sexp" ] || die "preflight $name wrote no actual.sexp (see $pd.log)"
    p=$(tr -d ' \t\n' < "$po/$name/params.sexp")
    ic=$(echo "$p" | sed -n 's/.*(initial_cash\([0-9.]*\)).*/\1/p')
    awk -v a="$ic" -v b="$(cash_of "$arm")" 'BEGIN { exit !(a + 0 == b + 0) }' || die "preflight $name: params.sexp initial_cash '$ic', expected $(cash_of "$arm")"
    case "$arm:$p" in
      P-*'(max_entry_adv_participation(0.10))'*'(min_entry_dollar_adv100000.0)'*'(min_hold_dollar_adv50000.0)'*) ;;
      F-*) case "$p" in *max_entry_adv_participation*) die "preflight $name: F arm carries the participation cap" ;; esac ;;
      *) die "preflight $name: params.sexp lacks the live-size lines in order" ;; esac
    cache=$(grep -h 'Panel_runner: snapshot cache hits' "$pd.log" | tail -1)
    ns=$(echo "$cache" | sed -n 's/.* n_symbols=\([0-9]*\) .*/\1/p'); na=$(echo "$cache" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
    [ "$ns" = "$NSYM" ] && [ "$na" = 1 ] || die "preflight $name: n_symbols=$ns n_symbols_absent=$na (expected $NSYM and 1)"
    rm_root "$po"; log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s, initial_cash=$ic, n_symbols=$ns absent=$na)"
  done
}

# One 26y cell. Its files land in $ART as <tag>-<kind>; the .ok marker is written last.
run_cell() { # $1 arm, $2 seed
  tag=ns-$1-k$2-s0; name=ns-$1-k$2; d=$WORK/cell-$tag
  [ -f "$ART/$tag.ok" ] && { log "SKIP $tag (done)"; return 0; }
  rm -rf "$d"; mkdir -p "$d"; rm -f "$ART/$tag"-* "$ART/$tag".*; cp "$(spec_of "$1" "$2")" "$d/" || return 1
  log "RUN $tag"; t0=$(date +%s)
  runner "$d" "$ART/$tag.log" "/usr/bin/time -f 'peak_rss_kb=%M' -o $(cpath "$ART")/$tag.rss timeout $CELL_TIMEOUT"
  root=$(out_of "$ART/$tag.log"); ex=$(tail -1 "$ART/$tag.log"); rss=$(tail -1 "$ART/$tag.rss" 2>/dev/null)
  for f in $KINDS; do cp "$root/$name/$f" "$ART/$tag-$f" 2>/dev/null; done
  if [ "$ex" != exit=0 ] || [ ! -s "$ART/$tag-actual.sexp" ] || [ ! -s "$ART/$tag-trades.csv" ]; then
    rm -f "$ART/$tag"-*; log "CELL FAILED $tag: $ex ${rss:-no rss} (wall $(( $(date +%s) - t0 ))s)"; return 1; fi
  dk "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir $(cpath "$root/$name") -data-dir $(cpath "$TD") -share-classes $CROOT/trading/test_data/share_classes.sexp -out $(cpath "$ART")/$tag-validator.sexp > $(cpath "$ART")/$tag.validator.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.validator.log"
  rm_root "$root"
  [ -s "$ART/$tag-validator.sexp.sexp" ] || { log "CELL FAILED $tag: no validator report (see $tag.validator.log)"; return 1; }
  md5_of "$ART/$tag-trades.csv" > "$ART/$tag-trades.md5"
  touch "$ART/$tag.ok"
  r=$(sed -n 's/.*(total_return_pct \([-0-9.eE+]*\)).*/\1/p' "$ART/$tag-actual.sexp" | head -1)
  dd=$(sed -n 's/.*(max_drawdown_pct \([-0-9.eE+]*\)).*/\1/p' "$ART/$tag-actual.sexp" | head -1)
  lr=$(awk -v r="$r" 'BEGIN { if (r == "") print "?"; else printf "%.4f", log(1 + r / 100) }')
  log "RESULT $tag => log_nav_ratio $lr total_return_pct ${r:-?} max_drawdown_pct ${dd:-?} $rss (wall $(( $(date +%s) - t0 ))s)"
}
cell_ok() { [ -f "$ART/ns-$1-k$2-s0.ok" ]; }

tripwire() { # F-1M k0's trades.csv against the record's (README "Tripwire and validity"). Hard gate unless waived.
  t=ns-F-1M-k0-s0
  logged "TRIPWIRE MATCH $t \|TRIPWIRE WAIVED for $t:" && return 0
  run_cell F-1M 0 || die "CELL FAILED $t (the tripwire cell); a relaunch re-runs it"
  got=$(cat "$ART/$t-trades.md5")
  if [ "$got" = "$TRIP_MD5" ]; then log "TRIPWIRE MATCH $t trades.csv md5 $got ($(wc -l < "$ART/$t-trades.csv" | tr -d ' ') lines)"; return 0; fi
  log "TRIPWIRE MISMATCH $t trades.csv md5 $got, expected $TRIP_MD5 (the record's S k0, ../observatory/lane.sh)"
  [ -n "${TRIPWIRE_WAIVE:-}" ] || die "tripwire: ns-F-1M-k0 does not reproduce the record; stop (README). Diagnose the build, image or stage."
  log "TRIPWIRE WAIVED for $t: $TRIPWIRE_WAIVE"
}

cells() { # $1 seed: seed K's six cells (k0's F-1M is the tripwire, already done), PAR at a time
  todo=; for arm in $ARMS; do cell_ok "$arm" "$1" || todo="$todo $arm"; done
  par=$(par_n); n=0; log "CELLS k$1: to run:${todo:- none} (PAR $par)"
  for arm in $todo; do run_cell "$arm" "$1" & n=$((n + 1))
    [ "$n" -lt "$par" ] || { wait; n=0; disk_ok || die "disk < ${DISK_MIN_GB}G"; }; done
  wait
  for arm in $ARMS; do cell_ok "$arm" "$1" || die "CELL FAILED ns-$arm-k$1-s0 (art/ns-$arm-k$1-s0.log); a relaunch re-runs only unfinished cells"; done
}

# The audit as one record per line, and the placed/skipped extract (../stale-e-cap-k5-2026-11-14/chain.sh, unchanged).
audit_records() { tr -s '\n\t ' '   ' < "$1" | awk '{ gsub(/\(\(entry \(/, "\n&"); print }'; }
entries_extract() { # $1 trade_audit.sexp -> stdout TSV
  printf 'position_id\tsymbol\tdecision_date\tkind\tside\tskip_reason\n'
  audit_records "$1" | awk '
    /^\(\(entry \(/ {
      sym = ""; d = ""; id = ""; side = ""
      if (match($0, /\(symbol [^ )]+\)/)) sym = substr($0, RSTART + 8, RLENGTH - 9)
      if (match($0, /\(entry_date [0-9-]+\)/)) d = substr($0, RSTART + 12, RLENGTH - 13)
      if (match($0, /\(position_id [^ )]+\)/)) id = substr($0, RSTART + 13, RLENGTH - 14)
      if (match($0, /\(side [A-Za-z]+\)/)) side = substr($0, RSTART + 6, RLENGTH - 7)
      print id "\t" sym "\t" d "\tplaced\t" side "\t-"
      s = $0; i = index(s, "(alternatives_considered"); if (i == 0) next; s = substr(s, i)
      while (match(s, /\(symbol [^ )]+\) \(side [A-Za-z]+\) \(score [^ )]+\) \(grade [A-Za-z_]+\) \(reason_skipped [A-Za-z_]+\)/)) {
        r = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        split(r, t, /[() ]+/)
        k = d "|" t[3] "|" t[11]
        if (!(k in seen)) { seen[k] = 1; print "-\t" t[3] "\t" d "\tskipped\t" t[5] "\t" t[11] } } }' |
    LC_ALL=C sort -t "$(printf '\t')" -k3,3 -k4,4 -k1,1
}
cap_skips() { awk -F'\t' '$4 == "skipped" && $6 == "Adv_participation_cap"' "$1" | wc -l | tr -d ' '; }

reads() { # $1 seed: extracts, V6 (P vs F, same cash) and liveness, each skipped once written
  for arm in $ARMS; do t=ns-$arm-k$1-s0
    [ -s "$ART/$t-entries.tsv" ] || { entries_extract "$ART/$t-trade_audit.sexp" > "$ART/$t-entries.tsv" || die "ENTRIES $t: extract FAILED"; }
    log "EXTRACT $t: $(awk -F'\t' '$4 == "placed"' "$ART/$t-entries.tsv" | wc -l | tr -d ' ') placed, Adv_participation_cap skips $(cap_skips "$ART/$t-entries.tsv") (lower bound)"
  done
  for c in 100k 1M 10M; do f=ns-F-$c-k$1-s0; p=ns-P-$c-k$1-s0; v=$ART/$p.v6diff-F.log
    [ -s "$v" ] || dk "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$(cpath "$ART")/$f-validator.sexp.sexp -report arm=$(cpath "$ART")/$p-validator.sexp.sexp > $(cpath "$v") 2>&1; echo exit=\$? >> $(cpath "$v")"
    same=differ; cmp -s "$ART/$f-trades.csv" "$ART/$p-trades.csv" && same=IDENTICAL
    # README liveness: differ on >= 3/5 seeds AND the cap in the audit. Applied pooled at read time; logged per seed.
    log "LIVE k$1 $c: trades.csv P vs F $same; P Adv_participation_cap skips $(cap_skips "$ART/$p-entries.tsv"); V6 $(tail -1 "$v")"
  done
}

collect() { # $1 seed
  k=$1; pub=$OUT/results/k$k/public/$EXP/results/k$k; prv=$OUT/results/k$k/private/$EXP/results/k$k
  rm -rf "$OUT/results/k$k"; mkdir -p "$pub" "$prv"
  for f in "$ART"/ns-*-k"$k"-s0[.-]*; do [ -f "$f" ] || continue; b=${f##*/}; c=$(classify "$b")
    [ "$c" = skip ] && continue; cp "$f" "$prv/"; [ "$c" = private ] || cp "$f" "$pub/"; done
  if [ "$k" != 0 ]; then mkdir -p "$pub/trip"   # this session's tripwire cell: mark-free evidence only
    for f in "$ART"/ns-F-1M-k0-s0[.-]*; do [ -f "$f" ] && [ "$(classify "${f##*/}")" = public ] && cp "$f" "$pub/trip/"; done; fi
  cp "$LOG" "$pub/chain-k$k.log"; cp "$WORK/td-ca-extra.txt" "$pub/" 2>/dev/null
  log "COLLECT k$k: public $(find "$pub" -type f | wc -l | tr -d ' ') files, private $(find "$prv" -type f | wc -l | tr -d ' ') files ($OUT/results/k$k)"
}

publish() { # $1 seed: the private half into trading-results main (lane.sh publish, private part)
  k=$1; src=$OUT/results/k$k/private
  [ -d "$src/$EXP" ] || die "nothing collected for k$k (sh chain.sh collect $k)"
  [ -d "$TR/.git" ] && git -C "$TR" remote get-url origin 2>/dev/null | grep -q trading-results || die "no dayfine/trading-results checkout at TR=$TR"
  { git -C "$TR" fetch -q origin main && git -C "$TR" checkout -q main && git -C "$TR" merge -q --ff-only origin/main; } \
    || die "trading-results at $TR does not fast-forward to origin/main"
  cp -R "$src"/. "$TR/"; git -C "$TR" add "$EXP"
  git -C "$TR" diff --cached --quiet || G "$TR" commit -q -m "nav-scale-participation k$k: price-bearing cells" || die "trading-results commit"
  i=0; until git -C "$TR" push -q origin HEAD:main 2>/dev/null; do i=$((i + 1))
    [ "$i" -le 3 ] && G "$TR" pull -q --rebase origin main || die "push trading-results main"; done
  log "PUBLISH k$k private: dayfine/trading-results main at $(git -C "$TR" rev-parse --short=9 HEAD)"
}

dry_run() { # [$1 seed]
  seeds=${1:-0 1 2 3 4}; par=${PAR:-2}
  echo "nav-scale-participation dry run: no guards, no container, no network, nothing written. PAR=$par (cloud: (MemTotal - 3) / 6)"
  for k in $seeds; do seed_ok "$k" || { echo "usage: sh $0 dry-run [K]" >&2; exit 2; }
    echo "== session k$k (SC_SHA=<sha> sh $EXP/chain.sh run $k)"
    spec_checks "$k"
    echo "  1. preflight to 2000-03-31: $(for a in $ARMS; do printf 'ns-%s-k%s ' "$a" "$k"; done)"
    echo "  2. TRIPWIRE alone: ns-F-1M-k0-s0  $EXP/specs/ns-F-1M-k0.sexp  trades.csv md5 must be $TRIP_MD5$([ "$k" = 0 ] || echo ' (extra cell; public evidence under trip/)')"
    todo=; for a in $ARMS; do [ "$k" = 0 ] && [ "$a" = F-1M ] || todo="$todo $a"; done
    b=1; n=0; printf '  3. batch %d:' "$b"
    for a in $todo; do [ "$n" -lt "$par" ] || { b=$((b + 1)); n=0; printf '\n     batch %d:' "$b"; }; printf ' ns-%s-k%s' "$a" "$k"; n=$((n + 1)); done; echo
    for a in $ARMS; do s=$EXP/specs/ns-$a-k$k.sexp
      case $a in F-*) liq="record (min_entry_dollar_adv 1e6, min_hold_dollar_adv 5e5)"; pr=- ;;
                 P-*) liq="live-size (participation 0.10, min_entry 1e5, min_hold 5e4)"; pr="V6 vs ns-F-${a#P-}-k$k-s0" ;; esac
      ic=$(sed -n 's/^ (initial_cash \([0-9.]*\))$/\1/p' "$REPO/$s"); [ -n "$ic" ] || ic="default (1000000.0)"
      printf '     cell ns-%s-k%s-s0  spec %s  initial_cash %s  liquidity %s  %s\n' "$a" "$k" "$s" "$ic" "$liq" "$pr"; done
    echo "  4. extracts, V6 x3, LIVE x3 -> collect: public -> $EXP/results/k$k/ (this repo); private -> trading-results $EXP/results/k$k/"
  done
  echo "public kinds: actual.sexp summary.sexp params.sexp macro_trend.sexp entries.tsv trades.md5 .rss .validator.log .v6diff-F.log chain log"
  echo "private kinds (trading-results only): trades.csv equity_curve.csv open_positions.csv splits.csv force_liquidations.sexp validator reports cell log"
  echo "not kept: trade_audit.sexp (size; entries.tsv carries its skip reasons)"
}

cmd_run() { # $1 seed
  seed_ok "${1:-}" || { echo "usage: sh $0 run K   (K in 0..4)" >&2; exit 2; }
  exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"
  rm -rf "$OUT/tmp"/r2_bars.* "$WH".partial.*   # a restart mid-pull's leftovers, safe to drop under the lock
  log "nav-scale-participation run k$1; SC_SHA=${SC_SHA:-unset} CELL_TIMEOUT=${CELL_TIMEOUT}s"
  guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  stage; build; spec_checks "$1"; [ "$1" = 0 ] || spec_checks 0
  preflight "$1"
  tripwire
  cells "$1"
  reads "$1"
  collect "$1"
  log "NAV-SCALE k$1 DONE. Next: sh $EXP/chain.sh publish $1 (trading-results), then commit results/k$1/public into this repo."
}

case "$CMD" in
  dry-run) dry_run "${1:-}" ;;
  run) cmd_run "${1:-}" ;;
  stage) guards; stage ;;
  check) seed_ok "${1:-}" || { echo "usage: sh $0 check K" >&2; exit 2; }; spec_checks "$1" ;;
  collect) seed_ok "${1:-}" || { echo "usage: sh $0 collect K" >&2; exit 2; }; collect "$1" ;;
  publish) seed_ok "${1:-}" || { echo "usage: sh $0 publish K" >&2; exit 2; }; publish "$1" ;;
  entries) entries_extract "${1:?usage: sh $0 entries AUDIT}" ;;
  *) echo "usage: sh $0 {dry-run [K]|run K|stage|check K|collect K|publish K|entries AUDIT}" >&2; exit 2 ;;
esac
