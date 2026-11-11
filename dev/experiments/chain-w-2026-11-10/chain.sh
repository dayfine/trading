#!/bin/sh
# chain-w-2026-11-10: the cloud verification chain for the [after-merge] items of #3136, #3109 (with #3104) and #3183.
# Pre-registration: README.md beside this file. NOT run by its author.
#
# Runs in a Claude cloud session (docs/howtos/claude_cloud_sessions.md), from the session's checkout at origin/main,
# on the session host (POSIX sh). Every OCaml step runs in ghcr.io/dayfine/trading-ci:latest with the checkout
# mounted at /w. Everything the chain writes goes under .sweep-output/chain-w/ (gitignored, inside the mount, so a
# session-worker restart that wipes /tmp loses nothing). Nothing is written to /tmp.
#
# Subcommands:
#   sh chain.sh run              lock -> guards -> stage (R2 pulls, data dir) -> build -> spec checks -> preflight
#                                -> #3183 policy runs -> cells, one at a time -> first-divergence reads -> collect
#   sh chain.sh stage            only the R2 pulls and the data dir (resumable; each step leaves a .done marker)
#   sh chain.sh preflight        build + spec checks + 3-month preflight of the 26y specs (needs stage)
#   sh chain.sh collect DEST     copy the per-cell artifacts and reads into DEST (the results/ dir of the results PR)
# Re-running `run` skips every cell whose RESULT line is already in chain.log (resume after a session restart).
#
# Env: OUT (.sweep-output/chain-w), IMG, BARS_NAME (data-20261102), CELL_TIMEOUT (21600), GOLDEN_TIMEOUT (3600),
#      DISK_MIN_GB (5), ALLOW_NON_MAIN (unset; 1 = run a HEAD other than origin/main, logged).
#
# Cell guard: CELL_TIMEOUT=21600 s. The record spec rk-k0 measured 6,527-6,870 s per 26y cell in the cloud (#3381,
# next-session-priorities-2026-11-10) and 12,336-23,162 s locally under host load (record-kseed chain.log); 3x the
# slowest cloud cell is 20,610 s. Golden cells: GOLDEN_TIMEOUT=3600 s; goldens-sp500 measured 162-958 s locally
# (dev/status/perf-long-cells.csv, exit-basis-flip-2026-09-03).
#
# R2 credentials (R2_*) come from the environment and are never printed (dev/scripts/r2_bars.sh header).
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
REPO=${REPO:-$(git rev-parse --show-toplevel)}
EXP=dev/experiments/chain-w-2026-11-10
OUT=${OUT:-$REPO/.sweep-output/chain-w}
IMG=${IMG:-ghcr.io/dayfine/trading-ci:latest}
BARS_NAME=${BARS_NAME:-data-20261102}                 # full bar store in R2 (bars/<name>.tar.gz, 11,888 symbols)
WH_NAME=v12wk-9236; CA_NAME=corpact-2026-10-27        # the record's warehouse and corporate actions (#3535)
WH=$OUT/warehouse/snap_top3000_pit_v12wk; CA=$OUT/warehouse/corpact
BARS=$OUT/bars; TD=$OUT/td-full                       # TD: bars + committed test_data + corpact (README §Data)
ART=$OUT/art; WORK=$OUT/work; LOG=$OUT/chain.log
EXPECT_WH=9236; EXPECT_DIV=11880                      # manifest entries; dividends.csv count of corpact-2026-10-27
CELL_TIMEOUT=${CELL_TIMEOUT:-21600}; GOLDEN_TIMEOUT=${GOLDEN_TIMEOUT:-3600}
MMAP_HANDLES=12000                                    # >= manifest size (#2839/#2882)
DISK_MIN_GB=${DISK_MIN_GB:-5}
REC=dev/experiments/record-kseed-2026-10-27           # the committed record rk-k0 s0
GOLDENS="sp500-2019-2023 sp500-2019-2023-long-only sp500-2019-2023-armed-stoplimit sp500-2019-2023-bah-spy sp500-2019-2023-bah-brk-b"
RC_FIELD=split_raw_confirm_min_share                  # the #3109 prerequisite field (README §Prerequisite)
# Commits the run tree must contain: #3510 (upper-case shards), #3547 (relocatable warehouse), #3301 (true_dollar_volume),
# #3297 (raw-confirm + frozen-adjusted rule), #3280 (symbol-class filter).
NEED="20824663d 8ee1ed797 e05b7e217 04273ff7e dc090140a"

