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
#      NOT reliably live under a "Follow-up" heading: dev/status/
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
# "the next new heading" the way heading-matching did twice before. The
# tradeoff (documented, not hidden): this also counts open Tier 1-4
# roadmap checkboxes in harness.md, not just ad-hoc follow-up notes —
# i.e. the metric is now "total open checkbox work across all status
# files", a broader (but honest and unbroken) definition of what the
# orchestrator's maintenance-cycle threshold gates on. If that changes
# the practical threshold calculus, that is a `dev/config/
# merge-policy.json` retune — a separate decision from this
# counting-correctness fix.
#
# `- [x]` (closed) items and plain prose bullets (`- some note`, no
# checkbox) are NOT counted — only `- [ ]`.
#
# This check also exports a per-file breakdown to a sidecar file so
# Check 8 (trends) can read it and print a matching per-file table —
# the breakdown IS the report's scope statement in practice: it lets a
# reader see which files contributed to the total rather than trusting
# a bare integer.

set -e

REPORT_FILE="${1:?Usage: check_05_followup_items.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 5: Open item count (from status files)
# ────────────────────────────────────────────────────────────────

FOLLOWUP_COUNT=0
# FOLLOWUP_PER_FILE accumulates lines of the form "file:count" for Check 8 Trends.
FOLLOWUP_PER_FILE=""
for status_file in "${REPO_ROOT}"/dev/status/*.md; do
  [ -f "$status_file" ] || continue
  file_count=0
  # Count every open checkbox item ("- [ ] ...") anywhere in the file,
  # unscoped by heading. See the file header comment for why heading
  # scoping was removed.
  while IFS= read -r line; do
    case "$line" in
      "- [ ]"*)
        FOLLOWUP_COUNT=$((FOLLOWUP_COUNT + 1))
        file_count=$((file_count + 1))
        ;;
    esac
  done < "$status_file"
  if [ "$file_count" -gt 0 ]; then
    fname="$(basename "$status_file")"
    FOLLOWUP_PER_FILE="${FOLLOWUP_PER_FILE}${fname}:${file_count}\n"
  fi
done

if [ "$FOLLOWUP_COUNT" -gt 10 ]; then
  add_warning "Open item accumulation: ${FOLLOWUP_COUNT} open \`- [ ]\` items across dev/status/*.md, unscoped by heading (threshold: 10) — see 'Followup Count Detail' below for the per-file breakdown"
elif [ "$FOLLOWUP_COUNT" -gt 0 ]; then
  add_info "Open items: ${FOLLOWUP_COUNT} total \`- [ ]\` items across dev/status/*.md, unscoped by heading"
fi

add_metric FOLLOWUP_COUNT "$FOLLOWUP_COUNT"
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
