#!/bin/sh
# gate-funnel-2026-11-15: ONE cell, the record config S-k0 (#3602's pbb-S-k0: #3595's spec, Seeded seed 0) re-run with
# --emit-candidates on a build that carries the top-N view (#3625 + #3626), then the read (read/read.sh) inside the same
# Claude cloud session, then the split publish: mark-free outputs to a branch of dayfine/trading, price-bearing ones
# to dayfine/trading-results. Pre-registration and rules: README.md beside this file. NOT run by its author.
#
# Runs on the session host (POSIX sh) from the session's checkout at GF_SHA, the one main SHA named in the launch brief.
# Every OCaml step and the read run in ghcr.io/dayfine/trading-ci:latest with the checkout mounted at /w. Everything is
# written under .sweep-output/gate-funnel/ (gitignored, inside the mount; TMPDIR points there too).
#
# Subcommands (GF_SHA must be set for run, stage, read and publish):
#   sh chain.sh run          lock -> guards -> stage -> build -> spec check -> preflight (3 months, with the read on
#                            it) -> gf-S-k0-s0 -> tripwire + parity + n_symbols_absent -> read -> collect -> publish
#   sh chain.sh stage        only the R2 pulls and the data dir (resumable; each step leaves a .done marker)
#   sh chain.sh read         re-run the read on the finished cell (FORCE_READ=1 skips the validity gate, logged)
#   sh chain.sh collect      split the artifacts into results/public and results/private under the output dir
#   sh chain.sh publish      commit results/public to branch experiment/gate-funnel-results (a git worktree at
#                            GF_SHA, pushed) and results/private to dayfine/trading-results main (TR checkout, pushed)
# Re-running `run` skips the preflight once PREFLIGHT_OK is logged, the cell once its RESULT line is, the read once
# READ DONE is, and the publish once PUBLISH DONE is (resume after a session restart). The lock is an flock on a file
# descriptor, so a killed run leaves no stale lock. A cell that ends without actual.sexp or trades.csv logs CELL FAILED,
# not RESULT, and aborts, so a relaunch re-runs it.
#
# Derived from ../price-band-binding-2026-11-13/chain.sh: the same guards, stage (warehouse v12wk-9236,
# corpact-2026-10-27, bars data-20261102 for the data dir), build, flock, SHA pin, preflight and resume. Changes:
#   1. The build must carry the top-N view: candidate_log.mli's rank / walk / shadow and the week's long_cash_left_pct
#      and long_resting_reserved_pct (README §Definitions), checked in guards and again in the preflight's file.
#   2. Validity (README §Validity): trades.csv md5 must be #3602's pbb-S-k0 (= #3595's pb-S-k0), every
#      n_symbols_absent on the cell's cache lines must be 1, and parity with #3602's committed files is logged.
#   3. The read is this experiment's (read/read.sh), with STORE_END = the run's end, EVENTS=all for the macro proxy.
#   4. collect splits public from private (README §Files, EODHD terms) and publish pushes both.
#
# Sizing (README §Cost):
#   CELL_TIMEOUT 50,000 s, 2.4x the slow end of the expected cell (README §Cost): #3602's cell with the flag ran
#     7,477 s; the shadow adds one stop check per cut row per open Friday (~430 x 1,099). The local top-3000 cost probe
#     (results/smoke/cost.txt) put it between nothing and ~9 s per weekly cycle, so 7,500-21,000 s for the cell.
#   MEM_MIN_GB 12: #3602's cell with the flag peaked at 9.06 GB RSS on a 15 GB session. The shadow added no peak RSS
#     in the cost probe (3.13 GB with and without it), so ~9-10 GB is expected. An OOM kill shows as exit=137 with no
#     actual.sexp: CELL FAILED, and the launch brief says not to relaunch on it (README §Cost).
#   DISK_CELL_GB 8 before the cell: candidates.sexp (~1 GB on #3602; the new fields add a few %), trade_audit.sexp,
#     and the read's scratch (~3 GB together: it requests forward outcomes for ~1M symbol-dates).
#
# R2 credentials (R2_*) come from the environment and are never printed (dev/scripts/r2_bars.sh header).
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
REPO=${REPO:-$(git rev-parse --show-toplevel)}
EXP=dev/experiments/gate-funnel-2026-11-15
PBX=dev/experiments/price-band-tiebreak-2026-11-13
PBB=dev/experiments/price-band-binding-2026-11-13
SPEC=$PBX/specs/pb-S-k0.sexp
SPEC_MD5=7a2d9eba26bc5c49a7db29df468c0e2c             # pb-S-k0.sexp as run by #3595 and #3602
TRIP_MD5=0928cfe40333560429f5a6e57c9c18de             # #3602 pbb-S-k0-s0-trades.csv = #3595 pb-S-k0-s0-trades.csv, 577 lines
TAG=gf-S-k0-s0
RUN_END=2026-06-26                                    # the spec's end_date: STORE_END for the read (README §Definitions)
OUT=${OUT:-$REPO/.sweep-output/gate-funnel}
TR=${TR:-$REPO/../trading-results}                    # the session's checkout of dayfine/trading-results
PUB_BRANCH=experiment/gate-funnel-results
IMG=${IMG:-ghcr.io/dayfine/trading-ci:latest}
BARS_NAME=${BARS_NAME:-data-20261102}                 # full bar store in R2 (bars/<name>.tar.gz, 11,888 symbols)
WH_NAME=v12wk-9236; CA_NAME=corpact-2026-10-27        # the record's warehouse and corporate actions (#3535)
WH=$OUT/warehouse/snap_top3000_pit_v12wk; CA=$OUT/warehouse/corpact
BARS=$OUT/bars; TD=$OUT/td-full                       # TD: bars + committed test_data + corpact (chain-w README §Data)
ART=$OUT/art; WORK=$OUT/work; LOG=$OUT/chain.log
EXPECT_WH=9236; EXPECT_DIV=11880                      # manifest entries; dividends.csv count of corpact-2026-10-27
CELL_TIMEOUT=${CELL_TIMEOUT:-50000}
MEM_MIN_GB=${MEM_MIN_GB:-12}
MMAP_HANDLES=12000                                    # >= manifest size (#2839/#2882)
DISK_MIN_GB=${DISK_MIN_GB:-5}; DISK_CELL_GB=${DISK_CELL_GB:-8}
PIT=/w/trading/test_data/backtest_scenarios/pit-v12/composition
# Commits the run tree must contain: #3510 (upper-case shards), #3547 (relocatable warehouse), #3626 (the top-N view,
# squash 917341665, on top of #3625 63a608151).
NEED="20824663d 8ee1ed797 63a608151 917341665"