mkdir -p "$OUT" "$ART" "$WORK"
log() { echo "[$(date -u '+%m-%d %H:%M:%S')Z] $*" | tee -a "$LOG"; }
die() { log "ABORT: $*"; exit 1; }
cpath() { echo "$1" | sed "s#^$REPO#/w#"; }           # host path -> container path
dk() { docker run --rm --user 0 -e HOME=/home/opam -v "$REPO:/w" -w /w/trading "$IMG" bash -c "eval \$(opam env) 2>/dev/null && $1"; }
disk_ok() { g=$(df -BG --output=avail "$REPO" | tail -1 | tr -dc 0-9); log "disk free ${g}G"; [ "$g" -ge "$DISK_MIN_GB" ]; }
rc_enabled() { grep -q "$RC_FIELD" "$REPO/trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli"; }

# ------------------------------------------------------------------------------------------------------------ guards
guards() {
  cd "$REPO" || exit 1
  [ "$(git rev-parse --is-shallow-repository)" = true ] && git fetch -q --unshallow origin main
  git fetch -q origin main
  for c in $NEED; do git merge-base --is-ancestor "$c" HEAD || die "HEAD lacks $c"; done
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    [ "${ALLOW_NON_MAIN:-}" = 1 ] || die "HEAD $(git rev-parse --short HEAD) is not origin/main"
    log "WARNING: HEAD $(git rev-parse --short HEAD) is not origin/main (ALLOW_NON_MAIN=1)"
  fi
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "checkout dirty"
  [ -f "$EXP/README.md" ] || die "$EXP not in the checkout (pre-registration not merged?)"
  if rc_enabled; then log "#3109 prerequisite field $RC_FIELD present: the Wrc and golden-flip cells run"
  else log "PREREQ_MISSING: $RC_FIELD is not a config field at HEAD; the #3109 cells are skipped (README §Prerequisite)"; fi
  log "HEAD=$(git rev-parse --short=9 HEAD) image=$IMG $(docker image inspect -f '{{.Id}}' "$IMG" 2>/dev/null | cut -c1-19)"
}

# ------------------------------------------------------------------------------------------------------------- stage
stage() {
  cd "$REPO" || exit 1; R2="sh dev/scripts/r2_bars.sh"
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
  for f in A/N/AMZN/data.csv A/N/AMZN/splits.csv C/C/C/data.csv C/C/C/splits.csv symbol_types.sexp share_classes.sexp macro/tbill_3m_dtb3.csv breadth/nyse_advn.csv; do
    [ -s "$TD/$f" ] || die "TD lacks $f (the #3136 divisor reads data.csv + splits.csv)"; done
  log "STAGE OK: warehouse $n entries, TD $nd dividends.csv, $(find "$TD" -name data.csv | wc -l | tr -d ' ') data.csv"
}

# ------------------------------------------------------------------------------------------------------- spec checks
# Normalised content: comments, the name and description lines and all whitespace dropped, one override removed.
norm() { sed -e 's/;;.*$//' -e '/^((name "/d' -e '/^ (description "/d' "$1" | tr -d ' \t\n' | sed "s/$2//"; }
same() { [ "$(norm "$1" "$3")" = "$(norm "$2" '^$')" ] || die "$1 differs from $2 by more than ${3:-the header}"; }
spec_checks() {
  cd "$REPO" || exit 1; S=$EXP/specs; G=trading/test_data/backtest_scenarios/goldens-sp500
  same "$S/cw-W0.sexp" "$REC/specs/rk-k0.sexp" '^$'
  same "$S/cw-Wtd.sexp" "$S/cw-W0.sexp" '((liquidity_config((true_dollar_volumetrue))))'
  same "$S/cw-Wrc.sexp" "$S/cw-W0.sexp" "(($RC_FIELD(0.5)))"
  for g in $GOLDENS; do same "$S/cw-g-$g-rc.sexp" "$G/$g.sexp" "(($RC_FIELD(0.5)))"; done
  log "SPEC CHECKS OK (W0 = rk-k0; each arm = its base + one override)"
}

