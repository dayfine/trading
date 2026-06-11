# Status: harvest-rotate

## Last updated: 2026-06-11

## Status
MERGED

## Outcome (2026-06-11): WF-CV REJECT — mechanism stays default-off, axis NOT promoted

The full rigorous test ran end-to-end (Steps 1–5 all merged: #1525 core
partial-exit, #1528 mechanism, #1530 WF-CV surface spec, #1532 WF-CV REJECT +
decomposed why). **Verdict: REJECT (WF-CV-grade).** No `harvest_fraction` passes
the per-fold gate (k033 7/15, k050 8/15 but worst-fold ΔSharpe 1.57, k100 6/15).
Decomposed *why* (the deliverable): harvest-rotate is **dispersion-amplifying
noise, not Sharpe edge** — best variant Sharpe 0.627 ≈ baseline 0.645 while return
σ inflates 1.64×; the gate-killer worst-folds are exactly where baseline rode
winners to high Sharpe and harvest trimmed them (the structural tax — a quantified
instance of `project_edge_is_the_fat_tail`). Mechanism remains default-off
(`enable_harvest_rotate=false`, bit-identical baseline); not promotable. Ledger:
`dev/experiments/_ledger/2026-06-11-harvest-rotate-top3000.sexp`; writeup +
outputs: `dev/experiments/harvest-rotate-wfcv-2026-06-11/`.

## Interface stable
YES

Step 2 of `dev/plans/harvest-rotate-rigorous-test-2026-06-10.md`: implement
harvest-rotate as a **default-off config surface** so it can be backtested as a
variant under WF-CV. The mechanism trims a fraction of every held long whose
current stage is `Stage2 { late = true }` (the earliest Stage-3 topping
precursor) and recycles the freed capital through the existing entry pipeline
into a fresh Stage-2 leader.

Background: the read-only screen
(`dev/experiments/harvest-rotate-validation-2026-06-10/`) was **inconclusive**
(coin-flip per decision, no exploitable edge, mild tail-risk) — not a rejection.
Per `.claude/rules/mechanism-validation-rigor.md`, only the WF-CV surface test
can reject the mechanism. This track builds that surface.

## Completed

- **Step 1 — core partial-exit transition** (MERGED via #1525). Strategy-agnostic
  `TriggerPartialExit { exit_reason; exit_price; target_quantity }` on
  `Position.t`: `Holding(q) → Exiting → Holding(q − trim)` round-trip, remainder
  keeps tracking its stop on the reduced quantity.

- **Step 2 — harvest-rotate mechanism** (default-off, 2026-06-10, this PR). New
  module `Harvest_rotate_runner`
  (`trading/trading/weinstein/strategy/lib/harvest_rotate_runner.{ml,mli}`): on a
  screening (Friday) day, for every held **long** in `Stage2 { late = true }`,
  emits a `TriggerPartialExit` trimming `held_quantity *. harvest_fraction` at the
  current close. Decoupled MVP — the runner does NOT detect/pair a specific
  cash-blocked candidate; freed capital recycles through the existing entry path
  next cycle (the blocked-candidate entry-coupling is a deliberate later
  refinement, deferred). Long-only (shorts never trimmed); non-`Holding` states
  skipped. Wired into `weinstein_strategy.ml` `_process_market_day` as
  `_run_harvest_rotate` (mirrors `_run_late_stage2_tighten`); transitions threaded
  into `_assemble_output` (exit-side) and filtered against the full-exit skip-id
  union so a position already being closed is not also trimmed.
  - Config fields (both default to baseline no-op):
    `enable_harvest_rotate : bool [@sexp.default false]`,
    `harvest_fraction : float [@sexp.default 0.5]` (0.5 = sell half; 1.0 = full
    rotate; ≤ 0.0 = no-op).
  - Flag-discipline: default-off (R1, flag-off path bit-identical to baseline —
    runner short-circuits to `[]`), real config fields routable through
    `Overlay_validator` → `Variant_matrix` axis (R2), NOT promoted (R3).
  - Weinstein-faithful: the **exit-aggressiveness** dial ("sell half as the
    Stage-3 top forms") + **rotate-into-leadership**, both Weinstein's "The
    Trader's Way" (book §Stage 3 detail, Ch. 2: "Investors: sell half, protect
    remaining half"). Spine untouched (stage classification, Stage-2-only entries,
    breakout+volume, macro/sector gate, RS all unaffected).
  - Tests: `test_harvest_rotate_runner.ml` (13 cases) — trim half at close,
    fraction plumbs through (0.33), full rotate at 1.0, no-trim for
    early-Stage2 / Stage1 / Stage3 / Stage4, zero-fraction no-op, non-Friday
    no-op, short-side no-trim, empty/missing-stage/missing-price no-ops.

## In Progress

- (none — all steps complete; track closed REJECT)

## Next Steps

- (none — Steps 3–5 complete, mechanism REJECTED at WF-CV. Step 3 axis wiring was
  FREE — config fields resolve generically via `Overlay_validator`. Step 4 WF-CV
  surface (#1530) had all variants FAIL the per-fold gate. Step 5 decision/ledger
  recorded REJECT — `dev/experiments/_ledger/2026-06-11-harvest-rotate-top3000.sexp`.
  See §Outcome above.)

## Follow-ups

- **Partial-exit audit capture.** `Exit_audit_capture.emit_exit_audit` currently
  handles only `TriggerExit` (full exits); harvest-rotate `TriggerPartialExit`
  transitions are piped through it but are a no-op there, so their MFE/MAE
  excursion metrics default to 0.0. Extending the exit audit to partial exits
  (a different, non-closing MFE/MAE semantics) is deferred to a separate change.
- **Blocked-candidate entry coupling.** The MVP recycles freed capital through
  the normal entry path; pairing the trim atomically to a specific blocked,
  better-ranked candidate (the `alternatives_considered` / `Insufficient_cash`
  signal) is the later refinement named in the plan.
