# Status: stage-accuracy

## Last updated: 2026-08-23

## Status
IN_PROGRESS

## Interface stable
YES

## Where this track actually stands (reconciled 2026-08-23)

**This is a rejection streak, not a stall.** Both mechanisms this track set out
to build were built, tested, swept, and **rejected as defaults**; they survive
as default-off `Variant_matrix` axes, which is the intended terminal state for
a mechanism with no ledger ACCEPT (`experiment-flag-discipline.md` R1/R2). The
track has produced no PR since **#1864 (`14fbf64a`, 2026-07-06)** and this file
was untouched from 2026-06-06 to 2026-08-23 (78 days). The track pacer flagged
that on 07-12, 07-19, 07-26, 08-02, 08-09, 08-16 and 08-23 — seven asks. This
section is the answer.

Verified on main 2026-08-23:

- `late_stage2_stop_runner.{ml,mli}` and `macro_bearish_trim_runner.{ml,mli}`
  both exist and have **no commits since 2026-06-06**.
- All four config fields are present and at their no-op defaults in
  `weinstein_strategy_config.ml`: `enable_late_stage2_stop_tighten = false`,
  `late_stage2_stop_buffer_pct = 0.0`,
  `enable_macro_bearish_exposure_trim = false`,
  `macro_bearish_max_long_exposure_pct = macro_bearish_no_op_cap`.
