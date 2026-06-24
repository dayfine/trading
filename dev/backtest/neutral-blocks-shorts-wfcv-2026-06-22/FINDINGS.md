# `neutral_blocks_shorts` WF-CV — FINDINGS (2026-06-22)

The promote-track step the deep screen
(`dev/backtest/faithful-short-deep-screen-2026-06-22/FINDINGS.md`) called for.
That screen found `neutral_blocks_shorts` (Bearish-tape-only shorts) **strictly
helpful-or-inert** across a bull and a bear regime. This walk-forward CV tests it
across rolling OOS folds spanning every regime 2000-2026.

- **Spec:** `test_data/walk_forward/neutral-blocks-shorts-deep-2000-2026.sexp`.
- **Base:** `sp500-2000-2026-longshort` (deep long-short, sp500-as-of-2000 PIT,
  enable_short_side=true). CSV mode on the deep `data/` store (1998-2026).
- **Geometry:** Rolling 2000-2026, test 365 / step 365 / train 0 → **26
  non-overlapping OOS folds**. Axis `((flag neutral_blocks_shorts) (values (true
  false)))`. Decision: `Variant_ranking` (Pareto) + `Deflated_sharpe`.

## Result — `true` ≥ baseline (helpful-or-inert CONFIRMED), modest edge

| Variant | Sharpe (mean) | Calmar | MaxDD % | Pareto | DSR |
|---|---|---|---|---|---|
| baseline (≡ false) | 0.687 | 1.301 | 11.58 | yes | 0.9998 |
| **neutral_blocks_shorts=true** | **0.707** | **1.331** | 11.61 | yes | 0.9998 |

Aggregate: +0.020 Sharpe, +0.030 Calmar, mean return 11.06 → 11.38%, MaxDD +0.03
(negligible). `true` sits on the Pareto frontier; it is never dominated.

### Per-fold — identical in 24/26; one big win, one tiny loss
- **24 of 26 folds: byte-identical** to baseline. Most years have no Neutral-tape
  short episode, so the gate is inert — exactly the screen's "inert when shorts
  are already faithful" finding, fold by fold.
- **fold-003 (2003, post-dot-com recovery): 19.65 → 28.66% return, Sharpe 1.262 →
  1.832.** The big differentiator — blocking Neutral-tape shorts avoided getting
  squeezed in the 2003 post-bottom rip (the same squeeze mechanism the shallow
  2010-2026 screen saw in 2010).
- **fold-010 (2010): 14.88 → 14.10% return, Sharpe 0.959 → 0.914.** The only fold
  where `true` is worse — a Neutral-tape short that would have helped was removed.

Net across folds: `true` ≥ baseline in **25/26 folds** (24 ties + 1 large win),
worse in 1 (marginally). The aggregate edge is real but small and concentrated in
the 2003 squeeze-avoidance fold.

## Verdict: ACCEPT (single cell) — promote-track, default flip gated on the grid

Per `promotion-confirmation.md`, a single-surface ACCEPT is **necessary but not
sufficient** to flip the default:
- **ACCEPT rationale:** `true` is a *faithful* change (Weinstein shorts only in
  confirmed Bearish tapes) that is **helpful-or-inert across 26 folds / every
  regime** — never meaningfully worse, occasionally much better. It is on the
  Pareto frontier. This is the "free-or-positive faithful filter" the screen
  predicted.
- **Why NOT a default flip yet:** the aggregate edge is small and **DSR does not
  distinguish the variants** (0.9998 for all — the gain is within fold-to-fold
  noise). It is driven by one fold (2003). Promotion needs the macro-regime-diverse
  **confirmation grid**: ≥1 more (period × universe) cell — e.g. a different
  universe (sp500-2010 or top-1000) and/or a disjoint window — showing `true` ≥
  baseline before flipping the default.

Recorded in the ledger: `dev/experiments/_ledger/2026-06-22-neutral-blocks-shorts-wfcv.sexp`.

## Caveats
- **Static sp500-as-of-2000 universe** over 26 years (stale in late folds — no
  post-2000 additions, 2000-members held to delisting). Affects both cells
  equally, so the baseline-vs-variant *comparison* holds; and the gate decision is
  macro/index-driven (universe-independent). But a per-fold-rotated universe is the
  rigorous next step (the confirmation-grid cell should use a different snapshot).
- 26 annual non-overlapping folds; a finer step (182) would add folds for DSR power
  but overlap the OOS windows.
- The deep `data/` store is gitignored (1998-2026 EODHD fetch); the WF report +
  ranking are committed here as the evidence artifacts.
