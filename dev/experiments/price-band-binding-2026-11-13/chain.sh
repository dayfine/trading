#!/bin/sh
# price-band-binding-2026-11-13: ONE cell, the record config S-k0 (Seeded, seed 0) re-run with --emit-candidates, then
# the offline read (read/read.sh) inside the same Claude cloud session. Pre-registration and rules: README.md beside
# this file. NOT run by its author.
#
# Runs on the session host (POSIX sh) from the session's checkout at PB_SHA, the one main SHA named in the launch brief.
# Every OCaml step and the read run in ghcr.io/dayfine/trading-ci:latest with the checkout mounted at /w. Everything is
# written under .sweep-output/price-band-binding/ (gitignored, inside the mount; TMPDIR points there too).
#
# Subcommands (PB_SHA must be set for run, stage and read):
#   sh chain.sh run          lock -> guards -> stage -> build -> spec check -> preflight (3 months, with the read on
#                            it) -> pbb-S-k0-s0 -> tripwire -> read -> collect into results/
#   sh chain.sh stage        only the R2 pulls and the data dir (resumable; each step leaves a .done marker)
#   sh chain.sh read         re-run the read on the finished cell (FORCE_READ=1 skips the tripwire gate, logged)
#   sh chain.sh collect DEST copy the per-arm artifacts and the read's tables into DEST
# Re-running `run` skips the cell when its RESULT line is in chain.log and the read when READ DONE is (resume after a
# session restart). The lock is an flock on a file descriptor, so a killed run leaves no stale lock.
#
# Derived from ../price-band-tiebreak-2026-11-13/chain.sh: the same guards, stage (warehouse v12wk-9236,
# corpact-2026-10-27, bars data-20261102 for the data dir), build, flock, PB_SHA pin and resume. Changes:
#   1. One cell, arm S seed 0, run from the price-band experiment's own spec (md5-pinned below), with --emit-candidates.
#   2. Tripwire: its trades.csv must be byte-identical to #3595's pb-S-k0-s0-trades.csv (md5 below). The read runs only
#      on a match: a mismatch means the flag or the build moved the path, and the candidates would not describe it.
#   3. The read runs here, in the container, because candidates.sexp (~1 GB) is never committed or pushed.
#
# Sizing (README §Cost):
#   CELL_TIMEOUT 49,500 s = 3 x the expected cell. Expected = 8,058 s (pb-S-k0-s0, the slowest S cell of #3595,
#     chain-k0.log) x 2.05, the --emit-candidates wall factor measured 2026-09-21 (d0-funnel-diag 26,681 s against
#     13,020 s for the same cell without it; ../top-of-funnel-2026-09-21/results/d0-funnel-decomposition.md) = 16,519 s.
#   MEM_MIN_GB 11: pb-S-k0-s0 peaked at 5.77 GB RSS; emission added 3.4 GB on 09-21 (7.60 GB against ~4.2 GB) -> ~9.2 GB.
#   DISK_MIN_GB 8 before the cell: the usual 5 GB plus candidates.sexp (945 MB on 09-21), trade_audit.sexp and the
#     read's scratch (~2 GB together).
#
# R2 credentials (R2_*) come from the environment and are never printed (dev/scripts/r2_bars.sh header).
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
REPO=${REPO:-$(git rev-parse --show-toplevel)}
EXP=dev/experiments/price-band-binding-2026-11-13
PBX=dev/experiments/price-band-tiebreak-2026-11-13
SPEC=$PBX/specs/pb-S-k0.sexp
SPEC_MD5=7a2d9eba26bc5c49a7db29df468c0e2c             # pb-S-k0.sexp as run by #3595 (HEAD=1034b458e)
TRIP_MD5=0928cfe40333560429f5a6e57c9c18de             # #3595 results/k0/pb-S-k0-s0-trades.csv, 577 lines
TAG=pbb-S-k0-s0
OUT=${OUT:-$REPO/.sweep-output/price-band-binding}
IMG=${IMG:-ghcr.io/dayfine/trading-ci:latest}
BARS_NAME=${BARS_NAME:-data-20261102}                 # full bar store in R2 (bars/<name>.tar.gz, 11,888 symbols)
WH_NAME=v12wk-9236; CA_NAME=corpact-2026-10-27        # the record's warehouse and corporate actions (#3535)
WH=$OUT/warehouse/snap_top3000_pit_v12wk; CA=$OUT/warehouse/corpact
BARS=$OUT/bars; TD=$OUT/td-full                       # TD: bars + committed test_data + corpact (chain-w README §Data)
ART=$OUT/art; WORK=$OUT/work; LOG=$OUT/chain.log
EXPECT_WH=9236; EXPECT_DIV=11880                      # manifest entries; dividends.csv count of corpact-2026-10-27
CELL_TIMEOUT=${CELL_TIMEOUT:-49500}
MEM_MIN_GB=${MEM_MIN_GB:-11}
MMAP_HANDLES=12000                                    # >= manifest size (#2839/#2882)
DISK_MIN_GB=${DISK_MIN_GB:-5}; DISK_CELL_GB=${DISK_CELL_GB:-8}
PIT=/w/trading/test_data/backtest_scenarios/pit-v12/composition
# Commits the run tree must contain: #3510 (upper-case shards), #3547 (relocatable warehouse). #3587 is checked in guards.
NEED="20824663d 8ee1ed797"

