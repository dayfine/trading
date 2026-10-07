#!/bin/sh
# Build the PIT snapshot warehouse /tmp/snap_top3000_pit_v12pit from the pit-v12 true-dollar-volume lists (#3136).
# POSIX sh. NOT run by the author of this file: the dispatcher launches it when the container is free.
#
# Recipe = the v11 recipe (dev/experiments/pit-universe-2026-09-14/{README.md,step4/}) with its three known
# pitfalls turned into guards instead of post-mortems:
#   1. single-pass build of ~10k names OOM-kills at 7.75 GB (exit 137)         -> 4 chunks, one job at a time
#   2. a chunked -incremental build misses every CROSS-chunk rename twin (233 legs in v11, V6 > 0 on the null)
#                                                                              -> pair scan + twin fix phases
#   3. -incremental once clobbered the manifest (#2724, fixed)                  -> every manifest entry has a .snap and no
#                                                                                  unexpected orphan .snap, after every build step
# plus the handle cap (#2882): every chain that reads this warehouse exports SNAPSHOT_MAX_MMAP_HANDLES >= manifest size.
#
# Usage (host, repo root of the checkout that holds this script; the lists live in THIS checkout):
#   RUN_TREE=/workspaces/trading-1/.claude/worktrees/sweep-pit-v12 \   # container path of a PINNED, built, clean tree
#     sh dev/scripts/build_pit_warehouse_v12.sh <phase>
# Phases, in order (each is resumable; `all` = preflight superset chunks classify chunk5 twinscan twinfix verify):
#   preflight  host/container guards (no network, no writes)
#   superset   union of the v12 lists + extras - quarantine -> $WORK/union.txt, 4 chunk specs        (host only)
#   chunks     chunks 1-4: build_snapshots -incremental -dedupe-rename-twins -twin-basis returns
#   classify   in-chunk twin drops -> legit (match >= 0.95) alias map vs false legs (match < 0.95)    (host only)
#   chunk5     rebuild the false legs as their own series, no dedupe (-incremental)
#   twinscan   six chunk-pair twin scans (report written before the per-symbol loop; kill after it)
#   twinfix    direct-edge cross-chunk twins -> one -incremental dedupe rebuild of the pairs; collateral rebuilt alone
#   verify     manifest == .snap set, D6 list coverage (expected absent = MEL + alias-delta legs), sample symbols, size
# Dry harness for the guard / resume / D6 logic: trading/devtools/checks/build_pit_warehouse_v12_guard_smoke.sh
# Output: warehouse in the container ($OUT); everything else under $WORK (host path /tmp/pit-v12-work).
#
# Estimates, from the v11 build (rebuild-pit-chunked.log, pair-scan.log): chunks 28-41 min each, ~2 h for four;
# chunk 5 and the twin fix ~1 min each; the six pair scans 33-38 min each, ~3.6 h; total ~6 h wall, container-
# exclusive (peak ~5-6 GB in a chunk build; ~4.3 GB in a pair scan). Warehouse 3.5 GB at 9,364 entries.
# v12's union is larger than v11's 9,900 (the inventory grew 5,734 -> 11,888), so budget 7-8 h.
#
# Env: RUN_TREE (required), CONTAINER (trading-1-dev), HOST_ROOT (/Users/difan/Projects/trading-1),
#      OUT (/tmp/snap_top3000_pit_v12pit), WORK (/tmp/pit-v12-work), END (today), START (1998-01-01).
set -u

