#!/bin/sh
# Check 5: Open item count (from status files) — feeds the orchestrator's
# Step 2b maintenance-cycle decision (dev/config/merge-policy.json
# "followup_threshold").
#
# Usage: sh check_05_followup_items.sh <report_file> [findings_file]
#
# SCOPE (read this before changing the regex — see H-FOLLOWUP-COUNT in
# dev/status/harness.md for the incident that made this comment necessary):
#
# This counts every open checkbox item — lines matching `- [ ]` — across
# the ENTIRE body of each dev/status/*.md file, regardless of which
# heading it sits under. It is deliberately NOT scoped to a
# "## Follow-up" / "## Followup" heading.
#
# A heading-scoped implementation was tried and broke twice:
#   1. It matched only `## Follow-up*` / `## Followup*` (H2), so a file
#      using `### Follow-up` (H3) was invisible to it.
#   2. Even a widened heading set still misses the next new heading
#      name. In practice, open work in this repo's status files does
#      NOT reliably live under a "Follow-up" heading at all: dev/status/
#      harness.md's open items live under a dated heading like
#      "## Added 2026-07-27 (orchestrator run N)"; dev/status/
#      cleanup.md's live under "## Backlog". Both are functionally "the
#      open items in this file" — matching one hardcoded heading
#      spelling can never keep up with every file's own naming, and
#      each new heading spelling reproduces the exact defect being
#      fixed here.
#
# Counting unscoped by heading, filtered only by `- [ ]` (open
# checkbox), is robust to arbitrary heading names and cannot regress by
# "the next new heading" the way heading-matching did twice before.
#
# `- [x]` (closed) items and plain prose bullets (`- some note`, no
# checkbox) are NOT counted — only `- [ ]`.
#
# ────────────────────────────────────────────────────────────────
# ACTIONABLE vs EXCLUDED (H-FOLLOWUP-THRESHOLD-RETUNE)
# ────────────────────────────────────────────────────────────────
#
# H-FOLLOWUP-COUNT's fix (above) made the count honest about WHAT it
# measures ("every open checkbox, unscoped by heading") but that count
# is crossed by construction: dev/status/harness.md's Tier 2-4 roadmap
# (10 checkboxes as of the filing) is explicitly declared undispatchable
# by lead-orchestrator Step 2c (milestone-gated / human-request-only),
# and dev/status/cleanup.md's "How findings get here" section documents
# the literal Backlog-entry template inside a fenced code block — that
# placeholder text is not an open item at all. Neither shape is
# "actionable open debt", which is what the threshold is trying to gate
# on, so both are now EXCLUDED from the headline FOLLOWUP_COUNT metric
# via a distinct, self-describing convention — not a denylist that can
# silently drift from the file it describes:
#
#   1. Tier/roadmap items — any `- [ ]` line whose nearest preceding H2
#      heading (`## ...`) matches `## Tier <digit>` (e.g.
#      "## Tier 2 — Milestone-gated"). This is an EXISTING convention
#      already used in dev/status/harness.md for exactly this category
#      of long-horizon, not-currently-dispatchable roadmap; a reader can
#      see the exclusion by reading the file's own heading, with no
#      separate list to keep in sync as tiers gain or lose items.
#   2. Template / example text inside a fenced code block (```` ``` ````
#      ... ```` ``` ````). This is the standard Markdown convention for
#      "this is example text, not prose" — a `- [ ]` line inside a fence
#      is documentation of what an entry should look like, not an entry.
#
# Both exclusions are counted, not silently dropped — see
# FOLLOWUP_EXCLUDED / FOLLOWUP_TOTAL below, surfaced in both the
# Warnings/Info line and the metrics block, so the derived split is
# always visible and never has to be reconciled against prose by hand.
#
# Retuning `dev/config/merge-policy.json`'s `followup_threshold` upward
# instead was the other candidate resolution the filing left open; NOT
# taken, because the non-actionable floor is not a constant (Tier items
# open and close over time) and a raised threshold decays the moment the
# roadmap's shape changes, whereas an exclusion keyed on the file's own
# structure tracks that shape automatically.
#
# ────────────────────────────────────────────────────────────────
# FAIL-LOUD ON ZERO FILES READ
# ────────────────────────────────────────────────────────────────
#
# A broken REPO_ROOT resolution or a missing/emptied dev/status/
# directory must never silently report FOLLOWUP_COUNT=0 — that reads as
# "no open debt" when the real answer is "the scan didn't run". This
# check `die`s (non-zero exit, "FAIL:" to stderr) if it reads zero
# dev/status/*.md files, before computing or reporting anything.
#
# This check also exports a per-file breakdown (actionable counts only)
# to a sidecar file so Check 8 (trends) can read it and print a matching
# per-file table — the breakdown IS the report's scope statement in
# practice: it lets a reader see which files contributed to the total
# rather than trusting a bare integer.

set -e

REPORT_FILE="${1:?Usage: check_05_followup_items.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 5: Open item count (from status files)
# ────────────────────────────────────────────────────────────────

STATUS_DIR="${REPO_ROOT}/dev/status"