mkdir -p "$OUT" "$ART" "$WORK" "$OUT/tmp"
export TMPDIR=$OUT/tmp                                # r2_bars.sh stages downloads in $TMPDIR; keep them off /tmp
log() { echo "[$(date -u '+%m-%d %H:%M:%S')Z] $*" | tee -a "$LOG"; }
die() { log "ABORT: $*"; exit 1; }
logged() { grep -q "$1" "$LOG" 2>/dev/null; }
cpath() { echo "$1" | sed "s#^$REPO#/w#"; }           # host path -> container path
dk() { docker run --rm --user 0 -e HOME=/home/opam -v "$REPO:/w" -w /w/trading "$IMG" bash -c "eval \$(opam env) 2>/dev/null && $1"; }
disk_ok() { g=$(df -BG --output=avail "$REPO" | tail -1 | tr -dc 0-9); log "disk free ${g}G"; [ "$g" -ge "${1:-$DISK_MIN_GB}" ]; }
md5_of() { md5sum "$1" 2>/dev/null | cut -c1-32; }

# ------------------------------------------------------------------------------------------------------------ guards
guards() {
  cd "$REPO" || exit 1
  [ "$(git rev-parse --is-shallow-repository)" = true ] && git fetch -q --unshallow origin main
  git fetch -q origin main
  [ -n "${GF_SHA:-}" ] || die "GF_SHA unset (the launch brief names the one SHA this session runs)"
  gf=$(git rev-parse --verify -q "$GF_SHA^{commit}") || die "GF_SHA $GF_SHA is not a commit here"
  [ "$(git rev-parse HEAD)" = "$gf" ] || die "HEAD $(git rev-parse --short HEAD) is not GF_SHA $GF_SHA (git checkout $GF_SHA first)"
  git merge-base --is-ancestor "$gf" origin/main || die "GF_SHA $GF_SHA is not on origin/main"
  prev=$(sed -n 's/.*\] HEAD=\([0-9a-f]*\) .*/\1/p' "$LOG" | head -1)
  [ -z "$prev" ] || [ "$prev" = "$(git rev-parse --short=9 HEAD)" ] || die "HEAD differs from this chain.log's earlier HEAD=$prev"
  for c in $NEED; do git merge-base --is-ancestor "$c" HEAD || die "HEAD lacks $c"; done
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "checkout dirty"
  [ -f "$EXP/README.md" ] || die "$EXP not in the checkout (pre-registration not merged?)"
  [ "$(md5_of "$SPEC")" = "$SPEC_MD5" ] || die "$SPEC md5 $(md5_of "$SPEC") is not the one #3595 and #3602 ran ($SPEC_MD5)"
  # The top-N view the read needs (#3625 + #3626). Refuse a build without any of it: the cell would be 2 h of nothing.
  C=trading/trading/backtest/lib/candidate_log.mli
  for f in 'rank : int option' 'walk : walk_result option' 'shadow : shadow_verdict option' 'long_cash_left_pct : float option' 'long_resting_reserved_pct'; do
    grep -q "$f" $C || die "candidates.sexp lacks '$f' at this HEAD ($C): the top-N view is not merged"; done
  grep -q 'breakout_gate : breakout_gate option' $C || die "candidates.sexp has no #2533 breakout_gate"
  grep -q '"--emit-candidates"' trading/trading/backtest/scenarios/cli_args.ml || die "scenario_runner has no --emit-candidates"
  # SK1 re-checks the rank order with the Seeded hash (README §Self-check); refuse a HEAD where the hash moved.
  R=trading/analysis/weinstein/screener/lib/screener_ranking.ml
  grep -q 'sprintf "%d|%s|" tiebreak_seed date' $R || die "Seeded seed key changed in $R"
  grep -q '0x811c9dc5' $R && grep -q '0x01000193' $R || die "_ticker_hash constants changed in $R"
  # The private half of the publish needs the trading-results checkout; find out now, not after the cell.
  [ -d "$TR/.git" ] || die "no dayfine/trading-results checkout at TR=$TR (the launch brief's sibling source)"
  git -C "$TR" remote get-url origin 2>/dev/null | grep -q 'trading-results' || die "TR=$TR is not a dayfine/trading-results checkout"
  if git -C "$TR" fetch -q origin main && git -C "$TR" push --dry-run -q origin FETCH_HEAD:refs/heads/gate-funnel-push-check >/dev/null 2>&1; then log "TR push check ok ($TR)"; else log "TR push check FAILED ($TR): the private publish will need a hand push"; fi
  mem=$(awk '/^MemTotal/ { printf "%d", $2 / 1048576 }' /proc/meminfo 2>/dev/null)
  log "HEAD=$(git rev-parse --short=9 HEAD) image=$IMG $(docker image inspect -f '{{.Id}}' "$IMG" 2>/dev/null | cut -c1-19) mem=${mem:-?}G"
  [ "${mem:-0}" -ge "$MEM_MIN_GB" ] || die "MemTotal ${mem:-?} GB < MEM_MIN_GB $MEM_MIN_GB (expected peak ~9-10 GB, README §Cost)"
}