PHASE=${1:-}
CONTAINER=${CONTAINER:-trading-1-dev}
HOST_ROOT=${HOST_ROOT:-/Users/difan/Projects/trading-1}
OUT=${OUT:-/tmp/snap_top3000_pit_v12pit}
WORK=${WORK:-/tmp/pit-v12-work}
START=${START:-1998-01-01}
END=${END:-$(date +%Y-%m-%d)}
CSV=/workspaces/trading-1/data
HERE=$(cd "$(dirname "$0")/../.." && pwd)                  # the checkout holding the lists
V12=$HERE/trading/test_data/backtest_scenarios/pit-v12
V11EXP=$HERE/dev/experiments/pit-universe-2026-09-14
EXC=$HERE/trading/test_data/warehouse_exceptions.sexp
RUN_TREE=${RUN_TREE:-}
EXE=$RUN_TREE/trading/_build/default/analysis/scripts/build_snapshots/build_snapshots.exe
HANDLE_CAP=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}

mkdir -p "$WORK"
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$WORK/build.log"; }
die() { log "ABORT: $*"; exit 1; }
dx() { docker exec "$CONTAINER" "$@"; }                    # the dry harness redefines dx after sourcing this file
n_manifest() { dx sh -c "grep -c '(symbol ' $OUT/manifest.sexp 2>/dev/null || echo 0"; }
manifest_syms() { dx grep -o '((symbol [^)]*)' "$OUT/manifest.sexp" | sed 's/((symbol //; s/)$//' | LC_ALL=C sort -u; }

snap_syms() { dx sh -c "ls $OUT/*.snap 2>/dev/null" | sed 's#.*/##; s#\.snap$##' | LC_ALL=C sort -u; }

# Guard 3 (the #2669/#2724 clobber signature is a tiny manifest, i.e. MANY .snap files with no manifest entry).
# $1 tag, $2 optional file of symbols that MAY be orphan .snap files (in $OUT but not in the manifest).
# Fails when (a) a manifest entry has no .snap, or (b) any orphan .snap is not in the allowed file. With no allowed
# file the manifest must equal the .snap set exactly. The twin-fix rebuild (chunk6) legitimately leaves the
# dropped legs' .snap files on disk (v11: 9,364 manifest vs 9,597 .snap = 233 cross-chunk legs), so it passes
# its own symbol set as the allowance; a clobbered manifest orphans thousands of files and still aborts.
assert_manifest_matches() {
  manifest_syms > "$WORK/guard-manifest.txt"; snap_syms > "$WORK/guard-snaps.txt"
  LC_ALL=C comm -23 "$WORK/guard-manifest.txt" "$WORK/guard-snaps.txt" > "$WORK/guard-missing.txt"
  LC_ALL=C comm -13 "$WORK/guard-manifest.txt" "$WORK/guard-snaps.txt" > "$WORK/guard-orphans.txt"
  [ ! -s "$WORK/guard-missing.txt" ] || die "$(wc -l < "$WORK/guard-missing.txt" | tr -d ' ') manifest entries have no .snap after $1 (e.g. $(head -3 "$WORK/guard-missing.txt" | tr '\n' ' '))"
  if [ -n "${2:-}" ]; then LC_ALL=C comm -23 "$WORK/guard-orphans.txt" "$2" > "$WORK/guard-bad.txt"; else cp "$WORK/guard-orphans.txt" "$WORK/guard-bad.txt"; fi
  [ ! -s "$WORK/guard-bad.txt" ] || die "$(wc -l < "$WORK/guard-bad.txt" | tr -d ' ') unexpected orphan .snap files (not in manifest) after $1: manifest=$(wc -l < "$WORK/guard-manifest.txt" | tr -d ' ') snaps=$(wc -l < "$WORK/guard-snaps.txt" | tr -d ' ') (manifest clobber?)"
  log "$1: manifest=$(wc -l < "$WORK/guard-manifest.txt" | tr -d ' ') snaps=$(wc -l < "$WORK/guard-snaps.txt" | tr -d ' ') expected-orphans=$(wc -l < "$WORK/guard-orphans.txt" | tr -d ' ') OK"
}

