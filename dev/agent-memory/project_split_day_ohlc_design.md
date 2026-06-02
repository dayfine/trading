---
name: split-day OHLC inconsistency — broker-model redesign in flight (PR #656)
description: Broker-model plan landed as PR #656 on 2026-04-28; 4 phases ~650 LOC; #641 closed as superseded
type: project
originSessionId: 1b3c22f4-6967-4e7d-bdd3-6cfe881e12e5
---
`Daily_price.t` carries both `close_price` (raw) and `adjusted_close` (back-adjusted). Each layer uses a different one:
- Simulator MtM: raw `close_price` → 75% phantom drop on AAPL 2020-08-31 split day
- Panel `weekly_view.closes`: adjusted (smooth across splits)
- Panel `weekly_view.highs/lows`: raw (so MA-30w breakout sees raw $211 highs vs adjusted $124 closes)

**Why:** PR #641 attempted a `_split_adjust_bar` ratio fix in the simulator. It's over-broad — rescales every bar where `adjusted_close ≠ close_price` (i.e., every pre-corporate-action bar in EODHD's back-rolled data), not just split days. Drift on small goldens (1-3 round-trips) and 30-trade sp500 outcome (no longer comparable to 478-trade baseline). Held indefinitely as PR #641.

**Recommended design** (per rebase agent on #641):
Broker model — track positions in split-adjusted shares; quantity multiplies on the split day (400 shares × 4:1 → 1600 shares, cash basis preserved). Use raw OHLC everywhere for execution; adjusted only for relative comparisons (RS line, MA, breakout detection).

**Why:** layered-architecture mismatch (not a "data is wrong" problem). Knowing this means future debugging starts at the broker abstraction, not the data feed.

**Plan landed:** `dev/plans/split-day-ohlc-redesign-2026-04-28.md` (PR #656, 2026-04-28). 4 phases ~650 LOC:
- PR-1: `Split_detector` primitive (close-ratio comparison: `adj_ratio / raw_ratio` snapped to small rationals N/M ≤ 20, 5% threshold) — 150 LOC
- PR-2: `Split_event` ledger alongside Portfolio — 250 LOC
- PR-3: simulator integration + re-enable `test_split_day_mtm.ml` from closed #641 — 200 LOC
- PR-4: sp500 verification + decisions archive — 50 LOC

**How to apply:** when implementing PR-1..PR-4, follow the plan file exactly; the canonical sp500 baseline (PR #657) is the verification target — 97.7% MaxDD must drop after PR-3 lands. Then re-pin `goldens-sp500/sp500-2019-2023.sexp` `expected` ranges against the post-fix numbers.
