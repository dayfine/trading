#!/bin/sh
# verify-chain-v-2026-10-19: the 26y verification chain for the [after-merge] items of #3266, #3173, #3174 and #3138
# (dev/plans/issue-burndown-2026-10-19.md §Chain V). Pre-registration: README.md beside this file.
# NOT run by its author: the dispatcher launches it when the container is free (no agents, no other backtest).
#
# Subcommands (host side; POSIX sh):
#   sh chain.sh launch            pin a worktree at origin/main, stage inputs outside any VCS tree, start `run` detached
#   sh chain.sh run               (started by launch) lock -> guards -> build -> warehouse rebuild -> preflight -> 7 cells
#                                 -> review packs (build + render) -> per-arm results staged under $STAGE/results
#   sh chain.sh validate [SPEC..] short-window parse/override check of the specs (minutes each, not a 26y cell)
#   sh chain.sh collect DEST      copy the per-arm artifacts from the sweep output into DEST (the results/ dir)
#
# Copied from ../breadth-fix-rb1-2026-10-11/results/{launch,driver-bp,chain-bp}.sh, with three changes:
#   1. A warehouse rebuild phase (`wh`). #3266 (#3283, 3f51d4afd) changed the weekly bucketing that build_snapshots
#      stores in the Stage / RS / Macro columns and the .weekly side-table; /tmp/snap_top3000_pit_v12pit was built on
#      2026-10-08, before it, and no hash detects the stale rule (#3266 comments). The phase rebuilds EXACTLY the v12
#      manifest's 9,236 symbols (no twin dedupe: the set is already deduped) at the pinned tree into
#      /tmp/snap_top3000_pit_v12wk, same START / END / tail-exceptions as the v12 build, and every cell runs on it.
#   2. Cells pair across arms: M sN with the committed N sN (breadth-fix-rb1), M+3138 sN with M sN, M+3174 s0 with M s0.
#   3. The review packs are built and rendered at the end (backtest-result-review.md), from the pinned tree.
#
# Cell guard: CELL_TIMEOUT=36000 s. Measured 26y cells of this exact spec on v12: N 8,207 / 10,392 / 10,595 s
# (breadth-fix-rb1-2026-10-11/results/chain-N.log), rb1 10,091-11,881 s (rebaseline-v12 chain-R.log); slowest
# 11,881 s, 1.5x = 17,822 s. 36,000 s (3x) leaves room for the two unmeasured arms (the resize arm books more
# positions), as breadth-fix did. Warehouse rebuild: v12 chunk builds took ~20 min each for ~2,300 names
# (/tmp/v12-chunk1.build.log: 1,190 s), so ~1.5 h for four chunks.
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
C=${CONTAINER:-trading-1-dev}
REPO=${REPO:-/Users/difan/Projects/trading-1}
EXP=dev/experiments/verify-chain-v-2026-10-19
STAGE=${STAGE:-/tmp/vcv-run}                         # host, outside every VCS tree (sweep-hygiene.md: inputs too)
H=$REPO/.sweep-output                                # host side of the container's /tmp/sweeps bind-mount
ART=/tmp/sweeps/verify-chain-v                       # container side; host $H/verify-chain-v
WTREL=${WTREL:-.claude/worktrees/sweep-vcv}          # the pinned run tree, repo-relative (container-visible)
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
WH_OLD=/tmp/snap_top3000_pit_v12pit                  # v12, built 2026-10-08 (pre-#3283)
WH=${WH:-/tmp/snap_top3000_pit_v12wk}                # v12 symbol set, rebuilt at the pinned tree (post-#3283)
EXPECT_WH=9236                                       # v12 manifest entries (chain-N.log n_symbols_touched + 1 absent)
WH_START=1998-01-01; WH_END=2026-10-07               # the v12 build's START and END (build_pit_warehouse_v12.sh, launched 10-07 PT)
CELL_TIMEOUT=${CELL_TIMEOUT:-36000}
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}     # #2839/#2882: >= manifest size, so the LRU never cycles
N_RES=dev/experiments/breadth-fix-rb1-2026-10-11/results   # the committed record N (in the pinned tree)
# Commits the run tree must contain: #3283 (#3266 fix), #3181 (#3173 guard), #3222 (dividend/guard default-on),
# #3193 (#3174 flag), #3195 (#3138 audit record).
NEED="3f51d4afd e9d6bb7a0 904746e8c 974e91885 852e61c2e"
# Cell order: salt 0 of every arm first, so the cheapest-to-read cells exist even if a later cell dies.
# token = spec:salt:partner-validator (container path; "-" = no pair)
cells() {
  echo "vcv-M:0:$WT/$N_RES/N-rb1-26-s0-v12-validator.sexp.sexp"
  echo "vcv-M3174:0:$ART/vcv-M-s0-validator.sexp.sexp"
  echo "vcv-M3138:0:$ART/vcv-M-s0-validator.sexp.sexp"
  echo "vcv-M:1:$WT/$N_RES/N-rb1-26-s1-v12-validator.sexp.sexp"
  echo "vcv-M3138:1:$ART/vcv-M-s1-validator.sexp.sexp"
  echo "vcv-M:2:$WT/$N_RES/N-rb1-26-s2-v12-validator.sexp.sexp"
  echo "vcv-M3138:2:$ART/vcv-M-s2-validator.sexp.sexp"
}
LOG_HOST=$STAGE/chain.log
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
die() { log "ABORT: $*"; exit 1; }
dx() { docker exec "$C" "$@"; }
run() { docker exec "$C" bash -c "cd $ROOT && eval \$(opam env) && $1"; }
host_free_ok() { free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ]; }