# Delete the .snap of every symbol in $1 (sorted file of dropped legs) that is an orphan (not in the manifest).
prune_orphans() {
  manifest_syms > "$WORK/guard-manifest.txt"
  LC_ALL=C comm -23 "$1" "$WORK/guard-manifest.txt" > "$WORK/pruned.txt"
  while read -r s; do dx rm -f "$OUT/$s.snap"; done < "$WORK/pruned.txt"
  log "pruned $(wc -l < "$WORK/pruned.txt" | tr -d ' ') orphan .snap files of dropped twin legs"
}

# `build_snapshots` over a Pinned universe spec file (host path), logging to $WORK/<tag>.log.
# $1 tag, $2 spec (host), $3.. extra build_snapshots flags
run_build() {
  tag=$1; spec=$2; shift 2
  docker cp "$spec" "$CONTAINER:/tmp/v12-$tag.sexp" || die "docker cp $spec"
  docker cp "$EXC" "$CONTAINER:/tmp/warehouse_exceptions.sexp" || die "docker cp exceptions"
  log "BUILD $tag ($(grep -c '(symbol ' "$spec") symbols) -> $OUT"
  dx bash -c "cd $RUN_TREE/trading && eval \$(opam env) && $EXE -universe-path /tmp/v12-$tag.sexp -csv-data-dir $CSV -output-dir $OUT -benchmark-symbol GSPC.INDX -start-date $START -end-date $END -incremental $* -tail-exceptions /tmp/warehouse_exceptions.sexp > /tmp/v12-$tag.build.log 2>&1; echo exit=\$? >> /tmp/v12-$tag.build.log"
  docker cp "$CONTAINER:/tmp/v12-$tag.build.log" "$WORK/$tag.build.log" 2>/dev/null
  tail -1 "$WORK/$tag.build.log" | grep -qx 'exit=0' || die "build $tag did not exit 0 (see $WORK/$tag.build.log; exit=137 = OOM)"
  docker cp "$CONTAINER:$OUT/rename_twin_report.txt" "$WORK/$tag.rename_twin_report.txt" 2>/dev/null
  assert_manifest_matches "$tag" "${ORPHAN_OK:-}"
}

# A Pinned spec from a file of symbols, one per line. $1 symbols file, stdout = spec.
pinned_spec() {
  echo "(Pinned ("
  sed 's/.*/  ((symbol &) (sector "Unknown"))/' "$1"
  echo "))"
}

phase_preflight() {
  [ -n "$RUN_TREE" ] || die "RUN_TREE (container path of a pinned, built tree) is required"
  dx test -x "$EXE" || die "exe missing: $EXE (build it in the pinned tree: dune build analysis/scripts/build_snapshots/build_snapshots.exe)"
  host_tree=$(echo "$RUN_TREE" | sed "s#^/workspaces/trading-1#$HOST_ROOT#")
  git -C "$host_tree" rev-parse --git-dir >/dev/null 2>&1 || die "run tree $host_tree is not a git tree (RUN_TREE outside /workspaces/trading-1? set HOST_ROOT)"
  [ -z "$(git -C "$host_tree" status --porcelain)" ] || die "run tree $host_tree is dirty"
  git -C "$host_tree" merge-base --is-ancestor 6141b23c3239cca9e9c4a0927694ec163adfb610 HEAD || die "run tree lacks #2724 (-incremental manifest merge, commit 6141b23c3): rebase it onto main"
  log "run tree HEAD=$(git -C "$host_tree" rev-parse --short HEAD) (#2724 verified present; #2882 handle cap is an env knob)"
  # container-exclusive: no other long job
  if dx pgrep -f 'build_snapshots|scenario_runner|panel_runner|bayesian_runner' >/dev/null; then die "another build/backtest is running in $CONTAINER"; fi
  used=$(docker stats --no-stream --format '{{.MemUsage}}' "$CONTAINER" | awk '{print $1}')
  log "container mem in use: $used (need >= 6 GB free of 7.75 GB: expect < 1.5 GB)"
  free_gb=$(df -g / | awk 'NR==2{print $4}'); [ "$free_gb" -gt 30 ] || die "host free ${free_gb} GB < 30 GB (sweep-hygiene.md)"
  dx test -e "$OUT" && die "$OUT already exists; refusing to overwrite (move it or set OUT)"
  # the SGP_old1 tail cut is a store edit, not a build flag: rows after 2009-11-03 must be absent
  late=$(dx awk -F, '$1 > "2009-11-03" && $1 ~ /^[0-9]/' "$CSV/S/1/SGP_old1/data.csv" | wc -l | tr -d ' ')
  [ "$late" = 0 ] || die "SGP_old1 has $late rows after 2009-11-03: the 3b store edit is missing (see pit-universe-2026-09-14 README)"
  n_lists=$(ls "$V12/composition"/top-3000-*.sexp | wc -l | tr -d ' ')
  [ "$n_lists" -ge 27 ] || die "expected >= 27 top-3000 lists in $V12/composition, found $n_lists"
  log "preflight OK; HANDLE CAP for every chain on this warehouse: export SNAPSHOT_MAX_MMAP_HANDLES=$HANDLE_CAP (must be >= manifest size)"
}