build() {
  log "BUILD"
  dk "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe analysis/data/universe/bin/apply_composition_policy.exe > /w/.sweep-output/chain-w/work/build.log 2>&1" \
    || die "build failed (work/build.log)"
  log "BUILD_DONE"
}

w_specs() { if rc_enabled; then echo "cw-W0 cw-Wtd cw-Wrc"; else echo "cw-W0 cw-Wtd"; fi; }
preflight() {
  for name in $(w_specs); do pd=$WORK/preflight-$name; rm -rf "$pd"; mkdir -p "$pd"
    sed 's/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2026-04-01) (end_date 2026-06-26)))/' \
      "$REPO/$EXP/specs/$name.sexp" > "$pd/$name.sexp"
    log "PREFLIGHT $name"; t0=$(date +%s)
    dk "TRADING_DATA_DIR=$(cpath "$TD") SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$pd") --fixtures-root /w/trading/test_data/backtest_scenarios --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --parallel 1 > $(cpath "$pd").log 2>&1"
    out=$(grep 'Output root' "$pd.log" | tail -1 | sed 's/.*: //' | sed 's#^/w#'"$REPO"'#')
    [ -s "$out/$name/actual.sexp" ] || die "preflight $name wrote no actual.sexp (see $pd.log)"
    log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
  done
}