# ---------------------------------------------------------------------------------------------------------------- launch
cmd_launch() {
  mkdir -p "$STAGE"; cd "$REPO" || exit 1
  git fetch -q origin main
  SHA=${RUN_SHA:-$(git rev-parse --short=9 origin/main)}
  for c in $NEED; do git merge-base --is-ancestor "$c" "$SHA" || die "run tree $SHA lacks $c"; done
  if [ -d "$WTREL" ]; then
    [ "$(git -C "$WTREL" rev-parse --short=9 HEAD)" = "$SHA" ] || die "$WTREL is not at $SHA; remove it first"
  else git worktree add --detach "$WTREL" "$SHA" || die "worktree add"; fi
  # Inputs come from a commit, never a working copy: the pre-registration commit (default: the run SHA itself,
  # which holds this directory once the PR is merged).
  PREREG=${PREREG:-$SHA}
  rm -rf "$STAGE/specs"; mkdir -p "$STAGE/specs"
  for s in vcv-M vcv-M3138 vcv-M3174; do git show "$PREREG:$EXP/specs/$s.sexp" > "$STAGE/specs/$s.sexp" || die "spec $s not at $PREREG"; done
  git show "$PREREG:$EXP/chain.sh" > "$STAGE/chain.sh" || die "chain.sh not at $PREREG"
  # Lists = warehouse: every symbol of the v12 schedule must be in the v12 manifest (MEL excepted), as breadth-fix.
  L=$WTREL/trading/test_data/backtest_scenarios/pit-v12/composition
  for f in "$L"/top-3000-1999.sexp "$L"/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done \
    | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > "$STAGE/lists-union.txt"
  dx grep -o '((symbol [^)]*)' $WH_OLD/manifest.sexp | sed 's/((symbol //; s/)$//' | LC_ALL=C sort -u > "$STAGE/manifest-old.txt"
  [ "$(wc -l < "$STAGE/manifest-old.txt" | tr -d ' ')" = "$EXPECT_WH" ] || die "v12 manifest has $(wc -l < "$STAGE/manifest-old.txt") entries, expected $EXPECT_WH"
  LC_ALL=C comm -23 "$STAGE/lists-union.txt" "$STAGE/manifest-old.txt" | grep -v -x -F MEL > "$STAGE/absent.txt" || true
  [ ! -s "$STAGE/absent.txt" ] || die "$(wc -l < "$STAGE/absent.txt" | tr -d ' ') list symbols not in the v12 manifest"
  echo "lists md5 $(cat "$L"/top-3000-1999.sexp "$L"/top-3000-20*.sexp | md5 -q)" > "$STAGE/lists.md5"
  # Dividends + splits (EODHD, #3158) into the run tree's test_data: dividend_crediting, split_dividend_guard and
  # ex_dividend_stop_adjust read them from TRADING_DATA_DIR.
  rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ "$WTREL/trading/test_data/"
  echo "staged $(find "$WTREL/trading/test_data" -name dividends.csv | wc -l | tr -d ' ') dividends.csv" | tee -a "$STAGE/launch.log"
  nohup env REPO="$REPO" STAGE="$STAGE" WTREL="$WTREL" EXPECT_HEAD="$(git -C "$WTREL" rev-parse --short HEAD)" PREREG="$PREREG" \
    sh "$STAGE/chain.sh" run > "$STAGE/run.out" 2>&1 &
  echo "launched run pid $! (tree $SHA, prereg $PREREG); log $LOG_HOST"
}