phase_superset() {
  rm -f "$WORK/twinfix.plan"                                 # a new universe starts a new run: never inherit an old plan
  quarantine=$(awk '{print $1}' "$V11EXP/results/quarantine.txt")
  {
    for f in "$V12"/composition/top-3000-199[9].sexp "$V12"/composition/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done | sed 's/(symbol //; s/)$//'
    cat "$V12/warehouse-extras.txt"
  } | LC_ALL=C sort -u | grep -v -x -e GSPC.INDX -e MEL $(for q in $quarantine; do printf -- '-e %s ' "$q"; done) > "$WORK/union.txt"
  # chunk key: the symbol without its _old[N] suffix, so a rename twin pair never straddles a chunk boundary
  # (v11 chunked by first letter for the same reason). Four equal chunks cut only where the key changes.
  sed 's/_old[0-9]*$//' "$WORK/union.txt" | paste - "$WORK/union.txt" | LC_ALL=C sort -k1,1 -k2,2 > "$WORK/keyed.txt"
  total=$(wc -l < "$WORK/keyed.txt" | tr -d ' ')
  awk -v total="$total" -v dir="$WORK" '
    BEGIN { target = int((total + 3) / 4); c = 1 }
    { if (n >= c * target && c < 4 && $1 != prev) c++
      print $2 > (dir "/chunk-" c ".txt"); n++; prev = $1 }' "$WORK/keyed.txt"
  for c in 1 2 3 4; do
    [ "$c" = 1 ] && echo GSPC.INDX >> "$WORK/chunk-1.txt"
    LC_ALL=C sort -u -o "$WORK/chunk-$c.txt" "$WORK/chunk-$c.txt"
    pinned_spec "$WORK/chunk-$c.txt" | sed 's/((symbol GSPC.INDX) (sector "Unknown"))/((symbol GSPC.INDX) (sector "Index"))/' > "$WORK/chunk-$c.sexp"
    log "chunk $c: $(wc -l < "$WORK/chunk-$c.txt" | tr -d ' ') symbols"
  done
  log "union=$total (+GSPC.INDX); v11 comparison: union 9,900, manifest 9,364 after twin dedupe"
}

phase_chunks() {
  for c in 1 2 3 4; do
    run_build "chunk$c" "$WORK/chunk-$c.sexp" -dedupe-rename-twins -twin-basis returns
  done
}

