#!/bin/sh
# build_pit_warehouse_v12_guard_smoke.sh -- dry harness for the manifest/.snap guard, the twin-fix resume contract and
# the D6 expected-absent set of dev/scripts/build_pit_warehouse_v12.sh (#3182 QC rework).
#
# The 6-8 h warehouse build cannot run in a test, so the script's functions are sourced (V12_LIB_ONLY=1) and `docker` /
# `dx` are replaced by a local sandbox with a fake build_snapshots.exe that writes one .snap and one manifest entry per
# symbol of the universe spec. FAKE_DROP_FILE makes a `-dedupe-rename-twins` build drop those symbols from the manifest
# while leaving their .snap on disk (what the real chunk6 does to cross-chunk legs: v11 had 9,364 manifest entries vs
# 9,597 .snap files). FAKE_CLOBBER=1 makes a build rewrite the manifest with only its own spec (the #2669 signature).
#
# Cases:
#   a. expected twin drops pass the guard; orphan .snap files of the dropped legs are pruned; manifest == snaps after.
#   b. a clobbered (tiny) manifest still aborts: on a plain chunk build and on chunk6 despite its orphan allowance.
#   c. a rerun of twinfix after chunk6 reuses the saved plan: the alias delta is unchanged and the run still succeeds
#      (before the fix it logged "no cross-chunk twins" and lost the delta).
#   e. guard half (a): a manifest entry without a .snap aborts.
#   f. prune_orphans keeps the .snap of a planned leg still in the manifest (v11 EMBT); the warning is logged.
#   g. a saved plan from a different run (union id mismatch) is refused.  h. no pairs: apply-alias instruction printed.
#   i. superset deletes the saved plan and stale twin-scan directory.
#   Each case runs in a subshell; fatal guards still allow later cases and the summary.
#   d. D6: the expected-absent set is MEL + alias-delta legs only; an unaliased absent list symbol (also an `_old` one)
#      aborts verify, and a list that follows the alias delta passes.
#
# Run: sh trading/devtools/checks/build_pit_warehouse_v12_guard_smoke.sh
set -eu

. "$(dirname "$0")/_check_lib.sh"
SCRIPT="$(repo_root)/dev/scripts/build_pit_warehouse_v12.sh"

SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
# Persist assertion counts across case subshells, including an aborted case.
RESULTS="$SB/results"
: > "$RESULTS"
ok() { echo PASS >> "$RESULTS"; echo "PASS: $1"; }
bad() { echo FAIL >> "$RESULTS"; echo "FAIL: $1"; }
run_case() {
  # Keep errexit active inside each case, but collect its exit in the parent.
  set +e
  ( set -e; "$@" )
  case_rc=$?
  set -e
  [ "$case_rc" = 0 ] || bad "$1 aborted (rc=$case_rc)"
}
# expect <desc> <expected rc> <rc>
expect() { if [ "$3" = "$2" ]; then ok "$1"; else bad "$1 (rc=$3, wanted $2)"; fi; }

# --- sandbox: fake opam, fake build_snapshots.exe -------------------------------------------------------------------
RUN_TREE="$SB/tree"
EXE_DIR="$RUN_TREE/trading/_build/default/analysis/scripts/build_snapshots"
mkdir -p "$EXE_DIR" "$SB/bin" "$SB/ctmp"
printf '#!/bin/sh\nexit 0\n' > "$SB/bin/opam"; chmod +x "$SB/bin/opam"
cat > "$EXE_DIR/build_snapshots.exe" <<'EOF'
#!/bin/sh
# fake: -universe-path P -output-dir O [-dedupe-rename-twins]
while [ $# -gt 0 ]; do
  case "$1" in
    -universe-path) P=$2; shift ;;
    -output-dir) O=$2; shift ;;
    -dedupe-rename-twins) DEDUPE=1 ;;
  esac
  shift
done
mkdir -p "$O"; touch "$O/manifest.sexp"
[ -z "${FAKE_CLOBBER:-}" ] || : > "$O/manifest.sexp"
for s in $(grep -o '(symbol [^)]*)' "$P" | sed 's/(symbol //; s/)$//'); do
  touch "$O/$s.snap"
  grep -q "((symbol $s)" "$O/manifest.sexp" || echo "((symbol $s) (byte_size 1))" >> "$O/manifest.sexp"
