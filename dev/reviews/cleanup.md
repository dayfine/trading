Reviewed SHA: 5bb2b749

# QC review — cleanup track

## PR #2099 — `cleanup/support-floor-citation` (MERGED `aca88729`)

Split the `support_floor.mli` stop-rule citation: `Ch. 6 §5.1` for the long
rule, `Ch. 7 §6.3` for the short rule. Doc-comment only, no behavior change.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 0.

Full verdicts are PR review comments on #2099 (the authoritative channel per
`.claude/rules/pr-merge-gates.md`). Written here by the **orchestrator**, not by
the QC agents: both were fenced read-only because the GHA container shares a
single git working tree, so a file write from an agent would land on a sibling
agent's branch. This file exists so the `Reviewed SHA:` idempotency key that
Step 1.5 and Step 0.5 Condition 1 depend on is actually present — its absence
was a carried `[medium]` from run 3.

**Field format matters.** The three `*_qc:` lines above are deliberately at
column 0 with no list marker or backticks, and the `## Quality Score` heading
below is followed by a bare integer. `record_qc_audit.sh` greps
`^structural_qc: (APPROVED|NEEDS_REWORK)` and reads the first non-blank line
after a `## Quality Score` heading. A prettier rendering (`- \`structural_qc:
APPROVED\` — 5/5`) parses to **SKIPPED / null** *without erroring* — a silently
wrong audit record. See §Escalations in `dev/daily/2026-07-26-run4.md`.

### Structural (5/5)

All rows PASS or NA. A1 NA (`weinstein/stops/lib/` is not on the core-module
watch-list); A3 PASS on exactly 2 in-scope files with zero drift; P6 NA (no test
files). Confirmed the change is strictly inside the header `(** … *)` block —
no `val`, no `type`, no value, no `.ml` change.

### Behavioral (4/5)

Verified both cited sections from primary source, including their parent
headings (which carry the book-chapter attribution):

- `## 5. Stop-Loss and Selling Rules (Ch. 6)` → `### 5.1 Initial Stop Placement`
  contains, **verbatim**, "Place below the significant support floor (prior
  correction low) BEFORE the breakout". `Ch. 6 §5.1` ✅
- `## 6. Short-Selling Criteria (Ch. 7)` → `### 6.3 Short Stop (Buy-Stop) Rules`
  contains "Initial buy-stop: above prior rally peak (above round number)".
  `Ch. 7 §6.3` ✅

Both citations resolve to sections that exist **and contain the claim** — so
this is not a fifth instance of the recurring defect.

Held at 4/5 for two reasons, both non-blocking:

1. The short line's **"BEFORE the breakdown"** is not stated in §6.3. It is a
   two-hop inference from "**Initial** buy-stop" + §6's explicit "Mirror image
   of buying" preamble + §5.1's "BEFORE the breakout". Sound and structurally
   licensed (§6.2 enumerates the differences from buying, and stop *timing* is
   not among them), but derived rather than quoted.
2. An **uncited** domain claim remains in the same file: the `min_pullback_pct`
   docstring says *"Weinstein's book default is [0.08] (8%)"* with no section
   reference. Nearest support is §5.2 ("substantial correction (8-10%+)"). This
   is the same detection-evading shape as the four defects already found — a
   numeric domain constant asserting book provenance without a `§N.N` token.

Both filed to `dev/status/cleanup.md` §Backlog. Item 2 is classified
`harness_gap: LINTER_CANDIDATE` — a linter *can* mechanically flag docstrings
that assert book provenance without a section token, which would catch this
whole defect family going forward. Item 1 is `harness_gap: ONGOING_REVIEW`:
telling a faithful paraphrase from drift requires reading both sections in
context and is not mechanizable.

## Quality Score

4 — behavioral score (takes precedence over structural 5/5 per the audit
convention). Correctly targeted, independently verifiable fix with an honest
status note; held off 5 by the derived "BEFORE the breakdown" clause and the
uncited 8% claim remaining in the same file.

## Verdict

APPROVED
