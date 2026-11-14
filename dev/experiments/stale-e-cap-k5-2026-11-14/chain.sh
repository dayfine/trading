#!/bin/sh
# stale-e-cap-k5-2026-11-14: one tie seed's three arms (S, then C, then G) in a Claude cloud session. Five sessions, one
# per seed, run side by side. Pre-registration and read rule: README.md beside this file. NOT run by its author.
#
#   sec-S-kK  the record config (rk-kK), Seeded tie order seed K       2000-01-01 -> 2026-06-26, top-3000 PIT v12
#   sec-C-kK  sec-S-kK + ((entry_cap_local_range_weeks 4)) (#3604)     same window and schedule; V6 against sec-S-kK
#   sec-G-kK  sec-C-kK + ((entry_cap_stop_gate_on_uncapped true))      same window and schedule; V6 against sec-S-kK
#             (#3609): the cap, with every stop-gate decision read at the uncapped trigger (README §Arm G)
#
# Runs on the session host (POSIX sh) from the session's checkout at SC_SHA, the one main SHA all five sessions use
# (named in the launch brief). Every OCaml step runs in ghcr.io/dayfine/trading-ci:latest with the checkout mounted at
# /w. Everything is written under .sweep-output/stale-e-cap-k5/ (gitignored, inside the mount, so a session-worker
# restart that wipes /tmp loses nothing); TMPDIR points there too.
#
# Subcommands (SC_SHA must be set for run and stage):
#   sh chain.sh run K          lock -> guards -> stage (R2 pulls, data dir) -> build -> spec checks -> preflight of the
#                              three arms -> sec-S-kK -> TRIPWIRE (hard gate) -> sec-C-kK (V6 vs S) -> sec-G-kK (V6 vs
#                              S), each arm's extracts right after its cell -> G check (information) -> collect into
#                              results/kK -> read/split.sh on it (information only)
#   sh chain.sh stage          only the R2 pulls and the data dir (resumable; each step leaves a .done marker)
#   sh chain.sh collect K DEST copy seed K's artifacts and extracts into DEST
#   sh chain.sh check K        only the spec checks of seed K (no guards, no container)
#   sh chain.sh tickets AUDIT  print the per-ticket extract of one trade_audit.sexp (README §Files; no guards)
#   sh chain.sh entries AUDIT  print the placed/skipped list extract of one trade_audit.sexp (no guards)
#   sh chain.sh preflight K    local smoke only: spec checks + the preflight of the three arms against an existing WH
#                              and TD (RUNNER=exec), with no guards and no stage. The run path never uses it.
# Resume, per arm (from chain.log, as ../price-band-binding-2026-11-13/chain.sh does): re-running `run K` skips each
# arm's preflight whose PREFLIGHT_OK line is logged (all of them once any cell's RESULT is), each cell whose RESULT line
# is logged, the tripwire once its MATCH or WAIVED line is, and each arm's extracts once its EXTRACT line is and both
# files are non-empty. A restart therefore costs only the cell in flight. RESULT is logged only for a cell that exited
# 0 and wrote actual.sexp and trades.csv; a failed cell logs CELL FAILED and aborts, so a relaunch re-runs it rather
# than skipping it. The lock is an flock on a file descriptor, so a killed run leaves no stale lock behind.
#
# Derived from ../price-band-confirm-2026-11-13/chain.sh (#3598), itself from #3588's: the same guards, SHA pin and
# resume, stage (warehouse v12wk-9236, corpact-2026-10-27, bars data-20261102 for the validator's data dir, the
# warehouse .done marker outside the verified dir per #3599/#3601), build, run_cell, V6 diff, keyed trades diff,
# entries extract, collect, RUNNER=exec, and the leftover cleanup under the lock. Changes:
#   1. Three cells per seed (S, C, G). Spec checks: sec-S-kK = rk-kK = #3595's pb-S-kK below the header; sec-C-kK =
#      sec-S-kK plus the cap; sec-G-kK = sec-C-kK plus the gate flag; the fill-model and scope settings the cap depends
#      on are asserted in S, and G is asserted free of the two settings `make` refuses with the flag (README §Design).
#   2. TRIPWIRE: sec-S-kK's trades.csv must be byte-identical to #3595's pb-S-kK-s0-trades.csv (md5 below). Both flags
#      are inert when off (README §Tripwire), so a mismatch means the build, image or data stage moved; the chain stops
#      before arm C. TRIPWIRE_WAIVE="<reason>" continues past a mismatch and logs the reason (the read reports it).
#   3. tickets_extract: one row per placed ticket from trade_audit.sexp (anchor, cap flag, resolution), never prices.
#   4. Preflight: each arm's FIRST three months (2000-01-03 .. 2000-03-31). It checks the overrides in params.sexp
#      (the cap 4 in C and G, 0 in S; the gate flag in G only), the cache line (n_symbols=9200, n_symbols_absent=1),
#      that C and G each cap at least one ticket and S none, and that G caps no ticket on a key S's preflight skipped
#      at the stop gate (the G check, README §Arm G; the local smoke's C had 3 such admissions in this quarter).
#   5. The G check on the full cells, logged per seed (information; the read applies it pooled, README §Arm G).
#   6. Resume per arm (above): per-arm preflight and extract markers, and CELL FAILED in place of a RESULT line for a
#      failed cell, which the derived chains logged as RESULT and then skipped on a relaunch.
#
# Cell guard: CELL_TIMEOUT=16200 s = 2 x the slowest #3595 cloud cell of this spec (pb-S-k0, 8,058 s; the ten cells ran
# 7,161-8,058 s). Three cells now share a session, so 3 x (24,200 s) would let one hung cell take the whole session;
# 2 x still clears the observed spread with room. Peak RSS was 5.71-5.77 GB (maxrss 5.91 GB) and the arms run one at a
# time (the one-year smoke: S and C 3.76 GB, G 3.61 GB), so MEM_MIN_GB=7 (whole GiB). The session should take about
# 7 h: stage ~0.2 h, build ~0.02 h, three preflights ~0.3 h, three cells 6.0-6.7 h, extracts and read ~0.1 h.
#
# R2 credentials (R2_*) come from the environment and are never printed (dev/scripts/r2_bars.sh header).
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
REPO=${REPO:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
EXP=dev/experiments/stale-e-cap-k5-2026-11-14
OUT=${OUT:-$REPO/.sweep-output/stale-e-cap-k5}
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
CELL_TIMEOUT=${CELL_TIMEOUT:-16200}
MEM_MIN_GB=${MEM_MIN_GB:-7}                         # MemTotal in whole GiB, truncated; a cell peaks at ~5.9 GB
MMAP_HANDLES=12000                                    # >= manifest size (#2839/#2882)
DISK_MIN_GB=${DISK_MIN_GB:-5}                         # before each cell (a cell's outputs are < 1 GB, #3595 logs)
DISK_STAGE_GB=${DISK_STAGE_GB:-12}                    # before an unfinished stage: 20-22 GB -> 14-16 GB on 11-13
NSYM=9200                                             # pb-S-k0's cache line: n_symbols=9200 n_symbols_absent=1 (MEL)
REC=dev/experiments/record-kseed-2026-10-27           # the record cells rk-k0..rk-k4 the S specs derive from
PB=dev/experiments/price-band-tiebreak-2026-11-13     # #3595: its arm S cells are this experiment's tripwire
OVR='((entry_cap_local_range_weeks4))'                # arm C's one override, whitespace dropped
GOVR='((entry_cap_stop_gate_on_uncappedtrue))'        # arm G's one override on top of C's, whitespace dropped
# #3595's pb-S-kK-s0-trades.csv md5 for K = 0..4 (HEAD=1034b458e, image sha256:3865e48e8a61, same data stage).
TRIP_MD5="0928cfe40333560429f5a6e57c9c18de 9441578a81c6cfe4be68a7ca5aecbb8f 2034e05dd8dd00f10c16d93be4ce2ce2 0f33cdad0d6e28e1829f53f7e3fd3d92 995be28e6ef1c1829f7db0c8ecd79a41"
# Commits the run tree must contain: #3510 (upper-case shards), #3547 (relocatable warehouse), #3604 (the cap),
# #3609 (the gate flag).
NEED="20824663d 8ee1ed797 d521e5254 9664e1705"

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
md5_of() { { md5sum "$1" 2>/dev/null || md5 -q "$1" 2>/dev/null; } | cut -c1-32; }
logged() { grep -q "$1" "$LOG" 2>/dev/null; }
FIX() { echo "$CROOT/trading/test_data/backtest_scenarios"; }

# ------------------------------------------------------------------------------------------------------------ guards
guards() {
  cd "$REPO" || exit 1
  [ "$(git rev-parse --is-shallow-repository)" = true ] && git fetch -q --unshallow origin main
  git fetch -q origin main
  [ -n "${SC_SHA:-}" ] || die "SC_SHA unset (the launch brief names the one SHA all five sessions run)"
  sc=$(git rev-parse --verify -q "$SC_SHA^{commit}") || die "SC_SHA $SC_SHA is not a commit here"
  [ "$(git rev-parse HEAD)" = "$sc" ] || die "HEAD $(git rev-parse --short HEAD) is not SC_SHA $SC_SHA (git checkout $SC_SHA first)"
  git merge-base --is-ancestor "$sc" origin/main || die "SC_SHA $SC_SHA is not on origin/main"
  prev=$(sed -n 's/.*\] HEAD=\([0-9a-f]*\) .*/\1/p' "$LOG" | head -1)
  [ -z "$prev" ] || [ "$prev" = "$(git rev-parse --short=9 HEAD)" ] || die "HEAD differs from this chain.log's earlier HEAD=$prev"
  for c in $NEED; do git merge-base --is-ancestor "$c" HEAD || die "HEAD lacks $c"; done
  # The flag-off identities the tripwire relies on (README §Tripwire): cap off returns the replace anchor unchanged, and
  # the gate flag yields no gate entry unless it and the cap are both armed.
  grep -q '| None, _, _ -> range_top' trading/analysis/weinstein/stock_analysis/lib/stale_entry_cap.ml \
    || die "Stale_entry_cap.ticket_anchor's cap-off arm changed (README §Tripwire)"
  f=trading/trading/weinstein/strategy/lib/entry_cap_stop_gate.ml
  grep -q 'config.entry_cap_stop_gate_on_uncapped$' "$f" && grep -q '&& config.entry_cap_local_range_weeks > 0' "$f" \
    && grep -q 'if _armed config && entry_is_trigger then _uncapped_trigger ~config cand' "$f" \
    || die "Entry_cap_stop_gate.gate_entry's off path changed (README §Tripwire)"
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "checkout dirty"
  [ -f "$EXP/README.md" ] || die "$EXP not in the checkout (pre-registration not merged?)"
  mem=$(awk '/^MemTotal/ { printf "%d", $2 / 1048576 }' /proc/meminfo 2>/dev/null)
  log "HEAD=$(git rev-parse --short=9 HEAD) image=$IMG $(docker image inspect -f '{{.Id}}' "$IMG" 2>/dev/null | cut -c1-19) mem=${mem:-?}G"
  [ "${mem:-0}" -ge "$MEM_MIN_GB" ] || die "MemTotal ${mem:-?} GB < MEM_MIN_GB $MEM_MIN_GB (a cell peaks at ~5.9 GB, README §Cost)"
}

# ------------------------------------------------------------------------------------------------------------- stage
stage() {
  cd "$REPO" || exit 1; R2="sh dev/scripts/r2_bars.sh"
  if [ ! -f "$WH.done" ] || [ ! -f "$CA/.done" ] || [ ! -f "$TD/.done" ]; then
    disk_ok "$DISK_STAGE_GB" || die "disk < ${DISK_STAGE_GB}G before an unfinished stage"; fi
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
# Normalised content: comments, the name and description lines and all whitespace dropped, one override removed ($2).
norm() { sed -e 's/;;.*$//' -e '/^((name "/d' -e '/^ (description "/d' "$1" | tr -d ' \t\n' | sed "s/$2//"; }
spec_checks() { # $1 seed
  cd "$REPO" || exit 1; S=$EXP/specs; s=$S/sec-S-k$1.sexp; c=$S/sec-C-k$1.sexp; g=$S/sec-G-k$1.sexp
  [ "$(norm "$s" '^$')" = "$(norm "$REC/specs/rk-k$1.sexp" '^$')" ] || die "sec-S-k$1 differs from rk-k$1 below the header"
  [ "$(norm "$s" '^$')" = "$(norm "$PB/specs/pb-S-k$1.sexp" '^$')" ] || die "sec-S-k$1 differs from #3595's pb-S-k$1"
  [ "$(norm "$c" "$OVR")" = "$(norm "$s" '^$')" ] || die "sec-C-k$1 differs from sec-S-k$1 by more than the override"
  [ "$(norm "$c" '^$')" != "$(norm "$s" '^$')" ] || die "sec-C-k$1 lacks the override"
  [ "$(norm "$g" "$GOVR")" = "$(norm "$c" '^$')" ] || die "sec-G-k$1 differs from sec-C-k$1 by more than the gate flag"
  [ "$(norm "$g" '^$')" != "$(norm "$c" '^$')" ] || die "sec-G-k$1 lacks the gate flag"
  ns=$(norm "$s" '^$'); ng=$(norm "$g" '^$')
  # The cap reaches a fill only through these (README §Design): the trigger AT the ticket E, as a StopLimit(E, 1.02 E).
  for need in '((enable_sim_entry_stoplimittrue))' '((sim_entry_trigger_at_suggestedtrue))' '((entry_extension_max_pct2.0))' \
              '((enable_short_sidefalse))' '((screening_config((tiebreak_seed'"$1"'))))'; do
    case "$ns" in *"$need"*) ;; *) die "sec-S-k$1 lacks $need" ;; esac; done
  # Scope: the replace anchor, continuation buys and the frozen E would each change what the cap acts on.
  for bad in entry_anchor_local_range_weeks enable_continuation_buys freeze_entry_at_first_breakout entry_cap_local_range_weeks \
             entry_cap_stop_gate_on_uncapped; do
    case "$ns" in *"$bad"*) die "sec-S-k$1 sets $bad (README §Design: scope)" ;; esac; done
  # Implied by the relations above, asserted on G's own text: Weinstein_strategy.make refuses the gate flag together with
  # the replace anchor or the entry freeze (#3609), which would fail every G cell at its start.
  for bad in entry_anchor_local_range_weeks freeze_entry_at_first_breakout; do
    case "$ng" in *"$bad"*) die "sec-G-k$1 sets $bad (#3609: make refuses the gate flag with it)" ;; esac; done
  log "SPEC CHECKS OK (sec-S-k$1 = rk-k$1 = pb-S-k$1; sec-C-k$1 = sec-S-k$1 + entry_cap_local_range_weeks 4; sec-G-k$1 = sec-C-k$1 + entry_cap_stop_gate_on_uncapped true, no replace anchor or freeze; trigger at E, StopLimit 2 %)"
}

