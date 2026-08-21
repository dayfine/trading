# Status: arc-readiness

## Last updated: 2026-08-21

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

### 2026-08-20 — the book-faithful entry bundle is assembled (PR #2452)

`staging-arc-2026-08/top3000-2000-2026-arc-faithful.sexp`. Most of it already
existed: `staging-record-convention/...-fullbook-graded.sexp` carried the whole
**entry-ticket** half (`sim_entry_trigger_at_suggested` so the trigger RESTS at
E rather than the current close, `enable_sim_entry_stoplimit` +
`entry_extension_max_pct 2.0`, `stop_anchor_at_entry_base`). The bundle adds the
**screening** half: `entry_anchor_local_range_weeks 4`,
`entry_freshness_basis Range_top_breakout`, `volume_confirm_at_fill true`.

The **2pp band is the book's number**, not a tuned one — §"Buying Within
Limits" specifies a buy-stop at the breakout with a limit ¼ point above it,
= 2.06% on Weinstein's own 12⅛ example. He rejects both neighbours: no limit
gives *"the proud owner of XYZ at 15"*; limit == trigger gives *"one out of
four, the stock will break out without your ever buying it"* — the fat-tail-miss
objection, anticipated and priced by the author at 1-in-4.

**Live picks regenerated at as-of 2026-08-14** (control reproduces the committed
`f88c277d5` report **bit-identical**, validating universe / bars / as-of /
invocation together): **17 of 20 unchanged**; out PAY, TPC, INVX; in DRI, BLK,
NDAQ. Tickets now carry the 2pp band (`trigger $86.68 limit $88.41`) vs the old
15pp. Extended/watch-only rows 4 → 1.

**26y run in flight** against this bundle. Because `fullbook-graded`'s 26y
result is already recorded (**+287%, MaxDD 23.2%**), it measures specifically
what **rt + volume-at-fill add on top** — not what the bundle does from zero.

⚠ **Defect found during assembly:** `Range_top_breakout` was armed **without
`entry_anchor_local_range_weeks`**, the knob defining the `local_range_top` its
freshness test measures against. Live picks went to **zero candidates**; adding
`4` restored 20. `staging-record-convention/*` and the live picks config set
that knob **zero times**, so any bundle built on that base inherits the `0`
default. **A backtest smoke did not catch it** — armed without the anchor a
1-year cell gave 93 trades vs 35 for the control, a large plausible-looking
delta. That proved the field was *read*, not *correctly configured*.
**Liveness is not correctness.** (`project_rt_needs_its_anchor_knob`.)

---

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
| step 3 — build each axis behind its own flag | ✅ **3 of 3** (G3, G2a, G2b) |
| step 4 — one grid over all three + null | ready — A1-3 arms G3, then A1-4 |

### Sub-tasks

- [x] **A1-1 — Build G2a `entry_fill_reject_retries`** (retry). Built on
      `feat/arc-g2a-fill-retries`. Default-off `int`, default `0`
      (`experiment-flag-discipline.md` R1/R2/R3 — no ledger verdict exists, so
      it ships off). New `Trading_simulation.Entry_fill_retry` holds the run's
      budget + per-ticket ledger; on a refused entry fill it leaves the
      `Entering` position alone and re-submits a copy of the refused order so
      the engine re-offers it next tick, up to N times, instead of the ticket
      being destroyed. Threaded through `Simulator.create_deps` from
      `panel_runner`. At `0` `handle_rejected_entries` returns its input list
      itself — no ledger write, no order-manager call — so the cancel path is
      bit-identical and no golden moved. Axis reachability through the real
      `Overlay_validator.apply_overrides` is pinned for `(0 1 2)` in
      `test_runner_hypothesis_overrides.ml`. Also pays back the file-length
      budget it consumed: `Simulator._compute_benchmark_return` moved to the
      existing `Simulator_metrics` (simulator.ml 500 → 493, its declared-large
      cap is 500).
