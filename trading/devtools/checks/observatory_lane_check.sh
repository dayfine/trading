#!/bin/sh
# observatory_lane_check.sh -- fixture test of dev/experiments/observatory/lane.sh, the axis observatory lane
# (dev/plans/axis-observatory-2026-11-14.md §2.1, §2.2). No container and no network: it builds a two-commit git repo in
# a temp dir holding the lane, the reader, the record specs, the fixture queue (fixtures/observatory_lane/queue.tsv),
# an empty lane state (the surface header alone, whatever lanes have merged) and a made-up trading-results dir, and
# checks:
#   - --dry-run: the first pending arm is chosen, and a status on the lane-results branch beats HEAD's queue (none
#     pending: the drift mode); each cell's reuse decision (run; trading-results for the seeds finished there; finished
#     in OUT); the batches at PAR = (15 - 3) / 6 = 2; the tripwire's md5 and its source; the drift pair; the publish
#     lists (price-bearing kinds private, mark-free kinds public, trade_audit never); and that it copies nothing;
#   - specs: obs-S-kK is rk-kK below the header, the arm adds exactly its overrides after the tiebreak line, and an arm
#     that resets a field the record sets (a scalar and a list) replaces the record's line: the field appears once,
#     and the spec is S with exactly that line replaced, matched on the full field path (a sibling under the same
#     parent and a field sharing only the leaf name stay); a form setting two fields, or tiebreak_seed, is refused; a
#     screening_config sibling of tiebreak_seed (queue cap-40, fbt-05) is added beside it, replacing nothing; and every
#     pending arm of the real queue.tsv passes the lane's spec checks;
#   - the validator config (V12 follows the arm's stop gate): an arm that sets stops_config.max_stop_distance_pct X gets
#     ((gate_max_stop_distance_pct X)), logged once as VALIDATOR CONFIG, passed as -config in the validator command the
#     dry run prints (the one run_cell runs) and published; S and an arm that does not set the dial get none, so the
#     validator keeps its defaults;
#   - read, the lane's real path, on synthetic cells from fixtures/obs_read/gen_fixture.sh: a live arm appends a surface
#     row and becomes done@HEAD; S against the last published HEAD's S is the drift row; a changed S k0 is one
#     baseline-drift event; a dead arm reads nothing and becomes dead@HEAD; a re-read over the branch's surface replaces
#     its row and keeps the others; collect keeps every price-bearing file out of the public tree;
#   - the gates on their failing side: one failing V6 log makes a live arm, or a would-be-dead one, invalid@HEAD and
#     unread; one differing seed is live; a parent S identical to HEAD's is a tripwire match with no baseline-drift
#     event and a drift-none event with no drift row; a failing drift V6 log is drift-invalid with no drift row;
#     a drift pair obs_read.sh refuses is drift-read-failed (with its exit 2) and no drift row;
#   - years: the SPY bull/bear rule on a made-up bar file (tie, gap, the run-end cut, a bad header), writing no OUT;
#   - the lock (where flock exists): run, read, stage, docker, collect and publish refuse to run beside another
#     holder, and a dockerd that the docker preflight starts (a stub on PATH) does not keep lane.lock after the lane exits;
#   - lane.sh parses under dash -n (it is outside posix_sh_check.sh's scan dirs).
# Run: sh trading/devtools/checks/observatory_lane_check.sh
set -eu
. "$(dirname "$0")/_check_lib.sh"

ROOT=$(repo_root); EXP=dev/experiments/observatory
LFIX=$ROOT/trading/devtools/checks/fixtures/observatory_lane; OFIX=$ROOT/trading/devtools/checks/fixtures/obs_read
[ -f "$ROOT/$EXP/lane.sh" ] || die "observatory_lane_check: script under test not found: $ROOT/$EXP/lane.sh"
command -v git > /dev/null 2>&1 || { echo "SKIP: observatory_lane_check: no git"; exit 0; }
TMP=$(mktemp -d); trap 'kill "$(cat "$TMP/dockerd.pid" 2> /dev/null)" 2> /dev/null || :; rm -rf "$TMP"' EXIT INT TERM
fails=0
ok() { echo "OK: observatory_lane_check: $1"; }
bad() { echo "FAIL: observatory_lane_check: $1" >&2; fails=$((fails + 1)); }
expect() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected '$2', got '$3'"; fi; }
has() { if grep -qxF -- "$2" "$TMP/$3"; then ok "$1"; else bad "$1: no line '$2' in $3"; fi; }
md5_of() { { md5sum "$1" 2> /dev/null || md5 -q "$1" 2> /dev/null; } | cut -c1-32; }

