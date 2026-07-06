# capital-management-scale-in

Explore/exploit scale-in — the **reallocation** capital-management lever (P1
capacity/concentration frontier). Design: `dev/plans/capital-management-scale-in-2026-07-02.md`
(#1829). A 4-PR build; **v1 BUILT — all 4 PRs merged, default-off** (#1830–#1833; plan
marked BUILT v1 in #1835). **Empirical validation COMPLETE — two-cell WF-CV surface
(SP500 + top-3000) → REJECTED for promotion (ledger #1840); default stays off.**
**Post-REJECT participation measurement (#1843): the v1 add channel never physically
functioned** (adds emit as zero-width `StopLimit(close,close)` → structurally unfillable).
The add-channel-fix + book-faithful continuation-add build then shipped
(#1852/#1855/#1856, `Consolidation_breakout` trigger + `add_fraction` knob, default-off)
and its broad-only WF-CV surface was run → **v2 REJECT (#1860, ledger
`2026-07-05-continuation-add-v2-surface`).** **PROGRAM CLOSED: both halves tested and
rejected; mechanisms stay merged default-off + searchable. Standing directive — stop
proposing intra-envelope capital-reallocation variants.**

## Status
MERGED

<!-- Program CLOSED. Mechanisms merged default-off (v1 #1830–#1833, v2 #1855); both surfaces
REJECTED (v1 #1840, v2 #1860). No further variants; class exhausted per 2026-07-06 directive. -->


## Last updated: 2026-07-06

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

## Participation finding (2026-07-03, #1843) — the v1 add channel never functioned
- Instrumented per-fold participation (`dev/experiments/scale-in-participation-2026-07-03/RESULTS.md`)
  found the scale-in **add channel is structurally non-functional in v1**: adds emit as
  zero-width `StopLimit(close, close)` at Friday's close (`Weinstein_order_gen._entry_order`
  reused verbatim) → a gap-up triggers the stop but the limit can never fill; only adverse
  retreat-to-close fills are possible. 4/4 observed fills collided with same-day parent exits.
- **`either_loose`'s broad "risk-smoothing" re-attributed:** it is a Friday cash-reservation
  throttle (funded-but-unfillable adds deduct ≈$590–736k cumulative/fold from the same-Friday
  entry budget) + path divergence — **not** continuation-adds. Confirmed via in-fold-011 proof
  (pullback has more breadth, 120 vs 98 entries, yet ≈ baseline). Ledger amended in-place (#1843).
- **Consequence:** the v1 REJECT stands, but the "un-taxed press-the-winner" shape was never
  actually tested — it was blocked by three pinned defects (below), not disproven.

## v2 continuation-add surface (2026-07-05) — **REJECT** (#1860, ledger `2026-07-05-continuation-add-v2-surface`)
- The add-channel-fix + book-faithful continuation-add build shipped (#1852 plan, #1855
  `Consolidation_breakout` trigger + `add_fraction` knob, #1856 broad-only WF-CV surface
  spec) — full-size initial entries + book-faithful adds (Ch. 3 §The Trader's Way),
  default-off, triple-gated. This *was* the "un-taxed press-the-winner" test #1843 said the
  v1 REJECT had left undone.
- **Verdict: REJECT** (writeup `dev/notes/continuation-add-v2-wfcv-2026-07-05.md`): gate FAIL
  on all variants; the faithful trigger is too rare to matter (5–6/13 folds unchanged);
  regime-mixed when it fires (f010 +10.7pp vs f007 −15.7pp); a 1.5× volume filter removes
  both the harm and the edge; full-size adds are financed by *displaced entries* — **breadth
  is the edge** (9th fat-tail confirmation).

## Next Steps
- **PROGRAM CLOSED — no active work.** Both halves tested + rejected: v1 ½-sizing (fat-tail
  tax, #1840) and v2 book-faithful continuation adds (flat redistribution, #1860). Mechanisms
  stay merged, default-off, searchable. Per the 2026-07-06 standing directive
  (`dev/notes/next-session-priorities-2026-07-06.md`): **stop proposing intra-envelope
  capital-reallocation variants** (v1, v2, harvest-rotate, laggard-cap, macro-trim — the class
  is exhausted).
- **Architectural blocker on any revisit:** the sizing envelope cannot be *loosened* — actual
  deployment is already 89–99% invested and the `check_limits` battery is dead code in the sim
  path (`dev/notes/envelope-knobs-dead-2026-07-05.md`, #1861). Continuation adds have no free
  capital to redeploy into; the precondition for revisiting is unsatisfiable in the current
  architecture. Any future envelope experiment would be a *tightening* mechanism (working
  cash-reserve flag, default-off — likely a breadth tax); that is a **decision item**, not a
  next step.
- Non-blocking reconcile (inert while default-off, address only if the axis is ever searched
  again): (a) plan §5 `max_adds` no-op default `0` vs impl `1`; (b) `early_new_high`'s ≥2-bar /
  above-entry clauses pinned only transitively.

## Blocked on
None. Program closed — no in-flight work. Any revisit is a fresh surface, data-gated
(deep/regime-diverse EODHD warehouse absent in GHA) + architecturally blocked (unsatisfiable
loosening precondition), and would run as a maintainer LOCAL decision, not a feat-agent dispatch.
