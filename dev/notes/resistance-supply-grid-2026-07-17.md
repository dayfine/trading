# resistance-v2 confirmation grid — 3/3 CONFIRM, mechanism ACCEPT (2026-07-17)

Ledger: `2026-07-17-resistance-supply-confirmation-grid.sexp` (verdict
**Accept** at mechanism level; **default flip = pending human decision**,
R3). Follows the 07-16 home surface (Inconclusive, boundary winner).

## The grid (mean fold Sharpe; per-cell best bolded)

| cell | baseline | w=15 | w=30 | w=45 | w=60 |
|---|---:|---:|---:|---:|---:|
| broad top-3000, 2000-26, 13×2y (home) | 0.691 | 0.787 | 0.860 | **0.897** | 0.772 |
| sp500-515, 2000-26, 26×1y | 0.396 | **0.623** | 0.552 | — | — |
| broad top-3000, 2011-26, 7×2y | 0.619 | 0.696 | **0.825** | — | — |

- **Interior found**: the home curve is a clean concave hump peaking ~45,
  rolling off at 60 — the 07-16 boundary objection is resolved.
- **Universe + geometry transfer**: sp500 cell (different universe AND 1y
  folds) — both weights beat baseline; optimum shifts LOWER on the narrow
  universe (breadth-dependent optimum; the capacity-surface pattern).
- **Period transfer**: 2011-26 cell — w=30 0.825 vs 0.619, with fold-Sharpe
  σ collapsing 0.566 → 0.223 (the consistency gain is the headline there).
- **Robust value per promotion-confirmation.md: w=30** (beats baseline in
  all three cells, never badly dominated). Per-cell winners (45/15) are not
  the promotable value. w=15 = the conservative alternative (also 3/3).
- Macro diversity: the two 2000-2026 cells span dot-com + GFC; 2011 is the
  bull-heavy favorable check.

## Why promotion is NOT automatic (the flag for the human decision)

The 28y single-path pair (dedup-v3, certified): baseline +7,914% (bit-equal
Run D) vs w=30 **+1,991%** — identical trade count, better DD (29.0 vs
32.3), fold means all favor w=30, yet terminal wealth is ¼. The AXTI
forensic explains it: the penalty structurally excludes the crash-recovery
monster cohort (AXTI-2025 had 97/130 recent weeks overhead at its $2.18
entry — the score was CORRECT), and when AXTI became genuinely virgin at
$11-17 (Dec-25/Jan-26) it was permanently inadmissible (stale per
`early_stage2_max_weeks`). **Supplied monsters: denied at birth, stale at
redemption.** Fold-reset compounding favors w=30 (+3,020% vs +2,350%
compounded fold returns); contiguous-path compounding reverses it because
the record's wealth is one financed monster chain.

Decision inputs the promotion needs:
1. **Terminal-wealth distribution across many paths** (rolling-start
   matrix), not one draw — does w=30 shift the wealth distribution's
   median up enough to accept losing the right tail's lottery mass?
2. Optionally, the **virgin-crossing re-admission** lever (below) built
   default-off FIRST — it restores access to redeemed monsters and would
   plausibly convert the w=30 trade-off from "sell the lottery ticket" to
   "re-buy it at 6× the price for ⅓ of the payoff, with far better risk."

## Designed follow-up levers (all default-off, sequenced)

1. **Virgin-crossing re-admission** — when a Stage-2 name crosses above its
   520w max on volume, treat as a fresh admissible breakout (book-faithful
   "new high ground" entry; entry-side, tail-PRESERVING). Direct product of
   the AXTI post-mortem.
2. **Regime softener** — `effective_w = w × (1 − k × index_supply_score)`;
   modulator must be STATE-based (distance-below-prior-highs, price-vs-MA,
   macro stage), never event-based (no reversal/bottom calls — user
   constraint 07-16). Axis k ∈ {0, 0.5, 1}; only testable on the deep grid
   (~2 recovery episodes in 26y).
3. **`stale_old_floor` axis {0, 0.1, 0.3}** — is a 5-10y-old top real
   supply or psychology? (AXTI data note: its saturation came from RECENT
   supply, so this axis only matters for floor-bound names.)
4. **RS-laggard metric variant** — laggard rotation ranked by RS-slope
   instead of return (loser-touching, safe class).
5. **Supply-located stop tightening** — tighten trail when a holding climbs
   into its own dense overhead zone (insurance class, ext-stop precedent).

## Artifacts

- Sweeps: `/tmp/sweeps/resist-supply-{ext,sp500,2011}` (reports + fold
  actuals + aggregates).
- Specs committed: `test_data/walk_forward/resistance-supply-weight-
  {EXT-BROAD-2000-2026,SP500-2000-2026,BROAD-2011-2026}.sexp`.
- Warehouses: `/tmp/snap_top3000_dedup_v3_sketch` (certified),
  `/tmp/snap_sp500_2000_2026_v3_sketch` (521 symbols). dedup-v2 dir now
  safe to delete.
- 28y pair: `dev/backtest/scenarios-2026-07-16-131756/` (baseline
  bit-identity = the v3 certification of record).
