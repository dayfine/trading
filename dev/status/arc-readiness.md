# Status: arc-readiness

## Last updated: 2026-08-20

## Status
IN_PROGRESS

## Interface stable
NO

G2a/G2b add two new config fields, and the config `.mli` is slated for
docstring compression (A3-3).

---

## What this track is

The user's framing, 2026-08-20:

> *"we are not yet trying to get this arc to beat record. We are trying to get
> the necessary features in place together first"*

and the three axes to be ready on:

1. **All arc features built and working properly** — trading performance may not
   be impressive yet; we keep iterating within the arc.
2. **All necessary validation and testing tools** — not only trade performance
   but **execution correctness** (it does what we thought) and **book
   faithfulness**.
3. **Simplified / compressed codebase + docs** to minimise confusion and
   distraction.

**This reframes every measurement.** At a 132.5pp (26y) / 278pp (ladder-v4)
noise floor most single mechanisms cannot clear anything — the broad-5y cell
showed one arm's own salt-to-salt spread (9.24pp) exceeding the arm-to-arm gap
(−6.22pp). So "does X clear its null" is the wrong question right now. "Is X
built, correct, composable, faithful" is the right one.

Design rationale: `dev/plans/arc-readiness-2026-08-20.md` (#2447).

---

## Axis 1 — arc features built and working (~85%)

Seven mechanisms, all built and tested (1–4 test files each). **Six of seven
verified running together** — `ladder-v4-async-ticket-2026-08-10` cell `v4-16`
arms `Range_top_breakout` + rescreen + rest-4wk + `Drop_over_max` + volconf
simultaneously (checked as armed *values*, not field mentions).

The hole is the **funding leg**, whose plan
(`dev/plans/ticket-funding-2026-08-16.md`) has four steps:

| step | state |
|---|---|
| G1 — land `ticket_age_weeks_at_cancel` + `cancel_reason` (#2348) | ✅ done (3 impl, 5 test files) |
| step 2 — measure the cohort from artifacts | ✅ done — 3,530 rejections, median shortfall 52%, 63% in bursts |
| step 3 — build each axis behind its own flag | **1 of 3** |
| step 4 — one grid over all three + null | **blocked** |

### Sub-tasks

- [ ] **A1-1 — Build G2a `entry_fill_reject_retries`** (retry). Does not exist:
      0 mli, 0 impl, 0 tests. Default-off `int`, default `0`, per
      `experiment-flag-discipline.md` R1/R2. Same shape as the built G3.
- [ ] **A1-2 — Build G2b `entry_fill_size_to_available`** (resize). Does not
      exist. Default-off `bool`, default `false`. Independent of A1-1.
- [ ] **A1-3 — Arm G3 `reserve_cash_for_resting_tickets` in a combined arc
      cell.** It is built and tested (`Entry_walk._spendable_cash`) but armed
      in **zero specs** — the only arc mechanism never exercised.
- [ ] **A1-4 — Run the funding three-way grid** (G2a vs G2b vs G3 + null).
      Blocked on A1-1 + A1-2. The three are **alternatives, not complements**,
      so arming G3 alone cannot answer it. This is an *internal* comparison, so
      it is **not** blocked by the noise floor. Broad universe only
      (`universe-discipline.md`).

**Why G3 matters beyond bookkeeping:** an unfundable triggered ticket is
silently **destroyed** — not retried, not resized. `Entry_walk`'s per-tick
`remaining_cash` is re-seeded from `portfolio.cash` every tick, so a ticket
resting from week N is invisible in week N+1 and its money is committed twice.

---

## Axis 2 — validation and testing tools

Three capabilities. Two are strong; one had no tooling at all.

### (a) Trade performance — strong tooling, low power

`variant_matrix`, `variant_ranking` (Pareto), `deflated_sharpe`, `fold_health`,
`rolling_start` + convexity/dispersion stats; 15 artifacts per scenario run.

- [ ] **A2-1 — Automate effect-vs-null reporting.** The gap is not a missing
      tool: **nothing reports effect-vs-null automatically.** Nulls are
      hand-built with salted re-runs every time and are the binding constraint
      on every verdict. Emit per-metric gap, that metric's own null, and the
      ratio — the Rule-4 table currently written by hand in every writeup.
      Must refuse to import a null across scales **or** universes.

### (b) Execution correctness — ✅ covered, no action

`decision_audit` (counterfactual / screen_record / weekly_adapter),
`trade_audit` + recorder + basis + report + ratings + `trade_score`,
`entry_audit_capture` / `exit_audit_capture` / `audit_recorder`,
`screener_cascade_diagnostics`, HTML report.

### (c) Book faithfulness — was absent; partly addressed

No automated check exists anywhere in `trading/devtools/` or `.github/`;
"faithful" appears only in `.mli` prose. Enforcement is qc-behavioral's manual
S1–S6 / L1–L4 / C1–C3 checklist. **This cannot be linted** — faithfulness is a
judgment, not a predicate over source.

- [x] **A2-2 — Make the book a first-class resource** (#2447). Shipped
      `.claude/rules/book-as-authority.md`: the local path, the OCR caveat
      (extraction has spacing artifacts, so exact long-phrase greps fail and a
      failed grep is *not* evidence of absence), and a three-tier protocol —
      reference → book when the reference is silent/ambiguous/contested →
      **write the answer back**, so the reference becomes a cache of resolved
      questions. Cited from `weinstein-faithful-core.md` W2 and
      `qc-behavioral-authority.md`.
- [ ] **A2-3 — Resolve the fill-model A/B** ⚠ **USER DECISION.** The record
      convention uses a **non-book** market + deep-floor fill rule; the honest
      book rule scores ≈ **+310%** (`project_fill_model_inversion`). This
      determines whether the arc is iterating against a baseline whose
      execution model is the one the book specifies — so it changes what every
      other measurement on this track means.

---

## Axis 3 — compression

Measured surfaces: `dev/notes/` 368 files / **53,200 lines**; `dev/plans/` 139
files / 28,718 lines; `weinstein_strategy_config.mli` **1,787 lines for 81
fields** (1,554 of them docstring, ~19/field, +337 lines in 11 days).

**Rule 4 is net-zero:** 0 promotions, 0 net retirements, +7 inert mechanisms in
11 days.

### Why it never happens — the load-bearing finding

**Every prune list built by hand on 2026-08-20 shrank by half or more once each
row was verified:**

| list | headline | after verification |
|---|---:|---:|
| Rule-4 retirement "confirm" flags | 5 | **0** (5→2→0 across two passes) |
| orphaned experiment dirs | 145 files | **53** |
| superseded priorities docs | 106 | **84** |

The headline always overstates; **the per-row verification is the work**, and
nobody budgets it. That is why the flag inventory sat unworked from 08-09.

### Sub-tasks

- [x] **A3-0 — Correct the flag inventory** (#2450). `enable_late_stage2_stop_tighten`
      reclassified RETIRE → **KEEP-AXIS**; the eligible count is **zero**. Its
      memory says *"Dial stays default-off / available as an axis; no further
      investment"* — REJECT-as-legitimate-axis, which Rule 4 says does not
      retire. **Caught by the tool below reading the record and reporting it as
      the one `ELIGIBLE` row** — making the claim operational is what exposed
      an assertion that had sat unchallenged for 11 days.
- [ ] **A3-1 — Land `prune_candidates.sh` + weekly GHA** (#2449, in flight).
      Automates the *verification*, not the deletion: proposes, never deletes.
      Three checkers, each encoding a trap that cost a real error —
      `[[:space:]]` not `\s`; sanity probes that hard-abort rather than report
      an empty list as clean; a 30-day quarantine (a "cited by nothing" test
      also catches *this week's* work, so it measures citation **age**, not
      deadness); and a path name is not its content.
- [ ] **A3-2 — Delete the 84 uncited priorities docs** (9,579 lines). Blocked
      on A3-1 so the list is tool-verified. `session-rampup.md` already says
      only the newest is load-bearing. Deletion loses nothing — git history
      keeps them.
- [ ] **A3-3 — Compress `weinstein_strategy_config.mli` docstrings.** Move
      mechanism *histories* out (they already live in the ledger and experiment
      records) and leave the contract. **Not** a Rule-4 retirement — the flags
      stay, only the prose moves.

---

## Next task

A1-1 and A1-2 (build G2a and G2b) — the arc's only genuine feature hole, and
unblocked by the noise floor since step 4 is an internal three-way comparison.

## Follow-ups

- **#2433 framing** ⚠ USER DECISION — held under `do-not-merge`. Both gates
  stale at `42da124b6`. The broad-5y result (#2448) bears on it: MaxDD agrees
  across both windows, but the **win-rate leg fails Rule 4 on broad-5y** and
  should no longer be quoted as a Rule-4 survivor without that counter-evidence.
- Two non-blocking observations on #2449 recorded rather than fixed: checker 3's
  two sanity probes mutually mask, and the `newest`-by-git-log-vs-filename bound
  is not discriminated because the fixture's filename order coincides with its
  commit order.
