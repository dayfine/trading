#!/bin/sh
# lane.sh -- the axis observatory lane (dev/plans/axis-observatory-2026-11-14.md §2.1, §2.2, §4). A Claude cloud session
# takes the first pending arm of queue.tsv, runs it as K=5 seeds paired with the baseline S (the record config,
# ../record-kseed-2026-10-27/specs/rk-kK.sexp) on one build, checks the pair, reads it with obs_read.sh and publishes the
# split: mark-free files to the observatory/lane-results branch of dayfine/trading, price-bearing ones to
# dayfine/trading-results. README.md beside this file, §Lane, has the rules; the pattern is
# ../gate-funnel-2026-11-15/chain.sh (dev/rules/sweep-hygiene.md §"Chains that publish").
#
# Subcommands. LANE_SHA, the one main SHA the launch brief names, must be set for run, drift, stage and publish.
#   sh lane.sh run [--dry-run]    lock -> guards -> stage -> SPY years -> docker -> build -> specs -> S k0-k4 and the
#                                 arm's k0-k4 (each cell reused when this HEAD's copy is finished in OUT or in
#                                 trading-results; the rest run PAR at a time after a 3-month preflight) -> tripwire ->
#                                 V6 -> liveness -> obs_read.sh -> drift read -> collect -> publish. No pending arm: drift.
#   sh lane.sh drift [--dry-run]  the same without an arm: S at HEAD, then the baseline-drift read (S at HEAD against S at
#                                 the last HEAD whose S is in trading-results, i.e. A = the new S) into drift.tsv
#   sh lane.sh read [LABEL]       re-run the checks and reads on finished cells (no guards; a missing V6 log needs docker)
#   sh lane.sh stage | docker | collect | publish     one step alone, under the lock (docker: the daemon preflight)
#   sh lane.sh specs LABEL DIR    write and check obs-S-kK and obs-LABEL-kK for the queue's LABEL (no guards)
#   sh lane.sh years CSV          print the SPY bull/bear labels of a bar file (no guards)
# --dry-run prints the arm, the cell plan with each cell's reuse decision, the batches, the checks and the publish lists.
# It skips the guards, the container and the network, and writes only under $OUT/dry.
#
# Resume: a relaunch reuses every finished cell (its .ok marker), re-runs the rest, replaces its own surface row
# (obs_read.sh keys a row by arm and commit) and commits only what changed. The lock is an flock on a descriptor.
# Cells: a 26y top-3000 cell peaked at 5.7-5.9 GB RSS and ran 7,161-8,058 s on the cloud (#3595, stale-e-cap README), so
# CELL_GB=6 and PAR = (MemTotal - MEM_RESERVE_GB) / CELL_GB: 2 on the 15 GB VM. CELL_TIMEOUT 20,000 s is 2.5 x the slowest
# cell, for two cells sharing the host. R2 credentials (R2_*) come from the environment and are never printed.
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
DRY=0; [ "${1:-}" = --dry-run ] && { DRY=1; shift; }
REPO=${REPO:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
EXP=dev/experiments/observatory
REC=dev/experiments/record-kseed-2026-10-27/specs
OUT=${OUT:-$REPO/.sweep-output/observatory-lane}
TR=${TR:-$REPO/../trading-results}                    # the session's checkout of dayfine/trading-results
QUEUE=$REPO/$EXP/queue.tsv
PUB_BRANCH=observatory/lane-results
STATE_REF=${STATE_REF:-origin/$PUB_BRANCH}            # where surface, drift, events and queue statuses accumulate
IMG=${IMG:-ghcr.io/dayfine/trading-ci:latest}
RUNNER=${RUNNER:-run}                                 # run: docker run $IMG, checkout at /w. exec: docker exec $CTR
CTR=${CTR:-trading-1-dev}
if [ "$RUNNER" = exec ]; then CROOT=${CROOT:?RUNNER=exec needs CROOT, the checkout path inside $CTR}; else CROOT=/w; fi
BARS_NAME=${BARS_NAME:-data-20261102}; WH_NAME=v12wk-9236; CA_NAME=corpact-2026-10-27   # the record's stage (#3535)
WH=${WH:-$OUT/warehouse/snap_top3000_pit_v12wk}; CA=$OUT/warehouse/corpact; BARS=$OUT/bars; TD=${TD:-$OUT/td-full}
EXPECT_WH=9236; EXPECT_DIV=11880; NSYM=9200; MMAP_HANDLES=12000
RUN_START=2000-01-01; RUN_END=2026-06-26; SEEDS="0 1 2 3 4"; NSEEDS=5
TRIP_MD5=0928cfe40333560429f5a6e57c9c18de             # #3602 pbb-S-k0 = #3595 pb-S-k0 trades.csv: the record's S k0
CELL_TIMEOUT=${CELL_TIMEOUT:-20000}
CELL_GB=${CELL_GB:-6}; MEM_RESERVE_GB=${MEM_RESERVE_GB:-3}
DISK_MIN_GB=${DISK_MIN_GB:-8}; DISK_STAGE_GB=${DISK_STAGE_GB:-12}
NEED="20824663d 8ee1ed797"                            # #3510 (upper-case shards), #3547 (relocatable warehouse)
KINDS="actual.sexp trades.csv splits.csv params.sexp summary.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp"
NEED_KINDS="actual.sexp trades.csv equity_curve.csv open_positions.csv summary.sexp macro_trend.sexp validator.sexp.sexp"

case $CMD in years|'') PURE=1 ;; *) PURE=0 ;; esac            # years and the usage line write nothing
[ "$PURE" = 1 ] || { mkdir -p "$OUT" && OUT=$(cd "$OUT" && pwd); }   # absolute: the reads link cells by path
HEAD9=$(git -C "$REPO" rev-parse --short=9 HEAD 2> /dev/null)
[ "$PURE" = 1 ] || [ -n "$HEAD9" ] || { echo "lane: $REPO is not a git checkout" >&2; exit 2; }
HD=$OUT/runs/$HEAD9; THD=$TR/$EXP/runs/$HEAD9            # this HEAD's cells, in OUT and in trading-results
if [ "$DRY" = 1 ]; then WORK=$OUT/dry/work; STATE=$OUT/dry/state; SPECS=$OUT/dry/specs; LOG=$OUT/dry/lane.log
else WORK=$OUT/work; STATE=$OUT/state; SPECS=$OUT/specs/$HEAD9; LOG=$OUT/lane.log; fi
[ "$PURE" = 1 ] || mkdir -p "$WORK" "$STATE" "$OUT/tmp"
export TMPDIR=$OUT/tmp                                # r2_bars.sh stages downloads in $TMPDIR; keep them off /tmp
LABEL=; OVR=; LEDGER=; PREV=; TORUN=