build() {
  log "BUILD"
  dk "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe > $(cpath "$WORK")/build.log 2>&1" \
    || die "build failed (work/build.log)"
  log "BUILD_DONE"
}

# Count of placed long tickets and of those anchored at local_range_top (the cap bound) in one audit.
capped_count() { # $1 tickets.tsv
  awk -F'\t' 'NR > 1 && $4 == "Long" { n++; if ($5 == "Local_range_top") c++ } END { printf "%d of %d", c + 0, n + 0 }' "$1"
}

# The G check's two inputs and its count (README §Arm G). gate_keys: symbol|date of every skip at the stop gate in an
# entries.tsv. gate_admits: capped long tickets of a tickets.tsv on one of those keys (0 for arm G, by construction).
gate_keys() { awk -F'\t' '$4 == "skipped" && ($6 == "No_structural_stop" || $6 == "Stop_too_wide") { print $2 "|" $3 }' "$@" | LC_ALL=C sort -u; }
gate_admits() { # $1 gate keys, $2 tickets.tsv
  awk -F'\t' 'FILENAME == ARGV[1] { g[$1] = 1; next }
    FNR > 1 && $4 == "Long" && $5 == "Local_range_top" && (($2 "|" $3) in g) { n++ } END { print n + 0 }' "$1" "$2"
}

