---
name: rename-twin-dedup-returns-basis
description: Twin detection must compare DAILY RETURNS not adjusted-close levels — feeds carry different adjustment bases; levels miss 9/10 real rename twins
metadata: 
  node_type: memory
  type: project
  originSessionId: 7df7c106-7818-4bd3-9908-c008f4c7d09e
---

**2026-07-12/13 (C1 track).** Rename-twin dedup in the snapshot warehouse
(`Twin_detector`, `trading/backtest/snapshot_warehouse/`): v1 (#1940) compared
adjusted_close LEVELS (>95% of overlap within 1e-4 rel) — armed on the real
top-3000 store it caught 15 exact-feed rename groups (BB/BBRY, QRVO/RFMD,
FI/FISV_old, NLS/BFX…) but missed 9 of the 10 known groups because the two
feeds carry **different adjustment bases**: levels differ by constant or
DRIFTING ratios (BLL/BALL level-match 0.000, ratio cv 0.57).

**The discriminator is daily-return matching** (|ret_a − ret_b| ≤ 1e-3 on
consecutive shared dates): all 9 true twins score 0.951–0.993; false positives
BALL/TAP 0.055 and ASB/CDX_old 0.061 (the latter was a V6 trade-level
candidate — NOT actually a twin). v2 (#1946) adds `basis = Levels | Returns`
(default Levels) + return-anchored scale-invariant prefilter; arm with
`-dedupe-rename-twins -twin-basis returns`.

Validator V6 (trade-level same-date price/qty ≤5% heuristic) and the builder
detector cross-check each other; V6 alone has false positives.

**Why:** adjusted series are back-computed per feed; splits/dividends applied
differently compound level divergence while returns stay identical.
**How to apply:** any "same instrument under two symbols" comparison on this
store must be returns-based or ratio-stability-based, never level equality.
[[project_realism_defaults_flip_merged]] [[project_honest_tradeable_baseline]]
