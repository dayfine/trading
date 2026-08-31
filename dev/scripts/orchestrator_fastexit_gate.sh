#!/bin/sh
# orchestrator_fastexit_gate.sh -- mechanical backstop for A-FASTEXIT-VACUOUS
# (issue #2579).
#
# WHY THIS EXISTS
#   `.claude/agents/lead-orchestrator.md` Step 0.5 has a "Precondition -- the
#   queue must be non-empty" block (added 2026-08-02 to fix A-FASTEXIT-VACUOUS):
#   if the open orchestrator-PR queue is empty, the no-op fast-exit must NOT
#   fire -- an empty queue means a full pass is required, not that the queue is
#   saturated. That block is PROSE inside an agent-instructions file. Run
#   33063628087 (2026-08-27) proved prose does not bind: the orchestrator took
#   the no-op path with an empty PR queue AND with dev/status/ drift since the
#   prior summary -- both of the fast-exit's own gates said "do a full pass" --
#   and nothing caught it. See issue #2579.
#
#   Per `.claude/rules/pr-merge-gates.md` Rule 0's lesson ("anything that must
#   not happen while nobody is watching has to be expressed in the vocabulary
#   automation reads"), this script moves the precondition out of agent
#   judgment and into a mechanical check `.github/workflows/orchestrator.yml`
#   runs independently of the model:
#
#     1. BEFORE the orchestrator agent runs, the workflow calls
#        `open_pr_count` and injects the number into the agent's prompt as a
#        computed fact ("QUEUE_NON_EMPTY=<n>") -- so the agent does not have
#        to compute it itself and cannot silently drop the precondition. This
#        layer alone is still prose-adjacent (the agent could still ignore
#        the fact), so it is not the enforcement -- see (2).
#     2. AFTER the orchestrator agent finishes, the workflow calls
#        `verify <summary-path>` on the daily summary it wrote. If the
#        summary declares NO-OP mode (`**Mode:** NO-OP`) while the open-PR
#        queue is empty, or while dev/status/*.md changed since the prior
#        summary (Condition 2), `verify` exits non-zero and the workflow
#        FAILS THE JOB. This is the actual backstop: it does not depend on
#        the model reading or obeying anything.
#
# USAGE
#   dev/scripts/orchestrator_fastexit_gate.sh open_pr_count
#       Prints the number of currently-open PRs in the repo. Used both as the
#       pre-run prompt-injection fact and internally by `verify`.
#
#   dev/scripts/orchestrator_fastexit_gate.sh status_changed_since <iso-ts>
#       Prints the count of dev/status/ file touches by a commit since
#       <iso-ts>, excluding orchestrator summary-landing commits. This is
#       Step 0.5 Condition 2's check, exposed as a single source of truth --
#       see the `_status_changed_since` comment below for why the inline
#       grep-pipeline version this replaced did not actually implement its
#       own documented exemption.
#
#   dev/scripts/orchestrator_fastexit_gate.sh verify <summary-path>
#       Reads the daily summary at <summary-path>. If it is not a NO-OP-mode
#       summary, prints a note and exits 0 (nothing to check). If it IS
#       NO-OP-mode, independently recomputes the open-PR count and the
#       dev/status/ drift since the prior summary and FAILS (exit 1, with an
#       `::error::` line per violation) if either contradicts the no-op
#       claim. Exits 0 only when both checks confirm the queue really was
#       empty of work.
#
# BACKEND SELECTION (mirrors dev/scripts/pr_gate_status.sh)
#   The GHA orchestrator container has `curl` + `$GH_TOKEN` but no `gh`
#   binary (see pr_gate_status.sh's "BACKEND SELECTION" comment for the
#   measured evidence). Local interactive sessions usually have `gh`
#   authenticated. Prefer `gh` when present (fewer moving parts locally);
#   fall back to the curl+REST path otherwise; refuse loudly if neither is
#   usable rather than silently reporting a PR count of 0 (which would be
#   indistinguishable from a real empty queue -- exactly the false-clean this
#   script exists to prevent).
#
#   Test-only override: ORCHESTRATOR_FASTEXIT_GATE_BACKEND=gh|curl forces a
#   backend regardless of what's on PATH (see
#   orchestrator_fastexit_gate_test.sh).
#
# LIMITATION: open_pr_count reads a single page (per_page=100, no
# pagination), same limitation as pr_gate_status.sh's `_list_open_prs_curl`.
# This repo's open-PR queue has never approached 100; if it ever does, this
# undercounts rather than erroring -- worth revisiting then, not now.

set -eu

REPO="${ORCHESTRATOR_FASTEXIT_GATE_REPO:-dayfine/trading}"

# --- backend selection -------------------------------------------------