# A three-month run from each arm's own start: the spec parses at this build, the overrides resolve, and the runner
# resolves the record universe. Each arm is skipped once its PREFLIGHT_OK is logged (resume).
preflight() { # $1 seed
  k=$1; pend=2000-03-31
  for name in sec-S-k$k sec-C-k$k sec-G-k$k; do pd=$WORK/preflight-$name
    if logged "PREFLIGHT_OK $name " && [ -s "$pd.tickets.tsv" ] && [ -s "$pd.entries.tsv" ]; then log "SKIP preflight $name (done)"; continue; fi
    rm -rf "$pd" "$pd.log"; mkdir -p "$pd"
    sed "s/(end_date 2026-06-26)/(end_date $pend)/" "$REPO/$EXP/specs/$name.sexp" > "$pd/$name.sexp"
    grep -q "(end_date $pend)" "$pd/$name.sexp" || die "preflight $name: end_date not rewritten"
    log "PREFLIGHT $name (to $pend)"; t0=$(date +%s)
    dk "TRADING_DATA_DIR=$(cpath "$TD") TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$pd") --fixtures-root $(FIX) --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --parallel 1 > $(cpath "$pd").log 2>&1"
    out=$(hpath "$(grep 'Output root' "$pd.log" | tail -1 | sed 's/.*: //')")
    [ -s "$out/$name/actual.sexp" ] || die "preflight $name wrote no actual.sexp (see $pd.log)"
    # params.sexp lists the spec's overrides: the cap at 4 in C and G (0 in S); the gate flag true in G (absent in S, C).
    p=$(tr -s ' \t\n' '   ' < "$out/$name/params.sexp")
    w=$(echo "$p" | grep -o '(entry_cap_local_range_weeks [0-9]*)' | tr -dc 0-9)
    gf=$(echo "$p" | grep -o '(entry_cap_stop_gate_on_uncapped [a-z]*)' | sed 's/.* \([a-z]*\))/\1/')
    case "$name" in *-S-*) [ "${w:-0}" = 0 ] && [ -z "$gf" ] || die "preflight $name params.sexp: cap '${w}', gate flag '${gf}' (expected none)" ;;
                    *-C-*) [ "$w" = 4 ] && [ -z "$gf" ] || die "preflight $name params.sexp: cap '${w}', gate flag '${gf}' (expected 4, none)" ;;
                    *-G-*) [ "$w" = 4 ] && [ "$gf" = true ] || die "preflight $name params.sexp: cap '${w}', gate flag '${gf}' (expected 4, true)" ;; esac
    cache=$(grep -h 'Panel_runner: snapshot cache hits' "$pd.log" | tail -1)
    ns=$(echo "$cache" | sed -n 's/.* n_symbols=\([0-9]*\) .*/\1/p'); na=$(echo "$cache" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
    [ "$ns" = "$NSYM" ] && [ "$na" = 1 ] || die "preflight $name: n_symbols=$ns n_symbols_absent=$na (expected $NSYM and 1)"
    tickets_extract "$out/$name/trade_audit.sexp" > "$pd.tickets.tsv"
    entries_extract "$out/$name/trade_audit.sexp" > "$pd.entries.tsv"
    # Liveness before the 2-hour cells: the local smoke's C capped 9 tickets in this quarter (CHH and ECIL on its first
    # Friday, 2000-01-07) and its G 2 (DIS 01-14, TRW1 03-24), from screens that do not depend on the portfolio; S caps
    # none (README §Smoke).
    nc=$(capped_count "$pd.tickets.tsv" | cut -d' ' -f1)
    case "$name" in *-S-*) [ "$nc" = 0 ] || die "preflight $name capped $nc tickets with the flag off" ;;
                    *) [ "$nc" -ge 1 ] || die "preflight $name capped no ticket (the cap is not reaching the ticket)" ;; esac
    ga=""
    if [ "$name" != "sec-S-k$k" ]; then   # the G check on the quarter, against S's preflight record of its stop gate
      gate_keys "$WORK/preflight-sec-S-k$k.entries.tsv" > "$pd.gatekeys"
      nga=$(gate_admits "$pd.gatekeys" "$pd.tickets.tsv"); ga=", capped on an S gate key $nga"
      case "$name" in *-G-*) [ "$nga" = 0 ] || die "preflight $name capped $nga tickets S skipped at the stop gate (the G check, README §Arm G)" ;; esac
    fi
    log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s, entry_cap_local_range_weeks=${w:-0}, gate flag ${gf:-off}, n_symbols=$ns absent=$na, capped tickets $(capped_count "$pd.tickets.tsv")$ga)"
  done
}