mkdir -p "$OUT" "$ART" "$WORK" "$OUT/tmp"
export TMPDIR=$OUT/tmp                                # r2_bars.sh stages downloads in $TMPDIR; keep them off /tmp
log() { echo "[$(date -u '+%m-%d %H:%M:%S')Z] $*" | tee -a "$LOG"; }
die() { log "ABORT: $*"; exit 1; }
cpath() { echo "$1" | sed "s#^$REPO#/w#"; }           # host path -> container path
dk() { docker run --rm --user 0 -e HOME=/home/opam -v "$REPO:/w" -w /w/trading "$IMG" bash -c "eval \$(opam env) 2>/dev/null && $1"; }
disk_ok() { g=$(df -BG --output=avail "$REPO" | tail -1 | tr -dc 0-9); log "disk free ${g}G"; [ "$g" -ge "${1:-$DISK_MIN_GB}" ]; }
md5_of() { md5sum "$1" 2>/dev/null | cut -c1-32; }

# ------------------------------------------------------------------------------------------------------------ guards
guards() {
  cd "$REPO" || exit 1
  [ "$(git rev-parse --is-shallow-repository)" = true ] && git fetch -q --unshallow origin main
  git fetch -q origin main
  [ -n "${PB_SHA:-}" ] || die "PB_SHA unset (the launch brief names the one SHA this session runs)"
  pb=$(git rev-parse --verify -q "$PB_SHA^{commit}") || die "PB_SHA $PB_SHA is not a commit here"
  [ "$(git rev-parse HEAD)" = "$pb" ] || die "HEAD $(git rev-parse --short HEAD) is not PB_SHA $PB_SHA (git checkout $PB_SHA first)"
  git merge-base --is-ancestor "$pb" origin/main || die "PB_SHA $PB_SHA is not on origin/main"
  prev=$(sed -n 's/.*\] HEAD=\([0-9a-f]*\) .*/\1/p' "$LOG" | head -1)
  [ -z "$prev" ] || [ "$prev" = "$(git rev-parse --short=9 HEAD)" ] || die "HEAD differs from this chain.log's earlier HEAD=$prev"
  for c in $NEED; do git merge-base --is-ancestor "$c" HEAD || die "HEAD lacks $c"; done
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "checkout dirty"
  [ -f "$EXP/README.md" ] || die "$EXP not in the checkout (pre-registration not merged?)"
  [ "$(md5_of "$SPEC")" = "$SPEC_MD5" ] || die "$SPEC md5 $(md5_of "$SPEC") is not the one #3595 ran ($SPEC_MD5)"
  # The read re-implements the Seeded draw and the band order; refuse a HEAD where either moved (README §Self-check).
  R=trading/analysis/weinstein/screener/lib/screener_ranking.ml
  grep -q 'sprintf "%d|%s|" tiebreak_seed date' $R || die "Seeded seed key changed in $R"
  grep -q '0x811c9dc5' $R && grep -q '0x01000193' $R || die "_ticker_hash constants changed in $R"
  grep -q 'let default_price_band_edges = \[ 8.0; 14.0; 33.0 \]' $R || die "default_price_band_edges is not [ 8.0; 14.0; 33.0 ]"
  grep -q '"--emit-candidates"' trading/trading/backtest/scenarios/cli_args.ml || die "scenario_runner has no --emit-candidates"
  grep -q 'breakout_gate : breakout_gate option' trading/trading/backtest/lib/candidate_log.mli || die "candidates.sexp has no #2533 breakout_gate"
  mem=$(awk '/^MemTotal/ { printf "%d", $2 / 1048576 }' /proc/meminfo 2>/dev/null)
  log "HEAD=$(git rev-parse --short=9 HEAD) image=$IMG $(docker image inspect -f '{{.Id}}' "$IMG" 2>/dev/null | cut -c1-19) mem=${mem:-?}G"
  [ "${mem:-0}" -ge "$MEM_MIN_GB" ] || die "MemTotal ${mem:-?} GB < MEM_MIN_GB $MEM_MIN_GB (expected peak ~9.2 GB, README §Cost)"
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

# read_on PREFIX(host; the files are PREFIX{candidates.sexp,trade_audit.sexp,trades.csv,open_positions.csv}) OUT WORK EVENTS
read_on() {
  p=$(cpath "$1")
  dk "cd /w && CANDS=${p}candidates.sexp AUDIT=${p}trade_audit.sexp TRADES=${p}trades.csv OPENPOS=${p}open_positions.csv DATA=$(cpath "$TD") PIT=$PIT OUT=$(cpath "$2") WORK=$(cpath "$3") EVENTS=$4 SEED=0 CAP=20 sh $EXP/read/read.sh > $(cpath "$3").log 2>&1"
}

# A 3-month run of the cell with --emit-candidates, then the read on it: the spec parses at this build, the flag writes
# candidates.sexp, and the self-check passes in this environment before the 4.6-hour cell starts.
preflight() {
  pd=$WORK/preflight; rm -rf "$pd" "$pd-read" "$pd-work"; mkdir -p "$pd"
  sed 's/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2026-04-01) (end_date 2026-06-26)))/' \
    "$REPO/$SPEC" > "$pd/pb-S-k0.sexp"
  log "PREFLIGHT pb-S-k0 (2026-04-01..06-26, --emit-candidates)"; t0=$(date +%s)
  dk "TRADING_DATA_DIR=$(cpath "$TD") TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$pd") --fixtures-root /w/trading/test_data/backtest_scenarios --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --emit-candidates --parallel 1 > $(cpath "$pd").log 2>&1"
  out=$(grep 'Output root' "$pd.log" | tail -1 | sed 's/.*: //' | sed 's#^/w#'"$REPO"'#')
  [ -s "$out/pb-S-k0/actual.sexp" ] || die "preflight wrote no actual.sexp (see $pd.log)"
  [ -s "$out/pb-S-k0/candidates.sexp" ] || die "preflight wrote no candidates.sexp (--emit-candidates inert?)"
  read_on "$out/pb-S-k0/" "$pd-read" "$pd-work" surfaced; rc=$?
  [ "$rc" -eq 0 ] || die "preflight read exit $rc: $(grep -h 'SC1\|SC2\|FAILED' "$pd-read/selfcheck.txt" "$pd-work.log" 2>/dev/null | tr '\n' ' ')"
  log "PREFLIGHT_OK ($(( $(date +%s) - t0 ))s): $(grep -h '^SC1\|^SC2' "$pd-read/selfcheck.txt" | tr '\n' ' ')"
}