log() { if [ "$DRY" = 1 ]; then echo "$*"; else echo "[$(date -u '+%m-%d %H:%M:%S')Z] $*" | tee -a "$LOG"; fi; }
die() { log "ABORT: $*"; exit 1; }
cpath() { echo "$1" | sed "s#^$REPO#$CROOT#"; }       # host path -> container path
hpath() { echo "$1" | sed "s#^$CROOT#$REPO#"; }       # container path -> host path
dk() {
  if [ "$RUNNER" = exec ]; then docker exec -w "$CROOT/trading" "$CTR" bash -c "eval \$(opam env) 2>/dev/null && $1"
  else docker run --rm --user 0 -e HOME=/home/opam -v "$REPO:/w" -w /w/trading "$IMG" bash -c "eval \$(opam env) 2>/dev/null && $1"; fi
}
disk_ok() { g=$(df -BG --output=avail "$REPO" 2>/dev/null | tail -1 | tr -dc 0-9)
  [ -n "$g" ] || { log "disk free unknown (no GNU df)"; return 0; }; log "disk free ${g}G"; [ "$g" -ge "${1:-$DISK_MIN_GB}" ]; }
md5_of() { { md5sum "$1" 2>/dev/null || md5 -q "$1" 2>/dev/null; } | cut -c1-32; }
mem_gb() { echo "${LANE_MEM_GB:-$(awk '/^MemTotal/ { printf "%d", $2 / 1048576 }' /proc/meminfo 2>/dev/null)}"; }
par_n() { m=$(mem_gb); p=$(( (${m:-0} - MEM_RESERVE_GB) / CELL_GB )); [ "$p" -ge 1 ] || p=1; echo "${PAR:-$p}"; }
G() { gd=$1; shift   # git in a checkout, with a fallback identity for a session that has none
  if git -C "$gd" config user.email > /dev/null; then git -C "$gd" "$@"
  else git -c user.name=observatory-lane -c user.email=noreply@anthropic.com -C "$gd" "$@"; fi; }

# README §Lane, Files. public = mark-free: the branch, and trading-results with the rest. private = trading-results only.
classify() {
  case $1 in
    *-trade_audit.sexp|*-candidates.sexp) echo skip ;;
    *-actual.sexp|*-summary.sexp|*-params.sexp|*-macro_trend.sexp|*.rss|*.validator.log|*.v6diff-*.log) echo public ;;
    *) echo private ;;   # trades, equity curve, open positions, splits, liquidations, validator reports, cell log, .ok
  esac
}

# --------------------------------------------------------------------------------------------------- queue and state
# One line per head, kind and label in events.tsv (a relaunch does not repeat it).
event() {
  [ -s "$STATE/events.tsv" ] || printf 'date\thead\tkind\tlabel\tdetail\n' > "$STATE/events.tsv"
  awk -F'\t' -v h="$HEAD9" -v k="$1" -v l="$2" '$2 == h && $3 == k && $4 == l { f = 1 } END { exit !f }' "$STATE/events.tsv" \
    || printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%d)" "$HEAD9" "$1" "$2" "$3" >> "$STATE/events.tsv"
}
# The state: surface, drift and events from the lane-results branch when it has them (else HEAD's), and the queue as
# HEAD has it with each arm's status taken from the branch, so an arm finished in an earlier session is not re-run
# before that branch merges. $STATE/.base is the branch commit read, where publish starts.
state_init() {
  [ -f "$QUEUE" ] || die "no queue file $QUEUE"
  [ "$DRY" = 1 ] || git -C "$REPO" fetch -q origin "+refs/heads/$PUB_BRANCH:refs/remotes/origin/$PUB_BRANCH" 2> /dev/null
  ref=$(git -C "$REPO" rev-parse -q --verify "$STATE_REF^{commit}" 2> /dev/null) || ref=
  for f in surface.tsv drift.tsv events.tsv spy_years.tsv; do rm -f "$STATE/$f"
    [ -n "$ref" ] && git -C "$REPO" show "$ref:$EXP/$f" > "$STATE/$f" 2> /dev/null && continue
    if [ -f "$REPO/$EXP/$f" ]; then cp "$REPO/$EXP/$f" "$STATE/$f"; else rm -f "$STATE/$f"; fi; done
  { [ -n "$ref" ] && git -C "$REPO" show "$ref:$EXP/queue.tsv" 2> /dev/null; } > "$WORK/queue.ref"
  awk -F'\t' -v OFS='\t' 'FILENAME == ARGV[1] { if ($0 !~ /^#/ && $1 != "label" && NF >= 4) st[$1] = $4; next }
    $0 !~ /^#/ && $1 != "label" && NF >= 4 && ($1 in st) { $4 = st[$1] } { print }' "$WORK/queue.ref" "$QUEUE" > "$STATE/queue.tsv"
  echo "${ref:-$(git -C "$REPO" rev-parse HEAD)}" > "$STATE/.base"
  log "STATE from ${ref:+$STATE_REF }${ref:-HEAD (no $PUB_BRANCH yet)}"
}
queue_set() { # $1 label, $2 status
  awk -F'\t' -v OFS='\t' -v l="$1" -v s="$2" '$0 !~ /^#/ && $1 == l { $4 = s } { print }' "$STATE/queue.tsv" > "$STATE/queue.tmp" \
    && mv "$STATE/queue.tmp" "$STATE/queue.tsv"; log "QUEUE $1 -> $2"
}
queue_field() { # $1 label, $2 column -> that column of the label's row
  awk -F'\t' -v l="$1" -v c="$2" '$0 !~ /^#/ && $1 == l { print $c; exit }' "$STATE/queue.tsv"
}
set_arm() { # $1 label: LABEL, OVR and LEDGER from the queue view
  LABEL=$1; OVR=$(queue_field "$1" 2); LEDGER=$(queue_field "$1" 3)
  case $LABEL in S|drift|*[!a-z0-9.-]*) die "queue label '$LABEL': [a-z0-9.-] only, and not S or drift" ;; esac
  [ -n "$OVR" ] || die "queue arm '$LABEL' has no row or no overrides in queue.tsv"
}
select_arm() { # run mode: the first pending arm; none pending -> the drift mode
  [ "$MODE" = run ] || return 0
  l=$(awk -F'\t' '$0 !~ /^#/ && $1 != "label" && $4 == "pending" { print $1; exit }' "$STATE/queue.tsv")
  if [ -z "$l" ]; then log "QUEUE no pending arm: running the drift mode"; MODE=drift; return 0; fi
  set_arm "$l"; log "ARM $LABEL: $OVR (ledger: $LEDGER)"
}