# ------------------------------------------------------------------------------------------------------------- stage
stage() {
  cd "$REPO" || exit 1; R2="sh dev/scripts/r2_bars.sh"
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
  for f in share_classes.sexp macro/tbill_3m_dtb3.csv breadth/nyse_advn.csv G/X/GSPC.INDX/data.csv; do
    [ -s "$TD/$f" ] || die "TD lacks $f"; done
  log "STAGE OK: warehouse $n entries, TD $nd dividends.csv, $(find "$TD" -name data.csv | wc -l | tr -d ' ') data.csv"
}

build() {
  log "BUILD"
  dk "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe > $(cpath "$WORK")/build.log 2>&1" \
    || die "build failed (work/build.log)"
  log "BUILD_DONE"
}

# read_on PREFIX(host; PREFIX{candidates.sexp,trade_audit.sexp,trades.csv,open_positions.csv,equity_curve.csv,
# actual.sexp}) OUT PRIV WORK EVENTS
read_on() {
  p=$(cpath "$1")
  dk "cd /w && CANDS=${p}candidates.sexp AUDIT=${p}trade_audit.sexp TRADES=${p}trades.csv OPENPOS=${p}open_positions.csv EQUITY=${p}equity_curve.csv ACTUAL=${p}actual.sexp PARAMS=${p}params.sexp DATA=$(cpath "$TD") PIT=$PIT OUT=$(cpath "$2") PRIV=$(cpath "$3") WORK=$(cpath "$4") EVENTS=$5 STORE_END=$RUN_END SEED=0 CAP=20 timeout 10800 sh $EXP/read/read.sh > $(cpath "$4").log 2>&1"
}