- [x] **A1-2 — Build G2b `entry_fill_size_to_available`** (resize). Built on
      `feat/funding-g2b`. Two default-off fields: `entry_fill_size_to_available`
      (`bool`, `false`) and its guard `entry_fill_min_size_fraction` (`float`,
      `0.5`, inert while the flag is off) — `experiment-flag-discipline.md`
      R1/R2/R3, no ledger verdict exists so it ships off. New
      `Trading_simulation.Entry_fill_resize` clamps a portfolio-refused entry
      fill to the largest whole-share quantity the cash floor accepts (paper-loss
      drag included) and books it **at the price the ticket triggered at**, so
      unlike G2a it pays no timing tax. Clamps below `min_size_fraction` of the
      designed quantity fall through to the unchanged destroy path. Threaded
      through `Simulator.create_deps` from `panel_runner` as one
      `?entry_fill_resize` value rather than two more optional scalars.
      **Precedence:** the resize runs *before* `Entry_fill_retry`, so retry
      budget is only spent on refusals the resize declined — pinned by a test
      that runs the real chain both ways (`(0, 1)` retries used). Also carries
      the #2466 guard: the `Entering` match requires the *entry* side, so a
      rejected exit is never claimed, and a claimed entry is removed from the
      list `Cancel_handler.revert_rejected_exits` scans (that scan matches on
      symbol alone, so an `Exiting` sibling on the same symbol would otherwise be
      reverted). Axis reachability for both fields pinned through the real
      `Overlay_validator.apply_overrides`. Pays back its own file-length budget:
      `Simulator._apply_transitions` moved to the existing `Cancel_handler`
      (simulator.ml 493 → 487, declared-large cap 500).
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
- [x] **A2-3 — Fill-model A/B: DECIDED 2026-08-20 as option B.**
      `project_fill_model_inversion` posed it as an explicit either/or — **(A)**
      align live to the record rule (market entry + deep floor: +8,367%, MaxDD
      37%, **one trade = 76% of it**) or **(B)** re-base records to the book
      ticket (~+280%, MaxDD 23%). The user's directive *"we will get faithful
      right first and then later chase down the performance gap"* **is** option
      B. Executed as the arc bundle below.

      **The deferred gap, stated plainly:** book ticket **+287%** vs record
      **+8,367%** vs **SPY-TR +687%** over the same 26y. The faithful arm
      currently runs *below buy-and-hold*. That is what "chase the gap later"
      means concretely.

- [ ] **A2-4 — Make the picks chart answer "how was entry picked?"**
      (`dev/plans/picks-chart-informative-2026-08-20.md`, PR #2453). The chart
      draws the **ticket** level (`entry`) while the level that governs
      **admission** (`breakout_price`) is invisible, and there is no date axis.
      Phase A (dates) needs no schema change; Phase B needs `schema_version`
      1 → 2 to emit `breakout_price` / `local_range_top` / Stage-2 start.
      Execution-correctness work, not a return lever.

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

**A1-4 — run the funding three-way grid** (G2a vs G2b vs G3 + null). All three
axes now exist: G3 was already built, G2a landed as #2463, G2b is built on
`feat/funding-g2b`. The comparison is *internal*, so the noise floor does not
gate it; A1-3 (arm G3 in a cell) is the only remaining set-up step. Sweep G2b's
`entry_fill_min_size_fraction` over `(0.25 0.5 0.75)` — the plan names it as the
knob to sweep, and it is the one dial that trades near-miss recovery against
undersized entries into the fat tail.

Also read the 26y arc-bundle result (in flight, PR #2452) against
`fullbook-graded`'s recorded +287% / MaxDD 23.2% — it isolates what rt +
volume-at-fill add.

Queued behind the container: the chart work (A2-4, PR #2453) and the
`.claude/worktrees` fix that unblocks A3-2 — both need `dune runtest`, and
agent waves cannot share the box with a backtest.

## Follow-ups

- **#2433 framing** ⚠ USER DECISION — held under `do-not-merge`. Both gates
  stale at `42da124b6`. The broad-5y result (#2448) bears on it: MaxDD agrees
  across both windows, but the **win-rate leg fails Rule 4 on broad-5y** and
  should no longer be quoted as a Rule-4 survivor without that counter-evidence.
- Two non-blocking observations on #2449 recorded rather than fixed: checker 3's
  two sanity probes mutually mask, and the `newest`-by-git-log-vs-filename bound
  is not discriminated because the fixture's filename order coincides with its
  commit order.
