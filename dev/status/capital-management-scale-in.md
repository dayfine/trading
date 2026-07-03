# capital-management-scale-in

Explore/exploit scale-in — the **reallocation** capital-management lever (P1
capacity/concentration frontier). Design: `dev/plans/capital-management-scale-in-2026-07-02.md`
(#1829). A 4-PR build; **v1 BUILT — all 4 PRs merged, default-off** (#1830–#1833; plan
marked BUILT v1 in #1835). Next is empirical validation before any promotion.

## Status
IN_PROGRESS

## Last updated: 2026-07-03

## Interface stable
NO

## Ownership
dayfine (maintainer, LOCAL sessions). Orchestrator QCs + merges the PRs as they land.

## Completed
- PR 1 (#1830) — `Fill_router` extraction (side-aware fill routing). MERGED.
- PR 2 (#1831) — `Stops_runner` advances the shared per-ticker Weinstein stop
  state machine **once per tick** via a per-`update` memo/replay
  (`Stop_transitions`), so scale-in siblings on one ticker don't double-advance.
  Bit-identical today (one position per ticker). QC APPROVED (structural + behavioral 4/5),
  3-gate auto-merged this run.
- PR 3 (#1832) — pure `Scale_in_detector` (pullback-hold / early-new-high / extension-gate
  predicates) + **default-off** config (`enable_scale_in=false`, `initial_entry_fraction=1.0`).
  No-behavior-change land; nothing consumes the flag yet. Faithful Weinstein ½+½
  "Trader's Way" dial (W1/W2 PASS). experiment-flag-discipline R1/R2 PASS. QC APPROVED
  (structural + behavioral 4/5), 3-gate auto-merged this run.
- PR 4 (#1833) — the scale-in **runner + strategy wiring** (default-off). Wires
  `enable_scale_in` + `Scale_in_detector` into `on_market_close`; the `Holding → add`
  transition of plan §4 landed as a **sibling position** (own id/lifecycle, same symbol,
  shared per-ticker stop) — same behavior, no core state-machine change. Merged directly
  (maintainer LOCAL session, 2026-07-03T04:33Z). Plan marked BUILT v1 in #1835. **v1 build
  complete; nothing changes backtest results until the flag is flipped.**

## Empirical status (2026-07-03)
- **First WF-CV surface run (SP500, maintainer LOCAL, landed via #1837)** →
  `dev/experiments/scale-in-wfcv-2026-07-03/out_sp500/walk_forward_report.md`.
  13 folds. **Both `scale_in_pullback` and `scale_in_either` FAIL the go/no-go
  gate**: 5/13 Sharpe wins (< 7 required); worst fold (fold-002) trails baseline
  by Δ1.222 (> 0.30). Scale-in also *lowers* mean return (36.1%→23.4%) and Sharpe
  (0.92→0.78) vs baseline across the folds. → **v1 not promoted; default stays
  off** (experiment-flag-discipline R3 / promotion-confirmation). No ledger entry
  written yet (a formal REJECT entry would close the loop). `out_top3000` not run
  (spec present; deep warehouse still absent). Next surface must be regime-diverse
  and/or the mechanism redesigned before re-testing.

## Next Steps
- **Empirical validation (data-gated / LOCAL)** before any promotion, per plan §6:
  (1) express `enable_scale_in` as a `Variant_matrix` axis; (2) bear-inclusive WF-CV on a
  deep, regime-diverse warehouse; (3) the §3.4 monster-under-sizing instrumentation;
  (4) confirmation grid (`promotion-confirmation.md`). Default stays off until a ledger
  ACCEPT + grid pass. Blocked in GHA: needs the EODHD warehouse (key absent) → maintainer
  LOCAL / data-gated.
- Non-blocking reconcile from PR 4: (a) plan §5 `max_adds` no-op default `0` vs impl `1`
  (inert while default-off) — reconcile if it matters when the axis is searched;
  (b) `early_new_high`'s ≥2-bar / above-entry clauses pinned only transitively.

## Blocked on
None between tracks (code side complete). The remaining work — empirical scale-in
axis promotion — is data-gated (deep/regime-diverse WF-CV warehouse; EODHD key absent in
GHA) and runs as maintainer LOCAL sessions.
