#!/bin/sh
# dispatch_disk_guard.sh -- pre-dispatch disk-space guard for agent dispatch.
#
# WHY THIS EXISTS
#   dev/status/harness.md H-AGENT-WORKTREE-DISK-16GB-EACH (measured 2026-09-05,
#   GHA orchestrator run 33962894987): a dispatched agent's worktree costs
#   ~16 GB once it has run `dune build` (three concurrent QC worktrees measured
#   16 GB / 16 GB / 16 GB = 48 GB). Combined with image layers and `_build`
#   growth, that run reached 100% disk and the harness's own task-output
#   filesystem returned ENOSPC, killing a tool call mid-orchestration.
#   `.claude/rules/container-capacity-scheduling.md`'s "cap 3 agents" is
#   stated in terms of memory and cores; it has an undocumented DISK
#   dimension that this script makes mechanical instead of held-by-hand --
#   the orchestrator capped itself at 2 agents instead of 3 on 09-14 and
#   09-15 purely on ad hoc reasoning, which is not a control (the same
#   "discipline held by hand" gap issue #2747 (D3) is still open on).
#
# CONTRACT
#   dispatch_disk_guard.sh <agent-count> [target-path]
#     agent-count   Number of agent worktrees about to be dispatched
#                   concurrently (an integer >= 0). Required.
#     target-path   Path on the filesystem that will hold the new agent
#                   worktree(s). Optional; defaults to ".". The guard reads
#                   free space on whatever filesystem this path resolves to
#                   (df resolves a path to its containing mount), so pass the
#                   directory under which worktrees are actually created
#                   (e.g. the parent of .claude/worktrees/) when it differs
#                   from the caller's cwd.
#
#   Exit 0  -- the dispatch fits: proceed.
#   Exit 1  -- the dispatch does NOT fit (or free space could not be
#              determined): refuse. Caller must not dispatch.
#
#   Either way the script prints the numbers it decided on (agent count,
#   per-agent cost, safety margin, computed floor, measured free space) so a
#   run log records *why*, not just pass/fail.
#
# FAIL DIRECTION -- chosen deliberately, not incidentally
#   The two possible mistakes are NOT symmetric in cost:
#     - false REFUSAL (guard says no, dispatch would actually have fit):
#       costs one dispatch slot for one cycle. Cheap, recoverable.
#     - false PASS (guard says yes, dispatch actually ENOSPCs mid-flight):
#       destroys the in-flight agent's work AND can corrupt the shared task-
#       output filesystem for every other agent in the run (the exact
#       incident this script exists to prevent). Expensive, not always
#       recoverable within the run.
#   Given that asymmetry this script is FAIL-CLOSED end to end:
#     - a missing/non-numeric agent-count argument refuses (does not default
#       to "assume 1" or "assume 0 and pass");
#     - a missing, empty, or malformed `df` reading refuses -- it never
#       falls through to "couldn't check, so allow it" (mirrors the
#       `check_hold` fail-closed default in the merge gate,
#       `.claude/rules/pr-merge-gates.md` Rule 0);
#     - the required-floor computation includes a fixed SAFETY_MARGIN_GB on
#       top of the raw per-agent multiply, to absorb the image-layer +
#       `_build` growth that made the source incident worse than the raw
#       "3 x 16 GB" arithmetic alone -- see the H-AGENT-WORKTREE-DISK-16GB-EACH
#       note above ("combined with image layers and _build growth").
#   The boundary case (free space EXACTLY equal to the computed floor) PASSES
#   -- the floor is defined as "the minimum free space that is acceptable",
#   not "the minimum free space that is still too little". This is the one
#   place the script is not maximally conservative; the SAFETY_MARGIN_GB
#   above is where the conservatism against the asymmetric cost actually
#   lives, not in the comparison operator. dispatch_disk_guard_test.sh pins
#   this exact boundary so a future edit cannot silently flip it either way
#   without a test going red.
#
# TESTING SEAM
#   Real `df` output is never the only path exercised by the test suite (a
#   fixture-driven test that only ran against the live runner's disk would
#   pass vacuously on a roomy runner and stop testing anything -- see
#   dispatch_disk_guard_test.sh's header). Set DISPATCH_DISK_GUARD_DF_TEXT to
#   literal df-style text (as `df -Pk <path>` would print it, header line +
#   one data line) to make the guard parse that text instead of shelling out
#   to `df`. This exercises the real parsing path, not just a bypass of it,
#   so a test using this seam also catches a malformed-df-output regression.
#
#   Set DISPATCH_DISK_GUARD_FLOOR_GB to override the computed floor
#   (agent-count * PER_AGENT_WORKTREE_GB + SAFETY_MARGIN_GB) with an explicit
#   number of GB instead -- lets a caller (or a test) pin an exact floor
#   without needing to reverse-engineer an agent count that produces it, and
#   satisfies the "agent count and/or a free-space floor" input the backlog
#   item (H-AGENT-WORKTREE-DISK-16GB-EACH) asks for.
#
# USAGE
#   sh dev/scripts/dispatch_disk_guard.sh 3
#   sh dev/scripts/dispatch_disk_guard.sh 3 /__w/trading
#   DISPATCH_DISK_GUARD_FLOOR_GB=50 sh dev/scripts/dispatch_disk_guard.sh 0

set -eu

# ---------------------------------------------------------------------------
# Named constants -- both measured/derived, cited, never bare magic numbers
# (trading/devtools/magic_numbers_linter enforces this for OCaml; this script
# follows the same discipline by convention since the linter is OCaml-only).
# ---------------------------------------------------------------------------

