# Deep 28-year backtest — top-3000 PIT, Cell-E, 1998-2026

**Date:** 2026-06-14 · **Window:** 1998-01-01 → 2026-04-30 (warmup from 1997-06-05),
7377 daily steps · **Universe:** PIT top-3000-by-marketcap composition as-of 1998
(survivorship-correct — delisted `_old` symbols present), 3000 tradeable + 15
context symbols (GSPC.INDX + GDAXI/ISF.LSE/N225 + 11 SPDR sector ETFs) ·
**Config:** Cell-E (0.14/0.70/0.30 sizing, stage3-force-exit h=1, laggard-rotation
h=2, short off, macro gate on, 5 bps spread cost) · **Benchmark:** GSPC.INDX
price-only · **Snapshot warehouse:** `/tmp/snap_top3000_1998_2026` (3015 symbols).

This is the single contiguous 28-year number none of the prior results provide
(the deep work was previously only WF-CV folds on PIT-SP500, or two disjoint
rolling-start matrices split at 2011).

## Headline

| metric | value | note |
|---|---|---|
| **MTM total return** | **+1785.2%** | final NAV $18.85M on $1.0M; CAGR ~10.9% |
| **Realized return** (banked) | **+1552.3%** | $15.52M realized PnL on 1075 closed trades — the robust floor |
| unrealized (terminal open marks) | +233pp | only **13%** of return is marks (vs **75%** in the 15y top-3000 case → far less MTM-inflated) |
| benchmark GSPC price-only | +599% | 975.04 → 6816.89; CAGR ~7.1% |
| **realized edge vs GSPC** | **~+3.3 pp/yr** | (MTM edge ~+3.8 pp/yr) |
| Sharpe / Sortino / Calmar | 0.59 / 0.96 / 0.30 | |
| MaxDD / underwater duration | 35.9% / 1403d (~3.8y) | vs SPX ~49% (dotcom) / ~55% (GFC) |
| Ulcer index | 12.95 | |
| trades / win / avg hold | 1075 / 32.9% / 48d | 8 force-liquidations |

**The edge is real and large over the full multi-regime window: realized +1552%
vs SPX price +599%, with ~20pp less drawdown.** This *confirms*
`project_index_beating_structural_bar` cleanly — the warmup-honest **bull-only
2011-2026** window showed *negative* realized edge (no bear to dodge), whereas the
full 1998-2026 window *contains* the dotcom bust + GFC, and there the Stage-4
exits sidestep the crashes. The strategy is a **bear-regime distribution
compressor, not a bull-return-beater.**

## Trade-by-trade decomposition (the WHY)

### 1. The edge IS the fat tail (validated over 28y)

| | share of total realized PnL |
|---|---|
| top 5 trades | **84.6%** |
| top 10 | 128% (rest net-negative) |
| top 20 | 176% |
| all 1075 | 100% ($15.52M) |

The entire realized return comes from ~5-10 monster trades; the other ~1065 are
net-negative in aggregate. Purest form of `edge_is_the_fat_tail` over 28 years.
Biggest single trade SKYW (+$4.87M, +304%, 504 days) = **31% of all realized PnL**.

Top monsters: SKYW +$4.87M (504d, laggard_rotation), BELFA +$2.91M (stop_loss),
BVN +$2.05M (laggard_rotation), LOGI +$1.72M (stop_loss), BKE +$1.60M
(laggard_rotation), FLSH +$1.53M (+999%, 1999-2000 dotcom 10-bagger,
laggard_rotation). Most held 300-500 days.

### 2. Win/loss asymmetry — cut losers, let winners run

- 354 winners (32.9%), avg win **+$162k**; 721 losers, avg loss **−$58k**;
  payoff ratio **2.79**.
- **Winners held avg 99 days; losers avg 23 days** (4.3× longer). Classic
  let-winners-run / cut-losses-fast. The low win-rate + high payoff is the
  signature, not a defect.

### 3. By exit channel — laggard-rotation harvests, stops pay the premium

