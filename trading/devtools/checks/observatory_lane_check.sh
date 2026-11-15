#!/bin/sh
# observatory_lane_check.sh -- fixture test of dev/experiments/observatory/lane.sh, the axis observatory lane
# (dev/plans/axis-observatory-2026-11-14.md §2.1, §2.2). No container and no network: it builds a two-commit git repo in
# a temp dir holding the lane, the reader, the record specs and the fixture queue (fixtures/observatory_lane/queue.tsv),
# plus a made-up trading-results dir, and checks:
#   - --dry-run: the first pending arm is chosen, and a status on the lane-results branch beats HEAD's queue (none
#     pending: the drift mode); each cell's reuse decision (run; trading-results for the seeds finished there; finished
#     in OUT); the batches at PAR = (15 - 3) / 6 = 2; the tripwire's md5 and its source; the drift pair; the publish
#     lists (price-bearing kinds private, mark-free kinds public, trade_audit never); and that it copies nothing;
#   - specs: obs-S-kK is rk-kK below the header, the arm adds exactly its overrides after the tiebreak line, and an arm
#     that sets a field the record already sets is refused;
#   - read, the lane's real path, on synthetic cells from fixtures/obs_read/gen_fixture.sh: a live arm appends a surface
#     row and becomes done@HEAD; S against the last published HEAD's S is the drift row; a changed S k0 is one
#     baseline-drift event; a dead arm reads nothing and becomes dead@HEAD; a re-read over the branch's surface replaces
#     its row and keeps the others; collect keeps every price-bearing file out of the public tree;
#   - years: the SPY bull/bear rule on a made-up bar file (tie, gap, the run-end cut, a bad header).
# Run: sh trading/devtools/checks/observatory_lane_check.sh
set -eu
. "$(dirname "$0")/_check_lib.sh"

