# Continuation-add v2 WF-CV — REJECT for promotion (scale-in program closed)

**Mechanism:** the book's continuation buy (Ch. 3 §The Trader's Way) as a
scale-in add trigger — full-size initial entries + full-size adds on a
consolidation-near-MA breakout with volume (plan #1852, mechanism #1855,
spec #1856). **Ledger:** `2026-07-05-continuation-add-v2-surface` (Reject).
**Artifacts:** `dev/experiments/continuation-add-v2-2026-07-05/out_top3000/`.

## Design

Broad-only (top-3000 PIT-2000, the decisive cell; NO sp500 per user
directive), 2000–2026, thirteen 2y non-overlapping folds, production caps +
catstop, Cell-E long-only + stage3/laggard. Variants (4 trials):
`baseline`, `cont_add` (fraction 1.0 + `Consolidation_breakout` @ ext 0.25),
`cont_add_tight` (band 0.06), `cont_add_vol` (volume ratio 1.5).
First-fold sanity pre-run: adds emit AND fill (COHU sibling add verified;
trades.csv trustworthy post-#1847).

## Results

| Variant | Sharpe μ±σ | Return μ±σ | MaxDD μ | Sharpe wins | worst-fold gap |
|---|---|---|---|---|---|
| baseline | 0.597 ± 0.494 | 19.9 ± 20.6 | 15.4 | — | — |
| cont_add | 0.567 ± 0.455 | 19.2 ± 22.5 | 15.7 | 4/13 | 0.497 (f007) |
| cont_add_tight | 0.566 ± 0.468 | 19.1 ± 20.2 | 15.2 | 3/13 | 0.497 (f007) |
| cont_add_vol | 0.595 ± 0.502 | 20.2 ± 22.9 | 15.7 | 4/13 | 0.172 (f009) |

Gate (m=7/13 Sharpe wins, worst-Δ 0.30): **FAIL for all three.** Means at or
below baseline — no DSR question arises.

## The why (the part that transfers)

1. **The trigger is as rare as the book intends — and that's low power.**
   5–6 of 13 folds are bit-identical to baseline (no add changed anything):
   the stacked gates (4-week tight band near the MA + volume + not-late +
   ext 0.25 + max_adds 1 + sole-holding) admit only a handful of adds per
   two-year fold. Faithful selectivity ⇒ few shots ⇒ the aggregate is decided
   by a handful of fold-level coin flips.
2. **When adds fire, the outcome is regime-mixed.** Fold-010 (2020–21
   monsters): the press-the-winner works exactly as the book describes —
   +10.7pp return, Sharpe 1.30→1.41, DD flat. Fold-007 (2014–15): the same
   mechanism presses into mean-reversion, −15.7pp, Sharpe 1.16→0.66 — the
   worst-fold gate breach.
3. **Volume confirmation is the load-bearing dial.** `cont_add_vol` (1.5× vs
   1.25×) blocked exactly the fold-007 damage (29.77% ≈ baseline 30.15%)
   while keeping the fold-010 win, and is the only variant passing the
   worst-Δ condition (0.17 < 0.30) — but it lands dead on baseline
   (Sharpe 0.595 vs 0.597). The book's "impressive volume" emphasis is
   empirically correct: the low-volume continuation breakouts are the ones
   that fail. Filtering them removes the harm — and with it, any edge.
4. **Root cause (9th confirmation of `edge_is_the_fat_tail`, new angle):**
   under the always-binding cash constraint (~10 `Insufficient_cash` skips
   per Friday), a full-size add is financed by displaced new entries. Even
   the book's own trader-mode press-the-winner is a reallocation INTO
   already-held winners OUT OF breadth — and breadth is the edge. The
   redistribution nets zero at best.

## Program closure

Scale-in is now tested on BOTH halves, both rejected for promotion:

- **v1 (½-sizing + adds):** REJECT — the ½-entry is an explore-side fat-tail
  tax (ledger `2026-07-03-scale-in-v1-surface`).
- **v2 (full-size + book-faithful continuation adds):** REJECT — flat
  redistribution; the faithful trigger fires too rarely to matter and its
  wins/losses cancel across regimes.

**Forward guidance:** the scale-in/capital-reallocation lever class is
exhausted — stop proposing intra-envelope reallocation variants. The
mechanism stays merged, default-off, a searchable axis (zero golden churn).
The remaining lever classes with any standing evidence: envelope size
(min_cash/max_exposure — never swept as a pair), breadth/universe, and the
promoted barbell overlay. If continuation-adds are ever revisited it should
be OUTSIDE the binding cash constraint (i.e., paired with an envelope
change), not inside it.

## Ops notes

- 13 folds × 4 variants ≈ 9h06m wall (fork-per-fold, snapshot warehouse,
  `--parallel 1`), zero failures, RSS bounded, host disk flat.
- Docker.raw preflight resolved non-destructively pre-launch (55→21 GB: the
  bloat was 37 GB of stale container `/tmp` scratch — dune-test-build,
  bar_reader spills, old snapshot copies; no image/container rebuild).
