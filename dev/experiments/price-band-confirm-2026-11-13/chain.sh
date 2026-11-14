#!/bin/sh
# price-band-confirm-2026-11-13: one tie seed's two confirmation pairs in a Claude cloud session. Five sessions, one per
# seed, run side by side. Pre-registration and read rule: README.md beside this file. NOT run by its author.
#
#   C1 (period)  pbc1-S-kK, then pbc1-P-kK (V6 vs pbc1-S-kK): 2013-01-01 -> 2026-06-26, top-3000 PIT v12 schedule
#   C2 (breadth) pbc2-S-kK, then pbc2-P-kK (V6 vs pbc2-S-kK): 2000-01-01 -> 2026-06-26, top-1000 PIT v12 schedule
#
# Runs on the session host (POSIX sh) from the session's checkout at PB_SHA, the one main SHA all five sessions use
# (named in the launch brief). Every OCaml step runs in ghcr.io/dayfine/trading-ci:latest with the checkout mounted at
# /w. Everything is written under .sweep-output/price-band-confirm/ (gitignored, inside the mount, so a session-worker
# restart that wipes /tmp loses nothing); TMPDIR points there too.
#
# Subcommands (PB_SHA must be set for run and stage):
#   sh chain.sh run K          lock -> guards -> stage (R2 pulls, data dir) -> build -> spec checks -> preflight of the
#                              four specs -> C1 S, C1 P -> C2 S, C2 P -> pair reads -> collect into results/kK
#   sh chain.sh stage          only the R2 pulls and the data dir (resumable; each step leaves a .done marker)
#   sh chain.sh collect K DEST copy seed K's artifacts and reads into DEST
#   sh chain.sh preflight K [NAME...]
#                              local smoke only: spec checks + the preflight of the named specs (all four if none),
#                              against an existing WH and TD, with no guards and no stage. The run path never uses it.
# Re-running `run K` skips every cell whose RESULT line is already in chain.log (resume after a session restart). The
# lock is an flock on a file descriptor, so a killed run leaves no stale lock behind.
#
# Derived from ../price-band-tiebreak-2026-11-13/chain.sh (#3588): the same guards, PB_SHA pin, stage (warehouse
# v12wk-9236, corpact-2026-10-27, bars data-20261102 for the validator's data dir), build, run_cell, V6 diff, keyed
# trades diff, entries extract, collect, and the leftover cleanup under the lock. Changes:
#   1. Four cells per seed (two cells x two arms) instead of two; no parity comparison with the record cells.
#   2. Spec checks: pbc1-S-kK = rk-kK with only start_date moved; pbc2-S-kK = rk-kK with only top-3000 -> top-1000 and
#      universe_size; pbc?-P-kK = pbc?-S-kK plus the one candidate_ranking override.
#   3. Preflight runs each spec's FIRST three months (not the last), so C1's warm-up boundary is what it exercises. It
#      checks the override, the universe size the runner resolved (n_symbols, n_symbols_absent=1), and that the macro
#      trend on every preflight Friday equals the 26y cell's (pb-S-k0, #3595) on the same date.
#   4. A stage disk guard (DISK_STAGE_GB) besides the per-cell one, and a RUNNER=exec mode for the local smoke.
#
# Cell guard: CELL_TIMEOUT=14400 s. The slowest #3595 cloud cell (pb-S-k0, 26.5 y top-3000 + 1 y warm-up) ran 8,058 s.
# C1 simulates 14.5 of its 27.5 years (~4,250 s); a top-1000 26y cell ran at ~55 % of a top-3000 one
# (../top-n-grid-2026-09-22 lane C3, 8,250-8,780 s against ~15,500 s locally), so C2 ~4,430 s. 14,400 s is 3.2x the
# larger projection and 1.8x a full top-3000 26y cell, so a mis-projection does not kill a healthy cell. The session
# should take about 5.5 h: stage ~0.2 h, build ~0.02 h, preflight ~0.35 h, four cells ~4.8 h.
#
# R2 credentials (R2_*) come from the environment and are never printed (dev/scripts/r2_bars.sh header).
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
REPO=${REPO:-$(git rev-parse --show-toplevel)}
EXP=dev/experiments/price-band-confirm-2026-11-13
OUT=${OUT:-$REPO/.sweep-output/price-band-confirm}
IMG=${IMG:-ghcr.io/dayfine/trading-ci:latest}
RUNNER=${RUNNER:-run}       # run: docker run $IMG, checkout at /w (cloud). exec: docker exec into $CTR (local smoke)
CTR=${CTR:-trading-1-dev}
if [ "$RUNNER" = exec ]; then CROOT=${CROOT:?RUNNER=exec needs CROOT, the checkout path inside $CTR}; else CROOT=/w; fi
BARS_NAME=${BARS_NAME:-data-20261102}                 # full bar store in R2 (bars/<name>.tar.gz, 11,888 symbols)
WH_NAME=v12wk-9236; CA_NAME=corpact-2026-10-27        # the record's warehouse and corporate actions (#3535)
WH=${WH:-$OUT/warehouse/snap_top3000_pit_v12wk}; CA=$OUT/warehouse/corpact
BARS=$OUT/bars; TD=${TD:-$OUT/td-full}                # TD: bars + committed test_data + corpact (chain-w README §Data)
ART=$OUT/art; WORK=$OUT/work; LOG=$OUT/chain.log
EXPECT_WH=9236; EXPECT_DIV=11880                      # manifest entries; dividends.csv count of corpact-2026-10-27
CELL_TIMEOUT=${CELL_TIMEOUT:-14400}
MMAP_HANDLES=12000                                    # >= manifest size (#2839/#2882)
DISK_MIN_GB=${DISK_MIN_GB:-5}                         # before each cell (a cell's outputs are < 1 GB, #3595 logs)
DISK_STAGE_GB=${DISK_STAGE_GB:-12}                    # before an unfinished stage: 20-22 GB -> 14-16 GB on 11-13
REC=dev/experiments/record-kseed-2026-10-27           # the record cells rk-k0..rk-k4 the S specs derive from
PB=dev/experiments/price-band-tiebreak-2026-11-13     # #3588/#3595: the 26y cells; pb-S-k0's macro_trend is the check
OVR='((screening_config((candidate_rankingPrice_band_seeded))))'   # arm P's one override, whitespace dropped
# Expected snapshot-cache line per cell (the schedule's list union + 15 index/ETF symbols; MEL is the one name in the
# lists that the warehouse lacks, as in every v12 record cell: pb-S-k0 reads n_symbols=9200 n_symbols_absent=1).
NSYM_C1=9200; NSYM_C2=3492
# Commits the run tree must contain: #3510 (upper-case shards), #3547 (relocatable warehouse).
NEED="20824663d 8ee1ed797"