# ---------------------------------------------------------------------------------------------------------- warehouse
pinned_spec() { echo "(Pinned ("; sed 's/.*/  ((symbol &) (sector "Unknown"))/; s/((symbol GSPC.INDX) (sector "Unknown"))/((symbol GSPC.INDX) (sector "Index"))/' "$1"; echo "))"; }
manifest_rows() { # $1 warehouse -> "symbol payload_md5 csv_mtime", sorted
  dx sh -c "tr '\n' ' ' < $1/manifest.sexp | tr -s ' ' | grep -o '(symbol [^)]*) (path [^)]*) (byte_size [0-9]*) (payload_md5 [0-9a-f]*) (csv_mtime [0-9.e+-]*)'" \
    | sed 's/(symbol \([^)]*\)) (path [^)]*) (byte_size [0-9]*) (payload_md5 \([0-9a-f]*\)) (csv_mtime \([^)]*\))/\1 \2 \3/' | LC_ALL=C sort
}
phase_wh() {
  if dx test -f $WH/.vcv-done; then log "WH $WH already rebuilt (marker present); skipped"; return 0; fi
  dx test -e $WH && die "$WH exists without its .vcv-done marker (a half-built rebuild): remove it and relaunch"
  W=$STAGE/wh; mkdir -p "$W"
  cp "$STAGE/manifest-old.txt" "$W/syms.txt"
  # four equal chunks (a single pass of ~9k names OOMs at 7.75 GB); the benchmark goes in chunk 1, as in the v12 build
  grep -v -x GSPC.INDX "$W/syms.txt" > "$W/syms-nobench.txt"
  awk -v d="$W" '{ c = int((NR - 1) * 4 / n) + 1; print > (d "/chunk-" c ".txt") }' n="$(wc -l < "$W/syms-nobench.txt" | tr -d ' ')" "$W/syms-nobench.txt"
  grep -q -x GSPC.INDX "$W/syms.txt" && echo GSPC.INDX >> "$W/chunk-1.txt"
  docker cp "$REPO/$WTREL/trading/test_data/warehouse_exceptions.sexp" "$C:/tmp/vcv-warehouse_exceptions.sexp" || die "exceptions copy"
  for c in 1 2 3 4; do
    pinned_spec "$W/chunk-$c.txt" > "$W/chunk-$c.sexp"; docker cp "$W/chunk-$c.sexp" "$C:/tmp/vcv-chunk-$c.sexp" || die "chunk $c copy"
    log "WH BUILD chunk $c ($(wc -l < "$W/chunk-$c.txt" | tr -d ' ') symbols) -> $WH"; t0=$(date +%s)
    run "/usr/bin/time -f 'peak_rss_kb=%M' -o /tmp/vcv-chunk-$c.rss ./_build/default/analysis/scripts/build_snapshots/build_snapshots.exe -universe-path /tmp/vcv-chunk-$c.sexp -csv-data-dir /workspaces/trading-1/data -output-dir $WH -benchmark-symbol GSPC.INDX -start-date $WH_START -end-date $WH_END -incremental -tail-exceptions /tmp/vcv-warehouse_exceptions.sexp > /tmp/vcv-chunk-$c.build.log 2>&1; echo exit=\$? >> /tmp/vcv-chunk-$c.build.log"
    docker cp "$C:/tmp/vcv-chunk-$c.build.log" "$W/chunk-$c.build.log" 2>/dev/null
    tail -1 "$W/chunk-$c.build.log" | grep -qx 'exit=0' || die "chunk $c did not exit 0 (see $W/chunk-$c.build.log; exit=137 = OOM)"
    log "WH chunk $c done: $(dx tail -1 /tmp/vcv-chunk-$c.rss) (wall $(( $(date +%s) - t0 ))s)"
  done
  # Same symbol set; the fix must have reached the stored columns; data drift since 10-08 is listed, not hidden.
  manifest_rows $WH_OLD > "$W/rows-old.txt"; manifest_rows $WH > "$W/rows-new.txt"
  awk '{ print $1 }' "$W/rows-new.txt" > "$W/syms-new.txt"
  cmp -s "$W/syms.txt" "$W/syms-new.txt" || die "rebuilt manifest symbol set differs from v12 (see $W/syms-new.txt)"
  LC_ALL=C join "$W/rows-old.txt" "$W/rows-new.txt" > "$W/rows-joined.txt"
  awk '$3 != $5 { print $1 }' "$W/rows-joined.txt" > "$W/csv-mtime-changed.txt"
  n_pay=$(awk '$2 != $4' "$W/rows-joined.txt" | wc -l | tr -d ' ')
  dx sh -c "cd $WH_OLD && md5sum *.weekly" | LC_ALL=C sort -k2 > "$W/weekly-old.md5"
  dx sh -c "cd $WH && md5sum *.weekly" | LC_ALL=C sort -k2 > "$W/weekly-new.md5"
  n_wk=$(LC_ALL=C join -1 2 -2 2 "$W/weekly-old.md5" "$W/weekly-new.md5" | awk '$2 != $3' | wc -l | tr -d ' ')
  log "WH verify: entries=$(wc -l < "$W/syms-new.txt" | tr -d ' ') payload_md5 differs=$n_pay .weekly differs=$n_wk csv_mtime changed since v12=$(wc -l < "$W/csv-mtime-changed.txt" | tr -d ' ') ($W/csv-mtime-changed.txt)"
  [ "$n_pay" -gt 0 ] || [ "$n_wk" -gt 0 ] || die "rebuilt warehouse is byte-identical to v12: the #3266 fix did not reach the stored columns"
  dx touch $WH/.vcv-done
}

