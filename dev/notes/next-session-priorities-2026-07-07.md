# Next-session priorities — 2026-07-07

**Supersedes** `next-session-priorities-2026-07-06.md`. Main green.

## What 2026-07-05→06 delivered (all merged / in this PR)

1. **P0 envelope pair-sweep CANCELLED — premise false (#1861).**
   `min_cash_pct` / `max_long_exposure_pct` / `max_positions` are dead code
   (`Portfolio_risk.check_limits` has zero production callers); backtests
   already run **89–99% deployed**. The ~9h sweep would have been 9
   bit-identical cells. Writeup: `dev/notes/envelope-knobs-dead-2026-07-05.md`.
   Consequence: the envelope cannot be loosened without margin → the
   continuation-add revisit precondition is unsatisfiable → **scale-in stays
   closed, permanently** (within current architecture).
2. **P2 shipped end-to-end:** `early_stage2_max_weeks` knob (#1862, default 4,
   both use sites, axis-reachable; triple-gated) → broad 13×2y WF-CV surface
   {2,4,6,8} → **REJECT alternatives; ≤4 empirically validated** (ledger
   `2026-07-06-early-stage2-window-surface`, writeup
   `dev/notes/early-stage2-window-wfcv-2026-07-06.md`). Key transferable
   finding: **entry-breadth ≠ universe-breadth** — widening admission
   manufactures breadth from staler entries (monotonic bear-fold tax); the
   lever question sharpens to "fresh opportunities or stale entries?"

3. **Cash-reserve experiment RUN AND RESOLVED (user-directed, 2026-07-06):**
   working `cash_reserve_pct` mechanism (#1867, default 0.0, triple-gated) →
   broad 13×2y WF-CV surface {0.10, 0.20, 0.30} → **REJECT all** (ledger
   `2026-07-06-cash-reserve-surface`, writeup
   `dev/notes/cash-reserve-wfcv-2026-07-06.md`). The asked-about 30% reserve
   is a clear loss (Sharpe 0.44 vs 0.60, worse in the 2022 bear fold).
   Response is non-monotonic (funding-reshuffle path-dependence; r20's
   aggregate spike = one flipped fold, not promotable — knife-edge class).
   **Envelope program closed BOTH directions.** Capital-protection lever of
   record: the barbell overlay.

## Decision items for the human (from the envelope finding)

- **Wire-or-delete `check_limits`** — a limits API that looks load-bearing but
  is test-only produced two wrong premises (2026-06-25 misread + the P0). If
  wired: it would CHANGE behavior (currently NO aggregate exposure / position
  count / cash floor exists) — that's a strategy change needing its own
  surface. If deleted: dead fields leave the config. Either way, cross-module;
  needs explicit approval. (The cash-floor half is now settled — reserve
  tested and rejected — so DELETE is the natural resolution unless the
  aggregate-exposure/position-count checks are wanted for live safety rails.)

## Open threads (carried, in rough priority order)

1. **P4 — continuous-RS scoring (display/UX only).** Spreads the A-tier tie at
   70 by folding in `rs_vs_spy` magnitude. RS-as-return-lever is WF-CV-rejected
   (#1788) — scope strictly as live-picks display sharpening, no default
   change.
2. **Decision-audit follow-ups:** RS-coverage harness gap (~77%
   `rs_value=None` in sp500 audits); weekly-picks Phase-2 forward-return
   counterfactual once a 2026 window matures.
3. **Faithful per-week universes (M6.6)** — per-week eligibility builder for
   the historical weekly-picks series. Deferred.
4. Catastrophic-stop sibling alignment (#1831 review) — inert, unchanged.
5. Harness gap (small): `write_ledger_entry.exe` doesn't regenerate
   `index.sexp` (this session hand-appended the row).

## Strategic context (unchanged, sharpened)

Entry-selection exhausted; intra-envelope reallocation exhausted; envelope
fixed at ~100% (no loosening without margin); admission window validated at
the book's value. The remaining evidenced directions: preset bundles
(trader/investor per `weinstein-faithful-core.md`), the barbell overlay
(70/30 passed its grid), and product/display work on the live weekly picks.
Two consecutive surfaces validated book dials (volume-1.5×, ≤4-week window) —
the Weinstein spine keeps proving load-bearing; arbitrary knob-space remains
flat.

## Ops notes

- `walk_forward_runner` needs `TRADING_DATA_DIR` passed via `docker exec -e`
  (or exported in the launched shell) — otherwise relative `universe_path` in
  base scenarios resolves against the wrong data root and the run dies at fold
  dispatch.
- Docker.raw 21G / host 89G free at session end; sweep artifacts copied to
  `dev/experiments/early-stage2-window-2026-07-05/`, `/tmp/sweeps` scratch can
  be cleaned.
