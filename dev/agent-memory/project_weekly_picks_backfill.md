---
name: project-weekly-picks-backfill
description: "USER 11-15: keep the weekly live-picks record continuous — backfill all missed Fridays (08-21..11-13); record config; full reports private (trading-results), public mark-free"
metadata:
  type: project
---

User 2026-11-15 22:10 PT, on the pacer's 93-day / 13-Friday gap (#3635): *"we should still backfill all the weekly picks"*. The weekly picks record is wanted as a continuous series, not dropped while research runs.

**Why:** the picks are the forward record of what the strategy would buy each Friday ([[project-fresh-eyes-dated-picks]]); gaps make it useless as a forward test.
**How to apply:** backfill 2026-08-21 → 11-13 (local bars ended 08-17/18: refresh first, stale set included — [[project_weekly_snapshot_generator_caveats]] caveat 3), then keep it weekly with an owner. Run on the record config (rk-k0 overrides), not the 07-14 `live-config-overrides.sexp`. Full reports (`.sexp/.md/.html/validation.txt`) print closes and entry/stop prices → private `dayfine/trading-results` under the same `dev/weekly-picks/<sha>/` path; public gets rank, symbol, grade, score, sector only ([[project-eodhd-terms-private-bucket]]).

**Done 11-16 (#3647, private trading-results afd8105 + c01e99a):** 13 Fridays at system version 89a08b1fe, `dev/weekly-picks/record-config-overrides.sexp` (24 rk-k0 overrides + live sparse_tail/rename_detect). Lookahead: as-of 08-21 picks byte-identical with a warehouse cut at 08-21 (cut not kept; keep it under `controls/` next time). Continuity: as-of 08-14 on the old live config = 16/20 of the f88c277d5 longs (vendor re-basing hit 595 symbols). Macro: Bullish to 10-23, Neutral 10-30, **Bearish 11-06 and 11-13 (0 longs)** — index-stage only (generator passes no A-D/global bars, so the record's breadth_direction is inert here). Universe = eligible list minus 472 csv-only OTC/foreign names (`build_inventory` now counts csv-only dirs). **Decided (user 11-16, "A it is"): picks stay on the record config**, without the live `failed_breakout_tolerance_pct 0.05`, though 10–19 of each Friday's 20 longs sit >5 % under their breakout (the buy-stop fills only on a re-break). Picks = what the backtest trades; the gate goes to the observatory as an arm (`failed_breakout_tolerance_pct 0.05`, next queue batch with cap 40; mind its overlap with the F2 re-screen cancel #2263) and reaches the picks only through the record. Refresh recipe: `dev/data/ops-fetch-2026-11-16/` (single-dash flags; shard-bucketed parallel fetch, #3645). Weekly cadence still has no owner.
