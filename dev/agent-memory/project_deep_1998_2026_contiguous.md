---
name: project_deep_1998_2026_contiguous
description: "First contiguous 28y top-3000 PIT Cell-E run (1998-2026) — realized +1552% vs SPX-price +599% (~+3.3pp/yr edge), MaxDD 35.9%; confirms multi-regime edge + fat-tail + laggard-harvest theses"
metadata: 
  node_type: memory
  type: project
  originSessionId: 165e76ce-4c40-406d-9202-d9e351ad0654
---

First single contiguous **28-year** backtest (1998-01-01 → 2026-04-30), top-3000
PIT-1998 universe (survivorship-correct), Cell-E, snapshot mode. Ran 2026-06-14.
Writeup: `dev/experiments/deep-1998-2026-2026-06-14/ANALYSIS.md`.

**Headline (quote REALIZED, not MTM):**
- MTM total return **+1785%** (CAGR 10.9%); **realized +1552%** ($15.52M on $1M,
  1075 trades) — only 13% of return is terminal open marks (vs 75% in the 15y
  top-3000 case → far less MTM-inflated, [[project_broad_universe_790_mtm_inflated]]).
- Benchmark GSPC price-only +599% (CAGR 7.1%) → **realized edge ~+3.3 pp/yr**.
- Sharpe 0.59 / Sortino 0.96 / Calmar 0.30; MaxDD **35.9%** (1403d underwater) vs
  SPX ~49% (dotcom) / ~55% (GFC). 32.9% win, payoff 2.79, 48d avg hold.

**Why it matters:** the edge shows up over a window that CONTAINS bears (dotcom +
GFC) — confirms [[project_index_beating_structural_bar]] cleanly. The warmup-honest
bull-only 2011-2026 window had NEGATIVE realized edge; the multi-regime 28y window
beats. Strategy = **bear-regime distribution compressor, not bull-return-beater**.

**Trade-by-trade decomposition (the transferable WHY):**
- **Fat tail:** top 5 trades = **84.6%** of realized PnL; top 10 = 128% (rest
  net-negative). SKYW alone +$4.87M = 31% of total. Purest [[project_edge_is_the_fat_tail]].
- **Exit channels:** laggard_rotation +$31.9M (n=317, 59% win) = THE profit engine;
  stop_loss −$16.6M (n=733, 22% win) = the insurance premium; net +$15.5M.
  Re-derives [[project_trade_forensics_2026_06_12]] from a fresh 28y angle.
- **Let-winners-run:** winners held 99d avg, losers 23d (4.3×). Low win-rate +
  high payoff is the signature.
- **Every regime net-positive** incl dotcom (+$2.85M) and GFC (flat +$58k = the
  defense). Win rate stable ~29-35% across eras.
- 100% of entries Stage2 (spine-faithful per [[weinstein-faithful-core]]).

**Forward guidance:** laggard-rotation harvest channel is load-bearing — don't
trim/cap/re-time it. Stops are the necessary premium. Evaluation MUST span a bear
(bull-only tuning is the recurrent overfit trap). Bias to tail-preserving levers.

**WF-CV CONFIRMATION (2026-06-15, no longer just a single path):** ran Cell-E as
**28 independent annual folds** 1998-2025 (PIT top-3000-1998, snapshot mode). Mean
fold **Sharpe 0.64 ± 0.86**, return 13.2%/yr ± 20, MaxDD 14.7% ± 5.6, Calmar 1.25;
**23/28 folds positive**; mean fold-Sharpe ≈ single-run 28y Sharpe 0.59. Down years
SHALLOW (2008 GFC −4.6% vs SPX ~−37%; 2001 −4.6, 2002 −7.6) = bear-defense holds
per-fold; big years = bull legs/post-bear dawns (1999 +82%, 2013 +39%, 2017 +42%).
**The +1552% is NOT a lucky path.** Caveat: worst fold 2024 (−21.9%) is a PIT-1998
membership-decay artifact (universe delisted-thin by 2024) → per-fold rolling
membership is the follow-up. Writeup: `dev/experiments/deep-1998-2026-2026-06-14/wfcv/`.

**Caveats:** one PIT-1998 snapshot (membership decays in late folds); quote realized
not MTM.

**Snapshot-mode gotcha (cost me 2 dead runs):** a snapshot warehouse built with
`build_snapshots -benchmark-symbol GSPC.INDX` does NOT include the macro/index/
sector-ETF context symbols (4 global indices + 11 SPDR sector ETFs). The reader
resolves `.snap` via the manifest, so missing context symbols → macro analyzer
returns empty (`macro_trend.sexp = ()`) → unconditional macro gate blocks ALL
entries → 0 trades, flat NAV. Fix: build with an AUGMENTED universe (tradeable +
15 context symbols) so the warehouse + manifest include them; keep the scenario's
`universe_path` at the tradeable set only (context symbols not traded). Incremental
rebuild adds just the 15 (~17s). The working `snap_top3000_2011` has 3015 files
(3000+15); a naive top-3000 build has only 3000.