_detect_backend() {
  if [ -n "${ORCHESTRATOR_FASTEXIT_GATE_BACKEND:-}" ]; then
    printf '%s' "$ORCHESTRATOR_FASTEXIT_GATE_BACKEND"
    return 0
  fi
  if command -v gh >/dev/null 2>&1; then
    printf gh
    return 0
  fi
  if command -v curl >/dev/null 2>&1 && [ -n "${GH_TOKEN:-}" ]; then
    printf curl
    return 0
  fi
  return 1
}

_open_pr_count_gh() {
  gh pr list --repo "$REPO" --state open --json number --jq 'length'
}

_open_pr_count_curl() {
  # Capture the body FIRST and check curl's own exit status before piping to
  # jq. `sh` has no `pipefail`, so `curl -f ... | jq 'length'` swallows a
  # failing curl: on a 401/403/5xx, `-f` makes curl exit non-zero and print
  # NOTHING to stdout, but the pipeline's exit status is jq's -- and jq on
  # empty input prints nothing and exits 0. That turned a curl failure into
  # `open_pr_count` silently returning rc=0 with an EMPTY count, which
  # `verify` could not distinguish from "queue is empty" (issue #2605
  # rework). Splitting the pipe closes that gap.
  _body=$(
    curl -sS -f \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${REPO}/pulls?state=open&per_page=100"
  ) || return 2
  _count=$(printf '%s' "$_body" | jq 'length') || return 2
  # Belt-and-braces: refuse to return anything that isn't a plain non-negative
  # integer, so a malformed/empty jq result can never be mistaken for a real
  # PR count by a caller that only checks the exit status.
  case "$_count" in
    '' | *[!0-9]*) return 2 ;;
  esac
  printf '%s' "$_count"
}

open_pr_count() {
  _backend=$(_detect_backend) || {
    echo "orchestrator_fastexit_gate: neither \`gh\` nor (\`curl\` + \$GH_TOKEN)" >&2
    echo "is available -- refusing to report an open-PR count (a silent 0" >&2
    echo "here would be indistinguishable from a real empty queue)." >&2
    return 2
  }
  case "$_backend" in
    gh) _open_pr_count_gh ;;
    curl) _open_pr_count_curl ;;
    *)
      echo "orchestrator_fastexit_gate: unrecognised backend '$_backend'" \
        "(from \$ORCHESTRATOR_FASTEXIT_GATE_BACKEND) -- refusing to report" \
        "an open-PR count rather than silently returning nothing." >&2
      return 2
      ;;
  esac
}

# --- dev/status/ drift (Condition 2, mirrored from lead-orchestrator.md) ----