mkdir -p "$OUT" "$ART" "$WORK" "$OUT/tmp"
export TMPDIR=$OUT/tmp                                # r2_bars.sh stages downloads in $TMPDIR; keep them off /tmp
log() { echo "[$(date -u '+%m-%d %H:%M:%S')Z] $*" | tee -a "$LOG"; }
die() { log "ABORT: $*"; exit 1; }
cpath() { echo "$1" | sed "s#^$REPO#$CROOT#"; }       # host path -> container path (other paths pass through)
hpath() { echo "$1" | sed "s#^$CROOT#$REPO#"; }       # container path -> host path
dk() {
  if [ "$RUNNER" = exec ]; then docker exec -w "$CROOT/trading" "$CTR" bash -c "eval \$(opam env) 2>/dev/null && $1"
  else docker run --rm --user 0 -e HOME=/home/opam -v "$REPO:/w" -w /w/trading "$IMG" bash -c "eval \$(opam env) 2>/dev/null && $1"; fi
}
disk_ok() { g=$(df -BG --output=avail "$REPO" | tail -1 | tr -dc 0-9); log "disk free ${g}G"; [ "$g" -ge "${1:-$DISK_MIN_GB}" ]; }
seed_ok() { case "${1:-}" in 0|1|2|3|4) return 0 ;; *) return 1 ;; esac; }
FIX() { echo "$CROOT/trading/test_data/backtest_scenarios"; }

