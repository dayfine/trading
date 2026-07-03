# capital-management-scale-in

Explore/exploit scale-in — the **reallocation** capital-management lever (P1
capacity/concentration frontier). Design: `dev/plans/capital-management-scale-in-2026-07-02.md`
(#1829). A 4-PR build; **v1 BUILT — all 4 PRs merged, default-off** (#1830–#1833; plan
marked BUILT v1 in #1835). **Empirical validation COMPLETE — two-cell WF-CV surface
(SP500 + top-3000) → REJECTED for promotion (ledger #1840); default stays off.**

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

## Empirical status (2026-07-03) — TWO-CELL SURFACE COMPLETE → **REJECTED** (ledger #1840)
- **Both WF-CV cells run (maintainer LOCAL); formal ledger REJECT written in #1840**
  (`dev/experiments/_ledger/2026-07-03-scale-in-v1-surface.sexp`; writeup
  `dev/notes/scale-in-wfcv-2026-07-03.md`; artifacts `dev/experiments/scale-in-wfcv-2026-07-03/`).
  - **Cell A — SP500-515 PIT-2000, 13 folds** (`out_sp500/`): scale-in is an outright
    **TAX** — mean Sharpe 0.92→0.78, mean return 36.1%→23.4%; 5/13 Sharpe wins (< 7),
    worst fold trails by Δ1.22 (> 0.30). Recovery-year monsters get half-sized at entry
    and never give the pullback that would restore full size.
  - **Cell B — top-3000 PIT-2000, 13 folds** (`out_top3000/`; the regime-diverse deep
    warehouse re-test run4 asked for): return dead-flat (~20%) with **mild risk
    smoothing** (`either_loose` best on every risk metric — DD 15.4→13.9, 2022 bear fold
    Sharpe −0.42→−0.03), but the +0.065 mean-Sharpe edge does **not** survive deflation
    (t≈0.5, n_trials≈5). Formal gate FAIL (6/13 Sharpe wins).
  - **Verdict: REJECT for promotion; mechanism KEEPS default-off axis status.** No default
    flip (experiment-flag-discipline R3 / promotion-confirmation).
- **Transferable why (in ledger):** (1) the half-sized initial entry is itself a fat-tail
  tax — under-sizing unpredictable winners is the same class as trimming them; (2) `Either`
  is structurally dead at `extension_max_pct=0.15` (breakouts already sit 10-20% above the
  30w MA) — only at ext≈0.25 does the continuation-add arm live and supply the risk benefit;
  (3) breadth reverses the sign — narrow SP500 has nowhere to redeploy the freed half so the
  tax dominates; broad redeploys and nets out (scale-in as designed is a diversifier, not an
  amplifier). **Validation bonus:** the surface caught the same-symbol-sibling fill mis-routing
  bug → fixed #1837.

## Next Steps
- **Lever REJECTED for return** — stop here on the current v1 shape. Default stays off
  (axis status retained). No further GHA-runnable code work on this track.
- **Only open forward path (data-gated / LOCAL, low priority per forward guidance):** if a
  smoother broad book is ever wanted, revisit the `either_loose` shape (Either + ext≈0.25) as
  tail-risk-lite — **possibly without the half-sizing** (full initial entries + continuation
  adds = pure press-the-winner, the un-taxed half of the idea). That is a *fresh surface*, not
  a re-run of v1; needs the deep/regime-diverse EODHD warehouse (absent in GHA).
- Non-blocking reconcile from PR 4 (inert while default-off): (a) plan §5 `max_adds` no-op
  default `0` vs impl `1`; (b) `early_new_high`'s ≥2-bar / above-entry clauses pinned only
  transitively. Address if/when the axis is ever searched again.

## Blocked on
None between tracks (code side complete; v1 REJECTED). Any future work (the un-taxed
press-the-winner fresh surface) is data-gated (deep/regime-diverse WF-CV warehouse; EODHD
key absent in GHA) and runs as maintainer LOCAL sessions.