# A 3-month run of the cell with --emit-candidates, then the read on it: the spec parses at this build, the flag writes
# candidates.sexp with every top-N field, and the self-check passes here before the 2-6 hour cell starts.
preflight() {
  pd=$WORK/preflight; rm -rf "$pd" "$pd-read" "$pd-priv" "$pd-work"; mkdir -p "$pd"
  sed 's/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2026-04-01) (end_date 2026-06-26)))/' \
    "$REPO/$SPEC" > "$pd/pb-S-k0.sexp"
  log "PREFLIGHT pb-S-k0 (2026-04-01..06-26, --emit-candidates)"; t0=$(date +%s)
  dk "TRADING_DATA_DIR=$(cpath "$TD") TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$pd") --fixtures-root /w/trading/test_data/backtest_scenarios --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --emit-candidates --parallel 1 > $(cpath "$pd").log 2>&1"
  out=$(grep 'Output root' "$pd.log" | tail -1 | sed 's/.*: //' | sed 's#^/w#'"$REPO"'#')
  [ -s "$out/pb-S-k0/actual.sexp" ] || die "preflight wrote no actual.sexp (see $pd.log)"
  c=$out/pb-S-k0/candidates.sexp
  [ -s "$c" ] || die "preflight wrote no candidates.sexp (--emit-candidates inert?)"
  for f in '(rank ' '(walk ' '(shadow ' '(long_cash_left_pct ' '(long_resting_reserved_pct '; do
    grep -q "$f" "$c" || die "preflight candidates.sexp has no '$f' field: the top-N view did not emit"; done
  read_on "$out/pb-S-k0/" "$pd-read" "$pd-priv" "$pd-work" none; rc=$?   # no macro-proxy scan: plumbing only
  [ "$rc" -eq 0 ] || die "preflight read exit $rc: $(grep -h 'SK1\|SK2\|SK3\|FAILED' "$pd-read/selfcheck.txt" "$pd-work.log" 2>/dev/null | tr '\n' ' ')"
  log "PREFLIGHT_OK ($(( $(date +%s) - t0 ))s): $(grep -h '^SK[123]' "$pd-read/selfcheck.txt" | cut -c1-60 | tr '\n' ' ')"
}