# ------------------------------------------------------------------------------------------------------------ guards
guards() {
  cd "$REPO" || exit 1
  [ "$(git rev-parse --is-shallow-repository)" = true ] && git fetch -q --unshallow origin main
  git fetch -q origin main
  [ -n "${PB_SHA:-}" ] || die "PB_SHA unset (the launch brief names the one SHA all five sessions run)"
  pb=$(git rev-parse --verify -q "$PB_SHA^{commit}") || die "PB_SHA $PB_SHA is not a commit here"
  head=$(git rev-parse HEAD)
  [ "$head" = "$pb" ] || die "HEAD $(git rev-parse --short HEAD) is not PB_SHA $PB_SHA (git checkout $PB_SHA first)"
  git merge-base --is-ancestor "$pb" origin/main || die "PB_SHA $PB_SHA is not on origin/main"
  prev=$(sed -n 's/.*\] HEAD=\([0-9a-f]*\) .*/\1/p' "$LOG" | head -1)
  [ -z "$prev" ] || [ "$prev" = "$(git rev-parse --short=9 HEAD)" ] || die "HEAD differs from this chain.log's earlier HEAD=$prev"
  for c in $NEED; do git merge-base --is-ancestor "$c" HEAD || die "HEAD lacks $c"; done
  grep -q 'Price_band_seeded' trading/analysis/weinstein/screener/lib/screener_ranking.mli \
    || die "HEAD has no Price_band_seeded candidate_ranking (#3587 not merged?)"
  grep -q 'let default_price_band_edges = \[ 8.0; 14.0; 33.0 \]' trading/analysis/weinstein/screener/lib/screener_ranking.ml \
    || die "default_price_band_edges at HEAD is not [ 8.0; 14.0; 33.0 ] (README §Mechanism)"
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "checkout dirty"
  [ -f "$EXP/README.md" ] || die "$EXP not in the checkout (pre-registration not merged?)"
  [ -s "$PB/results/k0/pb-S-k0-s0-macro_trend.sexp" ] || die "$PB/results/k0/pb-S-k0-s0-macro_trend.sexp missing (preflight macro check)"
  log "HEAD=$(git rev-parse --short=9 HEAD) image=$IMG $(docker image inspect -f '{{.Id}}' "$IMG" 2>/dev/null | cut -c1-19)"
}

# ------------------------------------------------------------------------------------------------------------- stage
stage() {
  cd "$REPO" || exit 1; R2="sh dev/scripts/r2_bars.sh"
  if [ ! -f "$WH/.done" ] || [ ! -f "$CA/.done" ] || [ ! -f "$TD/.done" ]; then
    disk_ok "$DISK_STAGE_GB" || die "disk < ${DISK_STAGE_GB}G before an unfinished stage"; fi
  if [ -f "$WH/.done" ]; then $R2 verify-dir --dir "$WH" --name "$WH_NAME" >> "$WORK/r2.log" 2>&1 || die "warehouse verify failed"
  else rm -rf "$WH"; mkdir -p "$(dirname "$WH")"
    log "PULL warehouse $WH_NAME"; $R2 pull-dir --dest "$WH" --name "$WH_NAME" >> "$WORK/r2.log" 2>&1 || die "pull-dir $WH_NAME"
    touch "$WH/.done"; fi
  n=$(grep -c '(symbol ' "$WH/manifest.sexp"); [ "$n" = "$EXPECT_WH" ] || die "warehouse manifest has $n entries, expected $EXPECT_WH"
  if [ ! -f "$CA/.done" ]; then rm -rf "$CA"
    log "PULL corpact $CA_NAME"; $R2 pull-dir --dest "$CA" --name "$CA_NAME" >> "$WORK/r2.log" 2>&1 || die "pull-dir $CA_NAME"
    touch "$CA/.done"; fi
  if [ ! -f "$TD/.done" ]; then
    rm -rf "$BARS" "$TD"
    log "PULL bars $BARS_NAME"; $R2 pull --dest "$BARS" --name "$BARS_NAME" >> "$WORK/r2.log" 2>&1 || die "pull $BARS_NAME"
    root=$BARS; [ -d "$BARS/data/A" ] && root=$BARS/data
    [ -d "$root/A" ] || die "bars archive layout not recognised (no A/ shard under $BARS)"
    # Shard dirs are upper-case since #3510; a lower-case second level would hide files from this build.
    low=$(find "$root" -mindepth 2 -maxdepth 2 -type d -name '[a-z]' | head -3)
    [ -z "$low" ] || die "lower-case shard dirs in the bar store (e.g. $low): pre-#3510 layout"
    mv "$root" "$TD"; rm -rf "$BARS"
    # committed test_data wins over the archive (the record's TRADING_DATA_DIR was the checkout's test_data)
    (cd "$REPO/trading/test_data" && tar cf - .) | (cd "$TD" && tar xf -) || die "test_data overlay"
    # corporate actions = exactly corpact-2026-10-27: overwrite, then drop any dividends/splits file not in its list
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
  for f in share_classes.sexp macro/tbill_3m_dtb3.csv breadth/nyse_advn.csv; do
    [ -s "$TD/$f" ] || die "TD lacks $f"; done
  log "STAGE OK: warehouse $n entries, TD $nd dividends.csv, $(find "$TD" -name data.csv | wc -l | tr -d ' ') data.csv"
}

