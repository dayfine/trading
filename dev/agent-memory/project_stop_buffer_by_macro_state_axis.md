---
name: stop-buffer-by-macro-state-axis
description: Item 3 (#2718 `initial_stop_buffer_by_macro_state`, default-off) — ledger REJECT-as-default / keep-as-regime-axis 2026-09-09; on the deduped `_v10dedup` warehouse (V6 = 0) the 12/8/4% map has NO salt-robust property (level −/+/−, realised −/+/+, maxDD worse/worse/better); the `_v7mark` "drawdown floor" was twin double-funding. Item 4 (width × 12%-weekly cadence) does not proceed.
metadata:
  type: project
---

**Verdict (ledger `2026-09-09-stop-width-by-macro-state-surface`, REJECT-as-default / keep-as-regime-axis).** On `_v10dedup` 2000 (rename twins dropped, MEL quarantined, `validator_diff -check V6` = 0 on all six cells, build 969637974): null a0 vs map a1 (Bullish/Recovering 12%, Neutral 8%, Deteriorating/Bearish 4%) per salt — level −101 / +91 / −242pp; realised −$683k / +$170k / +$1.06M; maxDD 37.6→41.0 / 32.8→35.0 / 43.0→39.6; Sharpe −/+/−. Only invariant: the exit mix (~80 fewer `stop_loss`, ~165 more `laggard_rotation` per cell) and the same shared trades widening (CLS 2023-06-20, BFX 2020-04-22, BB 2006) — a mechanism without an edge; whipsaws saved are paid back by wider losses on trades that fail anyway (WNC 2003 −$122k every cell) and 5 force liquidations per map cell vs 2–3.

**Why `_v7mark` looked like a drawdown floor (maxDD 42–45 → 31–38 at every salt, +207/+429/+571pp):** the map's smaller tickets let BOTH legs of a rename twin clear the cash gate (NLS/BFX, BB/BBRY, RCII/UPBD; V6 = 5–6 on every map cell), so a 2020 monster was funded twice and its doubled equity lifted the curve through the COVID drawdown — the maxDD win and $0.8–0.9M of each cell's level were one artifact, plus $1.4–1.9M open MTM (VIAV) and the corrupt MEL series (#2732). **A maxDD improvement on a warehouse with V6 > 0 is not a read.** Gate every paired read on V6 = 0 and decompose open MTM before any maxDD claim.

**Kept as an axis because:** the per-state read is inert and cheap (a0 = the record digit-for-digit at three salts on `_v7mark`), a narrower-than-record map (Deteriorating/Bearish < 1.0) was never tested, and the 09-04 per-state P&L asymmetry stands. Mechanics (#2718): `Weinstein_strategy.Stop_buffer_by_state`, one read site `Entry_walk._initial_stop_buffer`; `enable_breadth_direction` must be ON for Recovering/Deteriorating slots; the map is "12% almost everywhere" (Bullish+Recovering ≈ 73% of entries), a1↔a2 (Neutral 8 vs 10%) re-draws ~40% of the trade list — only salts are the read.

Related: [[record-rebase-2026-09-09]] (the comparator band on `_v10dedup`), [[stop-width-cadence-surface-2026-09-05]] (its 12%-weekly candidate must be re-measured on this band before any promotion), [[warehouse-dedup-v10]], [[clock52-promoted]] (the maxDD-only precedent).