done
if [ -n "${DEDUPE:-}" ] && [ -n "${FAKE_DROP_FILE:-}" ]; then
  for s in $(cat "$FAKE_DROP_FILE"); do grep -v "((symbol $s)" "$O/manifest.sexp" > "$O/m.tmp" || true; mv "$O/m.tmp" "$O/manifest.sexp"; done
fi
exit 0
EOF
chmod +x "$EXE_DIR/build_snapshots.exe"
PATH="$SB/bin:$PATH"

# --- source the script's functions, then point it at the sandbox --------------------------------------------------------
export RUN_TREE OUT="$SB/out" WORK="$SB/work" CONTAINER=fake END=2026-01-01
V12_LIB_ONLY=1
export V12_LIB_ONLY
. "$SCRIPT"
V12="$SB/v12"; EXC="$SB/exc.sexp"; : > "$EXC"
mkdir -p "$V12/composition"

_map() { sed -E "s#/tmp/(v12-|warehouse)#$SB/ctmp/\\1#g"; }
docker() { # only `cp` is used by the functions under test
  src=$(printf '%s' "$2" | sed "s#^$CONTAINER:##" | _map); dst=$(printf '%s' "$3" | sed "s#^$CONTAINER:##" | _map)
  cp "$src" "$dst"
}
dx() {
  if [ "$1" = bash ] && [ "$2" = -c ]; then bash -c "$(printf '%s' "$3" | _map)"; else "$@"; fi
}

# fresh state: 20 symbols S01..S20 built by chunk builds, the twin scan said S01~S02 and S03~S04 (drop S02, S04)
fresh() {
  unset FAKE_DROP_FILE
  rm -rf "$OUT" "$WORK"; mkdir -p "$WORK/twin-scan"
  : > "$WORK/syms.txt"; i=1
  while [ "$i" -le 20 ]; do printf 'S%02d\n' "$i" >> "$WORK/syms.txt"; i=$((i + 1)); done
  pinned_spec "$WORK/syms.txt" > "$WORK/chunk-1.sexp"
  ( run_build chunk1 "$WORK/chunk-1.sexp" -dedupe-rename-twins ) > "$WORK/fresh.out" 2>&1 || { cat "$WORK/fresh.out"; bad "fresh chunk build"; }
  printf '  survivor S01\n    S02 (overlap=250 match=0.99)\n  survivor S03\n    S04 (overlap=300 match=0.98)\n' > "$WORK/twin-scan/pair-12.report"
  : > "$WORK/false-legs.txt"; echo "S19 S18" > "$WORK/alias-inchunk.txt"
  printf 'S02\nS04\n' > "$WORK/fake-drop.txt"
  FAKE_DROP_FILE="$WORK/fake-drop.txt"; export FAKE_DROP_FILE
}
n_lines() { wc -l < "$1" | tr -d ' '; }

# a. expected drops pass, orphans pruned ---------------------------------------------------------------------------------
case_a() {
fresh
rc=0; ( phase_twinfix ) > "$WORK/a.out" 2>&1 || rc=$?
expect "a: twinfix with expected twin drops exits 0" 0 "$rc"
manifest_syms > "$WORK/m.txt"; snap_syms > "$WORK/s.txt"
[ "$(n_lines "$WORK/m.txt")" = 18 ] && [ "$(n_lines "$WORK/s.txt")" = 18 ] && cmp -s "$WORK/m.txt" "$WORK/s.txt" \
  && ok "a: manifest 18 == snaps 18 after the orphans of S02, S04 were pruned" || bad "a: manifest/snaps ($(n_lines "$WORK/m.txt")/$(n_lines "$WORK/s.txt"))"
grep -q 'expected-orphans=2 OK' "$WORK/build.log" && ok "a: chunk6 guard saw exactly the 2 expected orphans" || bad "a: chunk6 guard log"
grep -q '^S02 S01$' "$WORK/alias-v12-new.txt" && grep -q '^S04 S03$' "$WORK/alias-v12-new.txt" && grep -q '^S19 S18$' "$WORK/alias-v12-new.txt" \
  && ok "a: alias delta holds the cross-chunk and in-chunk legs" || bad "a: alias delta"
assert_manifest_matches final_a && ok "a: strict (no allowance) guard passes afterwards" || bad "a: strict guard"
}