# ------------------------------------------------------------------------------------------------------- spec checks
# Normalised content: comments, the name and description lines and all whitespace dropped, one override removed ($2),
# then an optional sed program ($3) applied to the result.
norm() { sed -e 's/;;.*$//' -e '/^((name "/d' -e '/^ (description "/d' "$1" | tr -d ' \t\n' | sed "s/$2//" | sed "${3:-}"; }
C1_TX='s/(start_date2000-01-01)/(start_date2013-01-01)/'
C2_TX='s/top-3000-/top-1000-/g;s/(universe_size3000)/(universe_size1000)/'
spec_checks() { # $1 seed
  cd "$REPO" || exit 1; S=$EXP/specs; r=$REC/specs/rk-k$1.sexp
  for c in 1 2; do
    tx=$C1_TX; [ "$c" = 2 ] && tx=$C2_TX
    # the transform must change the record spec, or the relation below would be vacuous
    [ "$(norm "$r" '^$' "$tx")" != "$(norm "$r" '^$')" ] || die "C$c transform does not apply to rk-k$1"
    [ "$(norm "$S/pbc$c-S-k$1.sexp" '^$')" = "$(norm "$r" '^$' "$tx")" ] \
      || die "pbc$c-S-k$1 differs from rk-k$1 by more than the C$c change"
    [ "$(norm "$S/pbc$c-P-k$1.sexp" "$OVR")" = "$(norm "$S/pbc$c-S-k$1.sexp" '^$')" ] \
      || die "pbc$c-P-k$1 differs from pbc$c-S-k$1 by more than the override"
    [ "$(norm "$S/pbc$c-P-k$1.sexp" '^$')" != "$(norm "$S/pbc$c-S-k$1.sexp" '^$')" ] || die "pbc$c-P-k$1 lacks the override"
  done
  n1=$(grep -c 'pit-v12/composition/top-1000-' "$S/pbc2-S-k$1.sexp"); n3=$(grep -c 'top-3000-' "$S/pbc2-S-k$1.sexp")
  [ "$n1" = 28 ] && [ "$n3" = 0 ] || die "pbc2-S-k$1 names $n1 top-1000 lists and $n3 top-3000 (expected 28 and 0)"
  for y in $(seq 1999 2025); do [ -s trading/test_data/backtest_scenarios/pit-v12/composition/top-1000-$y.sexp ] \
    || die "top-1000-$y.sexp missing"; done
  log "SPEC CHECKS OK (pbc1-S-k$1 = rk-k$1 + start 2013-01-01; pbc2-S-k$1 = rk-k$1 on top-1000 lists; P = S + Price_band_seeded)"
}

build() {
  log "BUILD"
  dk "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe > $(cpath "$WORK")/build.log 2>&1" \
    || die "build failed (work/build.log)"
  log "BUILD_DONE"
}

# Macro trend rows (date trend breadth_state) of a macro_trend.sexp, one per line.
macro_rows() { tr -d '()' < "$1" | awk 'NF >= 6 { print $2, $4, $6 }'; }