# ----------------------------------------------------------------------------------------------------------- cells
run_cell() { # $1 spec name, $2 salt, $3 partner validator (container path or -)
  name=$1; salt=$2; pair=$3; tag="$name-s$salt"; d=$STAGE_C/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return 0; fi
  host_free_ok || die "host disk < 20G before $tag"
  dx sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$STAGE/specs/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; return 0; }
  log "RUN $tag on $WH"; start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $STAGE_C/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $STAGE_C/$tag.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.log"
  out=$(dx sh -c "grep 'Output root' $STAGE_C/$tag.log | tail -1 | sed 's/.*: //'")
  # one arm's actual.sexp only (sweep-hygiene.md metric-glob rule)
  m=$(dx sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  dx sh -c "for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $STAGE_C/$tag.log $ART/${tag}.log; cp $STAGE_C/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
  cache=$(dx sh -c "grep -h 'snapshot cache' $STAGE_C/$tag.log | tail -1"); rss=$(dx sh -c "tail -1 $STAGE_C/$tag.rss 2>/dev/null")
  guards=$(dx sh -c "grep -hE 'Panel_runner: (split_dividend_guard|ex_dividend_stop_adjust)' $STAGE_C/$tag.log | tr '\n' ' '")
  rej=$(dx sh -c "grep -o '(cash_rejection ' $ART/${tag}-trade_audit.sexp 2>/dev/null | wc -l")
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -share-classes $ROOT/test_data/share_classes.sexp -out $ART/${tag}-validator.sexp > $STAGE_C/$tag.validator.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.validator.log"
  q=$(dx sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  v6=none
  if [ "$pair" != "-" ]; then
    run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$pair -report arm=$ART/${tag}-validator.sexp.sexp > $STAGE_C/$tag.v6diff.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.v6diff.log"
    dx cp $STAGE_C/$tag.v6diff.log $ART/${tag}.v6diff.log
    v6="$(basename "$pair"):$(dx sh -c "tail -1 $STAGE_C/$tag.v6diff.log")"
  fi
  log "GUARDS $tag => ${guards:-<none>} cash_rejections=$rej"
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
}

# ---------------------------------------------------------------------------------------------------- review packs
phase_packs() {
  WTH=$REPO/$WTREL
  for arm in M M3138 M3174; do
    runs=""; for s in 0 1 2; do [ -s "$H/verify-chain-v/vcv-$arm-s$s-trades.csv" ] && runs="$runs s$s=$H/verify-chain-v/vcv-$arm-s$s-"; done
    [ -n "$runs" ] || { log "PACK $arm: no runs"; continue; }
    out=$WTH/.review/vcv-$arm
    log "PACK $arm:$runs"
    # shellcheck disable=SC2086
    sh "$WTH/dev/scripts/review_pack.sh" --out "$out" --title "verify-chain-v $arm (26y, rebuilt v12 warehouse)" \
      --snapshot-dir $WH --data-dir "$REPO/data" $runs > "$STAGE/pack-$arm.log" 2>&1 || { log "PACK $arm build failed (see $STAGE/pack-$arm.log)"; continue; }
    sh "$WTH/dev/scripts/review_pack_render.sh" --site "$out/site" > "$STAGE/render-$arm.log" 2>&1 || log "RENDER $arm failed (see $STAGE/render-$arm.log)"
    rm -rf "$H/review-vcv-$arm"; mkdir -p "$H/review-vcv-$arm"
    cp -R "$out/site" "$out/render" "$H/review-vcv-$arm/" 2>/dev/null
    log "PACK $arm -> $H/review-vcv-$arm (site/ + render/top.png, part-N.png)"
  done
}

# -------------------------------------------------------------------------------------------------------------- run
cmd_run() {
  mkdir -p "$STAGE"; LOCK=$STAGE/chain.lock; STAGE_C=/tmp/vcv-work
  mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LOCK held (another chain V instance)"; exit 1; }
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  EXPECT_HEAD=${EXPECT_HEAD:?set by launch}
  head=$(git -C "$REPO/$WTREL" rev-parse --short HEAD)
  log "chain V run tree $WTREL HEAD=$head (expect $EXPECT_HEAD) prereg=${PREREG:-?} $(cat "$STAGE/lists.md5" 2>/dev/null)"
  log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (slowest measured cell of this spec 11,881 s); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
  [ "$head" = "$EXPECT_HEAD" ] || die "wrong HEAD"
  [ -z "$(git -C "$REPO/$WTREL" status --porcelain --untracked-files=no)" ] || die "run tree dirty"
  host_free_ok || die "host disk < 20G"
  if dx pgrep -f 'build_snapshots|scenario_runner|panel_runner|bayesian_runner' >/dev/null; then die "another build/backtest is running in $C"; fi
  dx mkdir -p $STAGE_C $ART
  log "BUILD"
  run "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe analysis/scripts/build_snapshots/build_snapshots.exe trading/backtest/bin/trade_audit_report_bin.exe analysis/scripts/stage_chart/bin/stage_chart.exe > $STAGE_C/build.log 2>&1" || die "build failed ($STAGE_C/build.log in the container)"
  log "BUILD_DONE"
  phase_wh
  # PREFLIGHT: every spec over the last ~3 months on the rebuilt warehouse; a spec/override error costs minutes.
  for name in vcv-M vcv-M3138 vcv-M3174; do pd=$STAGE_C/preflight-$name
    dx sh -c "mkdir -p $pd && rm -rf $pd/*"
    sed 's/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2026-04-01) (end_date 2026-06-26)))/' "$STAGE/specs/$name.sexp" > "$STAGE/preflight-$name.sexp"
    docker cp "$STAGE/preflight-$name.sexp" "$C:$pd/$name.sexp" || die "preflight copy $name"
    log "PREFLIGHT $name"; t0=$(date +%s)
    run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
    pout=$(dx sh -c "grep 'Output root' $pd.log | tail -1 | sed 's/.*: //'")
    dx test -s "${pout}/${name}/actual.sexp" || die "preflight $name wrote no actual.sexp (see $pd.log)"
    log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
  done
  for tok in $(cells); do
    name=${tok%%:*}; rest=${tok#*:}; salt=${rest%%:*}; pair=${rest#*:}
    run_cell "$name" "$salt" "$pair"
  done
  log "CELLS DONE"
  phase_packs
  cmd_collect "$STAGE/results"
  log "CHAIN V DONE. Next: perf_long_cells.sh update $LOG_HOST; collect into the results PR; read per README."
}

# --------------------------------------------------------------------------------------------------------- validate
# Parse + override check only, never a backtest. scenario_runner parses the spec and applies config_overrides
# (Overlay_validator.apply_overrides, in Runner._load_deps) BEFORE it prints "Running backtest" (backtest/lib/runner.ml).
# Each spec runs under `timeout 300` on an existing warehouse, in an already built tree, and is VALID iff its log
# reaches that line; the timeout then kills it. A negative control (vcv-M plus a nonexistent override) must fail
# before that line, which shows the check can fail.
_validate_one() { # $1 label, $2 spec file (host)
  pd=$STAGE_C/$1; dx sh -c "mkdir -p $pd && rm -rf $pd/*"; docker cp "$2" "$C:$pd/$1.sexp"
  run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 300 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $VWH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
  dx grep -q 'Running backtest' $pd.log
}
cmd_validate() {
  VWH=${VALIDATE_WH:-$WH_OLD}; STAGE_C=/tmp/vcv-validate; dx mkdir -p $STAGE_C
  here=$(cd "$(dirname "$0")" && pwd); rc=0; tmp=${TMPDIR:-/tmp}/vcv-validate.$$
  for name in ${*:-vcv-M vcv-M3138 vcv-M3174 control}; do
    if [ "$name" = control ]; then
      awk '{ print } $0 == "   ((dividend_crediting true))" { print "   ((vcv_no_such_flag true))" }' "$here/specs/vcv-M.sexp" \
        | sed 's/(name "vcv-M")/(name "control")/' > "$tmp"
      if _validate_one control "$tmp"; then echo "CONTROL FAILED: a bogus override reached 'Running backtest'"; rc=1
      else echo "CONTROL OK (bogus override rejected): $(dx sh -c "grep -m2 -iE 'error|exception|unknown|fail' $STAGE_C/control.log | tr '\n' ' ' | cut -c1-300")"; fi
    else
      f=$(grep -oE '\((entry_fill_size_to_available|ex_dividend_stop_adjust) true\)' "$here/specs/$name.sexp" || echo "(none)")
      cp "$here/specs/$name.sexp" "$tmp"
      if _validate_one "$name" "$tmp"; then echo "VALID $name: parsed, overrides applied, reached 'Running backtest'; arm flag $f"
      else echo "INVALID $name:"; dx tail -5 "$STAGE_C/$name.log"; rc=1; fi
    fi
  done
  rm -f "$tmp"; return $rc
}

# ---------------------------------------------------------------------------------------------------------- collect
cmd_collect() { # $1 destination results dir (host)
  dest=${1:?usage: chain.sh collect DEST}; mkdir -p "$dest"; src=$H/verify-chain-v
  for f in "$src"/vcv-*-s[0-9]-*; do
    [ -f "$f" ] || continue
    case "$f" in *-trade_audit.sexp) b=$(basename "$f" -trade_audit.sexp); grep -o '(cash_rejection ' "$f" | wc -l | tr -d ' ' > "$dest/$b-cash_rejections.txt"; continue ;; esac
    cp "$f" "$dest/"
  done
  for f in "$src"/vcv-*-s[0-9].log "$src"/vcv-*-s[0-9].rss "$src"/vcv-*-s[0-9].v6diff.log; do [ -f "$f" ] && cp "$f" "$dest/"; done
  [ -f "$LOG_HOST" ] && cp "$LOG_HOST" "$dest/chain.log"
  [ -d "$STAGE/wh" ] && { mkdir -p "$dest/wh"; cp "$STAGE"/wh/chunk-*.build.log "$STAGE/wh/csv-mtime-changed.txt" "$dest/wh/" 2>/dev/null; }
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') files (trade_audit.sexp reduced to a cash_rejections count)"
}

case "$CMD" in
  launch) cmd_launch ;;
  run) cmd_run ;;
  validate) cmd_validate "$@" ;;
  collect) cmd_collect "${1:-}" ;;
  *) echo "usage: sh $0 {launch|run|validate|collect DEST}" >&2; exit 2 ;;
esac