- Neither mechanism is Rule-4 retirement-eligible. The flag inventory
  (`dev/notes/mechanism-flag-inventory-2026-08-09.md`) initially listed
  `enable_late_stage2_stop_tighten` as RETIRE, then **reclassified it
  KEEP-AXIS** on a second pass (recorded there, and as A3-0 on the
  `arc-readiness` track, PR #2450) — its record reads *"available as an axis;
  no further investment"*, which is REJECT-as-legitimate-axis, not
  do-not-revive. `enable_macro_bearish_exposure_trim` was reclassified
  KEEP-AXIS on 2026-08-13 because **no ledger entry exists for it at all**, so
  Rule 4's required terminal REJECT citation cannot be made.

**What would restart the track: the broad-universe WF-CV re-run, and it is
data-gated.** Both sweeps to date ran on SP500 cells, which
`.claude/rules/universe-discipline.md` now forbids as a measurement surface;
re-running them on a broad (top-3000) universe needs EODHD data that is not
available in the GHA orchestrator environment. That blocker is systemic, not
track-specific — the pacer has carried it as the dominant capability gap for
several weeks across ~12 data-gated rows.

**Recommendation (not a decision):** this track is a candidate for closure or
for demotion to axis-maintenance. Both mechanisms are terminal-as-defaults and
the only live next step is blocked on a maintainer-level data decision. Whether
to close it, park it, or fold the remaining ideas into `arc-readiness` is a
maintainer call; this reconcile does not make it, and leaves the status keyword
at `IN_PROGRESS` accordingly.

---

P1 of the 2026-06-03 stage-lifecycle pivot
(`dev/notes/stage-lifecycle-pivot-diagnosis-2026-06-03.md`): wire the
already-computed-but-discarded `Stage2 { late }` MA-deceleration signal
into held-position risk management, instead of consuming it only at
entry. The diagnosis shows `late` fired weeks-to-months before 6 of 7
major single-name / index tops, while the strategy's actual de-risk
trigger (Stage-4 flip) lagged every top by 5-29 weeks (price already
down 5-44%).

## Completed

- **Macro-bearish held-exposure trim** (default-off, 2026-06-06). New
  module `Macro_bearish_trim_runner`
  (`trading/trading/weinstein/strategy/lib/macro_bearish_trim_runner.{ml,mli}`):
  on a screening (Friday) day, when the macro tape is confirmed `Bearish`,
  caps total held long exposure at
  `config.macro_bearish_max_long_exposure_pct` of portfolio value and
  exits the excess **weakest-RS-first** (reusing the laggard RS window
  return via the newly-exposed `Laggard_rotation_runner.window_return`).
  `0.0` = full flat; `1.0` (or higher) = no-op. Shorts never trimmed;
  never force-buys (re-entry naturally damped through the normal Stage-2
  breakout+volume screen). Wired into `weinstein_strategy.ml`
  `_process_market_day` as `_run_macro_bearish_trim`, after
  `_run_special_exits`; the macro result is hoisted into a new `_run_macro`
  helper (split out of `_run_macro_and_entries` → `_run_entries`) so the
  trend is available to the trim pass without computing macro twice.
  Respects the single-exit collision rule (skip-id union of stop /
  Stage-3 / laggard / force-liq exits).
  - Config fields (both default to baseline no-op):
    `enable_macro_bearish_exposure_trim : bool [@sexp.default false]`,
    `macro_bearish_max_long_exposure_pct : float [@sexp.default 0.70]`
    (mirrors the normal long cap → no-op even when flag flipped on).
  - Flag-discipline: default-off (R1, flag-off path bit-identical to
    baseline), real config fields → `Variant_matrix` flag + key axes
    (R2, pinned in `test_variant_matrix.ml`), NOT promoted (R3).
  - Weinstein-faithful: extends the macro gate (spine item #6) from
    "block buys" to "raise cash on a bear tape" — an exit-aggressiveness
    dial, book §Macro Analysis / §Stage 4. Spine untouched.
  - Tests: `test_macro_bearish_trim_runner.ml` (9 cases) — trim to cap,
    full-flat, under-cap no-op, no-op cap (1.0), non-positive portfolio
    value, shorts-not-trimmed, exit-reason label / never-force-buy,
    unranked-position-excluded, skip-id single-exit collision.
  - Plan: `dev/plans/macro-bearish-exposure-trim-2026-06-06.md`. Branch
    `feat/macro-bearish-trim`. Supersedes the late-dial as the deep-window
    DD lever (the late `late` flag resets on fast crashes; the macro gate
    fires early + persists through 2000/2008).

- **Late-Stage-2 trailing-stop tightening dial** (default-off). New
  module `Late_stage2_stop_runner`
  (`trading/trading/weinstein/strategy/lib/late_stage2_stop_runner.{ml,mli}`):
  on Friday ticks, raises the trailing stop of every held `Stage2
  { late = true }` long to `close * (1 - buffer_pct)`, never lowering an
  existing stop. Emits `UpdateRiskParams` adjust transitions (not
  exits). Wired into `weinstein_strategy.ml` `_process_market_day` via
  `_run_late_stage2_tighten`, gated on
  `config.enable_late_stage2_stop_tighten`.
  - Config fields (both default to baseline no-op):
    `enable_late_stage2_stop_tighten : bool [@sexp.default false]`,
    `late_stage2_stop_buffer_pct : float [@sexp.default 0.0]`.
  - Flag-discipline: default-off (R1), real config field → `Variant_matrix`
    flag axis (R2), NOT promoted / not wired into any preset (R3).
  - Weinstein-faithful: exit-aggressiveness dial (trader preset), book
    §Stage 3 detail "protect remaining half with tight sell-stop below
    support". Spine untouched.
  - Tests: `test_late_stage2_stop_runner.ml` (13 cases) — tighten on
    late Stage 2, no-op on every other stage / early Stage 2, never-lowered
    invariant (both directions), non-Friday / short-side / empty / missing
    stage / missing price no-ops.

## In Progress — nothing (merge record for #1446)

- **MERGED via #1446 (2026-06-04, squash `919e10a8`)** — `feat/late-stage2-stop-tighten`.
  QC structural APPROVED q=5 (review 4426367035) + behavioral APPROVED q=5
  (review 4426387423); all 3 merge gates green; auto-merged (Step 6.5).
  Audit `dev/audit/2026-06-04-late-stage2-stop-tighten.json`. The confirmation
  grid ran on 2026-06-06 and REJECTED the dial — see `## Outcome` item 1.
  **Nothing under this heading is in progress**; it is kept as the merge record
  for #1446.

## Next Steps

The old item 1 — "Confirmation grid — DONE 2026-06-06: REJECTED" — has been
moved to `## Outcome` below. It was a completed item sitting at the head of
this list for 78 days, which is what the pacer flagged seven times. None of
the three items below is currently dispatched; item 3 is a hard blocker on
the other two producing quotable evidence.

1. **Partial-trim variant** (separate larger PR): on `late`, trim the position
   toward a configurable fraction instead of (or in addition to) tightening the
   stop. Needs Position-core partial-exit support. **Not started; not
   currently queued.** Note the item-3 root cause below applies to it as well —
   `late` resets on fast crashes, so a trim keyed on `late` inherits the same
   blind spot the tightening dial died of. Worth re-screening
   (`.claude/rules/mechanism-validation-rigor.md`) before any build.
2. **Pair with the daily gap stop for fast vertical blow-offs** (2020-style),
   which reset `late` before the top — the gap stop, not `late`, catches those;
   do not weaken it. Standing guidance rather than a queued task.
3. **Blocked / data-gated: re-run both sweeps on a broad universe.** Required
   before any statement about these mechanisms' performance can be quoted as
   evidence at all (`.claude/rules/universe-discipline.md`: the existing SP500
   cells are valid rule-validation, invalid measurement). Blocked on EODHD data
   access in the orchestrator environment.

## Outcome — the two mechanisms, both rejected as defaults

1. **Late-Stage-2 stop tightening — REJECTED 2026-06-06.**
   (`dev/experiments/_ledger/2026-06-06-late-stage2-stop-tighten-grid.sexp`.)
   ⚠ Measured on SP500 cells, which `universe-discipline.md` now classifies as
   a rule-validation surface, not a measurement surface. The REJECT stands as a
   no-build decision; the numbers below should not be re-quoted as evidence.
   Swept `late_stage2_stop_buffer_pct ∈ {0.03,0.05,0.08}` × dial on/off on
   the deep (PIT-2000 SP500, 2000-2026, dot-com+GFC) and bull (PIT-2010,
   2010-2026) Cell E surfaces. The dial fires but is a clean REJECT:
   - **MaxDD unchanged to the basis point in BOTH windows** (37.32 deep,
     17.50 bull) — it does not cut drawdown, its entire design purpose.
   - **Buffer-insensitive** (0.03/0.05/0.08 byte-identical) — no tunable surface.
   - **Bull = complete no-op**; deep = a +321pp return bump (918→1239%) from
     ~1 trade (DD-neutral, Sharpe 0.70→0.76) = a single-episode capital-
     recycling artifact, not a robust improvement.
   - **Root cause:** the worst drawdowns are fast crashes (2000-02/2008/2020)
     that reset `late` before the top, so the dial never engages on the
     DD-defining episodes — which is why Next Step 2 (the gap stop) is the
     standing guidance and not this dial.

   Dial stays **default-off** + available as a `Variant_matrix` axis per
   flag-discipline; earns no further investment. The 2020-stall lever
   remains **breadth** (`project_cell_e_2020_stall_regime`), not this dial.
   Rule-4 classification: **KEEP-AXIS**, not RETIRE — see the reconcile note
   at the top of this file.

2. **Macro-bearish held-exposure trim — no ledger verdict, kept as an axis.**
   Built 2026-06-06 (see `## Completed`), never swept. The flag inventory
   records that `grep -rl macro_bearish dev/experiments/_ledger/` returns
   nothing, so there is **no ACCEPT and no REJECT** for it — it is neither
   promotable (R3 needs an ACCEPT) nor retirable (Rule 4 needs a terminal
   REJECT). Reclassified KEEP-AXIS 2026-08-13. `project_macro_bearish_trim_lever`
   describes it as regime-dependent.

## Follow-ups

- **The two SP500 sweep surfaces predate `universe-discipline.md`.** Nothing
  needs undoing — a no-build decision taken on a weak surface is still a valid
  no-build decision — but neither surface's figures may be quoted as evidence
  about strategy behaviour. If either mechanism is ever revisited, the broad
  re-run (Next Step 3) is the entry price.