# A three-month run from each spec's own start: the spec parses at this build, P's override resolves, the runner
# resolves the cell's universe, and the warm-up yields the 26y cell's macro state from the first Friday.
preflight() { # $1 seed, then optional spec names
  k=$1; shift; names=${*:-"pbc1-S-k$k pbc1-P-k$k pbc2-S-k$k pbc2-P-k$k"}
  for name in $names; do pd=$WORK/preflight-$name; rm -rf "$pd" "$pd.log"; mkdir -p "$pd"
    case "$name" in pbc1-*) pend=2013-03-29; nsym=$NSYM_C1 ;; pbc2-*) pend=2000-03-31; nsym=$NSYM_C2 ;; *) die "bad name $name" ;; esac
    sed "s/(end_date 2026-06-26)/(end_date $pend)/" "$REPO/$EXP/specs/$name.sexp" > "$pd/$name.sexp"
    grep -q "(end_date $pend)" "$pd/$name.sexp" || die "preflight $name: end_date not rewritten"
    log "PREFLIGHT $name (to $pend)"; t0=$(date +%s)
    dk "TRADING_DATA_DIR=$(cpath "$TD") SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$pd") --fixtures-root $(FIX) --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --parallel 1 > $(cpath "$pd").log 2>&1"
    out=$(hpath "$(grep 'Output root' "$pd.log" | tail -1 | sed 's/.*: //')")
    [ -s "$out/$name/actual.sexp" ] || die "preflight $name wrote no actual.sexp (see $pd.log)"
    grep -q 'Price_band_seeded' "$out/$name/params.sexp" 2>/dev/null && has=yes || has=no
    case "$name" in *-P-*) [ "$has" = yes ] || die "preflight $name params.sexp lacks Price_band_seeded" ;;
                    *) [ "$has" = no ] || die "preflight $name params.sexp carries Price_band_seeded" ;; esac
    cache=$(grep -h 'Panel_runner: snapshot cache hits' "$pd.log" | tail -1)
    ns=$(echo "$cache" | sed -n 's/.* n_symbols=\([0-9]*\) .*/\1/p'); na=$(echo "$cache" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
    [ "$ns" = "$nsym" ] && [ "$na" = 1 ] || die "preflight $name: n_symbols=$ns n_symbols_absent=$na (expected $nsym and 1)"
    macro_rows "$out/$name/macro_trend.sexp" > "$pd.macro"
    macro_rows "$REPO/$PB/results/k0/pb-S-k0-s0-macro_trend.sexp" > "$WORK/macro-26y.txt"
    mm=$(awk 'NR == FNR { m[$1] = $2 " " $3; next } { n++; if (!($1 in m) || m[$1] != $2 " " $3) { bad++; print "  " $0 " vs 26y " m[$1] > "/dev/stderr" } }
              END { printf "%d %d", n, bad + 0 }' "$WORK/macro-26y.txt" "$pd.macro" 2>> "$LOG")
    [ "${mm% *}" -gt 0 ] && [ "${mm#* }" = 0 ] || die "preflight $name: macro trend differs from the 26y cell on ${mm#* } of ${mm% *} Fridays"
    log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s, Price_band_seeded in params: $has, n_symbols=$ns absent=$na, macro = 26y on ${mm% *}/${mm% *} Fridays)"
  done
}