# ------------------------------------------------------------------------------------------- #3183 membership (no backtest)
p3183() {
  M=$ART/3183; if [ -f "$M/.done" ]; then log "3183 already measured"; return 0; fi
  rm -rf "$M"; mkdir -p "$M/off" "$M/on"; L=/w/trading/test_data/backtest_scenarios/pit-v12/composition
  log "3183 policy runs: 56 pit-v12 lists x {off, on}"
  dk "set -e; for n in 1000 3000; do for y in \$(seq 1998 2025); do f=$L/top-\$n-\$y.sexp; [ -f \$f ] || continue
      for arm in off on; do flags=''; [ \$arm = on ] && flags='--exclude-warrants --exclude-units --exclude-non-usd'
        ./_build/default/analysis/data/universe/bin/apply_composition_policy.exe --snapshot \$f --symbol-types $(cpath "$TD")/symbol_types.sexp \
          --out-snapshot $(cpath "$M")/\$arm/top-\$n-\$y.sexp --out-report $(cpath "$M")/\$arm/top-\$n-\$y.report.txt \$flags > $(cpath "$M")/\$arm/top-\$n-\$y.out 2>&1
      done; done; done" || die "3183 policy runs failed (see $M/*/*.out)"
  syms() { grep -o '(symbol [^)]*)' "$1" | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u; }
  cut -d, -f1 "$REPO/$REC/results/rk-k0-s0-trades.csv" | sed 1d | LC_ALL=C sort -u > "$WORK/rk-k0-traded.txt"
  echo "list,n_committed,n_off,n_on,dropped_class,warrant,unit,non_usd,dropped_traded_by_rk_k0,missed_spellings_in_on" > "$M/membership.csv"
  : > "$M/dropped.csv"
  for f in "$REPO"/trading/test_data/backtest_scenarios/pit-v12/composition/top-*-*.sexp; do b=$(basename "$f" .sexp)
    [ -f "$M/on/$b.sexp" ] || continue
    syms "$f" > "$WORK/c"; syms "$M/off/$b.sexp" > "$WORK/off"; syms "$M/on/$b.sexp" > "$WORK/on"
    LC_ALL=C comm -23 "$WORK/off" "$WORK/on" > "$WORK/d"
    w=$(grep -c -E -- '-WS(-|$)' "$WORK/d"); u=$(grep -c -E -- '-UN(-|$)' "$WORK/d"); nd=$(wc -l < "$WORK/d" | tr -d ' ')
    tr=$(LC_ALL=C comm -12 "$WORK/d" "$WORK/rk-k0-traded.txt" | tr '\n' ' ')
    miss=$(grep -E -- '-(WT|U|R|RI|RT)(-|$)' "$WORK/on" | tr '\n' ' ')
    echo "$b,$(wc -l < "$WORK/c" | tr -d ' '),$(wc -l < "$WORK/off" | tr -d ' '),$(wc -l < "$WORK/on" | tr -d ' '),$nd,$w,$u,$((nd - w - u)),${tr:-},${miss:-}" >> "$M/membership.csv"
    sed "s/^/$b,/" "$WORK/d" >> "$M/dropped.csv"
  done
  touch "$M/.done"; log "3183 DONE: $(sed 1d "$M/membership.csv" | wc -l | tr -d ' ') lists -> $M/membership.csv"
}

# ------------------------------------------------------------------------------------------------------------- cells
# run_cell TAG SPEC_FILE(host) MODE(w|g) PAIRS(label=validator-host-path[,...] or -)
run_cell() {
  tag=$1; spec=$2; mode=$3; pairs=$4; d=$WORK/cell-$tag
  if grep -q "RESULT $tag " "$LOG" 2>/dev/null; then log "SKIP $tag (done)"; return 0; fi
  disk_ok || die "disk < ${DISK_MIN_GB}G before $tag"
  rm -rf "$d"; mkdir -p "$d"; cp "$spec" "$d/" || die "spec $spec"
  name=$(sed -n 's/^((name "\([^"]*\)").*/\1/p' "$spec")
  if [ "$mode" = w ]; then td=$(cpath "$TD"); to=$CELL_TIMEOUT; extra="--snapshot-dir $(cpath "$WH") --no-emit-all-eligible --progress-every 26"
  else td=/w/trading/test_data; to=$GOLDEN_TIMEOUT; extra=""; fi
  log "RUN $tag ($name, TRADING_DATA_DIR=$td)"; start=$(date +%s)
  dk "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $(cpath "$ART")/$tag.rss timeout $to ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$d") --fixtures-root /w/trading/test_data/backtest_scenarios $extra --parallel 1 > $(cpath "$ART")/$tag.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.log"
  wall=$(( $(date +%s) - start ))
  out=$(grep 'Output root' "$ART/$tag.log" | tail -1 | sed 's/.*: //' | sed 's#^/w#'"$REPO"'#')
  for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do
    cp "$out/$name/$f" "$ART/$tag-$f" 2>/dev/null; done
  m=$(grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' "$out/$name/actual.sexp" 2>/dev/null | tr '\n' ' ')
  vdata=$td; [ "$mode" = w ] && vdata=$(cpath "$TD")
  dk "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir $(cpath "$out/$name") -data-dir $vdata -share-classes /w/trading/test_data/share_classes.sexp -out $(cpath "$ART")/$tag-validator.sexp > $(cpath "$ART")/$tag.validator.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.validator.log"
  q=$(grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 |V3 ' "$ART/$tag-validator.sexp.md" 2>/dev/null | tr '\n' ' ')
  v6=""
  if [ "$pairs" != - ]; then for p in $(echo "$pairs" | tr ',' ' '); do lab=${p%%=*}; pv=${p#*=}
    dk "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$(cpath "$pv") -report arm=$(cpath "$ART")/$tag-validator.sexp.sexp > $(cpath "$ART")/$tag.v6diff-$lab.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.v6diff-$lab.log"
    v6="$v6 vs$lab:$(tail -1 "$ART/$tag.v6diff-$lab.log")"; done; fi
  guards=$(grep -hE 'Panel_runner: (split_dividend_guard|snapshot cache)' "$ART/$tag.log" | tr '\n' ' ')
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} $(tail -1 "$ART/$tag.rss" 2>/dev/null) $(tail -1 "$ART/$tag.log") ${guards} (wall ${wall}s)"
}

# Keyed trades.csv diff of a pair: join on symbol|entry_date, ordered by entry date, no truncation. trades.csv is
# sorted by symbol, so a positional diff would name the wrong "first divergence".
trades_keyed_diff() { # $1 base trades.csv, $2 arm trades.csv
  awk -F, -v OFS='\t' '
    NR == FNR { if (FNR > 1) a[$1 "|" $3] = $0; next }
    FNR > 1 { k = $1 "|" $3
      if (!(k in a)) print $3, $1, "arm-only", $0
      else { seen[k] = 1; if (a[k] != $0) { print $3, $1, "changed-base", a[k]; print $3, $1, "changed-arm", $0 } } }
    END { for (k in a) if (!(k in seen)) { split(k, p, "|"); print p[2], p[1], "base-only", a[k] } }' "$1" "$2" |
    sort -s -t "$(printf '\t')" -k1,1 -k2,2
}

# Keyed trades.csv diff, splits.csv diff and equity_curve.csv first differing date of a pair (the README's trace
# reads start here). The first divergence is the earliest-dated line of the trades block.
firstdiff() { # $1 base tag, $2 arm tag
  { echo "== $2 vs $1"
    cmp -s "$ART/$1-trades.csv" "$ART/$2-trades.csv" && echo "trades.csv identical" || {
      echo "trades.csv keyed diff (date, symbol, kind, row), earliest first:"
      trades_keyed_diff "$ART/$1-trades.csv" "$ART/$2-trades.csv"; }
    cmp -s "$ART/$1-splits.csv" "$ART/$2-splits.csv" && echo "splits.csv identical" || diff "$ART/$1-splits.csv" "$ART/$2-splits.csv"
    awk -F, 'NR == FNR { a[FNR] = $0; next } a[FNR] != $0 { print "equity_curve first differing row: " $1; exit }' \
      "$ART/$1-equity_curve.csv" "$ART/$2-equity_curve.csv"; } >> "$ART/firstdiff.txt" 2>&1
}

cells() {
  R=$REPO/$REC/results; S=$REPO/$EXP/specs; G=$REPO/trading/test_data/backtest_scenarios/goldens-sp500
  run_cell cw-W0-s0 "$S/cw-W0.sexp" w "R=$R/rk-k0-s0-validator.sexp.sexp"
  run_cell cw-Wtd-s0 "$S/cw-Wtd.sexp" w "W0=$ART/cw-W0-s0-validator.sexp.sexp"
  if rc_enabled; then
    run_cell cw-Wrc-s0 "$S/cw-Wrc.sexp" w "W0=$ART/cw-W0-s0-validator.sexp.sexp"
    for g in $GOLDENS; do
      run_cell "g-$g" "$G/$g.sexp" g -
      run_cell "g-$g-rc" "$S/cw-g-$g-rc.sexp" g "base=$ART/g-$g-validator.sexp.sexp"
    done
  else log "SKIP #3109 cells: PREREQ_MISSING ($RC_FIELD)"; fi
  log "CELLS DONE"
  : > "$ART/firstdiff.txt"
  for f in actual.sexp trades.csv equity_curve.csv; do
    cmp -s "$R/rk-k0-s0-$f" "$ART/cw-W0-s0-$f" && log "PARITY W0 vs rk-k0 $f identical" || log "PARITY W0 vs rk-k0 $f DIFFERS"; done
  firstdiff cw-W0-s0 cw-Wtd-s0
  if rc_enabled; then firstdiff cw-W0-s0 cw-Wrc-s0; for g in $GOLDENS; do firstdiff "g-$g" "g-$g-rc"; done; fi
}

collect() {
  dest=${1:?usage: chain.sh collect DEST}; mkdir -p "$dest"
  for f in "$ART"/*; do [ -f "$f" ] || continue
    case "$f" in *-trade_audit.sexp) continue ;; esac              # large; the read uses trades.csv + splits.csv
    cp "$f" "$dest/"; done
  [ -d "$ART/3183" ] && { mkdir -p "$dest/3183"; cp "$ART/3183/membership.csv" "$ART/3183/dropped.csv" "$dest/3183/"; cp "$ART"/3183/on/*.report.txt "$dest/3183/" 2>/dev/null; }
  cp "$LOG" "$dest/chain.log"; cp "$WORK/td-ca-extra.txt" "$dest/" 2>/dev/null
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') entries"
}

cmd_run() {
  LOCK=$OUT/chain.lock; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LOCK held"; exit 1; }
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  log "chain-w run; CELL_TIMEOUT=${CELL_TIMEOUT}s GOLDEN_TIMEOUT=${GOLDEN_TIMEOUT}s"
  guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  stage; build; spec_checks; preflight; p3183; cells
  collect "$OUT/results"
  log "CHAIN W DONE. Next: commit $OUT/results into $EXP/results/ and read per README."
}

case "$CMD" in
  run) cmd_run ;;
  stage) guards; stage ;;
  preflight) guards; build; spec_checks; preflight ;;
  collect) collect "${1:-}" ;;
  *) echo "usage: sh $0 {run|stage|preflight|collect DEST}" >&2; exit 2 ;;
esac