# lane.sh sits outside posix_sh_check.sh's scan dirs: parse it here.
if command -v dash > /dev/null 2>&1; then psh=dash; else psh=sh; fi
if $psh -n "$ROOT/$EXP/lane.sh"; then ok "lane.sh parses under $psh -n"; else bad "lane.sh does not parse under $psh -n"; fi

# The repo: the lane, the reader, the record specs and the fixture queue, in two commits so HEAD has a parent.
R=$TMP/repo; mkdir -p "$R/$EXP" "$R/dev/experiments/record-kseed-2026-10-27"
cp -R "$ROOT/$EXP"/. "$R/$EXP/"; cp "$LFIX/queue.tsv" "$R/$EXP/queue.tsv"
# Merged lane results (surface rows, events, drift rows, cells, lane logs) are data, not the code under test: start
# from the surface header alone, so the fixtures see the same state whatever lanes have merged.
head -n 1 "$ROOT/$EXP/surface.tsv" > "$R/$EXP/surface.tsv"
rm -rf "$R/$EXP/runs" "$R/$EXP/lane-logs" "$R/$EXP/events.tsv" "$R/$EXP/drift.tsv"
cp -R "$ROOT/dev/experiments/record-kseed-2026-10-27/specs" "$R/dev/experiments/record-kseed-2026-10-27/"
g() { git -C "$R" -c user.name=check -c user.email=check@example.com "$@"; }
g init -q 2> /dev/null; g symbolic-ref HEAD refs/heads/main; g add -A; g commit -qm c1; C1=$(g rev-parse --short=9 HEAD)
echo x > "$R/marker"; g add marker; g commit -qm c2; C2=$(g rev-parse --short=9 HEAD)
# lane ARGS... -> lane.sh in the repo, with OUT $OUTX (TMP/out), trading-results $TRX (TMP/tr), MemTotal $MEMGB (15)
# and the state ref $SREF. Set these in a subshell only: an assignment before a function call may outlive it.
lane() { REPO=$R OUT=${OUTX:-$TMP/out} TR=${TRX:-$TMP/tr} LANE_MEM_GB=${MEMGB:-15} PAR= STATE_REF=${SREF:-origin/observatory/lane-results} \
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
has "A: the tripwire is the record's" "TRIPWIRE S k0 trades.csv md5 must be 3ee10dca319e54a85f5e0a7842d8c537 the record (S k0 at the One_basis flip, #3677 = vsb-1 k0); otherwise a baseline-drift event" A
has "A: no drift pair" "DRIFT none: no earlier HEAD has a finished S in trading-results" A
P=$EXP/runs/$C2/dead-arm/obs-dead-arm-k*-s0
for f in -trades.csv -equity_curve.csv -open_positions.csv -splits.csv -validator.sexp.sexp .log .ok; do
  has "A: $f is private" "PRIVATE $P$f" A; done
for f in -actual.sexp -summary.sexp -params.sexp -macro_trend.sexp -validator-config.sexp .rss .validator.log .v6diff-S.log; do
  has "A: $f is public" "PUBLIC $P$f" A; done
expect "A: trade_audit only on the SKIP line" "SKIP" "$(grep trade_audit "$TMP/A" | cut -d' ' -f1)"
# The validator's V12 follows the arm's stop gate (dead-arm sets 0.11): its command passes -config, S's does not.
has "A: the arm's validator config is logged" "VALIDATOR CONFIG dead-arm gate_max_stop_distance_pct 0.11" A
expect "A: the arm's validator config carries its gate" "((gate_max_stop_distance_pct 0.11))" \
  "$(cat "$TMP/out/dry/specs/obs-dead-arm.validator-config.sexp" 2> /dev/null)"
expect "A: S has no validator config" no "$([ -e "$TMP/out/dry/specs/obs-S.validator-config.sexp" ] && echo yes || echo no)"
expect "A: the arm's validator command passes its config, from the cell's own dir" 1 \
  "$(grep -c "^VALIDATOR CMD obs-dead-arm-k0-s0: .*post_run_validator_cli.exe .* -config [^ ]*/runs/$C2/dead-arm/obs-dead-arm-k0-s0-validator-config.sexp -out " "$TMP/A")"
expect "A: S's validator command has no -config" "1 0" \
  "$(grep -c '^VALIDATOR CMD obs-S-k0-s0: .*post_run_validator_cli.exe ' "$TMP/A") $(grep '^VALIDATOR CMD obs-S-k0-s0: ' "$TMP/A" | grep -c ' -config ')"
# run_cell cannot run here (it needs the container): it must build its validator command with the function printed above,
# and copy the arm's config into the cell's dir before it runs.
expect "run_cell runs the validator through validator_cmd and copies the config" "1 1" \
  "$(awk '/^run_cell\(\)/,/^}/' "$ROOT/$EXP/lane.sh" | grep -cF 'dk "$(validator_cmd "$root/$name" "$dest" "$tag" "$1")"') \
$(awk '/^run_cell\(\)/,/^}/' "$ROOT/$EXP/lane.sh" | grep -cF 'cp "$SPECS/obs-$1.validator-config.sexp" "$dest/$tag-validator-config.sexp"')"

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
# An override of a field the record sets replaces the record's line: the field appears once, with the arm's value.
# replaced LABEL FIELD LINE: LINE is the field's one line in obs-LABEL-k3, whitespace removed
replaced() { rc=0; lane specs "$1" "$TMP/specs-$1" > "$TMP/sp-$1" 2>&1 || rc=$?; expect "$1: specs written" 0 "$rc"
  expect "$1: $2 appears once, with the arm's value" "$3" "$(grep -v '^;;' "$TMP/specs-$1/obs-$1-k3.sexp" | grep "$2" | tr -d ' ')"; }
replaced dup-arm hysteresis_weeks '((laggard_rotation_config((hysteresis_weeks3))))'
replaced stale-arm stale_exit_after_days '((stale_exit_after_days(10)))'
expect "S keeps the record's hysteresis_weeks" '((laggard_rotation_config((hysteresis_weeks2))))' \
  "$(grep -v '^;;' "$TMP/specs-dup-arm/obs-S-k3.sexp" | grep hysteresis_weeks | tr -d ' ')"
expect "the replacements are logged" "1 1" "$(grep -c 'OVERRIDE laggard_rotation_config.hysteresis_weeks: 2 -> 3' "$TMP/sp-dup-arm") $(grep -c 'OVERRIDE stale_exit_after_days: (5) -> (10)' "$TMP/sp-stale-arm")"
# Byte for byte: obs-dup-arm-k3 is obs-S-k3 without the record's hysteresis line, plus the arm's line.
sed 1,4d "$TMP/specs-dup-arm/obs-S-k3.sexp" | grep -vxF '   ((laggard_rotation_config ((hysteresis_weeks 2))))' > "$TMP/dupS"
expect "obs-dup-arm-k3 is obs-S-k3 with exactly the one line replaced" "" \
  "$(sed 1,4d "$TMP/specs-dup-arm/obs-dup-arm-k3.sexp" | grep -vxF '   ((laggard_rotation_config ((hysteresis_weeks 3))))' | diff "$TMP/dupS" -)"
# The tie seed is the lane's: an arm that sets it is refused.
rc=0; lane specs seed-arm "$TMP/specs-seed" > "$TMP/sp-seed" 2>&1 || rc=$?
expect "an arm setting tiebreak_seed is refused" "1 1" "$rc $(grep -c 'an arm may not set tiebreak_seed' "$TMP/sp-seed")"
# The match is on the full field path. pos-arm resets one of the three portfolio_config lines: exactly that line is
# swapped and its siblings stay. leaf-arm sets stage3_force_exit_config.hysteresis_weeks, which shares only its leaf name
# with the record's laggard hysteresis: nothing is replaced, so its spec is S plus its line.
# swapped LABEL RECORD_LINE ARM_LINE: obs-LABEL-k3 is obs-S-k3 without RECORD_LINE (none if empty) plus ARM_LINE, exactly
swapped() { rc=0; lane specs "$1" "$TMP/specs-$1" > "$TMP/sp-$1" 2>&1 || rc=$?; f=$TMP/specs-$1/obs-$1-k3.sexp
  sed 1,4d "$TMP/specs-$1/obs-S-k3.sexp" | grep -vxF "${2:-@none@}" > "$TMP/sw-S"
  expect "$1: specs written, the arm line once" "0 1" "$rc $(grep -cxF "$3" "$f")"
  what=${2:+that line swapped}; what=${what:-no line replaced}
  expect "$1: obs-S-k3 with exactly $what, every other line kept" "" \
    "$(sed 1,4d "$f" | grep -vxF "$3" | diff "$TMP/sw-S" -)"; }
swapped pos-arm '   ((portfolio_config ((max_position_pct_long 0.14))))' '   ((portfolio_config ((max_position_pct_long 0.10))))'
swapped leaf-arm "" '   ((stage3_force_exit_config ((hysteresis_weeks 1))))'
expect "pos-arm logs its OVERRIDE; leaf-arm logs none" "1 0" \
  "$(grep -c 'OVERRIDE portfolio_config.max_position_pct_long: 0.14 -> 0.10' "$TMP/sp-pos-arm") $(grep -c OVERRIDE "$TMP/sp-leaf-arm")"
# A form that sets two fields at once cannot replace a single record line: refused.
rc=0; lane specs multi-arm "$TMP/specs-multi" > "$TMP/sp-multi" 2>&1 || rc=$?
expect "a form setting two fields is refused" "1 1" "$rc $(grep -c 'an override form sets more than one field' "$TMP/sp-multi")"
# A screening_config sibling of tiebreak_seed (the queue's cap-40 and fbt-05) is another path: it lands after the tiebreak
# line, which stays, and replaces nothing.
swapped sib-arm "" '   ((screening_config ((max_buy_candidates 40))))'
expect "sib-arm logs no OVERRIDE, keeps tiebreak_seed 3 above its line" "0 1" \
  "$(grep -c OVERRIDE "$TMP/sp-sib-arm") $(grep -c 'screening_config ((tiebreak_seed 3))' "$TMP/specs-sib-arm/obs-sib-arm-k3.sexp")"

# --- the validator config: V12 follows the arm's stop gate. msd-arm sets 0.18 (the queue's msd-18); the validator's own
# default is 0.15, so without the config every stop between them is a false V12 INV violation.
vcf() { cat "$TMP/specs-$1/obs-$1.validator-config.sexp" 2> /dev/null || echo none; }   # the arm's config, or none
rc=0; lane specs msd-arm "$TMP/specs-msd-arm" > "$TMP/sp-msd-arm" 2>&1 || rc=$?; expect "msd-arm: specs written" 0 "$rc"
expect "an arm setting max_stop_distance_pct 0.18 gets a validator config with 0.18" "((gate_max_stop_distance_pct 0.18))" "$(vcf msd-arm)"
expect "it is logged once, as the lane's VALIDATOR CONFIG line" 1 \
  "$(grep -c 'VALIDATOR CONFIG msd-arm gate_max_stop_distance_pct 0.18$' "$TMP/sp-msd-arm")"
expect "the config is the only file the arm adds beside S's" "msd-arm.validator-config.sexp" \
  "$(ls "$TMP/specs-msd-arm" | grep 'validator-config' | sed 's/^obs-//')"
# S and arms that do not set the dial: no config, so the validator keeps its defaults.
expect "S gets no validator config (in any specs dir)" "none" "$(ls "$TMP"/specs*/obs-S.validator-config.sexp 2> /dev/null | head -1 | grep . || echo none)"
for a in dup-arm sib-arm pos-arm leaf-arm; do
  expect "$a (no stop gate) gets no validator config, and says so" "none 1" \
    "$(vcf $a) $(grep -c "VALIDATOR CONFIG $a default (no -config)$" "$TMP/sp-$a")"; done
rc=0; lane specs stale-arm "$TMP/specs-stale-arm" > "$TMP/sp-stale-arm" 2>&1 || rc=$?
expect "stale-arm (a list field) gets no validator config" "0 none" "$rc $(vcf stale-arm)"

# --- read: the real path on finished cells (S is in OUT from D; the parent's S is in trading-results from B)
cell "$TMP/run" U "$TMP/out/runs/$C2/up-arm" up-arm; cell "$TMP/run" S "$TMP/out/runs/$C2/dead-arm" dead-arm
# up-arm ran with a validator config (a stop-gate arm): its copy in the cell dir is public, with the cell
echo "((gate_max_stop_distance_pct 0.13))" > "$TMP/out/runs/$C2/up-arm/obs-up-arm-k0-s0-validator-config.sexp"
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
  "runs/$C2/up-arm/obs-up-arm-k0-s0-summary.sexp" "runs/$C2/up-arm/obs-up-arm-k0-s0.v6diff-S.log" \
  "runs/$C2/up-arm/obs-up-arm-k0-s0-validator-config.sexp"; do
  expect "public has $f" yes "$([ -f "$PUB/$f" ] && echo yes || echo no)"; done
for f in "runs/$C2/up-arm/obs-up-arm-k0-s0-trades.csv" "runs/$C2/S/obs-S-k0-s0-equity_curve.csv" "reads/up-arm@$C2/D.tsv" \
  "drift/$C2-vs-$C1/D.tsv" "runs/$C2/up-arm/obs-up-arm-k0-s0.ok" "runs/$C2/up-arm/obs-up-arm-k0-s0-summary.sexp" \
  "runs/$C2/up-arm/obs-up-arm-k0-s0-validator-config.sexp"; do
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


# --- the gates on their failing side (no docker: v6_pair keeps a V6 log that already exists)
rows() { if [ -f "$1" ]; then awk 'NR > 1' "$1" | wc -l | tr -d ' '; else echo 0; fi; }      # data rows of a table
nev() { if [ -f "$1" ]; then awk -F'\t' -v k="$2" -v l="${3:-}" '$3 == k && (l == "" || $4 == l)' "$1" | wc -l | tr -d ' '; else echo 0; fi; }
# A live arm with one failing V6 log is invalid; so is a would-be-dead one, since V6 runs before liveness. Neither reads.
cell "$TMP/run" U "$TMP/out/runs/$C2/v6-arm" v6-arm; v6ok "$TMP/out/runs/$C2/v6-arm" v6-arm S
echo exit=1 >> "$TMP/out/runs/$C2/v6-arm/obs-v6-arm-k2-s0.v6diff-S.log"
cell "$TMP/run" S "$TMP/out/runs/$C2/v6dead-arm" v6dead-arm; v6ok "$TMP/out/runs/$C2/v6dead-arm" v6dead-arm S
echo exit=1 >> "$TMP/out/runs/$C2/v6dead-arm/obs-v6dead-arm-k0-s0.v6diff-S.log"
for a in v6-arm v6dead-arm; do rc=0; lane read "$a" > "$TMP/V" 2>&1 || rc=$?
  expect "$a: a failing V6 log stops the read" "1 1" "$rc $(grep -c "V6 FAILED $a: k[02]; no read" "$TMP/V")"
  expect "$a: invalid@HEAD, one invalid event, no row, no read dir" "invalid@$C2 1 0 no" \
    "$(awk -F'\t' -v a="$a" '$1 == a { print $4 }' "$TMP/out/state/queue.tsv") $(nev "$TMP/out/state/events.tsv" invalid "$a") $(rows "$S1") $([ -d "$TMP/out/reads/$a@$C2" ] && echo yes || echo no)"; done
# An arm that differs from S on one seed only is live.
cell "$TMP/run" S "$TMP/out/runs/$C2/one-arm" one-arm
for f in "$TMP/run/k4/obs-U-k4-s0"-*; do cp "$f" "$TMP/out/runs/$C2/one-arm/obs-one-arm-k4-s0-${f##*/obs-U-k4-s0-}"; done
v6ok "$TMP/out/runs/$C2/one-arm" one-arm S
rc=0; lane read one-arm > "$TMP/O" 2>&1 || rc=$?; expect "read one-arm" 0 "$rc"
expect "one differing seed is live" 1 "$(grep -c 'LIVE one-arm: trades.csv differs from S on 1 of 5 seeds' "$TMP/O")"
expect "the one-seed arm is read and done@HEAD" "one-arm done@$C2" \
  "$(awk -F'\t' 'NR > 1 { print $2 }' "$S1") $(awk -F'\t' '$1 == "one-arm" { print $4 }' "$TMP/out/state/queue.tsv")"
# The parent's S identical to HEAD's: the tripwire matches, with no baseline-drift event, and the drift read is a
# drift-none event with no row.
cell "$TMP/run" S "$TMP/out2/runs/$C2/S" S; v6ok "$TMP/out2/runs/$C2/S" S "$C1"
cell "$TMP/run" S "$TMP/tr2/$EXP/runs/$C1/S" S
rc=0; (OUTX=$TMP/out2; TRX=$TMP/tr2; lane read drift) > "$TMP/M" 2>&1 || rc=$?; expect "read drift, parent identical" 0 "$rc"
expect "the tripwire matches the parent's S" 1 "$(grep -c "TRIPWIRE MATCH S k0 trades.csv md5 [0-9a-f]* (S@$C1 in trading-results)" "$TMP/M")"
expect "no baseline-drift event, one drift-none event, no drift row" "0 1 0" \
  "$(nev "$TMP/out2/state/events.tsv" baseline-drift) $(nev "$TMP/out2/state/events.tsv" drift-none) $(rows "$TMP/out2/state/drift.tsv")"
# A failing drift V6 log: a drift-invalid event and no drift row (S at HEAD still differs from the parent's, fixture H).
echo exit=1 >> "$TMP/out/runs/$C2/S/obs-S-k1-s0.v6diff-$C1.log"
rc=0; lane read drift > "$TMP/DI" 2>&1 || rc=$?
expect "a failing drift V6 log stops the drift read" "1 1" "$rc $(grep -c "DRIFT V6 FAILED S@$C2 vs S@$C1: k1; no read" "$TMP/DI")"
expect "one drift-invalid event, no drift row" "1 0" "$(nev "$TMP/out/state/events.tsv" drift-invalid) $(rows "$TMP/out/state/drift.tsv")"
# A drift pair obs_read.sh refuses (the parent's k2 started from other cash): one drift-read-failed event, no drift row.
cell "$TMP/run" S "$TMP/out3/runs/$C2/S" S; v6ok "$TMP/out3/runs/$C2/S" S "$C1"
cell "$TMP/run" H "$TMP/tr3/$EXP/runs/$C1/S" S; f=$TMP/tr3/$EXP/runs/$C1/S/obs-S-k2-s0-summary.sexp
sed 's/(initial_cash 1000000.00)/(initial_cash 1000001.00)/' "$f" > "$TMP/x" && cp "$TMP/x" "$f"
rc=0; (OUTX=$TMP/out3; TRX=$TMP/tr3; lane read drift) > "$TMP/RF" 2>&1 || rc=$?
expect "a refused drift read: one drift-read-failed event, no drift row" "1 1 0" \
  "$rc $(nev "$TMP/out3/state/events.tsv" drift-read-failed) $(rows "$TMP/out3/state/drift.tsv")"
expect "the drift-read-failed event carries obs_read's exit 2 (unequal cash)" 1 \
  "$(awk -F'\t' '$3 == "drift-read-failed"' "$TMP/out3/state/events.tsv" | grep -c '(exit 2;')"

# --- years
printf '%s\n' date,open,high,low,close,adjusted_close,volume 1999-12-31,1,1,1,100,1,1 2000-06-30,1,1,1,120,1,1 \
  2000-12-29,1,1,1,95,1,1 2001-12-31,1,1,1,95,1,1 2002-12-31,1,1,1,94,1,1 2025-12-31,1,1,1,96,1,1 \
  2026-06-26,1,1,1,97,1,1 2026-06-29,1,1,1,80,1,1 > "$TMP/spy.csv"
expect "years: fall bear, tie bull, no prior year unlabelled, cut at the run end" "2000 bear,2001 bull,2002 bear,2026 bull" \
  "$(lane years "$TMP/spy.csv" | grep -v '^#' | tr '\t\n' ' ,' | sed 's/,$//')"
sed '1s/close/last/' "$TMP/spy.csv" > "$TMP/spy2.csv"; rc=0; lane years "$TMP/spy2.csv" > /dev/null 2>&1 || rc=$?
expect "years: a file without a close column is refused" 1 "$rc"
rc=0; (OUTX=$TMP/nope; lane years "$TMP/spy.csv") > /dev/null 2>&1 || rc=$?
expect "years writes nothing under OUT" "0 no" "$rc $([ -e "$TMP/nope" ] && echo yes || echo no)"

# --- the real queue: every pending arm passes the lane's spec checks. A refusal would end a cloud session at its launch,
# after the stage pull. The fixture queue is back in place afterwards.
cp "$ROOT/$EXP/queue.tsv" "$R/$EXP/queue.tsv"
for a in $(awk -F'\t' '$0 !~ /^#/ && $1 != "label" && $4 == "pending" { print $1 }' "$ROOT/$EXP/queue.tsv"); do
  rc=0; lane specs "$a" "$TMP/specs-q-$a" > "$TMP/sp-q-$a" 2>&1 || rc=$?
  expect "queue.tsv: pending arm $a passes the spec checks" "0 1" "$rc $(grep -c 'SPEC CHECKS OK' "$TMP/sp-q-$a")"; done
cp "$LFIX/queue.tsv" "$R/$EXP/queue.tsv"

# --- the lock: each step that writes OUT refuses to run beside another holder, and a dockerd the docker preflight starts
# does not keep lane.lock once the lane has exited (it would refuse every relaunch).
if command -v flock > /dev/null 2>&1; then
  exec 8> "$TMP/out/lane.lock"; flock -n 8 || bad "the check could not take lane.lock"
  for c in run read stage docker collect publish; do rc=0; lane "$c" > "$TMP/L" 2>&1 || rc=$?
    expect "$c refuses a held lock" "1 1" "$rc $(grep -c "another lane.sh holds" "$TMP/L")"; done
  exec 8>&-
  # Stubs: docker info fails until the stub dockerd has started; dockerd then sleeps on, as the real daemon runs on.
  mkdir -p "$TMP/bin"
  printf '#!/bin/sh\n[ "$1" = info ] || exit 0\n[ -f "%s" ] || { echo "Cannot connect to the Docker daemon" >&2; exit 1; }\n' "$TMP/dockerd.up" > "$TMP/bin/docker"
  printf '#!/bin/sh\necho $$ > "%s"; touch "%s"; exec sleep 30\n' "$TMP/dockerd.pid" "$TMP/dockerd.up" > "$TMP/bin/dockerd"
  printf '#!/bin/sh\nexec "$@"\n' > "$TMP/bin/setsid"
  printf '#!/bin/sh\n[ "$1" = -n ] && shift\nexec "$@"\n' > "$TMP/bin/sudo"
  chmod +x "$TMP/bin/docker" "$TMP/bin/dockerd" "$TMP/bin/setsid" "$TMP/bin/sudo"
  rc=0; (PATH=$TMP/bin:$PATH; lane docker) > "$TMP/L" 2>&1 || rc=$?
  expect "docker: the preflight starts the stub dockerd" "0 1" "$rc $(grep -c "DOCKER dockerd started" "$TMP/L")"
  expect "the stub dockerd is still running" yes "$(kill -0 "$(cat "$TMP/dockerd.pid")" 2> /dev/null && echo yes || echo no)"
  rc=0; flock -n "$TMP/out/lane.lock" true || rc=$?
  expect "the running dockerd does not hold lane.lock" 0 "$rc"
  kill "$(cat "$TMP/dockerd.pid")" 2> /dev/null || :
else echo "SKIP: observatory_lane_check: no flock; the lock cases need it"; fi

[ "$fails" -eq 0 ] || die "observatory_lane_check: $fails check(s) failed"
echo "OK: observatory_lane_check: all checks passed"