# In-chunk twin drops = list symbols absent from the manifest that appear as a dropped leg in a chunk report.
# Legit (match >= 0.95, as in v11's alias2) -> $WORK/alias-inchunk.txt "DROPPED SURVIVOR" (chains resolved);
# false (match < 0.95: transitive component drops) -> $WORK/false-legs.txt, rebuilt as their own series in chunk5.
phase_classify() {
  : > "$WORK/legs.txt"
  for c in 1 2 3 4; do
    awk '/^  survivor/ { s = $2 } /^    [^ ]+ \(overlap=/ { m = $3; gsub(/[^0-9.]/, "", m); print $1, s, m }' \
      "$WORK/chunk$c.rename_twin_report.txt" >> "$WORK/legs.txt"
  done
  awk '$3 >= 0.95 { print $1, $2 }' "$WORK/legs.txt" | LC_ALL=C sort -u > "$WORK/alias-raw.txt"
  awk '$3 < 0.95 { print $1 }' "$WORK/legs.txt" | LC_ALL=C sort -u > "$WORK/false-legs.txt"
  # resolve A->B, B->C chains to A->C (bounded; a cycle is a bug in the report, abort)
  awk '{ a[$1] = $2 } END { for (k in a) { v = a[k]; i = 0; while (v in a && i++ < 20) v = a[v]; if (i >= 20) { print "CYCLE " k > "/dev/stderr"; exit 1 } print k, v } }' \
    "$WORK/alias-raw.txt" > "$WORK/alias-resolved.tmp" || die "alias cycle"   # not piped: a pipeline's status is sort's
  LC_ALL=C sort "$WORK/alias-resolved.tmp" > "$WORK/alias-inchunk.txt"
  log "classify: $(wc -l < "$WORK/alias-inchunk.txt" | tr -d ' ') legit legs (alias), $(wc -l < "$WORK/false-legs.txt" | tr -d ' ') false legs (v11 by this rule: 360 / 86; v11 hand-removed IMPX_old and WCAP_old from its false-legs file, so its file had 84; v12 deliberately restores those two in chunk5)"
}

phase_chunk5() {
  [ -s "$WORK/false-legs.txt" ] || { log "chunk5: no false legs; skipped"; return 0; }
  pinned_spec "$WORK/false-legs.txt" > "$WORK/chunk-5.sexp"
  run_build chunk5 "$WORK/chunk-5.sexp"                      # no -dedupe-rename-twins: they are distinct series
}

# Guard 2, detection half: the twin pass on each chunk-PAIR union. The report is written before the per-symbol loop,
# so the build is killed once it exists. Output dir is a scratch dir, never $OUT.
phase_twinscan() {
  mkdir -p "$WORK/twin-scan"
  for pair in "1 2" "1 3" "1 4" "2 3" "2 4" "3 4"; do
    set -- $pair; i=$1; j=$2; tag=pair-$i$j; d=/tmp/v12-twin-scan/$tag
    [ -s "$WORK/twin-scan/$tag.report" ] && { log "scan $tag already done"; continue; }
    { cat "$WORK/chunk-$i.txt" "$WORK/chunk-$j.txt"; } | grep -v -x GSPC.INDX | LC_ALL=C sort -u > "$WORK/twin-scan/$tag.txt"
    { pinned_spec "$WORK/twin-scan/$tag.txt" | sed '$d'; echo '  ((symbol GSPC.INDX) (sector "Index"))'; echo "))"; } > "$WORK/twin-scan/$tag.sexp"
    dx mkdir -p "$d"; docker cp "$WORK/twin-scan/$tag.sexp" "$CONTAINER:$d/universe.sexp"
    log "SCAN $tag ($(grep -c '(symbol ' "$WORK/twin-scan/$tag.sexp") symbols)"; t0=$(date +%s)
    docker exec -d "$CONTAINER" bash -c "cd $RUN_TREE/trading && eval \$(opam env) && $EXE -universe-path $d/universe.sexp -csv-data-dir $CSV -output-dir $d -benchmark-symbol GSPC.INDX -start-date $START -end-date $END -dedupe-rename-twins -twin-basis returns > $d/build.log 2>&1; echo exit=\$? >> $d/build.log"
    sleep 5
    while :; do
      if dx test -f "$d/rename_twin_report.txt"; then
        dx pkill -x build_snapshots; sleep 2                  # narrow pattern on purpose (feedback_pkill_narrow_pattern)
        docker cp "$CONTAINER:$d/rename_twin_report.txt" "$WORK/twin-scan/$tag.report"
        log "RESULT $tag => $(sed -n 2p "$WORK/twin-scan/$tag.report") (wall $(( $(date +%s) - t0 ))s)"; break
      fi
      dx pgrep -x build_snapshots >/dev/null || { log "RESULT $tag => <no report> $(dx tail -1 "$d/build.log")"; die "pair scan $tag died (exit=137 = OOM)"; }
      sleep 20
    done
    dx rm -rf "$d"
  done
}