# c. resume after chunk6 reuses the saved plan -------------------------------------------------------------------------------
case_c() {
fresh
( phase_twinfix ) > "$WORK/c-setup.out" 2>&1 || {
  cat "$WORK/c-setup.out"; exit 1;
}
cksum "$WORK/alias-v12-new.txt" > "$WORK/alias.sum"
rc=0; ( phase_twinfix ) > "$WORK/c.out" 2>&1 || rc=$?
expect "c: rerun of twinfix after chunk6 exits 0" 0 "$rc"
grep -q 'reusing saved plan' "$WORK/c.out" && ok "c: rerun reuses the saved plan" || bad "c: no reuse message"
grep -q 'no cross-chunk twins' "$WORK/c.out" && bad "c: rerun lost the plan (no cross-chunk twins)" || ok "c: rerun does not report 'no cross-chunk twins'"
cksum "$WORK/alias-v12-new.txt" | cmp -s - "$WORK/alias.sum" && ok "c: alias delta byte-identical after the rerun" || bad "c: alias delta changed"
[ "$(n_lines "$WORK/to-drop-pairs.txt")" = 2 ] && ok "c: drop list still 2 pairs" || bad "c: drop list"
}

# b. a clobbered manifest still aborts -----------------------------------------------------------------------------------------
case_b() {
fresh
rc=0; ( FAKE_CLOBBER=1; export FAKE_CLOBBER; pinned_spec "$WORK/syms.txt" | head -3 > "$WORK/small.sexp"; echo "))" >> "$WORK/small.sexp"; run_build chunk2 "$WORK/small.sexp" ) > "$WORK/b1.out" 2>&1 || rc=$?
expect "b1: clobber on a plain build aborts" 1 "$rc"
grep -q 'manifest clobber' "$WORK/b1.out" || grep -q 'no .snap' "$WORK/b1.out" && ok "b1: abort names the guard" || bad "b1: abort message"
fresh
rc=0; ( FAKE_CLOBBER=1; export FAKE_CLOBBER; phase_twinfix ) > "$WORK/b2.out" 2>&1 || rc=$?
expect "b2: clobber during chunk6 aborts despite the orphan allowance" 1 "$rc"
grep -q 'unexpected orphan' "$WORK/b2.out" && ok "b2: abort reports the unexpected orphans" || bad "b2: abort message"
}

# d. D6 --------------------------------------------------------------------------------------------------------------------------
case_d() {
fresh
rc=0; ( phase_twinfix ) > "$WORK/d0.out" 2>&1 || rc=$?
expect "d0: twinfix setup" 0 "$rc"; [ "$rc" = 0 ] || cat "$WORK/d0.out"
list="$V12/composition/top-3000-2000.sexp"
{ i=1; while [ "$i" -le 20 ]; do printf '((symbol S%02d))\n' "$i"; i=$((i + 1)); done; echo '((symbol MEL))'; } > "$list"
rc=0; ( phase_verify ) > "$WORK/d1.out" 2>&1 || rc=$?
expect "d1: list holds only warehouse + MEL + alias-delta legs -> verify passes" 0 "$rc"
echo '((symbol ZZZ_old))' >> "$list"
rc=0; ( phase_verify ) > "$WORK/d2.out" 2>&1 || rc=$?
expect "d2: an unaliased absent _old symbol aborts verify (no blanket _old exemption)" 1 "$rc"
grep -q 'ZZZ_old' "$WORK/unexpected-absent.txt" && ok "d2: it is listed as unexpected" || bad "d2: unexpected list"
}