| exit_trigger | n | realized PnL | win% |
|---|---|---|---|
| **laggard_rotation** | 317 | **+$31.9M** | 59% |
| **stop_loss** | 733 | **−$16.6M** | 22% |
| stage3_force_exit | 17 | +$0.45M | 35% |
| end-of-sim / other | 8 | −$0.25M | 25% |

**Laggard-rotation generates ALL the profit (+$31.9M); stops cost $16.6M (the
insurance premium); net +$15.5M.** This re-derives `project_trade_forensics_2026_06_12`
("laggard rotation = THE profit channel, stops eat the losses") from a fresh 28y
angle — strong corroboration. The fat-tail monsters live in the laggard-rotation
bucket: a position that ran hard and then turns into a relative laggard is rotated
out, booking the gain.

### 4. Every regime net-positive (the bear defense)

| era (entry year) | n | realized PnL | win% |
|---|---|---|---|
| 1998-02 dotcom | 149 | +$2.85M | 29% |
| 2003-07 recovery | 203 | +$2.56M | 34% |
| 2008-09 GFC | 72 | +$0.058M | 26% |
| 2010-19 QE bull | 379 | +$4.86M | 35% |
| 2020-26 covid+ | 272 | +$5.20M | 33% |

Net-positive (or flat) in **every** regime including dotcom and GFC. The GFC
near-zero (+$58k on 72 trades) is the defense signature — it treaded water through
2008-09 rather than blowing up. Win rate is stable ~29-35% across all eras (the
edge is payoff-driven, not hit-rate-driven, in every regime).

### 5. Spine-faithfulness check

100% of the 1075 entries are **Stage2** (col `entry_stage`). Confirms
`weinstein-faithful-core.md` W2 (buy only in Stage 2) holds in this run — no
Stage-1/3/4 entries leaked.

## Forward guidance (what this rules in/out)

Re-confirms the standing prior (`project_edge_is_the_fat_tail`,
`mechanism-validation-rigor.md`): **bias search to tail-PRESERVING levers** (entry
quality, breadth, holding discipline) and **away from winner-touching levers**
(trim/rotate-cap/re-time). Specifically:

- The **laggard-rotation harvest channel is load-bearing** (+$31.9M) — do NOT
  tighten/cap/re-time it without strong evidence; it *is* the winner-harvest.
- **Stops are the necessary insurance premium** (−$16.6M) buying the +$31.9M
  harvest + the bear survival. A "reduce stop cost" lever that also reduces the
  harvest is net-negative.
- The bull-vs-multi-regime contrast (negative bull-only edge, large multi-regime
  edge) means **evaluation must span a bear** — bull-window-only tuning is the
  recurrent overfit trap.

## Caveats

- **Single contiguous run, not WF-CV folds** — no fold-level robustness here; this
  is one path, not a CV-corrected estimate. Treat as a regime-coverage existence
  proof, not a promotion-grade verdict.
- **One PIT-1998 membership snapshot** — survivorship-correct (delisted symbols
  present) but a single composition; breadth/snapshot diversity not exercised.
- **Quote realized +1552%, not MTM +1785%** — the +233pp gap is terminal open
  marks. Open book is 91% of terminal NAV → a few fat-tail winners dominate the
  open positions too (consistent with the concentration finding).
- `screener_score_at_entry` was uniformly ≥30 in the closed trades (entry filter
  pre-gates it) → cascade-inversion not checkable at this granularity here; use the
  rolling-start / all-eligible surfaces for that question.

## Artifacts

`trades.csv` (1075 closed trades, full per-trade fields), `equity_curve.csv`,
`summary.sexp`, `actual.sexp`, `params.sexp`, `macro_trend.sexp`,
`fold_health.sexp`. Run output root (gitignored):
`dev/backtest/scenarios-2026-06-15-011343/`. Scenario:
`/tmp/scn-deep-1998/weinstein-1998-2026-top3000-deep.sexp`.
