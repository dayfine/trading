---
description: Project-specific authority + checklist appendix for the qc-behavioral agent. The agent's generic protocol (Contract Pinning Checklist CP1–CP4, quality score format, FAIL semantics) lives in `.claude/agents/qc-behavioral.md`. This file lists the Weinstein-domain rows (S*/L*/C*/T*) appended to the behavioral checklist for every Weinstein-feature PR review, plus the authority document hierarchy.
harness: project
---

# qc-behavioral authority — Weinstein Trading System

This file is the **project-specific augmentation** of the generic qc-behavioral
agent. The agent's protocol (Contract Pinning Checklist CP1–CP4, quality
score format, write `dev/reviews/<feature>.md`, harness_gap classification)
lives in `.claude/agents/qc-behavioral.md` and is reusable across projects.
The rows + authority list below are specific to *this* repo's domain.

## Authority document hierarchy

For Weinstein domain features (stage classifiers, screener, stops, simulation):

- `docs/design/weinstein-book-reference.md` — primary authority for all
  domain rules (Stage definitions, buy/sell criteria, stop-loss rules,
  macro indicators, sector analysis, short-side rules).
- `docs/design/eng-design-2-screener-analysis.md` — screener / analysis spec
- `docs/design/eng-design-3-portfolio-stops.md` — portfolio / stops spec
- `docs/design/eng-design-4-simulation-tuning.md` — simulation spec
- `docs/design/weinstein-trading-system-v2.md` — system-level context

For infrastructure, library, refactor, or harness PRs (the qc-behavioral
generic protocol covers these via CP1–CP4 alone — the S*/L*/C*/T* rows
below do not apply):

- The new module's `.mli` docstrings — primary contract.
- The feature plan file (`dev/plans/<feature>.md`) — agreed design.
- The PR body's "Test plan" / "Test coverage" / "What it does" sections —
  the author's explicit claims.

## Domain checklist (append to qc-behavioral's generic Contract Pinning Checklist)

For Weinstein-feature PRs, append these rows below the CP1–CP4 rows. For
non-Weinstein PRs (infra / refactor / harness), skip the entire block —
mark every row NA with one explanatory note.

```
## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic (only fill if qc-structural flagged A1) | PASS/FAIL/NA | PASS: change generalizes to any strategy. FAIL: Weinstein-specific logic leaked into shared module — must decouple |
| S1 | Stage 1 definition matches book (basing/accumulation: price consolidating, MA flat or declining) | PASS/FAIL/NA | weinstein-book-reference.md §Stage Definitions |
| S2 | Stage 2 definition matches book (advancing: price above rising 30-week MA, volume expansion on up weeks) | PASS/FAIL/NA | |
| S3 | Stage 3 definition matches book (topping/distribution: price above MA but MA flattening) | PASS/FAIL/NA | |
| S4 | Stage 4 definition matches book (declining: price below declining MA) | PASS/FAIL/NA | |
| S5 | Buy criteria: entry only in Stage 2, on breakout above resistance with volume confirmation | PASS/FAIL/NA | |
| S6 | No buy signals generated during Stage 1, 3, or 4 | PASS/FAIL/NA | |
| L1 | Initial stop placed below the base (Stage 1 low) | PASS/FAIL/NA | weinstein-book-reference.md §Stop-Loss Rules |
| L2 | Trailing stop rises as price advances (never lowered) | PASS/FAIL/NA | |
| L3 | Stop triggers on weekly close below stop level (not intraday) | PASS/FAIL/NA | |
| L4 | Stop state machine transitions are correct (INITIAL → TRAILING → TRIGGERED) | PASS/FAIL/NA | eng-design-3-portfolio-stops.md |
| C1 | Screener cascade order: macro gate → sector filter → individual scoring → ranking | PASS/FAIL/NA | eng-design-2-screener-analysis.md |
| C2 | Bearish macro score blocks all buy candidates (macro gate is unconditional) | PASS/FAIL/NA | weinstein-book-reference.md §Macro Analysis |
| C3 | Sector analysis uses relative strength vs. market, not absolute performance | PASS/FAIL/NA | weinstein-book-reference.md §Sector Analysis |
| T1 | Tests cover all 4 stage transitions with distinct scenarios | PASS/FAIL/NA | |
| T2 | Tests include a bearish macro scenario that produces zero buy candidates | PASS/FAIL/NA | |
| T3 | Stop-loss tests verify trailing behavior over multiple price advances | PASS/FAIL/NA | |
| T4 | Tests assert domain outcomes (correct stage, correct signal), not just "no error" | PASS/FAIL/NA | |
```

## Worked example — NEEDS_REWORK with domain finding

```
## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| S1 | Stage 1 definition matches book | PASS | weinstein-book-reference.md §Stage 1: Neglect |
| S2 | Stage 2 definition matches book | FAIL | Implementation uses 20-week MA; book specifies 30-week MA (weinstein-book-reference.md §Stage 2: Advancing) |
| S3 | Stage 3 definition matches book | NA | Not in this feature |
| S4 | Stage 4 definition matches book | NA | Not in this feature |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | PASS | |
| S6 | No buy signals in Stage 1/3/4 | PASS | |
| L1 | Initial stop below base | NA | Stops not in this feature |
| L2 | Trailing stop never lowered | NA | |
| L3 | Stop triggers on weekly close | NA | |
| L4 | Stop state machine transitions | NA | |
| C1 | Screener cascade order | PASS | eng-design-2-screener-analysis.md §Cascade Filter |
| C2 | Bearish macro blocks all buys | PASS | |
| C3 | Sector RS vs. market, not absolute | PASS | |
| T1 | Tests cover all 4 stage transitions | PASS | |
| T2 | Bearish macro → zero buy candidates test | PASS | |
| T3 | Stop trailing tests | NA | |
| T4 | Tests assert domain outcomes | PASS | |

## Quality Score

2 — Wrong MA period is a fundamental domain parameter error; otherwise clean implementation.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### S2: Wrong moving average period in stage classifier
- Finding: Stage classifier uses 20-week MA for the primary trend line; Weinstein specifies 30-week MA throughout
- Location: analysis/weinstein/screener/stage_classifier.ml, line 34
- Authority: "The 30-week moving average is the key to stage analysis" — weinstein-book-reference.md §Stage 2: Advancing
- Required fix: Change ma_period from 20 to 30 weeks (must come from config, not hardcoded)
- harness_gap: LINTER_CANDIDATE — a golden scenario test with known Stage 2 input and 30-week MA window would catch this deterministically (T2-A)
```

## When to skip this file entirely

For pure infrastructure / library / refactor / harness PRs that touch no
domain logic — the generic CP1–CP4 in the qc-behavioral agent file alone
constitute the full review. Mark the entire S*/L*/C*/T* block NA with a
note: "Pure infra / harness / refactor PR; domain checklist not applicable."
qc-structural's A1 row will not be flagged for such PRs because there is
no domain logic to leak into core modules.

## What the generic agent doesn't know about

- The five Weinstein authority docs above.
- Stage definitions, stop-loss rules, screener cascade rules.
- The book's specific parameter values (30-week MA, 8% pullback threshold,
  etc.) — those live in `weinstein-book-reference.md`.

If reusing the generic qc-behavioral agent in a new project, replace this
file with the new project's domain authority + checklist. The agent itself
does not change.
