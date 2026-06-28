---
name: project_declining_ma_gate_breadth_preset
description: "declining-MA long-entry gate — do-no-harm faithful filter, broad-only benefit; first breadth-dependent knob → broad-preset concept"
metadata: 
  node_type: memory
  type: project
  originSessionId: 129802fb-f712-42ad-beeb-3b30ba08209d
---

**Declining-MA long-entry gate** (`reject_declining_ma_long_entry`, PR #1775,
default-off): drops long candidates whose stage-classification MA is `Declining`
at entry — a misclassified Stage-2 (counter-trend bounce in a Stage-4 downtrend;
the COO/WBA/DBD drawdown-driver pattern). A FAITHFUL tightening of the
Stage-2-only buy rule toward the book's rising-MA definition (spine intact). Built
as `weinstein_trading.declining_ma_gate` sub-lib + `Entry_assembly` extraction;
both QC APPROVED, default-off, goldens bit-identical.

**Origin:** 2026-06-27 drawdown-driver chart review + entry-quality audit. Across
1288 broad trades, win rate is ~flat 34% by entry-quality bucket (volume, slope,
freshness) — entry-selection is structurally dead (`project_accuracy_is_unreachable_diversify_instead`)
— EXCEPT declining-MA "Stage 2" entries: ~13% win / −0.1% avg vs ~34% / +2.6%.
Only ~30 of 1288 (2.3%), but negative-expectancy + misclassified.

**Single-window broad remeasure = MTM TRAP:** gate-on showed +848% vs +721%
(+126pp) / MaxDD 35.7 vs 43.8 — but realized P&L was LOWER ($7.63M vs $8.42M);
~all the headline gain was terminal unrealized MTM ($3.18M vs $1.26M). Classic
`project_broad_universe_790_mtm_inflated`. Do NOT trust single-window total-return.

**WF-CV grid (the honest verdict — `_ledger/2026-06-28-declining-ma-gate-grid`,
2000-2026, 2y folds, 3 universe cells):** the benefit is UNIVERSE-SPECIFIC.
- Cell A top-3000: 2 wins / 11 ties / 0 losses, mean Sharpe 0.450→0.495; wins are
  fast-crash folds (2018-19 −0.25→+0.21 Sharpe, 2020-21 +0.11).
- Cell B sp500-515: 0 wins, ~no-op (worst gap −0.006). Cell C top-1000: ~no-op.
- DO-NO-HARM across all 39 folds; HELPS only on broad → fails promotion-confirmation
  "strong majority of cells" → NO global default flip. The misclassified entries
  live in the small/deep/delisting TAIL only top-3000 contains.

**Outcome:** keep default-off; **ARM for broad** (validated do-no-harm + fast-crash
tail-insurance). First clear **breadth-dependent strategy knob** → motivated a
**broad preset** (`docs/design/broad-preset.md`): universe-tier config bundle where
breadth-sensitive dials change by universe (gate ON + concentration 0.30 for broad;
off/lower for large-cap), spine identical. cf. concentration regime/universe
dependence [[project_deep_goldens_conservative_vs_default]]. Method lesson: WF-CV
fold-means (many end-dates) neutralize the terminal-MTM luck that fools
single-window total-return. Related: [[project_edge_is_the_fat_tail]].