# ------------------------------------------------------------------------------------------------------------- cells
# run_cell TAG SPEC_FILE(host) PAIR(label=validator-host-path or -)
run_cell() {
  tag=$1; spec=$2; pair=$3; d=$WORK/cell-$tag
  if logged "RESULT $tag "; then log "SKIP $tag (done)"; return 0; fi
  disk_ok || die "disk < ${DISK_MIN_GB}G before $tag"
  rm -rf "$d"; mkdir -p "$d"; cp "$spec" "$d/" || die "spec $spec"
  for f in "$ART/$tag"-* "$ART/$tag".*; do [ -f "$f" ] && rm -f "$f"; done   # a lost run's leftovers
  name=$(sed -n 's/^((name "\([^"]*\)").*/\1/p' "$spec")
  td=$(cpath "$TD")
  log "RUN $tag ($name)"; start=$(date +%s)
  dk "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $(cpath "$ART")/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$d") --fixtures-root $(FIX) --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --progress-every 26 --parallel 1 > $(cpath "$ART")/$tag.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.log"
  wall=$(( $(date +%s) - start ))
  out=$(hpath "$(grep 'Output root' "$ART/$tag.log" | tail -1 | sed 's/.*: //')")
  for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do
    cp "$out/$name/$f" "$ART/$tag-$f" 2>/dev/null; done
  ex=$(tail -1 "$ART/$tag.log" 2>/dev/null)
  if [ "$ex" != exit=0 ] || [ ! -s "$ART/$tag-actual.sexp" ] || [ ! -s "$ART/$tag-trades.csv" ]; then
    die "CELL FAILED $tag (${ex:-no exit line}, wall ${wall}s; see art/$tag.log). No RESULT is logged, so a relaunch re-runs it."; fi
  # one arm's actual.sexp only (sweep-hygiene: a metric glob must be scoped to ONE arm)
  m=$(grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' "$out/$name/actual.sexp" 2>/dev/null | tr '\n' ' ')
  dk "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir $(cpath "$out/$name") -data-dir $td -share-classes $CROOT/trading/test_data/share_classes.sexp -out $(cpath "$ART")/$tag-validator.sexp > $(cpath "$ART")/$tag.validator.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.validator.log"
  q=$(grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 |V3 ' "$ART/$tag-validator.sexp.md" 2>/dev/null | tr '\n' ' ')
  v6=""
  if [ "$pair" != - ]; then lab=${pair%%=*}; pv=${pair#*=}
    dk "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$(cpath "$pv") -report arm=$(cpath "$ART")/$tag-validator.sexp.sexp > $(cpath "$ART")/$tag.v6diff-$lab.log 2>&1; echo exit=\$? >> $(cpath "$ART")/$tag.v6diff-$lab.log"
    v6=" vs$lab:$(tail -1 "$ART/$tag.v6diff-$lab.log")"; fi
  guards=$(grep -hE 'Panel_runner: (split_dividend_guard|snapshot cache)' "$ART/$tag.log" | tr '\n' ' ')
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} $(tail -1 "$ART/$tag.rss" 2>/dev/null) $ex ${guards} (wall ${wall}s)"
}

# Arm S must reproduce #3595's arm S of the same seed byte for byte (README §Tripwire). Hard gate unless waived.
tripwire() { # $1 seed, $2 S tag
  want=$(echo "$TRIP_MD5" | cut -d' ' -f$(( $1 + 1 ))); got=$(md5_of "$ART/$2-trades.csv")
  for f in actual.sexp equity_curve.csv; do   # information only: the gate is trades.csv
    cmp -s "$REPO/$PB/results/k$1/pb-S-k$1-s0-$f" "$ART/$2-$f" && log "PARITY $2 vs pb-S-k$1-s0 $f identical" \
      || log "PARITY $2 vs pb-S-k$1-s0 $f differs"; done
  if [ "$got" = "$want" ]; then log "TRIPWIRE MATCH $2 trades.csv md5 $got ($(wc -l < "$ART/$2-trades.csv" | tr -d ' ') lines)"; return 0; fi
  log "TRIPWIRE MISMATCH $2 trades.csv md5 ${got:-missing}, expected $want (#3595 pb-S-k$1-s0)"
  [ -n "${TRIPWIRE_WAIVE:-}" ] || die "tripwire: $2 does not reproduce #3595's arm S; diagnose before arm C (README §Tripwire)"
  log "TRIPWIRE WAIVED for $2: $TRIPWIRE_WAIVE"
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

# The audit as one record per line: whitespace flattened, a newline before every entry record.
audit_records() { tr -s '\n\t ' '   ' < "$1" | awk '{ gsub(/\(\(entry \(/, "\n&"); print }'; }

# Entry decisions of one cell (from #3588/#3598): one row per placed entry and one per distinct skipped alternative
# (date, symbol, reason_skipped). The read's cash-displacement and path classes, and the G check, use it.
entries_extract() { # $1 trade_audit.sexp -> stdout TSV
  printf 'position_id\tsymbol\tdecision_date\tkind\tside\tskip_reason\n'
  audit_records "$1" | awk '
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

# One row per placed ticket (README §Files). No price leaves the session: the stop width is a ratio, the fill against
# the trigger a signed fraction, and the position value, risk and cash figures are simulator dollars. Columns:
#   position_id symbol decision_date side anchor lrt stop_width risk_pct init_value init_risk cancel_reason
#   cancel_age_wk fill_age_wk cash_required cash_available fill_vs_trigger
# anchor = ticket_lifecycle entry_anchor (Local_range_top exactly when the cap bound, with the replace anchor off);
# lrt = 1 when the audit carries local_range_top (the capped level), else 0; "-" marks an absent field.
tickets_extract() { # $1 trade_audit.sexp -> stdout TSV
  printf 'position_id\tsymbol\tdecision_date\tside\tanchor\tlrt\tstop_width\trisk_pct\tinit_value\tinit_risk\tcancel_reason\tcancel_age_wk\tfill_age_wk\tcash_required\tcash_available\tfill_vs_trigger\n'
  audit_records "$1" | awk -v OFS='\t' '
    function num(tag,   v) { if (match($0, "\\(" tag " [-0-9.eE+]+\\)")) { v = substr($0, RSTART + length(tag) + 2, RLENGTH - length(tag) - 3); return v } return "-" }
    function tok(tag,   v) { if (match($0, "\\(" tag " [A-Za-z_]+\\)")) { v = substr($0, RSTART + length(tag) + 2, RLENGTH - length(tag) - 3); return v } return "-" }
    /^\(\(entry \(/ {
      id = ""; sym = ""; d = ""
      if (match($0, /\(position_id [^ )]+\)/)) id = substr($0, RSTART + 13, RLENGTH - 14)
      if (match($0, /\(symbol [^ )]+\)/)) sym = substr($0, RSTART + 8, RLENGTH - 9)
      if (match($0, /\(entry_date [0-9-]+\)/)) d = substr($0, RSTART + 12, RLENGTH - 13)
      se = num("suggested_entry"); st = num("installed_stop")
      sw = (se != "-" && st != "-" && se + 0 > 0) ? sprintf("%.4f", (se + 0 > st + 0 ? se - st : st - se) / se) : "-"   # numeric compare (#3608 smoke: TCR)
      rq = "-\t-"; if (match($0, /\(cash_rejection \(\(required [-0-9.eE+]+\) \(available [-0-9.eE+]+\)/)) {
        split(substr($0, RSTART, RLENGTH), c, /[() ]+/); rq = sprintf("%.2f\t%.2f", c[4], c[6]) }
      fv = num("fill_vs_trigger_pct"); if (fv != "-") fv = sprintf("%.5f", fv)
      rp = num("risk_pct"); if (rp != "-") rp = sprintf("%.4f", rp)
      iv = num("initial_position_value"); if (iv != "-") iv = sprintf("%.2f", iv)
      ir = num("initial_risk_dollars"); if (ir != "-") ir = sprintf("%.2f", ir)
      print id, sym, d, tok("side"), tok("entry_anchor"), (index($0, "(local_range_top ") > 0 ? 1 : 0), sw, rp, iv, ir,
        tok("cancel_reason"), num("ticket_age_weeks_at_cancel"), num("ticket_age_weeks_at_fill"), rq, fv }' |
    LC_ALL=C sort -t "$(printf '\t')" -k3,3 -k1,1
}

arm_reads() { # $1 tag: the two extracts of one finished cell, skipped once logged (resume)
  tag=$1
  if logged "EXTRACT $tag:" && [ -s "$ART/$tag-entries.tsv" ] && [ -s "$ART/$tag-tickets.tsv" ]; then log "SKIP extracts $tag (done)"; return 0; fi
  [ -s "$ART/$tag-trade_audit.sexp" ] || { log "EXTRACT $tag: no trade_audit.sexp"; return 0; }
  entries_extract "$ART/$tag-trade_audit.sexp" > "$ART/$tag-entries.tsv" || die "ENTRIES $tag: extract FAILED"
  tickets_extract "$ART/$tag-trade_audit.sexp" > "$ART/$tag-tickets.tsv" || die "TICKETS $tag: extract FAILED"
  log "EXTRACT $tag: $(awk -F'\t' '$4 == "placed"' "$ART/$tag-entries.tsv" | wc -l | tr -d ' ') placed, $(awk -F'\t' '$4 == "skipped"' "$ART/$tag-entries.tsv" | wc -l | tr -d ' ') skipped; capped tickets $(capped_count "$ART/$tag-tickets.tsv")"
}

cells() { # $1 seed. POSIX sh has no locals: these names must not be reused by the functions called below
  # (disk_ok sets g, run_cell sets tag, d and the rest).
  SP=$REPO/$EXP/specs; cs=sec-S-k$1-s0; cc=sec-C-k$1-s0; cg=sec-G-k$1-s0
  run_cell "$cs" "$SP/sec-S-k$1.sexp" -
  logged "TRIPWIRE MATCH $cs \|TRIPWIRE WAIVED for $cs:" || tripwire "$1" "$cs"
  arm_reads "$cs"
  run_cell "$cc" "$SP/sec-C-k$1.sexp" "S=$ART/$cs-validator.sexp.sexp"
  arm_reads "$cc"
  run_cell "$cg" "$SP/sec-G-k$1.sexp" "S=$ART/$cs-validator.sexp.sexp"
  arm_reads "$cg"
  firstdiff "$cs" "$cc"; firstdiff "$cs" "$cg"
  # The G check on this seed's own S record (information; the read applies it pooled over every S seed, README §Arm G).
  gate_keys "$ART/$cs-entries.tsv" > "$WORK/gatekeys-k$1"
  log "GCHECK k$1: capped tickets on a key sec-S-k$1 skipped at the stop gate: G $(gate_admits "$WORK/gatekeys-k$1" "$ART/$cg-tickets.tsv") (must be 0), C $(gate_admits "$WORK/gatekeys-k$1" "$ART/$cc-tickets.tsv")"
  log "CELLS DONE k$1"
}

collect() { # $1 seed, $2 dest
  k=$1; dest=${2:?usage: chain.sh collect K DEST}; mkdir -p "$dest"
  for f in "$ART"/sec-?-k"$k"-*; do [ -f "$f" ] || continue
    case "$f" in *-trade_audit.sexp) continue ;; esac   # ~0.3 GB; the reads use <tag>-tickets.tsv and -entries.tsv
    cp "$f" "$dest/"; done
  cp "$LOG" "$dest/chain-k$k.log"; cp "$WORK/td-ca-extra.txt" "$dest/" 2>/dev/null
  for pf in "$WORK"/preflight-sec-?-k"$k".log; do [ -f "$pf" ] || continue
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
  log "stale-e-cap-k5 run k$1; SC_SHA=${SC_SHA:-unset} CELL_TIMEOUT=${CELL_TIMEOUT}s"
  guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  stage; build; spec_checks "$1"
  if logged "RESULT sec-[SCG]-k$1-s0 "; then log "SKIP preflight (a cell of k$1 has run)"; else preflight "$1"; fi
  cells "$1"
  collect "$1" "$OUT/results/k$1"
  # Information only, for the session's report: the pre-registered read runs on the host after all five seeds.
  sh "$REPO/$EXP/read/split.sh" "$OUT/results" > "$OUT/results/k$1/split-k$1-insession.txt" 2>&1 \
    && log "READ k$1 (in-session, no open-position marks): $(grep -h '^SEED k'"$1" "$OUT/results/k$1/split-k$1-insession.txt" | tr '\n' ' ')" \
    || log "READ k$1 (in-session) failed; see results/k$1/split-k$1-insession.txt"
  log "STALE-E-CAP k$1 DONE. Next: commit $OUT/results/k$1 into $EXP/results/k$1/ and read per README."
}

cmd_preflight() { # local smoke: $1 seed
  seed_ok "${1:-}" || { echo "usage: sh $0 preflight K" >&2; exit 2; }
  if command -v flock > /dev/null; then   # a macOS host has no flock; the smoke is a manual, foreground run
    exec 9>"$OUT/chain.lock"; flock -n 9 || die "another chain.sh run holds $OUT/chain.lock"; fi
  dk "test -s $(cpath "$WH")/manifest.sexp && test -d $(cpath "$TD")" || die "WH or TD not found (RUNNER=$RUNNER)"
  log "stale-e-cap-k5 preflight k$1 (RUNNER=$RUNNER, smoke only: no guards, no stage)"
  spec_checks "$1"; preflight "$1"
}

case "$CMD" in
  run) cmd_run "${1:-}" ;;
  stage) guards; stage ;;
  preflight) cmd_preflight "$@" ;;
  check) seed_ok "${1:-}" || { echo "usage: sh $0 check K" >&2; exit 2; }; spec_checks "$1" ;;
  tickets) tickets_extract "${1:?usage: sh $0 tickets AUDIT}" ;;
  entries) entries_extract "${1:?usage: sh $0 entries AUDIT}" ;;
  collect) seed_ok "${1:-}" || { echo "usage: sh $0 collect K DEST" >&2; exit 2; }; collect "$1" "${2:-}" ;;
  *) echo "usage: sh $0 {run K|stage|check K|preflight K|tickets AUDIT|entries AUDIT|collect K DEST}" >&2; exit 2 ;;
esac
