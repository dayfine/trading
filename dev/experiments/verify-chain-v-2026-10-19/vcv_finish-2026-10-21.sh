#!/bin/sh
# verify-chain-v-2026-10-19: the 26y verification chain for the [after-merge] items of #3266, #3263, #3173, #3174 and
# #3138 (dev/plans/issue-burndown-2026-10-19.md §Chain V). Pre-registration: README.md beside this file.
# NOT run by its author: the dispatcher launches it when the container is free (no agents, no other backtest).
#
# Subcommands (host side; POSIX sh):
#   sh chain.sh launch            pin a worktree at origin/main, stage inputs outside any VCS tree, start `run` detached
#   sh chain.sh run               (started by launch) lock -> guards -> build -> warehouse rebuild -> preflight -> 8 cells
#                                 -> review packs (build + render) -> per-arm results staged under $STAGE/results
#   sh chain.sh validate [SPEC..] short-window parse/override check of the specs (minutes each, not a 26y cell)
#   sh chain.sh collect DEST      copy the per-arm artifacts from the sweep output into DEST (the results/ dir)
#
# Copied from ../breadth-fix-rb1-2026-10-11/results/{launch,driver-bp,chain-bp}.sh, with four changes:
#   1. A warehouse rebuild phase (`wh`). #3266 (#3283, 3f51d4afd) changed the weekly bucketing that build_snapshots
#      stores in the Stage / RS / Macro columns and the .weekly side-table; /tmp/snap_top3000_pit_v12pit was built on
#      2026-10-08, before it, and no hash detects the stale rule (#3266 comments). The phase rebuilds EXACTLY the v12
#      manifest's 9,236 symbols (no twin dedupe: the set is already deduped) at the pinned tree into
#      /tmp/snap_top3000_pit_v12wk, same START / END / tail-exceptions as the v12 build, and every cell runs on it.
#   2. Cells pair across arms: M sN with the committed N sN (breadth-fix-rb1), M+3138 sN with M sN, M+3174 s0 with M s0,
#      M-pre3339 s0 with both N s0 and M s0.
#   3. The review packs are built and rendered at the end (backtest-result-review.md), from the pinned tree.
#   4. One extra cell, M-pre3339 s0: the same binary and spec as M, with TRADING_DATA_DIR pointing at a copy of the run
#      tree's test_data whose two NYSE A-D CSVs are the pre-#3339 ones (git show 1f2432fa2^:...). #3339 changes no
#      shipped code (launch checks it), so this is the pre-#3339 tree as the backtest sees it, and M - M-pre3339 is
#      #3339 alone even if main moves before launch. N -> M-pre3339 is then #3283 (plus CSV drift).
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
# #3193 (#3174 flag), #3195 (#3138 audit record), #3339 (#3263 A-D fixture fix).
FIX3339=1f2432fa2
NEED="3f51d4afd e9d6bb7a0 904746e8c 974e91885 852e61c2e $FIX3339"
ADCSV="trading/test_data/breadth/nyse_advn.csv trading/test_data/breadth/nyse_decln.csv"
TD_PRE=/tmp/vcv-td-pre3339                           # container: run-tree test_data + the pre-#3339 A-D CSVs
N_LAUNCH='2026-10-11 00:00:00'                       # N's inputs were staged 10-11/12 (breadth-fix launch.sh)
# Cell order: salt 0 of every arm first, so the cheapest-to-read cells exist even if a later cell dies.
# token = spec:salt:pairs:data, pairs = label=partner-validator[,label=...] (container paths; "-" = no pair),
# data = main (the run tree's test_data) or pre3339 ($TD_PRE).
cells() {
  echo "vcv-M:0:N=$WT/$N_RES/N-rb1-26-s0-v12-validator.sexp.sexp:main"
  echo "vcv-Mpre3339:0:N=$WT/$N_RES/N-rb1-26-s0-v12-validator.sexp.sexp,M=$ART/vcv-M-s0-validator.sexp.sexp:pre3339"
  echo "vcv-M3174:0:M=$ART/vcv-M-s0-validator.sexp.sexp:main"
  echo "vcv-M3138:0:M=$ART/vcv-M-s0-validator.sexp.sexp:main"
  echo "vcv-M:1:N=$WT/$N_RES/N-rb1-26-s1-v12-validator.sexp.sexp:main"
  echo "vcv-M3138:1:M=$ART/vcv-M-s1-validator.sexp.sexp:main"
  echo "vcv-M:2:N=$WT/$N_RES/N-rb1-26-s2-v12-validator.sexp.sexp:main"
  echo "vcv-M3138:2:M=$ART/vcv-M-s2-validator.sexp.sexp:main"
}
SPECS="vcv-M vcv-Mpre3339 vcv-M3138 vcv-M3174"
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
  SHA=$(git rev-parse --short=9 "${RUN_SHA:-origin/main}") || die "cannot resolve ${RUN_SHA:-origin/main}"
  for c in $NEED; do git merge-base --is-ancestor "$c" "$SHA" || die "run tree $SHA lacks $c"; done
  # M-pre3339 (#3263 read): #3339 must change no shipped code, and nothing after it may touch the A-D CSVs, so that
  # swapping in the pre-#3339 CSVs undoes #3339 and nothing else.
  extra=$(git diff --name-only "$FIX3339^" "$FIX3339" | grep -v -e '^trading/test_data/breadth/' -e '/test/' || true)
  [ -z "$extra" ] || die "#3339 touches more than the A-D fixture and tests: $extra"
  later=$(git log --format=%h "$FIX3339..$SHA" -- $ADCSV)
  [ -z "$later" ] || die "commits after #3339 touch the A-D CSVs ($later): M-pre3339 would revert them too"
  rm -rf "$STAGE/pre3339"; mkdir -p "$STAGE/pre3339"
  for f in $ADCSV; do
    git show "$FIX3339^:$f" > "$STAGE/pre3339/$(basename "$f")" || die "pre-#3339 $f"
    git show "$SHA:$f" | cmp -s - "$STAGE/pre3339/$(basename "$f")" && die "pre-#3339 $f equals the run tree's"
  done
  echo "pre-#3339 A-D CSVs staged: $(cat "$STAGE"/pre3339/*.csv | md5 -q)" | tee -a "$STAGE/launch.log"
  if [ -d "$WTREL" ]; then
    [ "$(git -C "$WTREL" rev-parse --short=9 HEAD)" = "$SHA" ] || die "$WTREL is not at $SHA; remove it first"
  else git worktree add --detach "$WTREL" "$SHA" || die "worktree add"; fi
  # Inputs come from a commit, never a working copy: the pre-registration commit (default: the run SHA itself,
  # which holds this directory once the PR is merged).
  PREREG=${PREREG:-$SHA}
  rm -rf "$STAGE/specs"; mkdir -p "$STAGE/specs"
  for s in $SPECS; do git show "$PREREG:$EXP/specs/$s.sexp" > "$STAGE/specs/$s.sexp" || die "spec $s not at $PREREG"; done
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
  # ex_dividend_stop_adjust read them from TRADING_DATA_DIR. The files changed since N staged its copy are listed
  # first: they feed M but not N, so they are a confound of the M - N delta (README #3266 item 4, #3173).
  (cd data && find . \( -name dividends.csv -o -name splits.csv \) -newermt "$N_LAUNCH" | LC_ALL=C sort) > "$STAGE/corp-actions-changed.txt"
  echo "dividends/splits files modified since $N_LAUNCH: $(wc -l < "$STAGE/corp-actions-changed.txt" | tr -d ' ') ($STAGE/corp-actions-changed.txt)" | tee -a "$STAGE/launch.log"
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
  LC_ALL=C join "$W/rows-old.txt" "$W/rows-new.txt" > "$W/rows-joined.txt"   # symbol md5_old mtime_old md5_new mtime_new
  awk '$3 != $5 { print $1 }' "$W/rows-joined.txt" > "$W/csv-mtime-changed.txt"
  dx sh -c "cd $WH_OLD && md5sum *.weekly" | LC_ALL=C sort -k2 > "$W/weekly-old.md5"
  dx sh -c "cd $WH && md5sum *.weekly" | LC_ALL=C sort -k2 > "$W/weekly-new.md5"
  LC_ALL=C join -1 2 -2 2 "$W/weekly-old.md5" "$W/weekly-new.md5" | awk '$2 != $3 { sub(/\.weekly$/, "", $1); print $1 }' \
    | LC_ALL=C sort > "$W/weekly-differs.txt"
  # The fix detector counts only STABLE symbols (CSV mtime unchanged since v12): a refreshed CSV changes its payload
  # whether or not #3283 reached the columns, so drift alone must not satisfy the guard.
  awk '$3 == $5 { print $1 }' "$W/rows-joined.txt" | LC_ALL=C sort > "$W/stable.txt"
  awk '$3 == $5 && $2 != $4 { print $1 }' "$W/rows-joined.txt" | LC_ALL=C sort > "$W/payload-differs-stable.txt"
  LC_ALL=C comm -12 "$W/stable.txt" "$W/weekly-differs.txt" > "$W/weekly-differs-stable.txt"
  LC_ALL=C sort -u "$W/payload-differs-stable.txt" "$W/weekly-differs-stable.txt" > "$W/differs-stable.txt"
  n_st=$(wc -l < "$W/stable.txt" | tr -d ' '); n_fix=$(wc -l < "$W/differs-stable.txt" | tr -d ' ')
  log "WH verify: entries=$(wc -l < "$W/syms-new.txt" | tr -d ' ') csv_mtime changed since v12=$(wc -l < "$W/csv-mtime-changed.txt" | tr -d ' ') ($W/csv-mtime-changed.txt); stable symbols=$n_st, of which payload differs=$(wc -l < "$W/payload-differs-stable.txt" | tr -d ' ') .weekly differs=$(wc -l < "$W/weekly-differs-stable.txt" | tr -d ' ') either=$n_fix ($(awk -v a="$n_fix" -v b="$n_st" 'BEGIN { printf "%.1f", (b > 0 ? 100 * a / b : 0) }') %)"
  [ "$n_fix" -gt 0 ] || die "no stable symbol's stored columns changed vs v12: the #3266 fix did not reach the warehouse"
  dx touch $WH/.vcv-done
}
# M-pre3339's data dir: every run-tree test_data entry symlinked, except the two A-D CSVs, which are the pre-#3339
# copies staged by launch. Rebuilt on every run (cheap); checked to differ from the run tree's CSVs and only there.
phase_td_pre() {
  dx sh -c "rm -rf $TD_PRE && mkdir -p $TD_PRE/breadth && for e in $ROOT/test_data/*; do b=\$(basename \$e); [ \$b = breadth ] || ln -s \$e $TD_PRE/\$b; done && for e in $ROOT/test_data/breadth/*; do b=\$(basename \$e); case \$b in nyse_advn.csv|nyse_decln.csv) ;; *) ln -s \$e $TD_PRE/breadth/\$b ;; esac; done" || die "pre-#3339 data dir"
  for f in nyse_advn.csv nyse_decln.csv; do
    docker cp "$STAGE/pre3339/$f" "$C:$TD_PRE/breadth/$f" || die "pre-#3339 $f copy"
    dx cmp -s "$TD_PRE/breadth/$f" "$ROOT/test_data/breadth/$f" && die "pre-#3339 $f equals the run tree's"
  done
  log "TD_PRE $TD_PRE: A-D md5 $(dx sh -c "cat $TD_PRE/breadth/nyse_advn.csv $TD_PRE/breadth/nyse_decln.csv | md5sum | cut -c1-32") (run tree $(dx sh -c "cat $ROOT/test_data/breadth/nyse_advn.csv $ROOT/test_data/breadth/nyse_decln.csv | md5sum | cut -c1-32")); $(dx sh -c "ls $TD_PRE | wc -l") entries"
}