# _prior_summary_path <current-summary-path>
# Newest dev/daily/*.md (excluding -plan.md, -summary.md, and the current
# summary itself), by mtime. Empty output means no prior summary exists
# (first run ever) -- callers must treat that as "nothing to compare
# against", not a violation.
#
# -summary.md (the consolidated multi-run rollup the orchestrator also
# writes) is excluded for the same reason the workflow's own "Locate daily
# summary" step excludes it (.github/workflows/orchestrator.yml, run
# 24745079773 post-mortem): it is written LAST, minutes after this run's own
# per-run summary, by the SAME run. Without this exclusion, `ls -t` can pick
# the current run's own rollup as its "prior" summary -- comparing a
# timestamp against itself and independently zeroing the drift window,
# regardless of the mtime-vs-commit-date fix below.
_prior_summary_path() {
  _current="$1"
  ls -t dev/daily/*.md 2>/dev/null \
    | grep -v -- '-plan\.md$' \
    | grep -v -- '-summary\.md$' \
    | grep -vxF "$_current" \
    | head -1 || true
}

# _file_iso_mtime <path> -- portable (BSD date on macOS, GNU date on Linux/CI)
_file_iso_mtime() {
  date -r "$1" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null \
    || date -d "@$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1")" '+%Y-%m-%dT%H:%M:%S'
}

# _prior_summary_timestamp <path>
# Prefer the file's last COMMIT date over its mtime: `actions/checkout@v4`
# (the tree the GHA orchestrator job runs on) writes every file at checkout
# time and does not preserve mtimes, so on that runner `_file_iso_mtime`
# always reads as "a few seconds ago" regardless of how old the prior
# summary actually is -- making `_status_changed_since` structurally return
# 0 and the Condition-2 half of `verify` permanently inert where it is
# deployed (issue #2605 rework). Fall back to mtime only when the file has
# no commit history at all (e.g. a summary this run just wrote and has not
# committed yet).
_prior_summary_timestamp() {
  _path="$1"
  _committed=$(git log -1 --format='%cI' -- "$_path" 2>/dev/null || true)
  if [ -n "$_committed" ]; then
    printf '%s' "$_committed"
  else
    _file_iso_mtime "$_path"
  fi
}

# _status_changed_since <iso-timestamp>
# Count of dev/status/ file touches by a commit since <iso-timestamp>,
# excluding the orchestrator's own summary-landing commits ("ops: daily
# orchestrator summary ..." -- Step 5.5's auto-merged index reconciliation,
# not new track drift). Same exemption intent as lead-orchestrator.md Step
# 0.5 Condition 2, but resolved per-commit rather than by a single grep
# pipeline: a `--name-only --pretty="%s"` stream interleaves each subject
# line with its own touched-file lines, and every dev/status/ path contains
# a literal '.' (the .md extension) -- so filtering only the subject line
# out of that stream still leaves the exempted commit's file lines behind,
# and `grep -c '\.'` counts them anyway. Walking commit-by-commit and
# skipping the whole commit (subject AND files) when it matches the
# exemption is what actually implements the documented exemption.
_status_changed_since() {
  _since="$1"
  _count=0
  for _hash in $(git log --since="$_since" --pretty="format:%H" -- dev/status/); do
    _subject=$(git log -1 --pretty="format:%s" "$_hash")
    case "$_subject" in
      "ops: daily orchestrator summary "*) continue ;;
    esac
    _n=$(git show --name-only --pretty="format:" "$_hash" -- dev/status/ | grep -c '\.' || true)
    _count=$((_count + _n))
  done
  echo "$_count"
}

# --- verify: the actual backstop ---------------------------------------

verify() {
  _summary="$1"
  if [ ! -f "$_summary" ]; then
    echo "orchestrator_fastexit_gate verify: summary file not found: $_summary" >&2
    return 2
  fi

  if ! grep -qE '^\*\*Mode:\*\* NO-OP' "$_summary"; then
    echo "orchestrator_fastexit_gate verify: $_summary is not a NO-OP-mode run; nothing to verify."
    return 0
  fi

  _pr_count=$(open_pr_count) || {
    echo "::error::orchestrator_fastexit_gate verify: $_summary declares NO-OP but the open-PR count could not be determined -- refusing to validate a no-op run blind." >&2
    return 2
  }
  # Belt-and-braces on top of _open_pr_count_curl's own numeric guard: even
  # if some future backend returns rc=0 with a blank/garbage count, `verify`
  # itself refuses to treat it as a trustworthy number rather than letting
  # `[ "$_pr_count" -eq 0 ]` below silently read as false under `set -e`
  # (a non-numeric operand makes `[` error, but inside an `if` condition
  # that error is suppressed and reads as "condition false" -- exactly how
  # the original defect went undetected).
  case "$_pr_count" in
    '' | *[!0-9]*)
      echo "::error::orchestrator_fastexit_gate verify: $_summary declares NO-OP but open_pr_count returned a non-numeric value ('$_pr_count') -- refusing to validate a no-op run blind." >&2
      return 2
      ;;
  esac

  _prior=$(_prior_summary_path "$_summary")
  _status_changed=0
  if [ -n "$_prior" ]; then
    _prior_iso=$(_prior_summary_timestamp "$_prior")
    _status_changed=$(_status_changed_since "$_prior_iso")
  fi

  _fail=0
  if [ "$_pr_count" -eq 0 ]; then
    echo "::error::A-FASTEXIT-VACUOUS (issue #2579): $_summary declares NO-OP but the open-PR queue is EMPTY (0 open PRs). Per the fast-exit precondition (.claude/agents/lead-orchestrator.md Step 0.5), an empty queue is NOT saturation -- it is the opposite -- and the four fast-exit conditions should never have been evaluated. A full pass was required this run." >&2
    _fail=1
  fi
  if [ "${_status_changed:-0}" -gt 0 ]; then
    echo "::error::A-FASTEXIT-VACUOUS (issue #2579): $_summary declares NO-OP but $_status_changed dev/status/*.md commit(s) landed since the prior summary (${_prior:-none}), violating Condition 2 (no status drift since prior summary)." >&2
    _fail=1
  fi

  if [ "$_fail" -eq 1 ]; then
    return 1
  fi

  echo "orchestrator_fastexit_gate verify: NO-OP run OK (open PRs: $_pr_count, dev/status/ changes since prior summary: ${_status_changed:-0})."
  return 0
}

# Sourcing with ORCHESTRATOR_FASTEXIT_GATE_LIB=1 exposes every function above
# for orchestrator_fastexit_gate_test.sh without hitting the network or
# invoking the CLI dispatcher below. EVERYTHING BELOW THIS LINE IS A SIDE
# EFFECT and must stay below it.
[ "${ORCHESTRATOR_FASTEXIT_GATE_LIB:-}" = 1 ] && return 0

case "${1:-}" in
  open_pr_count)
    open_pr_count
    ;;
  status_changed_since)
    if [ $# -lt 2 ]; then
      echo "usage: $0 status_changed_since <iso-timestamp>" >&2
      exit 2
    fi
    _status_changed_since "$2"
    ;;
  verify)
    if [ $# -lt 2 ]; then
      echo "usage: $0 verify <summary-path>" >&2
      exit 2
    fi
    verify "$2"
    ;;
  *)
    echo "usage: $0 {open_pr_count|status_changed_since <iso-ts>|verify <summary-path>}" >&2
    exit 2
    ;;
esac