# e. guard half (a): a manifest entry whose .snap is gone aborts -------------------------------------------------------------
case_e() {
fresh
unset FAKE_DROP_FILE
rm -f "$OUT/S05.snap"
rc=0; ( assert_manifest_matches final_e ) > "$WORK/e.out" 2>&1 || rc=$?
expect "e: a manifest entry without a .snap aborts the guard" 1 "$rc"
grep -q 'have no .snap' "$WORK/e.out" && grep -q 'S05' "$WORK/e.out" && ok "e: abort names the missing-.snap condition and S05" || bad "e: abort message"
}

# f. prune keeps the .snap of a planned leg the detector left in the manifest (v11 EMBT "still indexed") ----------------------
case_f() {
fresh
printf 'S02\n' > "$WORK/fake-drop-s02.txt"
FAKE_DROP_FILE="$WORK/fake-drop-s02.txt"; export FAKE_DROP_FILE
rc=0; ( phase_twinfix ) > "$WORK/f.out" 2>&1 || rc=$?
expect "f: twinfix with one planned leg (S04) left indexed exits 0" 0 "$rc"
[ -e "$OUT/S04.snap" ] && ok "f: S04.snap (still in the manifest) was not pruned" || bad "f: S04.snap was deleted"
[ ! -e "$OUT/S02.snap" ] && ok "f: S02.snap (orphan dropped leg) was pruned" || bad "f: S02.snap survived"
grep -q 'dropped legs still indexed' "$WORK/f.out" && ok "f: the 'still indexed' warning is logged" || bad "f: no 'still indexed' warning"
assert_manifest_matches final_f > /dev/null 2>&1 && ok "f: strict guard passes afterwards" || bad "f: strict guard"
}

# g. a stale plan from another run is refused ---------------------------------------------------------------------------------
case_g() {
fresh
rc=0; ( phase_twinfix ) > "$WORK/g0.out" 2>&1 || rc=$?
expect "g0: twinfix setup" 0 "$rc"
echo S99 > "$WORK/chunk-1.txt"
rc=0; ( phase_twinfix ) > "$WORK/g.out" 2>&1 || rc=$?
expect "g: a plan whose union id differs from this run aborts" 1 "$rc"
grep -q 'different run' "$WORK/g.out" && ok "g: abort says the plan is from a different run" || bad "g: abort message"
}

# h. no cross-chunk pairs still tells the operator to apply the in-chunk alias map -----------------------------------------------
case_h() {
fresh
: > "$WORK/twin-scan/pair-12.report"
rc=0; ( phase_twinfix ) > "$WORK/h.out" 2>&1 || rc=$?
expect "h: twinfix with no cross-chunk pairs exits 0" 0 "$rc"
grep -q 'no cross-chunk twins' "$WORK/h.out" && grep -q 'alias-lists.pl' "$WORK/h.out" && grep -q '^S19 S18$' "$WORK/alias-v12-new.txt" \
  && ok "h: the apply-alias instruction is printed and the file holds the in-chunk map" || bad "h: no apply instruction"
}

# i. a new superset discards scan reports and its saved twin-fix plan
case_i() {
fresh
V11EXP="$SB/v11"; mkdir -p "$V11EXP/results"
: > "$V11EXP/results/quarantine.txt"
: > "$V12/warehouse-extras.txt"
cp "$WORK/chunk-1.sexp" "$V12/composition/top-3000-1999.sexp"
cp "$WORK/chunk-1.sexp" "$V12/composition/top-3000-2000.sexp"
printf 'stale plan\n' > "$WORK/twinfix.plan"
rc=0; ( phase_superset ) > "$WORK/i.out" 2>&1 || rc=$?
expect "i: superset with stale twin state exits 0" 0 "$rc"
[ ! -e "$WORK/twinfix.plan" ] && ok "i: saved plan deleted" \
  || bad "i: saved plan survived"
[ ! -e "$WORK/twin-scan" ] && ok "i: stale scan directory deleted" \
  || bad "i: stale scan directory survived"
}

run_case case_a
run_case case_c
run_case case_b
run_case case_d
run_case case_e
run_case case_f
run_case case_g
run_case case_h
run_case case_i

PASS=$(grep -c '^PASS$' "$RESULTS" || true)
FAIL=$(grep -c '^FAIL$' "$RESULTS" || true)
echo "build_pit_warehouse_v12_guard_smoke: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