# ----------------------------------------------------------------------------------------------------------- cells
td_of() { case $1 in pre3339) echo "$TD_PRE" ;; *) echo "$ROOT/test_data" ;; esac; }
run_cell() { # $1 spec name, $2 salt, $3 pairs (label=validator[,...] or -), $4 data (main|pre3339)
  name=$1; salt=$2; pairs=$3; tag="$name-s$salt"; d=$STAGE_C/$tag; td=$(td_of "$4")
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return 0; fi
  host_free_ok || die "host disk < 20G before $tag"
  dx sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$STAGE/specs/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; return 0; }
  log "RUN $tag on $WH (TRADING_DATA_DIR=$td)"; start=$(date +%s)
  run "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $STAGE_C/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $STAGE_C/$tag.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.log"
  out=$(dx sh -c "grep 'Output root' $STAGE_C/$tag.log | tail -1 | sed 's/.*: //'")
  # one arm's actual.sexp only (sweep-hygiene.md metric-glob rule)
  m=$(dx sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  dx sh -c "for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $STAGE_C/$tag.log $ART/${tag}.log; cp $STAGE_C/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
  cache=$(dx sh -c "grep -h 'snapshot cache' $STAGE_C/$tag.log | tail -1"); rss=$(dx sh -c "tail -1 $STAGE_C/$tag.rss 2>/dev/null")
  guards=$(dx sh -c "grep -hE 'Panel_runner: (split_dividend_guard|ex_dividend_stop_adjust)' $STAGE_C/$tag.log | tr '\n' ' '")
  rej=$(dx sh -c "grep -o '(cash_rejection ' $ART/${tag}-trade_audit.sexp 2>/dev/null | wc -l")
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -share-classes $ROOT/test_data/share_classes.sexp -out $ART/${tag}-validator.sexp > $STAGE_C/$tag.validator.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.validator.log"
  q=$(dx sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  v6=""
  if [ "$pairs" != "-" ]; then
    for p in $(echo "$pairs" | tr ',' ' '); do lab=${p%%=*}; pv=${p#*=}; vl=$tag.v6diff-$lab.log
      run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$pv -report arm=$ART/${tag}-validator.sexp.sexp > $STAGE_C/$vl 2>&1; echo exit=\$? >> $STAGE_C/$vl"
      dx cp $STAGE_C/$vl $ART/$vl
      v6="$v6 vs$lab($(basename "$pv")):$(dx sh -c "tail -1 $STAGE_C/$vl")"
    done
  fi
  log "GUARDS $tag => ${guards:-<none>} cash_rejections=$rej"
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
}

# ---------------------------------------------------------------------------------------------------- review packs
phase_packs() {
  WTH=$REPO/$WTREL
  for arm in M Mpre3339 M3138 M3174; do
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
  phase_td_pre
  # PREFLIGHT: every spec over the last ~3 months on the rebuilt warehouse; a spec/override error costs minutes.
  for name in $SPECS; do pd=$STAGE_C/preflight-$name
    [ "$name" = vcv-Mpre3339 ] && td=$(td_of pre3339) || td=$(td_of main)
    dx sh -c "mkdir -p $pd && rm -rf $pd/*"
    sed 's/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2026-04-01) (end_date 2026-06-26)))/' "$STAGE/specs/$name.sexp" > "$STAGE/preflight-$name.sexp"
    docker cp "$STAGE/preflight-$name.sexp" "$C:$pd/$name.sexp" || die "preflight copy $name"
    log "PREFLIGHT $name (TRADING_DATA_DIR=$td)"; t0=$(date +%s)
    run "TRADING_DATA_DIR=$td SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
    pout=$(dx sh -c "grep 'Output root' $pd.log | tail -1 | sed 's/.*: //'")
    dx test -s "${pout}/${name}/actual.sexp" || die "preflight $name wrote no actual.sexp (see $pd.log)"
    log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
  done
  for tok in $(cells); do
    name=${tok%%:*}; rest=${tok#*:}; salt=${rest%%:*}; rest=${rest#*:}; pairs=${rest%:*}; data=${rest##*:}
    run_cell "$name" "$salt" "$pairs" "$data"
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
  for name in ${*:-$SPECS control}; do
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
# One CSV row per trade_audit.sexp record: position_id,symbol,entry_date,cancel_reason,ticket_age_weeks_at_cancel,
# required,available (the last two only on a ticket_lifecycle cash_rejection, #3195). entry_date is the audit's join
# key, the placement date; the cancel step's date is not stored (it is placement + ticket_age_weeks_at_cancel weeks).
audit_rows() { # $1 trade_audit.sexp
  echo "position_id,symbol,entry_date,cancel_reason,ticket_age_weeks_at_cancel,required,available"
  tr -s '\n\t ' '   ' < "$1" | awk '
    function fld(k,   s) { if (match($0, "\\(" k " [^()]*\\)")) return substr($0, RSTART + length(k) + 2, RLENGTH - length(k) - 3); return "" }
    BEGIN { RS = "\\(\\(entry \\(\\(symbol "; OFS = "," }
    NR > 1 {
      req = ""; av = ""
      if (match($0, /\(cash_rejection \(\(required [-0-9.e+]+\) \(available [-0-9.e+]+\)\)\)/)) {
        split(substr($0, RSTART, RLENGTH), a, /[() ]+/); req = a[4]; av = a[6] }
      print fld("position_id"), substr($0, 1, index($0, ")") - 1), fld("entry_date"), fld("cancel_reason"),
        fld("ticket_age_weeks_at_cancel"), req, av }'
}
cmd_collect() { # $1 destination results dir (host)
  dest=${1:?usage: chain.sh collect DEST}; mkdir -p "$dest"; src=$H/verify-chain-v
  echo "cell,entry_year,cash_rejections" > "$dest/cash_rejections_by_year.csv"
  for f in "$src"/vcv-*-s[0-9]-*; do
    [ -f "$f" ] || continue
    case "$f" in *-trade_audit.sexp)
      b=$(basename "$f" -trade_audit.sexp)
      audit_rows "$f" > "$dest/$b-audit_entries.csv"
      awk -F, 'NR == 1 { print "position_id,symbol,entry_date,ticket_age_weeks_at_cancel,required,available,funded_fraction"; next }
        $6 != "" { printf "%s,%s,%s,%s,%s,%s,%.4f\n", $1, $2, $3, $5, $6, $7, ($6 > 0 ? $7 / $6 : 0) }' \
        "$dest/$b-audit_entries.csv" > "$dest/$b-cash_rejections.csv"
      echo $(( $(wc -l < "$dest/$b-cash_rejections.csv") - 1 )) > "$dest/$b-cash_rejections.txt"
      awk -F, -v c="$b" 'NR > 1 { n[substr($3, 1, 4)]++ } END { for (y in n) print c "," y "," n[y] }' \
        "$dest/$b-cash_rejections.csv" | LC_ALL=C sort >> "$dest/cash_rejections_by_year.csv"
      continue ;; esac
    cp "$f" "$dest/"
  done
  for f in "$src"/vcv-*-s[0-9].log "$src"/vcv-*-s[0-9].rss "$src"/vcv-*-s[0-9].v6diff-*.log; do [ -f "$f" ] && cp "$f" "$dest/"; done
  [ -f "$LOG_HOST" ] && cp "$LOG_HOST" "$dest/chain.log"
  [ -f "$STAGE/corp-actions-changed.txt" ] && cp "$STAGE/corp-actions-changed.txt" "$dest/"
  [ -d "$STAGE/wh" ] && { mkdir -p "$dest/wh"; cp "$STAGE"/wh/chunk-*.build.log "$STAGE/wh/csv-mtime-changed.txt" "$STAGE/wh/differs-stable.txt" "$dest/wh/" 2>/dev/null; }
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') files (trade_audit.sexp reduced to audit_entries.csv + cash_rejections.csv)"
}


# One-off (10-21): finish vcv-M-s2 after its `timeout 36000` wrapper was SIGKILLed at ~04:35 PT so the cell could run
# past the guard (projected ~46,500 s). Same post-processing as run_cell, after the detached runner exits.
STAGE_C=/tmp/vcv-work; name=vcv-M; salt=2; tag=vcv-M-s2; start=1792558712   # RUN line 10-20 21:58:32 PT
pairs="N=$WT/$N_RES/N-rb1-26-s2-v12-validator.sexp.sexp"
log "DETACHED $tag: timeout wrapper killed (guard 36000 s would cut a ~46,500 s cell); waiting for the runner"
while dx pgrep -f "scenario_runner.exe --dir $STAGE_C/$tag" >/dev/null; do sleep 60; done
out=$(dx sh -c "grep 'Output root' $STAGE_C/$tag.log | tail -1 | sed 's/.*: //'")
m=$(dx sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
dx sh -c "for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $STAGE_C/$tag.log $ART/${tag}.log" || true
cache=$(dx sh -c "grep -h 'snapshot cache' $STAGE_C/$tag.log | tail -1")
guards=$(dx sh -c "grep -hE 'Panel_runner: (split_dividend_guard|ex_dividend_stop_adjust)' $STAGE_C/$tag.log | tr '\n' ' '")
rej=$(dx sh -c "grep -o '(cash_rejection ' $ART/${tag}-trade_audit.sexp 2>/dev/null | wc -l")
run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -share-classes $ROOT/test_data/share_classes.sexp -out $ART/${tag}-validator.sexp > $STAGE_C/$tag.validator.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.validator.log"
q=$(dx sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
v6=""
for p in $(echo "$pairs" | tr ',' ' '); do lab=${p%%=*}; pv=${p#*=}; vl=$tag.v6diff-$lab.log
  run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$pv -report arm=$ART/${tag}-validator.sexp.sexp > $STAGE_C/$vl 2>&1; echo exit=\$? >> $STAGE_C/$vl"
  dx cp $STAGE_C/$vl $ART/$vl
  v6="$v6 vs$lab($(basename "$pv")):$(dx sh -c "tail -1 $STAGE_C/$vl")"
done
log "GUARDS $tag => ${guards:-<none>} cash_rejections=$rej"
log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} peak_rss_kb=n/a(detached) ${cache} (wall $(( $(date +%s) - start ))s)"
# Re-arm M3138-s1 (guard-killed at 36,022 s, 1433/1434 cycles) and run the two M3138 cells in place with cmd_run's own
# run_cell / phase_packs / cmd_collect. Not a cmd_run relaunch: its busy check (pgrep scenario_runner) matches the
# unreaped zombies the two killed cells leave under the container's PID 1, and build + preflight are already done at
# the pinned tree. Guard sized from the measured arm: M-s2 ~46.5k s, M3138-s1 > 36k s; 72,000 s >= 1.5x.
sed -i '' 's/RESULT vcv-M3138-s1 =>/GUARD-KILLED vcv-M3138-s1 =>/' "$LOG_HOST"
CELL_TIMEOUT=72000
log "REARM vcv-M3138-s1 (guard-killed at 36,022 s); running the M3138 s1/s2 cells with CELL_TIMEOUT=$CELL_TIMEOUT"
[ "$(git -C "$REPO/$WTREL" rev-parse --short HEAD)" = 7e7c65628 ] || die "wrong HEAD"
run_cell vcv-M3138 1 "M=$ART/vcv-M-s1-validator.sexp.sexp" main
run_cell vcv-M3138 2 "M=$ART/vcv-M-s2-validator.sexp.sexp" main
log "CELLS DONE"
phase_packs
cmd_collect "$STAGE/results"
log "CHAIN V DONE. Next: perf_long_cells.sh update $LOG_HOST; collect into the results PR; read per README."