ROOT=$(repo_root); EXP=dev/experiments/observatory
LFIX=$ROOT/trading/devtools/checks/fixtures/observatory_lane; OFIX=$ROOT/trading/devtools/checks/fixtures/obs_read
[ -f "$ROOT/$EXP/lane.sh" ] || die "observatory_lane_check: script under test not found: $ROOT/$EXP/lane.sh"
command -v git > /dev/null 2>&1 || { echo "SKIP: observatory_lane_check: no git"; exit 0; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
fails=0
ok() { echo "OK: observatory_lane_check: $1"; }
bad() { echo "FAIL: observatory_lane_check: $1" >&2; fails=$((fails + 1)); }
expect() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected '$2', got '$3'"; fi; }
has() { if grep -qxF -- "$2" "$TMP/$3"; then ok "$1"; else bad "$1: no line '$2' in $3"; fi; }
md5_of() { { md5sum "$1" 2> /dev/null || md5 -q "$1" 2> /dev/null; } | cut -c1-32; }

# The repo: the lane, the reader, the record specs and the fixture queue, in two commits so HEAD has a parent.
R=$TMP/repo; mkdir -p "$R/$EXP" "$R/dev/experiments/record-kseed-2026-10-27"
cp -R "$ROOT/$EXP"/. "$R/$EXP/"; cp "$LFIX/queue.tsv" "$R/$EXP/queue.tsv"
cp -R "$ROOT/dev/experiments/record-kseed-2026-10-27/specs" "$R/dev/experiments/record-kseed-2026-10-27/"
g() { git -C "$R" -c user.name=check -c user.email=check@example.com "$@"; }
g init -q 2> /dev/null; g symbolic-ref HEAD refs/heads/main; g add -A; g commit -qm c1; C1=$(g rev-parse --short=9 HEAD)
echo x > "$R/marker"; g add marker; g commit -qm c2; C2=$(g rev-parse --short=9 HEAD)
# lane ARGS... -> lane.sh in the repo, with OUT and the trading-results dir under TMP, MemTotal $MEMGB (15) and the
# state ref $SREF. Set MEMGB and SREF in a subshell only: an assignment before a function call may outlive it.
lane() { REPO=$R OUT=$TMP/out TR=$TMP/tr LANE_MEM_GB=${MEMGB:-15} PAR= STATE_REF=${SREF:-origin/observatory/lane-results} \
  sh "$R/$EXP/lane.sh" "$@"; }
# cell RUN ARM DIR NAME: one finished cell per seed in DIR from a gen_fixture run (plus actual, validator report, .ok)
cell() { mkdir -p "$3"; for k in 0 1 2 3 4; do s=obs-$2-k$k-s0; d=$3/obs-$4-k$k-s0
  for f in "$1/k$k/$s"-*; do cp "$f" "$d-${f##*/"$s"-}"; done
  echo "((total_return_pct 1.0))" > "$d-actual.sexp"; echo "(fixture)" > "$d-validator.sexp.sexp"; : > "$d.ok"; done; }
v6ok() { for k in 0 1 2 3 4; do printf 'V6 | 0 | 0 | agree\nexit=0\n' > "$1/obs-$2-k$k-s0.v6diff-$3.log"; done; }
# qset LABEL STATUS -> the repo queue with LABEL's status (every pending status when LABEL is empty) set
qset() { awk -F"\t" -v OFS="\t" -v l="$1" -v s="$2" '$0 !~ /^#/ && $1 != "label" && ($1 == l || (l == "" && $4 == "pending")) { $4 = s } { print }' "$R/$EXP/queue.tsv"; }
sh "$OFIX/gen_fixture.sh" "$TMP/run"

# --- dry run A: nothing finished anywhere
lane run --dry-run > "$TMP/A" 2>&1 || bad "dry run A exited non-zero: $(tail -1 "$TMP/A")"
has "A: the first pending arm" "ARM dead-arm: ((stops_config ((max_stop_distance_pct 0.11)))) (ledger: fixture: its cells copy S)" A
has "A: S k0 runs" "CELL obs-S-k0-s0 run" A
has "A: the arm's k4 runs" "CELL obs-dead-arm-k4-s0 run" A
expect "A: ten cells run" 10 "$(grep -c '^CELL obs-.* run$' "$TMP/A")"
has "A: two cells at a time on 15 GB" "PARALLEL 2 cells at a time (MemTotal 15 GB, reserve 3 GB, 6 GB per cell)" A
has "A: batch 3 straddles S and the arm" "BATCH 3: obs-S-k4-s0 obs-dead-arm-k0-s0" A
expect "A: five batches" 5 "$(grep -c '^BATCH ' "$TMP/A")"
(MEMGB=14 lane run --dry-run) > "$TMP/A14" 2>&1 || bad "dry run A14 exited non-zero: $(tail -1 "$TMP/A14")"
has "A14: one cell at a time on 14 GB: the 3 GB reserve counts" "PARALLEL 1 cells at a time (MemTotal 14 GB, reserve 3 GB, 6 GB per cell)" A14
expect "A14: ten batches of one" 10 "$(grep -c "^BATCH [0-9]*: obs-[^ ]*$" "$TMP/A14")"
has "A: the preflight runs the arm" "PREFLIGHT obs-dead-arm-k0 to 2000-03-31 before the cells" A
has "A: the tripwire is the record's" "TRIPWIRE S k0 trades.csv md5 must be 0928cfe40333560429f5a6e57c9c18de the record (#3595 pb-S-k0 = #3602 pbb-S-k0); otherwise a baseline-drift event" A
has "A: no drift pair" "DRIFT none: no earlier HEAD has a finished S in trading-results" A
P=$EXP/runs/$C2/dead-arm/obs-dead-arm-k*-s0
for f in -trades.csv -equity_curve.csv -open_positions.csv -splits.csv -validator.sexp.sexp .log .ok; do
  has "A: $f is private" "PRIVATE $P$f" A; done
for f in -actual.sexp -summary.sexp -params.sexp -macro_trend.sexp .rss .validator.log .v6diff-S.log; do
  has "A: $f is public" "PUBLIC $P$f" A; done
expect "A: trade_audit only on the SKIP line" "SKIP" "$(grep trade_audit "$TMP/A" | cut -d' ' -f1)"

# --- dry run B: trading-results has the parent's S and this HEAD's S for k0-k2
cell "$TMP/run" H "$TMP/tr/$EXP/runs/$C1/S" S
cell "$TMP/run" S "$TMP/tr/$EXP/runs/$C2/S" S; rm "$TMP/tr/$EXP/runs/$C2/S/obs-S-k3-s0.ok" "$TMP/tr/$EXP/runs/$C2/S/obs-S-k4-s0.ok"
lane run --dry-run > "$TMP/B" 2>&1 || bad "dry run B exited non-zero: $(tail -1 "$TMP/B")"
has "B: S k0 reused from trading-results" "CELL obs-S-k0-s0 reuse: trading-results $EXP/runs/$C2/S" B
has "B: S k3 runs (no .ok)" "CELL obs-S-k3-s0 run" B
expect "B: seven cells run" 7 "$(grep -c '^CELL obs-.* run$' "$TMP/B")"
has "B: batch 1 is S k3 and k4" "BATCH 1: obs-S-k3-s0 obs-S-k4-s0" B
has "B: the tripwire is the last published S" "TRIPWIRE S k0 trades.csv md5 must be $(md5_of "$TMP/tr/$EXP/runs/$C1/S/obs-S-k0-s0-trades.csv") S@$C1 in trading-results; otherwise a baseline-drift event" B
has "B: the drift pair" "DRIFT S@$C2 against S@$C1 -> drift.tsv" B
has "B: the drift V6 logs are public" "PUBLIC $EXP/runs/$C2/S/obs-S-k*-s0.v6diff-$C1.log" B
expect "B: a dry run copies nothing into OUT" no "$([ -d "$TMP/out/runs" ] && echo yes || echo no)"

# --- dry run C: a status on the lane-results branch beats HEAD's queue; nothing pending is the drift mode
g checkout -q -b observatory/lane-results
qset dead-arm done@bbbbbbbbb > "$TMP/q" && cp "$TMP/q" "$R/$EXP/queue.tsv"; g commit -qam lane1
L1=$(g rev-parse HEAD); g checkout -q main
(SREF=observatory/lane-results lane run --dry-run) > "$TMP/C" 2>&1 || bad "dry run C exited non-zero: $(tail -1 "$TMP/C")"
has "C: the state is the branch's" "STATE from observatory/lane-results $L1" C
has "C: the branch's done@ skips dead-arm" "ARM up-arm: ((stops_config ((max_stop_distance_pct 0.13)))) (ledger: fixture: its cells are obs_read fixture arm U)" C
g checkout -q observatory/lane-results
qset "" done@ccccccccc > "$TMP/q" && cp "$TMP/q" "$R/$EXP/queue.tsv"; g commit -qam lane2; g checkout -q main
(SREF=observatory/lane-results lane run --dry-run) > "$TMP/C2" 2>&1 || bad "dry run C2 exited non-zero: $(tail -1 "$TMP/C2")"
has "C2: nothing pending is the drift mode" "QUEUE no pending arm: running the drift mode" C2
expect "C2: the drift mode runs S only" "0 2" "$(grep -c '^CELL obs-[a-z]' "$TMP/C2") $(grep -c '^CELL obs-S-k[0-4]-s0 run$' "$TMP/C2")"

# --- dry run D: this HEAD's S finished in OUT
cell "$TMP/run" S "$TMP/out/runs/$C2/S" S
lane run --dry-run > "$TMP/D" 2>&1 || bad "dry run D exited non-zero: $(tail -1 "$TMP/D")"
has "D: S k4 reused from OUT" "CELL obs-S-k4-s0 reuse: finished in OUT" D
expect "D: only the arm runs" 5 "$(grep -c '^CELL obs-.* run$' "$TMP/D")"

# --- specs
rc=0; lane specs up-arm "$TMP/specs" > "$TMP/sp" 2>&1 || rc=$?; expect "specs up-arm" 0 "$rc"
rk=$R/dev/experiments/record-kseed-2026-10-27/specs/rk-k3.sexp; ovl='   ((stops_config ((max_stop_distance_pct 0.13))))'
sed 1,4d "$rk" > "$TMP/rk"
expect "obs-S-k3 is rk-k3 below the header" "" "$(sed 1,4d "$TMP/specs/obs-S-k3.sexp" | diff "$TMP/rk" -)"
expect "obs-up-arm-k3 is obs-S-k3 plus the override line" "" "$(sed 1,4d "$TMP/specs/obs-up-arm-k3.sexp" | grep -vxF "$ovl" | diff "$TMP/rk" -)"
expect "the override follows the tiebreak line" "$ovl" "$(grep -A1 'tiebreak_seed 3' "$TMP/specs/obs-up-arm-k3.sexp" | tail -1)"
rc=0; lane specs dup-arm "$TMP/specs2" > "$TMP/sp2" 2>&1 || rc=$?
expect "an arm resetting a record field is refused" "1 1" "$rc $(grep -c 'the record config already sets max_position_pct_long' "$TMP/sp2")"

# --- read: the real path on finished cells (S is in OUT from D; the parent's S is in trading-results from B)
cell "$TMP/run" U "$TMP/out/runs/$C2/up-arm" up-arm; cell "$TMP/run" S "$TMP/out/runs/$C2/dead-arm" dead-arm
v6ok "$TMP/out/runs/$C2/up-arm" up-arm S; v6ok "$TMP/out/runs/$C2/dead-arm" dead-arm S; v6ok "$TMP/out/runs/$C2/S" S "$C1"
mkdir -p "$TMP/out/spy"; printf '%s\n' date,open,high,low,close,adjusted_close,volume 2009-12-31,1,1,1,50,1,1 \
  2010-12-31,1,1,1,60,1,1 2011-12-30,1,1,1,55,1,1 2016-12-30,1,1,1,70,1,1 > "$TMP/out/spy/data.csv"
rc=0; lane read up-arm > "$TMP/R1" 2>&1 || rc=$?; expect "read up-arm" 0 "$rc"
cp "$TMP/out/state/surface.tsv" "$TMP/s1"   # the first read's surface, for the re-read below
S1=$TMP/out/state/surface.tsv
expect "a live arm appends one row: label, commit, v6, median D_end, flag" "1 up-arm $C2 ok 0.3600 UP" \
  "$(awk -F'\t' 'NR > 1 { print $1, $2, $4, $7, $8, $29 }' "$S1")"
expect "the live arm is done@HEAD" "done@$C2" "$(awk -F'\t' '$1 == "up-arm" { print $4 }' "$TMP/out/state/queue.tsv")"
expect "the drift row: S at HEAD against S at the parent" "drift@$C1 $C2 ok 0.3700" \
  "$(awk -F'\t' 'NR > 1 { print $2, $4, $7, $8 }' "$TMP/out/state/drift.tsv")"
expect "a changed S k0 is one baseline-drift event" "1" "$(awk -F'\t' -v h="$C2" '$2 == h && $3 == "baseline-drift"' "$TMP/out/state/events.tsv" | wc -l | tr -d ' ')"
expect "the SPY labels come from OUT's bar file" "2010 bull,2011 bear" \
  "$(grep -v '^#' "$TMP/out/state/spy_years.tsv" | tr '\t\n' ' ,' | sed 's/,$//')"
PUB=$TMP/out/results/public/$EXP; PRV=$TMP/out/results/private/$EXP
expect "public: no price-bearing file" "" "$(find "$PUB" -type f \( -name '*trades.csv' -o -name '*equity_curve.csv' \
  -o -name '*open_positions.csv' -o -name 'D.tsv' -o -name 'firstdiff-*' -o -name '*validator.sexp.sexp' -o -name '*.ok' \) | head -3)"
for f in surface.tsv drift.tsv events.tsv queue.tsv spy_years.tsv "lane-logs/$C2-up-arm.log" \
  "runs/$C2/up-arm/obs-up-arm-k0-s0-summary.sexp" "runs/$C2/up-arm/obs-up-arm-k0-s0.v6diff-S.log"; do
  expect "public has $f" yes "$([ -f "$PUB/$f" ] && echo yes || echo no)"; done
for f in "runs/$C2/up-arm/obs-up-arm-k0-s0-trades.csv" "runs/$C2/S/obs-S-k0-s0-equity_curve.csv" "reads/up-arm@$C2/D.tsv" \
  "drift/$C2-vs-$C1/D.tsv" "runs/$C2/up-arm/obs-up-arm-k0-s0.ok" "runs/$C2/up-arm/obs-up-arm-k0-s0-summary.sexp"; do
  expect "private has $f" yes "$([ -f "$PRV/$f" ] && echo yes || echo no)"; done

rc=0; lane read dead-arm > "$TMP/R2" 2>&1 || rc=$?; expect "read dead-arm" 0 "$rc"
expect "a dead arm logs DEAD" 1 "$(grep -c 'DEAD dead-arm: trades.csv identical to S on every seed; no read' "$TMP/R2")"
expect "a dead arm appends no row" 0 "$(awk 'NR > 1' "$S1" | wc -l | tr -d ' ')"
expect "the dead arm is dead@HEAD" "dead@$C2" "$(awk -F'\t' '$1 == "dead-arm" { print $4 }' "$TMP/out/state/queue.tsv")"

# A re-read over the branch's surface (up-arm's row and another arm's) replaces up-arm's row and keeps the other.
awk -F'\t' -v OFS='\t' 'NR == 2 { print; $1 = 2; $2 = "other"; print; next } { print }' "$TMP/s1" > "$TMP/s2"
g checkout -q observatory/lane-results; cp "$TMP/s2" "$R/$EXP/surface.tsv"; g commit -qam lane3; g checkout -q main
rc=0; (SREF=observatory/lane-results lane read up-arm) > "$TMP/R3" 2>&1 || rc=$?; expect "re-read up-arm" 0 "$rc"
expect "the re-read replaced its row and kept the other" "1 up-arm $C2|2 other $C2" \
  "$(awk -F'\t' 'NR > 1 { printf "%s%s %s %s", s, $1, $2, $4; s = "|" }' "$S1")"

# --- years
printf '%s\n' date,open,high,low,close,adjusted_close,volume 1999-12-31,1,1,1,100,1,1 2000-06-30,1,1,1,120,1,1 \
  2000-12-29,1,1,1,95,1,1 2001-12-31,1,1,1,95,1,1 2002-12-31,1,1,1,94,1,1 2025-12-31,1,1,1,96,1,1 \
  2026-06-26,1,1,1,97,1,1 2026-06-29,1,1,1,80,1,1 > "$TMP/spy.csv"
expect "years: fall bear, tie bull, no prior year unlabelled, cut at the run end" "2000 bear,2001 bull,2002 bear,2026 bull" \
  "$(lane years "$TMP/spy.csv" | grep -v '^#' | tr '\t\n' ' ,' | sed 's/,$//')"
sed '1s/close/last/' "$TMP/spy.csv" > "$TMP/spy2.csv"; rc=0; lane years "$TMP/spy2.csv" > /dev/null 2>&1 || rc=$?
expect "years: a file without a close column is refused" 1 "$rc"

[ "$fails" -eq 0 ] || die "observatory_lane_check: $fails check(s) failed"
echo "OK: observatory_lane_check: all checks passed"
