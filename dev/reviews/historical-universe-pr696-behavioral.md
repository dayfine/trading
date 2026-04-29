---

# Behavioral QC — historical-universe-pr696
Date: 2026-04-29
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | Pure docs PR; no `.mli` files added or modified. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | NA | PR body's "Test plan" is `[x] No code changes; pure docs.` — no behavioral claims to pin. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | NA | No test code in this PR. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | NA | No guarded code paths added. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural's A1 is PASS (no core module touched). Pure-doc PR adds zero code. |
| S1–S6 | Stage definitions / buy criteria | NA | Pure track-item proposal doc; no Weinstein domain logic implemented. |
| L1–L4 | Stop-loss state machine | NA | Pure track-item proposal doc; no stop logic. |
| C1–C3 | Screener cascade / macro / sector | NA | Doc proposes a future point-in-time membership pre-filter (P5) but does not implement it. |
| T1–T4 | Domain-outcome tests | NA | No code, no tests. |

(Pure track-item proposal / gap analysis doc; domain checklist not applicable per
`.claude/rules/qc-behavioral-authority.md` "When to skip this file entirely".)

## Spot-checks of the doc's quantitative claims

The PR body's headline claim that interval-shape is "~400× smaller" than naive
`(date, full-list)` was verified against the doc's own arithmetic:

- **Naive (per-day full list)**: 7,500 days × 500 symbols × 5 chars = **18.75 MB**.
  Doc says "~19 MB" — consistent (rounded).
- **Snapshot + deltas**: ~500 symbols (T0) + ~1,400 events × ~36 bytes ≈ **~50 KB**.
  19 MB ÷ 50 KB ≈ **380×**. Doc says "~400×" — consistent within back-of-envelope tolerance.
- **Per-symbol intervals**: ~1,000 symbols × ~2 intervals × ~40 bytes ≈ **~80 KB**.
  19 MB ÷ 80 KB ≈ **237×**. Doc itself only says "slightly larger than snapshot+deltas"
  and does NOT claim 400× for this shape — internally consistent.

The PR body's framing slightly conflates the two shapes (the body says intervals
are "~400× smaller", but per-symbol intervals are actually ~237× while snapshot+deltas
are ~380×). The note text inside the doc itself is correct. This is a minor PR-body
imprecision, not a behavioral defect — the doc's claims are accurate as written.

The "~1,000+ unique symbols over 30y" claim cannot be exactly verified without
external data, but is consistent with publicly known SP500 churn rates (~25
add/remove events per year × 30y ≈ ~750 churn events on top of a 491-symbol base,
yielding ~1,000+ ever-members).

Cross-references all resolve to existing files:
- `dev/notes/data-availability-2026-04-29.md` ✓
- `dev/notes/session-followups-2026-04-29-evening.md` ✓
- `dev/status/sector-data.md` ✓
- `analysis/data/sources/eodhd_*.ml` (referenced as "probably needs a new endpoint binding") — non-prescriptive pointer, no claim to verify.

The 6-phase rollout ownership map (P1/P2 → ops-data, P3/P4 → data-types,
P5 → feat-weinstein, P6 → feat-backtest) is sane sequencing — data fetch comes
before consumer integration, screener filter comes before scenario authoring.

## Quality Score

5 — Cleanly framed gap doc with verified arithmetic, valid cross-references, and reasonable phasing; PR-body imprecision on "~400×" vs. interval shape does not propagate into the note itself.

(Does not affect verdict. Tracked for quality trends over time.)

## Verdict

APPROVED

(Derived mechanically: all applicable items NA; no FAIL in CP* or domain rows.)
