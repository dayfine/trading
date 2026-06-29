---
name: project_screener_alphabetical_tiebreak
description: "Shared screener selects over-subscribed candidates by score-desc then ALPHABETICAL ticker tiebreak + cap — affects BACKTESTS too, not just live snapshots; magnitude bounded by tie-density"
metadata: 
  node_type: memory
  type: project
  originSessionId: 697feacb-3bb3-4fcf-b0b1-2706070b55c0
---

The Weinstein screener (`analysis/weinstein/screener/lib/screener.ml`, the
`_sort`/`_filter_and_cap` used by `_evaluate_longs/_shorts`) orders candidates
**score descending, then `String.compare ticker` (alphabetical) as the tiebreak**,
then caps at `max_buy_candidates` (default 20). The code comment (lines ~224-233)
explicitly acknowledges tied-score candidates "land on either side of a
cash-budget boundary depending on position in the sorted list" — the alphabetical
tiebreak was added for **determinism** (reproducible backtests), knowingly
arbitrary.

**This is the SHARED core — backtests use it, not just the live weekly snapshot.**
`Weinstein_strategy` → `weinstein_strategy_screening.ml:416` calls
`Screener.screen_with_cooldown` → same `_screen`; `entry_assembly.ml` consumes the
already-sorted+capped `buy_candidates`. So when a backtest is **over-subscribed**
(more qualifying Stage-2 breakouts than the cap / cash / exposure allows — common
in a broad bull), selection among **tied-score** candidates at the boundary is
**alphabetical** → systematic skew toward A-tickers. (Discovered 2026-06-28 via
the 2026-H1 live review: AIT appeared 12/26 weeks; same A-names repeated.)

**Magnitude is bounded, two mitigants:**
1. Bias bites only the **marginal tied group at the cap/cash boundary** — the
   highest-scored names are selected on merit; alphabetical only decides the
   cutoff ties. Not "all picks alphabetical."
2. The live 2026-H1 snapshots were a **worst case**: `data/sectors.csv.manifest`
   was missing → the +10 `w_sector_strong` differentiator never applied → every
   Early-Stage2+strong-vol+RS+clean-resistance candidate collapsed to exactly
   **70** → pure alphabetical. **Backtests have sector data**, so scores spread
   more (sector +10, RS-crossover +10, etc.) → fewer exact ties → less skew.
   Quick live fix: run `fetch_finviz_sectors.exe` to populate the manifest.

**Does picking "better" among ties even help? Prior evidence says probably NOT**
— this is the key tension for issue #1782 (quality ranking):
- [[project_cascade_selection_inversion]] — cascade score anti-predictive at top grade.
- [[project_accuracy_is_unreachable_diversify_instead]] — winners≈losers at ENTRY;
  cascade-reweight was **WF-CV-REJECTED** (taxed the tail); breakout success is
  unpredictable at entry by design.
- [[project_edge_is_the_fat_tail]] — return is a few right-tail monsters you can't
  pick in advance; winner-touching mechanisms keep getting rejected.
So alphabetical-among-ties may be ≈ as good as any score-ranked selection for
RETURNS, because the score isn't predictive of the monster.

**RESOLVED 2026-06-29 — built + WF-CV-tested + REJECTED for default-flip.** PR #1786
shipped `Screener.config.candidate_ranking` (default `Alphabetical` = current,
bit-identical; `Quality` = RS-mag→earliness→volume tiebreak), default-off axis.
Breadth-grid WF-CV (top-500/1000/3000 PIT-1998, 2000-2026, 13 folds; warehouses
`dev/data/snapshots/wfcv-top{500,1000,3000}-1998`; ledger
`2026-06-29-candidate-ranking-tiebreak-grid`, verdict **Reject**):
- **Quality FAILS do-no-harm:** lower Calmar in ALL 3 cells, lower Sharpe in 2/3,
  **dominated in narrow top-500**. Only consistent gain = lower dispersion/higher
  DSR — insufficient. top-1000 looked favorable (triggered the grid) but was the
  EXCEPTION → promotion-confirmation save.
- **WHY:** RS-magnitude-PRIMARY picks the most EXTENDED (run-up) names among ties —
  the "don't buy extended Stage-2" anti-pattern — mildly taxing the fat tail/Calmar.
  Alphabetical (random w.r.t. RS) diversifies → as-good-or-better. Confirms
  [[project_edge_is_the_fat_tail]] (chasing strength can select-AGAINST the tail).
- **DISTORTION Q ANSWERED:** alphabetical DOES reshuffle per-fold broad results
  (10-30pp), but is NOT inferior (marginally better Calmar/Sharpe) → **prior corpus
  NOT degraded, no re-pin**. Keep `Alphabetical` default; mechanism stays a
  default-off axis (no revert).
- **Forward directive:** if revisited, test **earliness-PRIMARY** ordering (fresh >
  extended), not RS-primary. Live-UX de-dup of repeat picks still has standalone
  value via the same axis, but it does NOT improve backtest returns.