# ------------------------------------------------------------------------------------------------------------- cell
run_cell() {
  d=$WORK/cell-$TAG
  if grep -q "RESULT $TAG " "$LOG" 2>/dev/null; then log "SKIP $TAG (done)"; return 0; fi
  disk_ok "$DISK_CELL_GB" || die "disk < ${DISK_CELL_GB}G before $TAG (candidates.sexp ~1 GB + read scratch)"
  rm -rf "$d"; mkdir -p "$d"; cp "$REPO/$SPEC" "$d/" || die "spec $SPEC"
  td=$(cpath "$TD")
  log "RUN $TAG (pb-S-k0 + --emit-candidates, CELL_TIMEOUT=${CELL_TIMEOUT}s)"; start=$(date +%s)
  dk "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $(cpath "$ART")/$TAG.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$d") --fixtures-root /w/trading/test_data/backtest_scenarios --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --emit-candidates --progress-every 26 --parallel 1 > $(cpath "$ART")/$TAG.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$TAG.log"
  wall=$(( $(date +%s) - start ))
  out=$(grep 'Output root' "$ART/$TAG.log" | tail -1 | sed 's/.*: //' | sed 's#^/w#'"$REPO"'#')
  for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp candidates.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do
    cp "$out/pb-S-k0/$f" "$ART/$TAG-$f" 2>/dev/null; done
  m=$(grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' "$out/pb-S-k0/actual.sexp" 2>/dev/null | tr '\n' ' ')
  dk "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir $(cpath "$out/pb-S-k0") -data-dir $td -share-classes /w/trading/test_data/share_classes.sexp -out $(cpath "$ART")/$TAG-validator.sexp > $(cpath "$ART")/$TAG.validator.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$TAG.validator.log"
  q=$(grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 |V3 ' "$ART/$TAG-validator.sexp.md" 2>/dev/null | tr '\n' ' ')
  csz=$(wc -c < "$ART/$TAG-candidates.sexp" 2>/dev/null | tr -d ' ')
  log "RESULT $TAG => ${m:-<no result>} ${q:-<no validator>} candidates_bytes=${csz:-none} $(tail -1 "$ART/$TAG.rss" 2>/dev/null) $(tail -1 "$ART/$TAG.log") (wall ${wall}s)"
}

# The flag is observability-only: the cell must reproduce #3595's S-k0 trades byte for byte.
tripwire() {
  got=$(md5_of "$ART/$TAG-trades.csv")
  if [ "$got" = "$TRIP_MD5" ]; then log "TRIPWIRE MATCH trades.csv md5 $got ($(wc -l < "$ART/$TAG-trades.csv" | tr -d ' ') lines)"
  else log "TRIPWIRE MISMATCH trades.csv md5 ${got:-missing}, expected $TRIP_MD5"; fi
  c=$REPO/$PBX/results/k0/pb-S-k0-s0-trades.csv
  [ -f "$c" ] && { cmp -s "$c" "$ART/$TAG-trades.csv" && log "TRIPWIRE vs committed $PBX/results/k0: identical" || log "TRIPWIRE vs committed $PBX/results/k0: differs"; }
  [ "$got" = "$TRIP_MD5" ]
}

entries_extract() { # $1 trade_audit.sexp -> stdout TSV (the #3595 entries.tsv shape, from ../price-band-tiebreak chain.sh)
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
  if grep -q "READ DONE" "$LOG" 2>/dev/null && [ "${FORCE_READ:-0}" != 1 ]; then log "SKIP read (done)"; return 0; fi
  [ -s "$ART/$TAG-entries.tsv" ] || entries_extract "$ART/$TAG-trade_audit.sexp" > "$ART/$TAG-entries.tsv"
  if ! tripwire; then
    [ "${FORCE_READ:-0}" = 1 ] || { log "READ SKIPPED: tripwire mismatch (README §Tripwire); FORCE_READ=1 overrides, logged"; return 1; }
    log "FORCE_READ=1: reading a cell whose trades differ from #3595 S-k0"
  fi
  rd=$WORK/cell-read; rm -rf "$OUT/read" "$rd"; mkdir -p "$rd"
  log "READ (EVENTS=all)"; t0=$(date +%s)
  read_on "$ART/$TAG-" "$OUT/read" "$rd/work" all; rc=$?
  if [ "$rc" -ne 0 ]; then log "READ ABORT exit $rc: $(grep -h 'SC1\|SC2\|FAILED' "$OUT/read/selfcheck.txt" "$rd/work.log" 2>/dev/null | tr '\n' ' ')"; return 1; fi
  log "READ DONE ($(( $(date +%s) - t0 ))s): $(grep -h '^SC1\|^Rule 1 (\|^Rule 2 (' "$OUT/read/selfcheck.txt" "$OUT/read/rules.txt" | tr '\n' ' ')"
}

collect() { # $1 dest
  dest=${1:?usage: chain.sh collect DEST}; mkdir -p "$dest/read"
  for f in "$ART/$TAG"-* "$ART/$TAG".*; do [ -f "$f" ] || continue
    case "$f" in *-candidates.sexp|*-trade_audit.sexp) continue ;; esac   # ~1 GB and ~0.3 GB: never committed
    cp "$f" "$dest/"; done
  [ -d "$OUT/read" ] && cp "$OUT/read"/* "$dest/read/"
  cp "$LOG" "$dest/chain.log"; cp "$WORK/td-ca-extra.txt" "$dest/" 2>/dev/null
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') entries, read/ $(ls "$dest/read" | wc -l | tr -d ' ')"
}

cmd_run() {
  exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"
  rm -rf "$OUT/tmp"/r2_bars.* "$WH".partial.*          # a restart mid-pull leaves these; safe to drop under the lock
  log "price-band-binding run; PB_SHA=${PB_SHA:-unset} CELL_TIMEOUT=${CELL_TIMEOUT}s"
  guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  stage; build
  log "SPEC CHECK OK ($SPEC md5 $SPEC_MD5)"
  grep -q "RESULT $TAG \|PREFLIGHT_OK" "$LOG" 2>/dev/null || preflight
  run_cell
  do_read; r=$?
  collect "$OUT/results"
  [ "$r" -eq 0 ] && log "PRICE-BAND-BINDING DONE. Next: commit $OUT/results into $EXP/results/cell/ and read per README." \
    || log "PRICE-BAND-BINDING READ ABORT. Next: commit $OUT/results (chain.log and read/selfcheck.txt say why) into $EXP/results/cell/."
}

case "$CMD" in
  run) cmd_run ;;
  stage) guards; stage ;;
  read) exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"; guards; do_read; collect "$OUT/results" ;;
  collect) collect "${1:-}" ;;
  *) echo "usage: sh $0 {run|stage|read|collect DEST}" >&2; exit 2 ;;
esac