# --------------------------------------------------------------------------------------------------------------- specs
# obs-$1-kK is rk-kK with the arm's overrides added after the tiebreak_seed line (../stale-e-cap-k5-*/make_specs.sh).
# An override of a field the record already sets replaces it: the record's line for the same field path (the chain of
# single-field records down to the value, scalar or not) is dropped, so the arm's value is the only one in the spec.
# Each replacement is listed in $3/obs-$1.replaced as "path<TAB>record value<TAB>arm value<TAB>record line".
write_specs() { # $1 S or a label, $2 overrides ("" for S), $3 dir
  mkdir -p "$3"; : > "$3/obs-$1.replaced"
  for ks in $SEEDS; do
    { echo ";; observatory lane obs-$1-k$ks: ../record-kseed-2026-10-27/specs/rk-k$ks.sexp below this header${2:+, plus $2}."
      echo ";; Staging scenario, NOT a golden. Written by dev/experiments/observatory/lane.sh."
      OVRX=$2 awk -v name="obs-$1-k$ks" -v desc="observatory $1 = record config${2:+ + queue overrides}, Seeded tie order seed $ks, 26y, pit-v12" \
        -v rep="$3/obs-$1.replaced" -v first="$([ "$ks" = 0 ] && echo 1)" '
        function balanced(s,   i, d, c) { d = 0
          for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); if (c == "(") d++; else if (c == ")" && --d < 0) return 0 }
          return d == 0 }
        function opath(s,   f, r, p) {   # one override form -> "path<TAB>value", descending single-field records
          gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/[ \t]+/, " ", s)
          while (match(s, /^\(\([a-z_][a-z_0-9]* /) && substr(s, length(s) - 1) == "))") {
            f = substr(s, 3, RLENGTH - 3); r = substr(s, RLENGTH + 1, length(s) - RLENGTH - 2)
            if (!balanced(r)) break
            p = p (p == "" ? "" : ".") f; s = r }
          return p "\t" s }
        BEGIN { o = ENVIRON["OVRX"]; d = 0; f = ""   # the overrides, split into top-level forms: ap[path] = value
          for (i = 1; i <= length(o); i++) { c = substr(o, i, 1); if (c == "(") d++; if (d > 0) f = f c
            if (c == ")" && --d == 0) { split(opath(f), t, "\t"); if (t[1] != "") ap[t[1]] = t[2]; f = "" } } }
        /^;;/ { next }
        /^\(\(name "/ { print "((name \"" name "\")"; next }
        /^ \(description "/ { print " (description \"" desc "\")"; next }
        /^[ \t]*\(\(/ { split(opath($0), t, "\t")
          if (t[1] in ap) { if (first) { l = $0; gsub(/^[ \t]+|[ \t]+$/, "", l); print t[1] "\t" t[2] "\t" ap[t[1]] "\t" l > rep }; next } }
        { print }
        /\(\(screening_config \(\(tiebreak_seed [0-9]+\)\)\)\)/ && o != "" { print "   " o }' "$REPO/$REC/rk-k$ks.sexp"
    } > "$3/obs-$1-k$ks.sexp"
  done
}
norm() { # $1 spec, $2 texts to drop once each, newline-separated: comments, name, description and whitespace removed
  sed -e 's/;;.*$//' -e '/^((name "/d' -e '/^ (description "/d' "$1" | tr -d ' \t\n' |
    DROP=$2 awk '{ n = split(ENVIRON["DROP"], d, "\n")
      for (k = 1; k <= n; k++) if (d[k] != "" && (i = index($0, d[k]))) $0 = substr($0, 1, i - 1) substr($0, i + length(d[k])); print }'
}
spec_checks() { # $1 dir, $2 label ("" = S only), $3 overrides
  o=$(printf '%s' "$3" | tr -d ' \t\n'); rp=$1/obs-$2.replaced
  rf=$([ -z "$2" ] || cut -f4 "$rp" | tr -d ' \t')   # the record lines the arm replaces, whitespace removed
  ! grep -q '^screening_config\.tiebreak_seed	' "$rp" 2> /dev/null || die "an arm may not set tiebreak_seed: the lane sets it per seed"
  for ks in $SEEDS; do s=$1/obs-S-k$ks.sexp; ns=$(norm "$s" "")
    [ "$ns" = "$(norm "$REPO/$REC/rk-k$ks.sexp" "")" ] || die "obs-S-k$ks differs from rk-k$ks below the header"
    case $ns in *"((screening_config((tiebreak_seed$ks))))"*) ;; *) die "obs-S-k$ks lacks tiebreak_seed $ks" ;; esac
    [ -n "$2" ] || continue
    [ "$(norm "$1/obs-$2-k$ks.sexp" "$o")" = "$(norm "$s" "$rf")" ] \
      || die "obs-$2-k$ks differs from obs-S-k$ks by more than the overrides and the record lines they replace"
    [ "$(norm "$1/obs-$2-k$ks.sexp" "")" != "$ns" ] || die "obs-$2-k$ks lacks the overrides"
  done
  [ -z "$2" ] || while IFS=$(printf '\t') read -r p rv av rl; do log "OVERRIDE $p: $rv -> $av"; done < "$rp"
  log "SPEC CHECKS OK: obs-S-kK = rk-kK${2:+; obs-$2-kK = obs-S-kK + $3}"
}

# The single-instance lock on fd 9, for every step that writes OUT. The kernel drops it when the last holder exits, so a
# killed lane leaves no stale lock; a process that must outlive the lane is launched with 9>&- (docker_ok).
lock() {
  if command -v flock > /dev/null; then exec 9> "$OUT/lane.lock"; flock -n 9 || die "another lane.sh holds $OUT/lane.lock"
  else log "no flock on this host: single instance not enforced"; fi
}

# --------------------------------------------------------------------------------------------------------- cell reuse
cell_ok() { # $1 dir, $2 cell tag: finished (its .ok marker and every file the read and V6 need)
  [ -f "$1/$2.ok" ] || return 1
  for kd in $NEED_KINDS; do [ -s "$1/$2-$kd" ] || return 1; done
}
decide() { # $1 arm, $2 seed -> local | trading-results | run
  if cell_ok "$HD/$1" "obs-$1-k$2-s0"; then echo local
  elif cell_ok "$THD/$1" "obs-$1-k$2-s0"; then echo trading-results
  else echo run; fi
}
prev_head() { # the newest ancestor of HEAD, not HEAD, whose S k0-k4 is finished in trading-results ("" if none)
  ph=; pn=-1
  for pd in "$TR/$EXP/runs"/*/S; do [ -d "$pd" ] || continue; h=$(basename "$(dirname "$pd")"); [ "$h" != "$HEAD9" ] || continue
    for ks in $SEEDS; do cell_ok "$pd" "obs-S-k$ks-s0" || continue 2; done
    git -C "$REPO" merge-base --is-ancestor "$h" HEAD 2> /dev/null || continue
    n=$(git -C "$REPO" rev-list --count "$h"); [ "$n" -le "$pn" ] || { ph=$h; pn=$n; }
  done
  echo "$ph"
}
plan() { # each cell's decision; copies trading-results cells into OUT; sets TORUN ("arm:seed", S first)
  TORUN=
  for arm in S $LABEL; do for ks in $SEEDS; do dc=$(decide "$arm" "$ks")
    case $dc in
      local) log "CELL obs-$arm-k$ks-s0 reuse: finished in OUT" ;;
      trading-results) log "CELL obs-$arm-k$ks-s0 reuse: trading-results $EXP/runs/$HEAD9/$arm"
        [ "$DRY" = 1 ] || { mkdir -p "$HD/$arm"; cp "$THD/$arm/obs-$arm-k$ks-s0"[.-]* "$HD/$arm/" || die "copy from $THD/$arm"; } ;;
      run) log "CELL obs-$arm-k$ks-s0 run"; TORUN="$TORUN $arm:$ks" ;;
    esac; done; done
  [ -n "$TORUN" ] || log "CELL every cell reused: nothing to run"
}
batches() { # the cells to run, PAR at a time, in the order run_cells starts them
  n=0; b=1; line=
  for c in $TORUN; do line="$line obs-${c%:*}-k${c##*:}-s0"; n=$((n + 1))
    [ "$n" -lt "$PAR" ] || { log "BATCH $b:$line"; b=$((b + 1)); n=0; line=; }; done
  [ -z "$line" ] || log "BATCH $b:$line"
}
trip_expect() { # the md5 S k0's trades.csv must have when HEAD's trades are unchanged, and its source
  if [ -n "$PREV" ]; then echo "$(md5_of "$TR/$EXP/runs/$PREV/S/obs-S-k0-s0-trades.csv") S@$PREV in trading-results"
  else echo "$TRIP_MD5 the record (#3595 pb-S-k0 = #3602 pbb-S-k0)"; fi
}

# ------------------------------------------------------------------------------------------------- guards and stage
guards() {
  cd "$REPO" || exit 1
  [ "$(git rev-parse --is-shallow-repository)" = true ] && git fetch -q --unshallow origin main
  git fetch -q origin main
  [ -n "${LANE_SHA:-}" ] || die "LANE_SHA unset (the launch brief names the one main SHA this session runs)"
  ls=$(git rev-parse --verify -q "$LANE_SHA^{commit}") || die "LANE_SHA $LANE_SHA is not a commit here"
  [ "$(git rev-parse HEAD)" = "$ls" ] || die "HEAD $(git rev-parse --short HEAD) is not LANE_SHA $LANE_SHA (git checkout $LANE_SHA)"
  git merge-base --is-ancestor "$ls" origin/main || die "LANE_SHA $LANE_SHA is not on origin/main"
  for c in $NEED; do git merge-base --is-ancestor "$c" HEAD || die "HEAD lacks $c"; done
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "checkout dirty"
  # trading-results holds earlier HEADs' S (reuse, drift) and every price-bearing file: a lane that cannot push there
  # would strand its cells in a session that ends, so a failed push check is fatal unless TR_PUSH_OPTIONAL=1.
  [ -d "$TR/.git" ] && git -C "$TR" remote get-url origin 2> /dev/null | grep -q trading-results \
    || die "no dayfine/trading-results checkout at TR=$TR (the launch brief's second source)"
  { git -C "$TR" fetch -q origin main && git -C "$TR" checkout -q main && git -C "$TR" merge -q --ff-only origin/main; } \
    || die "trading-results at $TR does not fast-forward to origin/main"
  if git -C "$TR" push --dry-run -q origin HEAD:refs/heads/observatory-push-check > /dev/null 2>&1; then log "TR push check ok ($TR)"
  elif [ "${TR_PUSH_OPTIONAL:-0}" = 1 ]; then log "TR push check FAILED ($TR); TR_PUSH_OPTIONAL=1: the private publish will need a hand push"
  else die "TR push check FAILED ($TR): no push credential for dayfine/trading-results (TR_PUSH_OPTIONAL=1 overrides)"; fi
  if git push --dry-run -q origin "$ls:refs/heads/observatory-push-check" > /dev/null 2>&1; then log "public push check ok"
  else log "public push check FAILED: the public publish will need a hand push"; fi
  m=$(mem_gb)
  log "HEAD=$HEAD9 image=$IMG $(docker image inspect -f '{{.Id}}' "$IMG" 2> /dev/null | cut -c1-19) mem=${m:-?}G par=$PAR"
  [ "${m:-0}" -ge $((CELL_GB + MEM_RESERVE_GB)) ] || die "MemTotal ${m:-?} GB < CELL_GB $CELL_GB + MEM_RESERVE_GB $MEM_RESERVE_GB"
}
docker_ok() { # sweep-hygiene §"Chains that publish": a cloud session's dockerd may be down at launch
  if [ "$RUNNER" = exec ]; then docker exec "$CTR" true > /dev/null 2>&1 || die "container $CTR not running (RUNNER=exec)"; return 0; fi
  docker info > /dev/null 2>&1 && return 0
  log "DOCKER daemon not answering ($(docker info 2>&1 | tail -1)); starting dockerd"
  # 9>&-: the daemon outlives the lane, and an inherited lock descriptor would hold lane.lock against every relaunch.
  if [ "$(id -u)" = 0 ]; then (setsid nohup dockerd > "$WORK/dockerd.log" 2>&1 9>&- &)
  else (setsid nohup sudo -n dockerd > "$WORK/dockerd.log" 2>&1 9>&- &); fi
  i=0; while [ "$i" -lt 30 ]; do docker info > /dev/null 2>&1 && { log "DOCKER dockerd started"; return 0; }; sleep 2; i=$((i + 1)); done
  die "docker daemon down and dockerd did not start in 60 s: $(tail -3 "$WORK/dockerd.log" 2> /dev/null | tr '\n' ' ')"
}
stage() { # the record's data stage (../stale-e-cap-k5-2026-11-14/chain.sh), plus the archive's SPY bars for the years
  cd "$REPO" || exit 1; R2="sh dev/scripts/r2_bars.sh"
  if [ ! -f "$WH.done" ] || [ ! -f "$CA/.done" ] || [ ! -f "$TD/.done" ]; then
    disk_ok "$DISK_STAGE_GB" || die "disk < ${DISK_STAGE_GB}G before an unfinished stage"; fi
  if [ -f "$WH.done" ]; then $R2 verify-dir --dir "$WH" --name "$WH_NAME" >> "$WORK/r2.log" 2>&1 || die "warehouse verify failed (work/r2.log)"
  else rm -rf "$WH"; mkdir -p "$(dirname "$WH")"
    log "PULL warehouse $WH_NAME"; $R2 pull-dir --dest "$WH" --name "$WH_NAME" >> "$WORK/r2.log" 2>&1 || die "pull-dir $WH_NAME"
    touch "$WH.done"; fi
  n=$(grep -c '(symbol ' "$WH/manifest.sexp"); [ "$n" = "$EXPECT_WH" ] || die "warehouse manifest has $n entries, expected $EXPECT_WH"
  if [ ! -f "$CA/.done" ]; then rm -rf "$CA"
    log "PULL corpact $CA_NAME"; $R2 pull-dir --dest "$CA" --name "$CA_NAME" >> "$WORK/r2.log" 2>&1 || die "pull-dir $CA_NAME"
    touch "$CA/.done"; fi
  if [ ! -f "$TD/.done" ]; then rm -rf "$BARS" "$TD"
    log "PULL bars $BARS_NAME"; $R2 pull --dest "$BARS" --name "$BARS_NAME" >> "$WORK/r2.log" 2>&1 || die "pull $BARS_NAME"
    root=$BARS; [ -d "$BARS/data/A" ] && root=$BARS/data
    [ -d "$root/A" ] || die "bars archive layout not recognised (no A/ shard under $BARS)"
    low=$(find "$root" -mindepth 2 -maxdepth 2 -type d -name '[a-z]' | head -3)
    [ -z "$low" ] || die "lower-case shard dirs in the bar store (e.g. $low): pre-#3510 layout"
    mv "$root" "$TD"; rm -rf "$BARS"
    # The committed test_data overlay below replaces SPY with a 2009+ file; keep the archive's for the years labels.
    mkdir -p "$OUT/spy"; cp "$TD/S/Y/SPY/data.csv" "$OUT/spy/data.csv" 2> /dev/null || log "SPY: the archive has no S/Y/SPY"
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
  for f in share_classes.sexp macro/tbill_3m_dtb3.csv breadth/nyse_advn.csv; do [ -s "$TD/$f" ] || die "TD lacks $f"; done
  log "STAGE OK: warehouse $n entries, TD $nd dividends.csv"
}
# SPY bull/bear labels (README §Lane, "SPY years"): year Y is bull when the last SPY close in Y (on or before RUN_END)
# is at or above the last close in Y-1, else bear. A year whose prior year is not in the file is not labelled.
spy_years() { # $1 bar file (date,open,high,low,close,...) -> stdout
  awk -F, -v s="${RUN_START%%-*}" -v end="$RUN_END" '
    NR == 1 { if ($5 != "close") { print "lane: column 5 of " FILENAME " is not close" > "/dev/stderr"; bad = 1; exit 1 }; next }
    $1 <= end { y = substr($1, 1, 4) + 0; c[y] = $5 + 0; if (!lo) lo = y; hi = y }
    END { if (bad) exit 1
      print "# SPY bull/bear years for obs_read.sh -y, written by lane.sh years (README.md §Lane, \"SPY years\"). Rule: year Y"
      print "# is bull when the last SPY close in Y (on or before " end ") is at or above the last close in Y-1, else bear."
      print "# Labels only: no price leaves the bar store."
      for (y = (lo + 1 > s ? lo + 1 : s); y <= hi; y++) { p = y - 1; if ((y in c) && (p in c)) print y "\t" (c[y] >= c[p] ? "bull" : "bear") } }' "$1"
}
years_step() { # $STATE/spy_years.tsv from the archive's SPY (else TD's); without either the committed copy stays
  src=$OUT/spy/data.csv; [ -s "$src" ] || src=$TD/S/Y/SPY/data.csv
  [ -s "$src" ] || { log "SPY YEARS: no SPY bar file in OUT or TD; using the committed spy_years.tsv"; return 0; }
  spy_years "$src" > "$WORK/spy_years.tsv" || die "SPY years from $src failed"
  grep -v '^#' "$WORK/spy_years.tsv" > "$WORK/spy.new"; grep -v '^#' "$REPO/$EXP/spy_years.tsv" > "$WORK/spy.committed" 2> /dev/null
  d=$(diff "$WORK/spy.committed" "$WORK/spy.new" | grep '^[<>]' | tr '\t\n' '  ')
  cp "$WORK/spy_years.tsv" "$STATE/spy_years.tsv"
  log "SPY YEARS from $src: $(grep -c 'bull$' "$STATE/spy_years.tsv") bull, $(grep -c 'bear$' "$STATE/spy_years.tsv") bear${d:+; differs from the committed labels: $d}"
}
build() {
  log "BUILD"
  dk "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe > $(cpath "$WORK")/build.log 2>&1" \
    || die "BUILD failed: $(tail -5 "$WORK/build.log" 2> /dev/null | tr '\n' ' ')"
  log "BUILD_DONE"
}

# ---------------------------------------------------------------------------------------------------------------- cells
runner() { # $1 spec dir, $2 log, $3 extra (time and timeout prefix): one scenario_runner call on the record's stage
  dk "TRADING_DATA_DIR=$(cpath "$TD") TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES $3 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $(cpath "$1") --fixtures-root $CROOT/trading/test_data/backtest_scenarios --snapshot-dir $(cpath "$WH") --no-emit-all-eligible --progress-every 26 --parallel 1 > $(cpath "$2") 2>&1; echo exit=\$? >> $(cpath "$2")"
}
out_of() { hpath "$(grep 'Output root' "$1" | tail -1 | sed 's/.*: //')"; }   # $1 runner log -> the output root
rm_root() { case $1 in */dev/backtest/scenarios-*) rm -rf "$1" ;; esac; }   # never anything but a runner's own root
# A 3-month run of the arm's k0 (S's in the drift mode): the spec parses at this build, the overrides reach params.sexp
# and the cache line is the record's. Skipped once its PREFLIGHT_OK is logged for this HEAD.
preflight() {
  pf=obs-${LABEL:-S}-k0; pd=$WORK/preflight-$pf
  grep -q "PREFLIGHT_OK $HEAD9 $pf " "$LOG" 2> /dev/null && { log "SKIP preflight $pf (done)"; return 0; }
  rm -rf "$pd"; mkdir -p "$pd"
  sed "s/(end_date $RUN_END)/(end_date 2000-03-31)/" "$SPECS/$pf.sexp" > "$pd/$pf.sexp"
  grep -q "(end_date 2000-03-31)" "$pd/$pf.sexp" || die "preflight $pf: end_date not rewritten"
  log "PREFLIGHT $pf (to 2000-03-31)"; runner "$pd" "$pd.log" "timeout 3600"
  po=$(out_of "$pd.log")
  [ -s "$po/$pf/actual.sexp" ] || die "preflight $pf wrote no actual.sexp: $(tail -3 "$pd.log" | tr '\n' ' ')"
  case $(tr -d ' \t\n' < "$po/$pf/params.sexp") in *"$(printf '%s' "$OVR" | tr -d ' \t\n')"*) ;;
    *) die "preflight $pf: params.sexp lacks the overrides $OVR" ;; esac
  cache=$(grep -h 'Panel_runner: snapshot cache hits' "$pd.log" | tail -1)
  ns=$(echo "$cache" | sed -n 's/.* n_symbols=\([0-9]*\) .*/\1/p'); na=$(echo "$cache" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
  [ "$ns" = "$NSYM" ] && [ "$na" = 1 ] || die "preflight $pf: n_symbols=$ns n_symbols_absent=$na (expected $NSYM and 1)"
  rm_root "$po"; log "PREFLIGHT_OK $HEAD9 $pf (n_symbols=$ns absent=$na)"
}
# One 26y cell, run in the background by run_cells: its files land in $HD/<arm>/ and its .ok marker is written last.
# A failed cell keeps only its .log and .rss, so the next launch re-runs it.
run_cell() { # $1 arm, $2 seed
  tag=obs-$1-k$2-s0; name=obs-$1-k$2; d=$WORK/cell-$tag; dest=$HD/$1
  rm -rf "$d"; mkdir -p "$d" "$dest"; rm -f "$dest/$tag"-* "$dest/$tag".*; cp "$SPECS/$name.sexp" "$d/" || return 1
  log "RUN $tag"; t0=$(date +%s)
  runner "$d" "$dest/$tag.log" "/usr/bin/time -f 'peak_rss_kb=%M' -o $(cpath "$dest")/$tag.rss timeout $CELL_TIMEOUT"
  root=$(out_of "$dest/$tag.log"); ex=$(tail -1 "$dest/$tag.log"); rss=$(tail -1 "$dest/$tag.rss" 2> /dev/null)
  for f in $KINDS; do cp "$root/$name/$f" "$dest/$tag-$f" 2> /dev/null; done
  if [ "$ex" != exit=0 ] || [ ! -s "$dest/$tag-actual.sexp" ] || [ ! -s "$dest/$tag-trades.csv" ]; then
    rm -f "$dest/$tag"-*; log "CELL FAILED $tag: $ex ${rss:-no rss} (wall $(( $(date +%s) - t0 ))s)"; return 1; fi
  dk "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir $(cpath "$root/$name") -data-dir $(cpath "$TD") -share-classes $CROOT/trading/test_data/share_classes.sexp -out $(cpath "$dest")/$tag-validator.sexp > $(cpath "$dest")/$tag.validator.log 2>&1; echo exit=\$? >> $(cpath "$dest")/$tag.validator.log"
  rm_root "$root"
  [ -s "$dest/$tag-validator.sexp.sexp" ] || { log "CELL FAILED $tag: no validator report (see $tag.validator.log)"; return 1; }
  touch "$dest/$tag.ok"
  m=$(grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|max_drawdown_pct [0-9.eE+-]+' "$dest/$tag-actual.sexp" | tr '\n' ' ')
  log "RESULT $tag => $m$rss (wall $(( $(date +%s) - t0 ))s)"
}
run_cells() { # TORUN, PAR at a time; every cell must finish. A cell keeps the lock descriptor on purpose: if lane.sh is
  # killed, a relaunch is refused until the cells still running finish, instead of starting them again into the same files.
  n=0; for c in $TORUN; do run_cell "${c%:*}" "${c##*:}" & n=$((n + 1)); [ "$n" -lt "$PAR" ] || { wait; n=0; disk_ok || die "disk < ${DISK_MIN_GB}G"; }; done
  wait
  for c in $TORUN; do cell_ok "$HD/${c%:*}" "obs-${c%:*}-k${c##*:}-s0" \
    || die "CELL FAILED obs-${c%:*}-k${c##*:}-s0 (runs/$HEAD9/${c%:*}/*.log); a relaunch re-runs only the unfinished cells"; done
}

# --------------------------------------------------------------------------------------------------- validity and reads
tripwire() { # S k0's trades.csv against the last published HEAD's (else the record's): a change is a baseline-drift event
  te=$(trip_expect); want=${te%% *}; src=${te#* }; got=$(md5_of "$HD/S/obs-S-k0-s0-trades.csv")
  if [ "$got" = "$want" ]; then log "TRIPWIRE MATCH S k0 trades.csv md5 $got ($src)"
  else log "BASELINE-DRIFT S k0 trades.csv md5 $got at $HEAD9, expected $want ($src)"; event baseline-drift S "S k0 trades md5 $got, expected $want ($src)"; fi
}
v6_pair() { # $1 base cell prefix, $2 arm cell prefix, $3 log: V6 of the two validator reports, kept once written
  [ -s "$3" ] || dk "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$(cpath "$1")-validator.sexp.sexp -report arm=$(cpath "$2")-validator.sexp.sexp > $(cpath "$3") 2>&1; echo exit=\$? >> $(cpath "$3")"
  [ "$(tail -1 "$3" 2> /dev/null)" = exit=0 ]
}
link_cells() { # $1 cell dir, $2 its arm, $3 read dir, $4 the arm's name in the read, $5 V6 log suffix to carry ("" = none)
  for ks in $SEEDS; do mkdir -p "$3/k$ks"; sp=obs-$2-k$ks-s0
    for f in "$1/$sp"-*; do [ -f "$f" ] && ln -sf "$f" "$3/k$ks/obs-$4-k$ks-s0-${f##*/"$sp"-}"; done
    [ -z "$5" ] || ln -sf "$1/$sp.v6diff-$5.log" "$3/k$ks/obs-$4-k$ks-s0.v6diff-S.log"; done
}
obs_run() { # $1 read dir, $2 arm name, $3 row label, $4 overlay, $5 surface, $6 private out dir
  rm -rf "$6"; mkdir -p "$6"; yf=$STATE/spy_years.tsv; [ -s "$yf" ] || yf=
  rc=0; sh "$REPO/$EXP/obs_read.sh" -r "$1" -p obs -a "$2" -l "$3" -v "$4" -c "$HEAD9" -O "$6" -t "$5" ${yf:+-y "$yf"} \
    > "$WORK/obs_read.log" 2>&1 || rc=$?
  cp "$WORK/obs_read.log" "$6/obs_read.log"   # private: a refusal can quote a level
  if [ "$rc" -eq 0 ]; then log "READ $3: $(tail -1 "$WORK/obs_read.log" | sed 's/ -> .*: / -> /; s/; detail in .*//')"
  else log "READ FAILED $3: obs_read.sh exit $rc (1 input or V6, 2 unpaired or unequal cash, 3 a leaked level); see its log in trading-results"; fi
  return "$rc"
}
read_arm() { # V6, liveness, then the read; sets the arm's queue status
  ad=$HD/$LABEL; live=0; v6bad=
  for ks in $SEEDS; do
    v6_pair "$HD/S/obs-S-k$ks-s0" "$ad/obs-$LABEL-k$ks-s0" "$ad/obs-$LABEL-k$ks-s0.v6diff-S.log" || v6bad="$v6bad k$ks"
    cmp -s "$HD/S/obs-S-k$ks-s0-trades.csv" "$ad/obs-$LABEL-k$ks-s0-trades.csv" || live=$((live + 1)); done
  if [ -n "$v6bad" ]; then log "V6 FAILED $LABEL:$v6bad; no read"; event invalid "$LABEL" "V6 failed on$v6bad"
    queue_set "$LABEL" "invalid@$HEAD9"; return 1; fi
  log "V6 OK $LABEL (k0-k4 against S)"
  if [ "$live" -eq 0 ]; then log "DEAD $LABEL: trades.csv identical to S on every seed; no read"
    event dead "$LABEL" "$OVR: trades identical to S on k0-k4"; queue_set "$LABEL" "dead@$HEAD9"; return 0; fi
  log "LIVE $LABEL: trades.csv differs from S on $live of $NSEEDS seeds"
  rd=$WORK/read-$LABEL; rm -rf "$rd"; link_cells "$HD/S" S "$rd" S ""; link_cells "$ad" "$LABEL" "$rd" "$LABEL" S
  if obs_run "$rd" "$LABEL" "$LABEL" "$OVR" "$STATE/surface.tsv" "$OUT/reads/$LABEL@$HEAD9"; then queue_set "$LABEL" "done@$HEAD9"
  else event invalid "$LABEL" "obs_read.sh refused the pair"; queue_set "$LABEL" "invalid@$HEAD9"; return 1; fi
}
drift_read() { # S at HEAD (arm "drift") against S at PREV, into drift.tsv
  [ -n "$PREV" ] || { log "DRIFT none: no earlier HEAD has a finished S in trading-results"; return 0; }
  pv=$OUT/runs/$PREV/S; mkdir -p "$pv"; same=0; bad=
  for ks in $SEEDS; do cell_ok "$pv" "obs-S-k$ks-s0" || cp "$TR/$EXP/runs/$PREV/S/obs-S-k$ks-s0"[.-]* "$pv/"
    v6_pair "$pv/obs-S-k$ks-s0" "$HD/S/obs-S-k$ks-s0" "$HD/S/obs-S-k$ks-s0.v6diff-$PREV.log" || bad="$bad k$ks"
    cmp -s "$pv/obs-S-k$ks-s0-trades.csv" "$HD/S/obs-S-k$ks-s0-trades.csv" && same=$((same + 1)); done
  if [ -n "$bad" ]; then log "DRIFT V6 FAILED S@$HEAD9 vs S@$PREV:$bad; no read"; event drift-invalid S "V6 failed on$bad vs $PREV"; return 1; fi
  if [ "$same" -eq "$NSEEDS" ]; then log "DRIFT NONE: S@$HEAD9 trades.csv identical to S@$PREV on every seed"; event drift-none S "vs $PREV"; return 0; fi
  rd=$WORK/read-drift; rm -rf "$rd"; link_cells "$pv" S "$rd" S ""; link_cells "$HD/S" S "$rd" drift "$PREV"
  obs_run "$rd" drift "drift@$PREV" "S@$PREV -> S@$HEAD9" "$STATE/drift.tsv" "$OUT/drift/$HEAD9-vs-$PREV" \
    || { event drift-read-failed S "obs_read.sh refused S@$HEAD9 vs S@$PREV (exit $rc; its log is in trading-results)"; return 1; }
}

# ------------------------------------------------------------------------------------------------- collect and publish
collect() { # results/public and results/private, each laid out as the repo path (README §Lane, Files)
  pub=$OUT/results/public; prv=$OUT/results/private; rm -rf "$pub" "$prv"; mkdir -p "$pub/$EXP/lane-logs" "$prv/$EXP"
  for f in "$OUT"/runs/*/*/*; do [ -f "$f" ] || continue; rel=${f#"$OUT"/}; c=$(classify "${f##*/}")
    [ "$c" = skip ] && continue; mkdir -p "$prv/$EXP/${rel%/*}"; cp "$f" "$prv/$EXP/$rel"
    [ "$c" = private ] || { mkdir -p "$pub/$EXP/${rel%/*}"; cp "$f" "$pub/$EXP/$rel"; }; done
  for d in reads drift; do [ ! -d "$OUT/$d" ] || { mkdir -p "$prv/$EXP/$d"; cp -R "$OUT/$d"/. "$prv/$EXP/$d/"; }; done
  for f in surface.tsv drift.tsv events.tsv queue.tsv spy_years.tsv; do [ ! -f "$STATE/$f" ] || cp "$STATE/$f" "$pub/$EXP/"; done
  cp "$LOG" "$pub/$EXP/lane-logs/$HEAD9-$(cat "$OUT/current" 2> /dev/null || echo drift).log"
  log "COLLECT public $(find "$pub" -type f | wc -l | tr -d ' ') files, private $(find "$prv" -type f | wc -l | tr -d ' ') files"
}
# Public: a worktree at the branch commit the state was read from, this session's files committed on it, then HEAD and
# the branch's newer tip merged in (surface, drift and events merge as a union, .gitattributes), so a concurrent lane's
# rows survive. Private: trading-results main, rebased on a race.
publish() {
  [ -d "$OUT/results/public" ] || { log "PUBLISH FAILED: nothing collected (sh lane.sh collect)"; return 1; }
  pt=$OUT/pubtree; hs=$(git -C "$REPO" rev-parse HEAD); what="${LABEL:-drift} at $HEAD9"
  [ -d "$pt" ] || git -C "$REPO" worktree add -q -B "$PUB_BRANCH" "$pt" "$(cat "$STATE/.base")" || { log "PUBLISH FAILED: worktree add"; return 1; }
  cp -R "$OUT/results/public"/. "$pt/"; git -C "$pt" add "$EXP"
  git -C "$pt" diff --cached --quiet || G "$pt" commit -q -m "observatory lane: $what, mark-free files" || { log "PUBLISH FAILED: public commit"; return 1; }
  G "$pt" merge -q --no-edit -X ours "$hs" > /dev/null || { git -C "$pt" merge --abort; log "PUBLISH FAILED: merging HEAD into $PUB_BRANCH"; return 1; }
  i=0; until git -C "$pt" push -q -u origin "$PUB_BRANCH" 2> /dev/null; do i=$((i + 1))
    [ "$i" -le 3 ] || { log "PUBLISH FAILED: push $PUB_BRANCH"; return 1; }
    git -C "$pt" fetch -q origin "+refs/heads/$PUB_BRANCH:refs/remotes/origin/$PUB_BRANCH" && G "$pt" merge -q --no-edit -X ours "origin/$PUB_BRANCH" > /dev/null \
      || { git -C "$pt" merge --abort 2> /dev/null; log "PUBLISH FAILED: merging origin/$PUB_BRANCH"; return 1; }; done
  log "PUBLISH public: $PUB_BRANCH at $(git -C "$pt" rev-parse --short=9 HEAD)"
  { git -C "$TR" fetch -q origin main && git -C "$TR" checkout -q main && git -C "$TR" merge -q --ff-only origin/main; } \
    || { log "PUBLISH FAILED: trading-results not fast-forwardable to origin/main"; return 1; }
  cp -R "$OUT/results/private"/. "$TR/"; git -C "$TR" add "$EXP"
  git -C "$TR" diff --cached --quiet || G "$TR" commit -q -m "observatory lane: $what, price-bearing cells and reads" || { log "PUBLISH FAILED: private commit"; return 1; }
  i=0; until git -C "$TR" push -q origin HEAD:main 2> /dev/null; do i=$((i + 1))
    [ "$i" -le 3 ] && G "$TR" pull -q --rebase origin main || { log "PUBLISH FAILED: push trading-results main"; return 1; }; done
  log "PUBLISH private: dayfine/trading-results main at $(git -C "$TR" rev-parse --short=9 HEAD)"; log "PUBLISH DONE"
}

# ------------------------------------------------------------------------------------------------------------- the lane
publish_lists() { # dry run: where each file of this plan goes, by the classify that collect uses
  log "PUBLIC (branch $PUB_BRANCH, and trading-results): $EXP/{surface.tsv,drift.tsv,events.tsv,queue.tsv,spy_years.tsv}, $EXP/lane-logs/$HEAD9-${LABEL:-drift}.log"
  for arm in S $LABEL; do for f in $KINDS validator.sexp.md validator.sexp.sexp; do pf=obs-$arm-k*-s0-$f
      log "$(classify "$pf" | tr a-z A-Z) $EXP/runs/$HEAD9/$arm/$pf"; done
    for f in .log .rss .validator.log .ok ${LABEL:+.v6diff-S.log}; do [ "$arm$f" != S.v6diff-S.log ] || continue
      log "$(classify "obs-$arm-k*-s0$f" | tr a-z A-Z) $EXP/runs/$HEAD9/$arm/obs-$arm-k*-s0$f"; done; done
  [ -z "$PREV" ] || log "PUBLIC $EXP/runs/$HEAD9/S/obs-S-k*-s0.v6diff-$PREV.log"
  [ -z "$LABEL" ] || log "PRIVATE $EXP/reads/$LABEL@$HEAD9/ (D.tsv, steps-kK, years-kK, firstdiff-kK, seeds, row, obs_read.log)"
  [ -z "$PREV" ] || log "PRIVATE $EXP/drift/$HEAD9-vs-$PREV/ (the same files for the drift read)"
  log "SKIP trade_audit.sexp and candidates.sexp (never published)"
}
lane() { # $1 run | drift
  MODE=$1; PAR=$(par_n)
  if [ "$DRY" = 1 ]; then log "DRY-RUN lane $MODE at HEAD $HEAD9: no guards, container or network; writes only under $OUT/dry"
  else
    lock
    rm -rf "$OUT/tmp"/r2_bars.* "$WH".partial.*   # a restart mid-pull leaves these; safe to drop under the lock
    log "observatory lane $MODE; LANE_SHA=${LANE_SHA:-unset} PAR=$PAR CELL_TIMEOUT=${CELL_TIMEOUT}s"
    guards; disk_ok || die "disk < ${DISK_MIN_GB}G"
  fi
  state_init; select_arm; [ "$DRY" = 1 ] || echo "${LABEL:-drift}" > "$OUT/current"
  if [ "$DRY" = 1 ]; then log "SPY YEARS from the archive's S/Y/SPY/data.csv after the stage (rule: README §Lane)"
  else stage; years_step; docker_ok; build; fi
  write_specs S "" "$SPECS"; [ -z "$LABEL" ] || write_specs "$LABEL" "$OVR" "$SPECS"; spec_checks "$SPECS" "$LABEL" "$OVR"
  PREV=$(prev_head)
  log "PARALLEL $PAR cells at a time (MemTotal $(mem_gb) GB, reserve $MEM_RESERVE_GB GB, $CELL_GB GB per cell)"
  plan; batches
  if [ "$DRY" = 1 ]; then
    [ -z "$TORUN" ] || log "PREFLIGHT obs-${LABEL:-S}-k0 to 2000-03-31 before the cells"
    log "TRIPWIRE S k0 trades.csv md5 must be $(trip_expect); otherwise a baseline-drift event"
    [ -z "$LABEL" ] || log "VALIDITY $LABEL: V6 on every seed against S; live when trades.csv differs from S on a seed, else DEAD and no read; obs_read.sh checks equal starting cash and paired curves"
    [ -z "$LABEL" ] || log "READ obs_read.sh -a $LABEL -c $HEAD9 -> surface.tsv"
    if [ -n "$PREV" ]; then log "DRIFT S@$HEAD9 against S@$PREV -> drift.tsv"; else log "DRIFT none: no earlier HEAD has a finished S in trading-results"; fi
    publish_lists; return 0
  fi
  [ -z "$TORUN" ] || { preflight; run_cells; }
  checks_and_reads; r=$?
  collect; publish; p=$?
  if [ "$p" -ne 0 ]; then log "LANE PUBLISH ABORT: the results are in $OUT/results; re-run: sh $EXP/lane.sh publish"
  elif [ "$r" -ne 0 ]; then log "LANE DONE WITH A REFUSED CHECK OR READ (lane.log above, events.tsv): ${LABEL:-drift} at $HEAD9"
  else log "LANE DONE: ${LABEL:-drift} at $HEAD9"; fi
}
checks_and_reads() { r=0; tripwire; [ -z "$LABEL" ] || read_arm || r=1; drift_read || r=1; return "$r"; }
cmd_read() { # $1 label (default: the session's arm) -- the checks and reads again on finished cells, then collect
  l=${1:-$(cat "$OUT/current" 2> /dev/null)}; MODE=run
  lock
  state_init; [ -z "$l" ] || [ "$l" = drift ] || set_arm "$l"; echo "${LABEL:-drift}" > "$OUT/current"
  for ks in $SEEDS; do for arm in S $LABEL; do cell_ok "$HD/$arm" "obs-$arm-k$ks-s0" || die "obs-$arm-k$ks-s0 is not finished in $HD"; done; done
  years_step; PREV=$(prev_head); checks_and_reads; r=$?; collect; return "$r"
}

case "$CMD" in
  run|drift) lane "$CMD" ;;
  read) cmd_read "${1:-}" ;;
  stage) lock; guards; stage ;;
  docker) lock; docker_ok; log "DOCKER ok" ;;
  collect) lock; collect ;;
  publish) lock; guards; [ "$(cat "$OUT/current" 2> /dev/null)" = drift ] || LABEL=$(cat "$OUT/current" 2> /dev/null); publish ;;
  specs) [ $# -eq 2 ] || { echo "usage: sh $0 specs LABEL DIR" >&2; exit 2; }
    cp "$QUEUE" "$STATE/queue.tsv"; set_arm "$1"; write_specs S "" "$2"; write_specs "$1" "$OVR" "$2"; spec_checks "$2" "$1" "$OVR" ;;
  years) spy_years "${1:?usage: sh $0 years SPY_CSV}" ;;
  *) echo "usage: sh $0 {run [--dry-run] | drift [--dry-run] | read [LABEL] | stage | docker | collect | publish | specs LABEL DIR | years CSV}" >&2; exit 2 ;;
esac