# Compute the twin-fix plan from the CURRENT manifest and save it. It is computed exactly once: after chunk6 the dropped
# legs are gone from the manifest, so a recomputation would see no pair and silently lose the alias delta.
_twinfix_plan() {
  manifest_syms > "$WORK/manifest-syms.txt"
  : > "$WORK/to-drop-pairs.txt"
  for r in "$WORK"/twin-scan/pair-*.report; do
    awk '/^  survivor/ { s = $2 } /^    [^ ]+ \(overlap=/ { o = $2; m = $3; gsub(/[^0-9]/, "", o); gsub(/[^0-9.]/, "", m); print s, $1, o, m }' "$r" > "$r.pairs"
    awk '{ print $1 }' "$r.pairs" | sort | uniq -c | awk '$1 > 4 { print $2 }' > "$r.hubs"
    awk '$3 >= 200 && $4 >= 0.95' "$r.pairs" | while read -r s d o m; do
      grep -q -x -F "$s" "$r.hubs" && continue
      grep -q -x -F "$s" "$WORK/manifest-syms.txt" && grep -q -x -F "$d" "$WORK/manifest-syms.txt" || continue
      grep -q -x -F "$d" "$WORK/false-legs.txt" && continue
      echo "$s $d"
    done >> "$WORK/to-drop-pairs.txt"
  done
  LC_ALL=C sort -u -o "$WORK/to-drop-pairs.txt" "$WORK/to-drop-pairs.txt"
  awk '{ print $2 }' "$WORK/to-drop-pairs.txt" | LC_ALL=C sort -u > "$WORK/drop-legs.txt"
  awk '{ print $1; print $2 }' "$WORK/to-drop-pairs.txt" | LC_ALL=C sort -u > "$WORK/pairs-universe.txt"
  # the lists must follow the warehouse: alias the dropped legs into them (written BEFORE the build that drops them)
  { awk '{ print $2, $1 }' "$WORK/to-drop-pairs.txt"; cat "$WORK/alias-inchunk.txt"; } | LC_ALL=C sort -u > "$WORK/alias-v12-new.txt"
  { echo "manifest_before=$(wc -l < "$WORK/manifest-syms.txt" | tr -d ' ')"; echo "union_id=$(_union_id)"; } > "$WORK/twinfix.plan"
}

# Identity of this run's symbol universe (the chunk files). A plan saved by an older run in the same $WORK carries another id.
_union_id() { cat "$WORK"/chunk-[1-4].txt 2>/dev/null | cksum | awk '{ print $1 "-" $2 }'; }