FILES_READ=0
FOLLOWUP_COUNT=0
FOLLOWUP_EXCLUDED=0
FOLLOWUP_TOTAL=0
# FOLLOWUP_PER_FILE accumulates lines of the form "file:count" for Check 8
# Trends — count here is the ACTIONABLE (post-exclusion) count only, since
# that is what the threshold and the Trends section both care about.
FOLLOWUP_PER_FILE=""
for status_file in "${STATUS_DIR}"/*.md; do
  [ -f "$status_file" ] || continue
  FILES_READ=$((FILES_READ + 1))

  file_count=0
  in_fence=0
  in_tier_heading=0
  while IFS= read -r line; do
    # A line starting with a fenced-code delimiter toggles fence state
    # before anything else runs, so the delimiter line itself is never
    # mistaken for content on either side of the fence.
    case "$line" in
      '```'*)
        in_fence=$((1 - in_fence))
        continue
        ;;
    esac
    # Track whether we are under a "## Tier <digit>" H2 heading. Any OTHER
    # H2 heading resets the flag; H3+ headings (e.g. "### T1-A: ...") and
    # non-heading lines leave it unchanged, since Tier sections in practice
    # contain only direct bullet items before the next H2.
    case "$line" in
      "## "*)
        case "$line" in
          "## Tier "[0-9]*) in_tier_heading=1 ;;
          *) in_tier_heading=0 ;;
        esac
        ;;
    esac
    case "$line" in
      "- [ ]"*)
        FOLLOWUP_TOTAL=$((FOLLOWUP_TOTAL + 1))
        if [ "$in_fence" -eq 1 ] || [ "$in_tier_heading" -eq 1 ]; then
          FOLLOWUP_EXCLUDED=$((FOLLOWUP_EXCLUDED + 1))
        else
          FOLLOWUP_COUNT=$((FOLLOWUP_COUNT + 1))
          file_count=$((file_count + 1))
        fi
        ;;
    esac
  done < "$status_file"
  if [ "$file_count" -gt 0 ]; then
    fname="$(basename "$status_file")"
    FOLLOWUP_PER_FILE="${FOLLOWUP_PER_FILE}${fname}:${file_count}\n"
  fi
done

if [ "$FILES_READ" -eq 0 ]; then
  die "check_05_followup_items: found zero dev/status/*.md files under ${STATUS_DIR} -- cannot measure open-item debt. Reporting FOLLOWUP_COUNT=0 here would misread as 'no open debt' instead of 'the scan did not run'. Check REPO_ROOT resolution (repo_root() in _check_lib.sh) and that dev/status/ exists and is non-empty."
fi

if [ "$FOLLOWUP_COUNT" -gt 10 ]; then
  add_warning "Open item accumulation: ${FOLLOWUP_COUNT} actionable open \`- [ ]\` items across dev/status/*.md, unscoped by heading (threshold: 10; ${FOLLOWUP_EXCLUDED} additional Tier-roadmap/template items excluded, ${FOLLOWUP_TOTAL} total open) — see 'Followup Count Detail' below for the per-file breakdown"
elif [ "$FOLLOWUP_COUNT" -gt 0 ]; then
  add_info "Open items: ${FOLLOWUP_COUNT} actionable total \`- [ ]\` items across dev/status/*.md, unscoped by heading (${FOLLOWUP_EXCLUDED} additional Tier-roadmap/template items excluded, ${FOLLOWUP_TOTAL} total open)"
fi

add_metric FOLLOWUP_COUNT "$FOLLOWUP_COUNT"
add_metric FOLLOWUP_EXCLUDED "$FOLLOWUP_EXCLUDED"
add_metric FOLLOWUP_TOTAL "$FOLLOWUP_TOTAL"
flush_findings

# Export per-file data for Check 8 Trends to read.
#
# IMPORTANT: the sidecar path is derived from the DIRECTORY of the
# findings/report file, not from the findings file's own full path.
# main.sh invokes Check 5 and Check 8 with distinctly-numbered findings
# files (05.findings, 08.findings) that live in the same shared
# FINDINGS_DIR. Keying the sidecar name off the full findings-file path
# (including its own basename) means each check computes a DIFFERENT
# sidecar filename ("05.findings.followup" vs "08.findings.followup"),
# so Check 8 silently reads a file Check 5 never wrote to — this was
# the root cause of Warnings and Trends contradicting each other
# (H-FOLLOWUP-COUNT defect 3). Keying off the shared directory instead,
# with a fixed filename, makes the handoff correct regardless of which
# check-number filenames main.sh uses.
FOLLOWUP_SIDECAR_DIR="$(dirname "${FINDINGS_FILE:-$REPORT_FILE}")"
FOLLOWUP_SIDECAR="${FOLLOWUP_SIDECAR_DIR}/followup_per_file.sidecar"
if [ -n "$FOLLOWUP_PER_FILE" ]; then
  printf '%b' "$FOLLOWUP_PER_FILE" > "$FOLLOWUP_SIDECAR"
else
  : > "$FOLLOWUP_SIDECAR"
fi