# ------------------------------------------------------------------------------------------------------------- cell
run_cell() {
  d=$WORK/cell-$TAG
  if logged "RESULT $TAG "; then log "SKIP $TAG (done)"; return 0; fi
  disk_ok "$DISK_CELL_GB" || die "disk < ${DISK_CELL_GB}G before $TAG (candidates.sexp ~1 GB + read scratch)"
  rm -rf "$d"; mkdir -p "$d"; cp "$REPO/$SPEC" "$d/" || die "spec $SPEC"
  td=$(cpath "$TD")
  log "RUN $TAG (pb-S-k0 + --emit-candidates, CELL_TIMEOUT=${CELL_TIMEOUT}s)"; start=$(date +%s)
  dk "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M user_s=%U sys_s=%S' -o $(cpath "$ART")/$TAG.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$d") --fixtures-root /w/trading/test_data/backtest_scenarios --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --emit-candidates --progress-every 26 --parallel 1 > $(cpath "$ART")/$TAG.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$TAG.log"
  wall=$(( $(date +%s) - start ))
  out=$(grep 'Output root' "$ART/$TAG.log" | tail -1 | sed 's/.*: //' | sed 's#^/w#'"$REPO"'#')
  for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp candidates.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do
    cp "$out/pb-S-k0/$f" "$ART/$TAG-$f" 2>/dev/null; done
  ex=$(tail -1 "$ART/$TAG.log"); rss=$(tail -1 "$ART/$TAG.rss" 2>/dev/null)
  if [ ! -s "$ART/$TAG-actual.sexp" ] || [ ! -s "$ART/$TAG-trades.csv" ]; then
    hint=""; [ "$ex" = "exit=137" ] && hint=" (exit 137: killed, most likely out of memory; README §Cost: do not relaunch)"
    [ "$ex" = "exit=124" ] && hint=" (exit 124: CELL_TIMEOUT ${CELL_TIMEOUT}s reached)"
    die "CELL FAILED $TAG: $ex ${rss:-no rss} (wall ${wall}s)$hint"
  fi
  m=$(grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' "$ART/$TAG-actual.sexp" | tr '\n' ' ')
  dk "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir $(cpath "$out/pb-S-k0") -data-dir $td -share-classes /w/trading/test_data/share_classes.sexp -out $(cpath "$ART")/$TAG-validator.sexp > $(cpath "$ART")/$TAG.validator.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$TAG.validator.log"
  q=$(grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 |V3 ' "$ART/$TAG-validator.sexp.md" 2>/dev/null | tr '\n' ' ')
  csz=$(wc -c < "$ART/$TAG-candidates.sexp" 2>/dev/null | tr -d ' ')
  log "RESULT $TAG => $m ${q:-<no validator>} candidates_bytes=${csz:-none} ${rss:-no rss} $ex (wall ${wall}s)"
}

# README §Validity: the flag and the new capture are observability only, so the cell must be #3602's pbb-S-k0 to the
# byte; every cache line must read n_symbols_absent=1. Returns 0 only when both hold. Parity is logged, not gating.
validity() {
  ok=0
  got=$(md5_of "$ART/$TAG-trades.csv")
  if [ "$got" = "$TRIP_MD5" ]; then log "TRIPWIRE MATCH trades.csv md5 $got ($(wc -l < "$ART/$TAG-trades.csv" | tr -d ' ') lines)"
  else log "TRIPWIRE MISMATCH trades.csv md5 ${got:-missing}, expected $TRIP_MD5"; ok=1; fi
  ab=$(grep -oE 'n_symbols_absent=[0-9]+' "$ART/$TAG.log" | sort | uniq -c | tr '\n' ' ' | tr -s ' ')
  if [ -n "$ab" ] && ! grep -oE 'n_symbols_absent=[0-9]+' "$ART/$TAG.log" | grep -qv '=1$'; then log "ABSENT ok:$ab"
  else log "ABSENT MISMATCH:${ab:- no cache line} (expected n_symbols_absent=1 on every line)"; ok=1; fi
  for f in actual.sexp summary.sexp macro_trend.sexp entries.tsv equity_curve.csv open_positions.csv splits.csv; do
    c=$REPO/$PBB/results/cell/pbb-S-k0-s0-$f
    [ -f "$c" ] || continue
    if cmp -s "$c" "$ART/$TAG-$f"; then log "PARITY $f identical to #3602's"; else log "PARITY $f differs from #3602's"; fi
  done
  return $ok
}

entries_extract() { # $1 trade_audit.sexp -> stdout TSV (the #3595 entries.tsv shape, from ../price-band-binding chain.sh)
  printf 'position_id\tsymbol\tdecision_date\tkind\tside\tskip_reason\n'
  tr -s '\n\t ' '   ' < "$1" | awk '{ gsub(/\(\(entry \(/, "\n&"); print }' | awk '
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

do_read() {
  if logged "READ DONE" && [ "${FORCE_READ:-0}" != 1 ]; then log "SKIP read (done)"; return 0; fi
  [ -s "$ART/$TAG-entries.tsv" ] || entries_extract "$ART/$TAG-trade_audit.sexp" > "$ART/$TAG-entries.tsv"
  if ! validity; then
    [ "${FORCE_READ:-0}" = 1 ] || { log "READ SKIPPED: validity failed (README §Validity); FORCE_READ=1 overrides, logged"; return 1; }
    log "FORCE_READ=1: reading a cell that is not #3602's pbb-S-k0 byte for byte"
  fi
  rd=$WORK/cell-read; rm -rf "$OUT/read" "$OUT/read-private" "$rd"; mkdir -p "$rd"
  log "READ (EVENTS=all, STORE_END=$RUN_END)"; t0=$(date +%s)
  read_on "$ART/$TAG-" "$OUT/read" "$OUT/read-private" "$rd/work" all; rc=$?
  if [ "$rc" -ne 0 ]; then log "READ ABORT exit $rc: $(grep -h 'SK1\|SK2\|SK3\|FAILED' "$OUT/read/selfcheck.txt" "$rd/work.log" 2>/dev/null | tr '\n' ' ')"; return 1; fi
  log "READ DONE ($(( $(date +%s) - t0 ))s): $(grep -h '^Rule 1 (\|^Rule 2 (' "$OUT/read/rules.txt" | tr '\n' ' ')"
}

# README §Files: public = mark-free; private = anything that prints a price or lets one be backed out. candidates.sexp
# and trade_audit.sexp go nowhere.
collect() {
  pub=$OUT/results/public; prv=$OUT/results/private; rm -rf "$pub" "$prv"; mkdir -p "$pub/read" "$prv/read"
  for f in "$ART/$TAG"-* "$ART/$TAG".*; do [ -f "$f" ] || continue
    case "$f" in
      *-candidates.sexp|*-trade_audit.sexp) continue ;;
      *-actual.sexp|*-summary.sexp|*-params.sexp|*-macro_trend.sexp|*-entries.tsv|*.rss|*.validator.log) cp "$f" "$pub/" ;;
      *) cp "$f" "$prv/" ;;   # trades, equity curve, open positions, splits, force liquidations, cell log, validator report
    esac
  done
  [ -d "$OUT/read" ] && cp "$OUT/read"/* "$pub/read/" 2>/dev/null
  [ -d "$OUT/read-private" ] && cp "$OUT/read-private"/* "$prv/read/" 2>/dev/null
  cp "$WORK/td-ca-extra.txt" "$pub/" 2>/dev/null
  cp "$LOG" "$pub/chain.log"
  log "COLLECT public $(find "$pub" -type f | wc -l | tr -d ' ') files, private $(find "$prv" -type f | wc -l | tr -d ' ') files"
}

publish() {
  if logged "PUBLISH DONE"; then log "SKIP publish (done)"; return 0; fi
  ident() { git -C "$1" config user.email > /dev/null || echo "-c user.name=gate-funnel-chain -c user.email=noreply@anthropic.com"; }
  # Public: a worktree at GF_SHA on PUB_BRANCH, so the session's own checkout never leaves GF_SHA.
  pt=$OUT/pubtree
  if [ ! -d "$pt" ]; then
    git -C "$REPO" worktree add -q -B "$PUB_BRANCH" "$pt" "$GF_SHA" || { log "PUBLISH FAILED: worktree add"; return 1; }; fi
  rm -rf "$pt/$EXP/results/cell"; mkdir -p "$pt/$EXP/results/cell"; cp -R "$OUT/results/public"/. "$pt/$EXP/results/cell/"
  cp "$LOG" "$pt/$EXP/results/cell/chain.log"
  git -C "$pt" add "$EXP/results/cell"
  git -C "$pt" diff --cached --quiet || git $(ident "$pt") -C "$pt" commit -q -m "experiment: gate-funnel 26y cell, mark-free outputs (results/cell)" \
    || { log "PUBLISH FAILED: public commit"; return 1; }
  git -C "$pt" push -q -u origin "$PUB_BRANCH" || { log "PUBLISH FAILED: push $PUB_BRANCH"; return 1; }
  log "PUBLISH public: $PUB_BRANCH at $(git -C "$pt" rev-parse --short=9 HEAD)"
  # Private: dayfine/trading-results main, same path.
  git -C "$TR" fetch -q origin main && git -C "$TR" checkout -q main && git -C "$TR" merge -q --ff-only origin/main \
    || { log "PUBLISH FAILED: trading-results checkout not fast-forwardable to origin/main"; return 1; }
  mkdir -p "$TR/$EXP/results/cell"; cp -R "$OUT/results/private"/. "$TR/$EXP/results/cell/"
  git -C "$TR" add "$EXP/results/cell"
  git -C "$TR" diff --cached --quiet || git $(ident "$TR") -C "$TR" commit -q -m "gate-funnel-2026-11-15: price-bearing per-arm artifacts and row-level read tables, gf-S-k0-s0" \
    || { log "PUBLISH FAILED: private commit"; return 1; }
  git -C "$TR" push -q origin HEAD:main || { log "PUBLISH FAILED: push trading-results main"; return 1; }
  log "PUBLISH private: dayfine/trading-results main at $(git -C "$TR" rev-parse --short=9 HEAD)"
  log "PUBLISH DONE"
}

cmd_run() {
  exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"
  rm -rf "$OUT/tmp"/r2_bars.* "$WH".partial.*          # a restart mid-pull leaves these; safe to drop under the lock
  log "gate-funnel run; GF_SHA=${GF_SHA:-unset} CELL_TIMEOUT=${CELL_TIMEOUT}s"
  guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  stage; build
  log "SPEC CHECK OK ($SPEC md5 $SPEC_MD5)"
  logged "RESULT $TAG \|PREFLIGHT_OK" || preflight
  run_cell
  do_read; r=$?
  collect
  publish; p=$?
  if [ "$r" -eq 0 ] && [ "$p" -eq 0 ]; then log "GATE-FUNNEL DONE. Next: open the results PR from $PUB_BRANCH; results-analyst reads it per README."
  elif [ "$r" -ne 0 ]; then log "GATE-FUNNEL READ ABORT. chain.log and read/selfcheck.txt say why; outputs published as far as they exist."
  else log "GATE-FUNNEL PUBLISH ABORT. The results are in $OUT/results/{public,private}; re-run: sh $EXP/chain.sh publish"; fi
}

case "$CMD" in
  run) cmd_run ;;
  stage) guards; stage ;;
  read) exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"; guards; do_read; collect ;;
  collect) collect ;;
  publish) exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"; guards; publish ;;
  *) echo "usage: sh $0 {run|stage|read|collect|publish}" >&2; exit 2 ;;
esac