# Guard 2, repair half. A cross-chunk leg is real only on a DIRECT edge (overlap >= 200, match >= 0.95), whose
# survivor is not a hub (> 4 legs: the flat-series class of #2823), whose leg is not a restored false leg, and with both
# legs currently in the manifest (v11 analyze-pair.sh). The pairs are rebuilt together (-incremental + dedupe) so the
# detector resolves each component and Build_runner drops the losers from the manifest. The dropped legs' .snap files
# stay on disk (their chunk builds wrote them): chunk6's guard allows exactly the pairs' symbols as orphans, and the
# orphans of the dropped legs are deleted afterwards. Resumable: the plan is saved before chunk6; a rerun reuses it.
phase_twinfix() {
  if [ -s "$WORK/twinfix.plan" ]; then
    [ "$(sed -n 's/^union_id=//p' "$WORK/twinfix.plan")" = "$(_union_id)" ] || die "$WORK/twinfix.plan is from a different run (symbol universe changed): delete it and the old twin-scan/ outputs, or use a fresh WORK"
    log "twinfix: reusing saved plan ($WORK/twinfix.plan, $WORK/to-drop-pairs.txt, $WORK/alias-v12-new.txt)"
  else _twinfix_plan; fi
  np=$(wc -l < "$WORK/to-drop-pairs.txt" | tr -d ' ')
  if [ "$np" -eq 0 ]; then
    log "twinfix: no cross-chunk twins (v11 had 233 legs). Still apply the in-chunk map: $WORK/alias-v12-new.txt"
    log "  perl dev/experiments/pit-universe-2026-09-14/step4/twin-scan/alias-lists.pl $WORK/alias-v12-new.txt $V12/composition/top-*.sexp"
    return 0
  fi
  before=$(sed -n 's/^manifest_before=//p' "$WORK/twinfix.plan")
  ORPHAN_OK="$WORK/pairs-universe.txt"
  pinned_spec "$WORK/pairs-universe.txt" > "$WORK/chunk-6.sexp"
  run_build chunk6 "$WORK/chunk-6.sexp" -dedupe-rename-twins -twin-basis returns
  ORPHAN_OK=
  prune_orphans "$WORK/drop-legs.txt"
  manifest_syms > "$WORK/manifest-syms.txt"
  # a leg that must be gone but is not, or a survivor/leg swept in by a degenerate component (v11: EMBT) and now missing
  still=$(LC_ALL=C comm -12 "$WORK/drop-legs.txt" "$WORK/manifest-syms.txt" | wc -l | tr -d ' ')
  [ "$still" = 0 ] || log "WARNING: $still dropped legs still indexed: $(LC_ALL=C comm -12 "$WORK/drop-legs.txt" "$WORK/manifest-syms.txt" | head -5 | tr '\n' ' ')"
  LC_ALL=C comm -23 "$WORK/pairs-universe.txt" "$WORK/drop-legs.txt" | LC_ALL=C comm -23 - "$WORK/manifest-syms.txt" > "$WORK/collateral.txt"
  if [ -s "$WORK/collateral.txt" ]; then
    log "collateral (survivors swept out by a degenerate component): $(tr '\n' ' ' < "$WORK/collateral.txt") -> rebuilt alone, no dedupe"
    pinned_spec "$WORK/collateral.txt" > "$WORK/chunk-7.sexp"; run_build chunk7 "$WORK/chunk-7.sexp"
  fi
  log "twinfix: $np pairs, $(wc -l < "$WORK/drop-legs.txt" | tr -d ' ') legs dropped; manifest $before -> $(n_manifest). Next: apply $WORK/alias-v12-new.txt to the lists"
  log "  perl dev/experiments/pit-universe-2026-09-14/step4/twin-scan/alias-lists.pl $WORK/alias-v12-new.txt $V12/composition/top-*.sexp"
}