# ------------------------------------------------------------------------------------------------------------- cells
# run_cell TAG SPEC_FILE(host) PAIR(label=validator-host-path or -)
run_cell() {
  tag=$1; spec=$2; pair=$3; d=$WORK/cell-$tag
  if grep -q "RESULT $tag " "$LOG" 2>/dev/null; then log "SKIP $tag (done)"; return 0; fi
  disk_ok || die "disk < ${DISK_MIN_GB}G before $tag"
  rm -rf "$d"; mkdir -p "$d"; cp "$spec" "$d/" || die "spec $spec"
  name=$(sed -n 's/^((name "\([^"]*\)").*/\1/p' "$spec")
  td=$(cpath "$TD")
  log "RUN $tag ($name)"; start=$(date +%s)
  dk "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $(cpath "$ART")/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$d") --fixtures-root $(FIX) --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --progress-every 26 --parallel 1 > $(cpath "$ART")/$tag.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.log"
  wall=$(( $(date +%s) - start ))
  out=$(hpath "$(grep 'Output root' "$ART/$tag.log" | tail -1 | sed 's/.*: //')")
  for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do
    cp "$out/$name/$f" "$ART/$tag-$f" 2>/dev/null; done
  # one arm's actual.sexp only (sweep-hygiene: a metric glob must be scoped to ONE arm)
  m=$(grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' "$out/$name/actual.sexp" 2>/dev/null | tr '\n' ' ')
  dk "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir $(cpath "$out/$name") -data-dir $td -share-classes $CROOT/trading/test_data/share_classes.sexp -out $(cpath "$ART")/$tag-validator.sexp > $(cpath "$ART")/$tag.validator.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.validator.log"
  q=$(grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 |V3 ' "$ART/$tag-validator.sexp.md" 2>/dev/null | tr '\n' ' ')
  v6=""
  if [ "$pair" != - ]; then lab=${pair%%=*}; pv=${pair#*=}
    dk "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$(cpath "$pv") -report arm=$(cpath "$ART")/$tag-validator.sexp.sexp > $(cpath "$ART")/$tag.v6diff-$lab.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.v6diff-$lab.log"
    v6=" vs$lab:$(tail -1 "$ART/$tag.v6diff-$lab.log")"; fi
  guards=$(grep -hE 'Panel_runner: (split_dividend_guard|snapshot cache)' "$ART/$tag.log" | tr '\n' ' ')
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} $(tail -1 "$ART/$tag.rss" 2>/dev/null) $(tail -1 "$ART/$tag.log") ${guards} (wall ${wall}s)"
}

# Keyed trades.csv diff of a pair (from chain-w): join on symbol|entry_date, ordered by entry date. Column 20
# (position_id) is blanked for the comparison; a row that differs only in its id is kind `id-shift`.
trades_keyed_diff() { # $1 base trades.csv, $2 arm trades.csv
  awk -F, -v OFS='\t' '
    function blank(s,   f, n, i, o) { n = split(s, f, ","); f[20] = ""; o = f[1]; for (i = 2; i <= n; i++) o = o "," f[i]; return o }
    NR == FNR { if (FNR > 1) a[$1 "|" $3] = $0; next }
    FNR > 1 { k = $1 "|" $3
      if (!(k in a)) print $3, $1, "arm-only", $0
      else { seen[k] = 1
        if (a[k] != $0) {
          if (blank(a[k]) == blank($0)) print $3, $1, "id-shift", a[k] " -> " $0
          else { print $3, $1, "changed-base", a[k]; print $3, $1, "changed-arm", $0 } } } }
    END { for (k in a) if (!(k in seen)) { split(k, p, "|"); print p[2], p[1], "base-only", a[k] } }' "$1" "$2" |
    sort -s -t "$(printf '\t')" -k1,1 -k2,2
}

firstdiff() { # $1 base tag, $2 arm tag
  { echo "== $2 vs $1"
    cmp -s "$ART/$1-trades.csv" "$ART/$2-trades.csv" && echo "trades.csv identical" || {
      echo "trades.csv keyed diff (date, symbol, kind, row), earliest first:"
      trades_keyed_diff "$ART/$1-trades.csv" "$ART/$2-trades.csv"; }
    awk -F, 'NR == FNR { a[FNR] = $0; next } a[FNR] != $0 { print "equity_curve first differing row: " $1; exit }' \
      "$ART/$1-equity_curve.csv" "$ART/$2-equity_curve.csv"; } > "$ART/$2-firstdiff.txt" 2>&1
}

# Entry decisions of one cell from its trade_audit.sexp (from chain-w): one row per placed entry and one per distinct
# skipped alternative (date, symbol, reason_skipped). The README's liveness read (the recorded post-cut lists) and its
# cash-displacement read use it.
entries_extract() { # $1 trade_audit.sexp -> stdout TSV
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

pair_reads() { # $1 S tag, $2 P tag
  firstdiff "$1" "$2"
  for tag in "$1" "$2"; do [ -s "$ART/$tag-trade_audit.sexp" ] || continue
    entries_extract "$ART/$tag-trade_audit.sexp" > "$ART/$tag-entries.tsv" &&
      log "ENTRIES $tag: $(awk -F'\t' '$4 == "placed"' "$ART/$tag-entries.tsv" | wc -l | tr -d ' ') placed, $(awk -F'\t' '$4 == "skipped"' "$ART/$tag-entries.tsv" | wc -l | tr -d ' ') skipped" ||
      log "ENTRIES $tag: extract FAILED"; done
}

cells() { # $1 seed
  S=$REPO/$EXP/specs
  for c in 1 2; do s=pbc$c-S-k$1-s0; p=pbc$c-P-k$1-s0
    run_cell "$s" "$S/pbc$c-S-k$1.sexp" -
    run_cell "$p" "$S/pbc$c-P-k$1.sexp" "S=$ART/$s-validator.sexp.sexp"
    pair_reads "$s" "$p"
    log "CELL C$c DONE k$1"
  done
}

collect() { # $1 seed, $2 dest
  k=$1; dest=${2:?usage: chain.sh collect K DEST}; mkdir -p "$dest"
  for f in "$ART"/pbc?-?-k"$k"-*; do [ -f "$f" ] || continue
    case "$f" in *-trade_audit.sexp|*candidates.sexp) continue ;; esac   # large; the reads use <tag>-entries.tsv
    cp "$f" "$dest/"; done
  cp "$LOG" "$dest/chain-k$k.log"; cp "$WORK/td-ca-extra.txt" "$dest/" 2>/dev/null
  for pf in "$WORK"/preflight-pbc?-?-k"$k".log; do [ -f "$pf" ] || continue
    grep -hE 'Panel_runner: snapshot cache hits|exit=' "$pf" > "$dest/$(basename "$pf" .log).cache.txt" 2>/dev/null; done
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') entries"
}

cmd_run() { # $1 seed
  seed_ok "${1:-}" || { echo "usage: sh $0 run K   (K in 0..4)" >&2; exit 2; }
  # The kernel drops an flock when its process dies, so a killed run cannot leave a stale lock for the resume.
  exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"
  # A restart mid-pull leaves the bars tar.gz in $TMPDIR and pull-dir its $WH.partial.<pid>; both are safe to drop
  # under the lock.
  rm -rf "$OUT/tmp"/r2_bars.* "$WH".partial.*
  log "price-band-confirm run k$1; PB_SHA=${PB_SHA:-unset} CELL_TIMEOUT=${CELL_TIMEOUT}s"
  guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  stage; build; spec_checks "$1"
  if grep -q "PREFLIGHT_OK pbc2-P-k$1 " "$LOG" 2>/dev/null; then log "SKIP preflight (done)"; else preflight "$1"; fi
  cells "$1"
  collect "$1" "$OUT/results/k$1"
  log "PRICE-BAND-CONFIRM k$1 DONE. Next: commit $OUT/results/k$1 into $EXP/results/k$1/ and read per README."
}

cmd_preflight() { # local smoke: $1 seed, then optional spec names
  seed_ok "${1:-}" || { echo "usage: sh $0 preflight K [NAME...]" >&2; exit 2; }
  if command -v flock > /dev/null; then   # a macOS host has no flock; the smoke is a manual, foreground run
    exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"; fi
  dk "test -s $(cpath "$WH")/manifest.sexp && test -d $(cpath "$TD")" || die "WH or TD not found (RUNNER=$RUNNER)"
  log "price-band-confirm preflight k$1 (RUNNER=$RUNNER, smoke only: no guards, no stage)"
  spec_checks "$1"; preflight "$@"
}

case "$CMD" in
  run) cmd_run "${1:-}" ;;
  stage) guards; stage ;;
  preflight) cmd_preflight "$@" ;;
  collect) seed_ok "${1:-}" || { echo "usage: sh $0 collect K DEST" >&2; exit 2; }; collect "$1" "${2:-}" ;;
  *) echo "usage: sh $0 {run K|stage|preflight K [NAME...]|collect K DEST}" >&2; exit 2 ;;
esac