# Measured 2026-09-05, GHA orchestrator run 33962894987
# (dev/status/harness.md H-AGENT-WORKTREE-DISK-16GB-EACH): three concurrent
# QC agent worktrees measured 16 GB / 16 GB / 16 GB after each ran
# `dune build`. Treat this as the per-agent cost of any dispatched
# feat-*/qc-*/harness-maintainer worktree, not just QC specifically -- all
# of them do a full OCaml link in their own worktree (issue #2470).
PER_AGENT_WORKTREE_GB=16

# Headroom beyond the raw "agent-count * PER_AGENT_WORKTREE_GB" multiply, to
# absorb image-layer growth and `_build` churn outside the agent worktrees
# themselves -- the source incident's own worktree arithmetic (3 x 16 = 48 GB)
# did not by itself explain reaching 100% disk; something beyond the
# worktrees ate the rest of a ~132 GB budget (145 GB total minus ~13 GB for
# the main checkout). 20 GB is a deliberately conservative round-number
# placeholder for that "something else" pending a second measured incident
# to pin it more precisely -- see dev/status/harness.md
# H-AGENT-WORKTREE-DISK-16GB-EACH follow-up note in this script's PR body.
SAFETY_MARGIN_GB=20

# ---------------------------------------------------------------------------
# Argument parsing -- fail closed on anything that isn't a clean non-negative
# integer agent count.
# ---------------------------------------------------------------------------

AGENT_COUNT="${1:-}"
TARGET_PATH="${2:-.}"

if [ -z "$AGENT_COUNT" ]; then
  echo "REFUSE: dispatch_disk_guard -- missing required <agent-count> argument" >&2
  echo "usage: dispatch_disk_guard.sh <agent-count> [target-path]" >&2
  exit 1
fi

case "$AGENT_COUNT" in
  0 | [1-9] | [1-9][0-9]*) : ;;
  *)
    echo "REFUSE: dispatch_disk_guard -- agent-count '$AGENT_COUNT' is not a non-negative integer" >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Required floor
# ---------------------------------------------------------------------------

if [ -n "${DISPATCH_DISK_GUARD_FLOOR_GB:-}" ]; then
  case "${DISPATCH_DISK_GUARD_FLOOR_GB}" in
    0 | [1-9] | [1-9][0-9]*) : ;;
    *)
      echo "REFUSE: dispatch_disk_guard -- DISPATCH_DISK_GUARD_FLOOR_GB '${DISPATCH_DISK_GUARD_FLOOR_GB}' is not a non-negative integer" >&2
      exit 1
      ;;
  esac
  REQUIRED_GB="$DISPATCH_DISK_GUARD_FLOOR_GB"
else
  REQUIRED_GB=$((AGENT_COUNT * PER_AGENT_WORKTREE_GB + SAFETY_MARGIN_GB))
fi

REQUIRED_KB=$((REQUIRED_GB * 1024 * 1024))

# ---------------------------------------------------------------------------
# Free-space reading -- via the DISPATCH_DISK_GUARD_DF_TEXT seam if set,
# otherwise a live `df -Pk` on TARGET_PATH. Default-closed: any reading that
# does not parse as a clean non-negative integer KB value refuses rather
# than falling through.
# ---------------------------------------------------------------------------

# NOTE: this must distinguish "unset" from "set to the empty string" -- an
# `[ -n "${VAR:-}" ]` test would treat an empty-string injection as "not
# set" and silently fall through to a live `df` call, which defeats the
# empty-output test scenario (a legitimate malformed-reading case) and was
# caught by exactly that scenario while building this script. `${VAR+set}`
# is POSIX and triggers on "is the variable set at all", regardless of
# content.
if [ "${DISPATCH_DISK_GUARD_DF_TEXT+set}" = "set" ]; then
  DF_RAW="$DISPATCH_DISK_GUARD_DF_TEXT"
else
  DF_RAW="$(df -Pk "$TARGET_PATH" 2>/dev/null)" || DF_RAW=""
fi

# POSIX `df -P` output: header line, then one data line with fields
# Filesystem / 1024-blocks / Used / Available / Capacity / Mounted-on.
# Available (KB free) is field 4 of the SECOND line.
FREE_KB="$(printf '%s\n' "$DF_RAW" | awk 'NR==2 {print $4}')"

case "${FREE_KB:-}" in
  '' | *[!0-9]*)
    echo "REFUSE: dispatch_disk_guard -- could not determine free disk space (missing or malformed df reading for '$TARGET_PATH'); default-closed" >&2
    echo "  raw df output was:" >&2
    printf '%s\n' "$DF_RAW" >&2
    exit 1
    ;;
esac

FREE_GB=$((FREE_KB / 1024 / 1024))

echo "dispatch_disk_guard: agent-count=$AGENT_COUNT per-agent=${PER_AGENT_WORKTREE_GB}GB safety-margin=${SAFETY_MARGIN_GB}GB required-floor=${REQUIRED_GB}GB free=${FREE_GB}GB target='$TARGET_PATH'"

if [ "$FREE_KB" -lt "$REQUIRED_KB" ]; then
  echo "REFUSE: dispatch_disk_guard -- ${FREE_GB}GB free is below the ${REQUIRED_GB}GB floor for $AGENT_COUNT agent(s); do not dispatch"
  exit 1
fi

echo "OK: dispatch_disk_guard -- ${FREE_GB}GB free meets the ${REQUIRED_GB}GB floor for $AGENT_COUNT agent(s); dispatch fits"
exit 0