phase_verify() {
  assert_manifest_matches final
  m=$(n_manifest); [ "$m" -le "$HANDLE_CAP" ] || die "manifest $m exceeds handle cap $HANDLE_CAP: raise SNAPSHOT_MAX_MMAP_HANDLES in the chains"
  manifest_syms > "$WORK/manifest-syms.txt"
  # D6: every list symbol must be in the manifest, except the expected-absent set. In v12 every list symbol has a CSV
  # (the lists are built from the inventory), so the v11 exemptions (_old without CSV, fetch misses, quarantine) do not
  # apply: an `_old` series missing here is a real drop. Expected absent = MEL (built from two interleaved issuers,
  # excluded in `superset`, not in warehouse_exceptions.sexp) + the legs the alias delta maps away (in-chunk drops from
  # `classify`, cross-chunk drops from `twinfix`), which the lists lose when alias-lists.pl is applied.
  for f in "$V12"/composition/top-3000-199[9].sexp "$V12"/composition/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > "$WORK/list-union.txt"
  LC_ALL=C comm -23 "$WORK/list-union.txt" "$WORK/manifest-syms.txt" > "$WORK/absent.txt"
  { echo MEL; [ -s "$WORK/alias-v12-new.txt" ] && awk '{ print $1 }' "$WORK/alias-v12-new.txt"; [ -s "$WORK/alias-inchunk.txt" ] && awk '{ print $1 }' "$WORK/alias-inchunk.txt"; } | LC_ALL=C sort -u > "$WORK/expected-absent.txt"
  grep -v -x -F -f "$WORK/expected-absent.txt" "$WORK/absent.txt" > "$WORK/unexpected-absent.txt"
  log "D6: absent=$(wc -l < "$WORK/absent.txt" | tr -d ' ') of which expected (MEL + alias-delta legs) $(( $(wc -l < "$WORK/absent.txt") - $(wc -l < "$WORK/unexpected-absent.txt") )); UNEXPECTED absent=$(wc -l < "$WORK/unexpected-absent.txt" | tr -d ' ') (must be 0)"
  [ ! -s "$WORK/unexpected-absent.txt" ] || die "D6: list symbols missing from the warehouse and not aliased: see $WORK/unexpected-absent.txt (twin component dropped an unaliased series, or list/alias out of sync)"
  # sample symbols: manifest entry present, byte_size == file size, active_through == last CSV date for ended series
  for s in AAPL AMZN C JPM GSPC.INDX AAAGY; do
    sz=$(dx stat -c %s "$OUT/$s.snap" 2>/dev/null || echo missing)
    ms=$(dx awk -v s="$s" '$0 ~ "\\(symbol " s "\\)" { f = 1 } f && /byte_size/ { match($0, /byte_size [0-9]+/); print substr($0, RSTART + 10, RLENGTH - 10); exit }' "$OUT/manifest.sexp")
    at=$(dx awk -v s="$s" '$0 ~ "\\(symbol " s "\\)" { f = 1 } f && /active_through/ { match($0, /active_through [0-9-]+/); print substr($0, RSTART + 15, RLENGTH - 15); exit }' "$OUT/manifest.sexp")
    csvf=$(dx sh -c "ls $CSV/*/*/$s/data.csv $CSV/*/*/$s/*/data.csv 2>/dev/null | head -1")
    last=$([ -n "$csvf" ] && dx tail -1 "$csvf" | cut -d, -f1)
    log "sample $s: snap_size=$sz manifest_size=${ms:-none} active_through=${at:-open} csv_last=${last:-n/a}"
  done
  log "size: $(dx du -sh "$OUT" | awk '{ print $1 }') (v11: 3.5G / 9,364 entries)"
  log "VERIFY DONE. Then: md5 the lists, copy terminal_runs.csv + rename_twin reports into the experiment dir, and re-run the V6=0 check on the first null cell."
}

[ -z "${V12_LIB_ONLY:-}" ] || { echo "V12_LIB_ONLY set: functions defined, no phase run" >&2; return 0 2>/dev/null || exit 0; }   # dry-harness hook

case "$PHASE" in
  preflight) phase_preflight ;;
  superset) phase_superset ;;
  chunks) phase_chunks ;;
  classify) phase_classify ;;
  chunk5) phase_chunk5 ;;
  twinscan) phase_twinscan ;;
  twinfix) phase_twinfix ;;
  verify) phase_verify ;;
  all) phase_preflight && phase_superset && phase_chunks && phase_classify && phase_chunk5 && phase_twinscan && phase_twinfix && phase_verify ;;
  *) echo "usage: $0 {preflight|superset|chunks|classify|chunk5|twinscan|twinfix|verify|all}" >&2; exit 2 ;;
esac
