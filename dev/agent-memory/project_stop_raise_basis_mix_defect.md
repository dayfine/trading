---
name: project-stop-raise-basis-mix-defect
description: "09-26 #2982: stop raise candidate = min(raw correction low, ADJUSTED MA) → ratchet can't fire when close/adj_close ≫ 1; 0/73 raised at factor ≥1.5 vs 50% at <1.02. Likely root of #2974 and the 08-24 'freeze'."
metadata:
  type: project
---

`weinstein_stops.ml:276` Long candidate `Float.min correction_extreme ma_value`: correction_extreme from RAW daily bars, ma_value from `stops_runner._compute_ma_and_stage` on ADJUSTED weekly closes (bar store adjusted_close is back-adjusted to latest for later splits + dividends). So candidate collapses to the shrunken MA → never above the stop. Same mix in `Stage3_force_exit_runner._margin_ok`.

f2-fills-faithful-s0 (26y PIT): held ≥13 wk raised 50 % at factor <1.02, 40 % 1.02–1.10, 13 % 1.10–1.5, **0/73 at ≥1.5** (241 trades, zero ever raised). Confound: high factors = older entries (check in-era).

Found by the #2973 split-corpus writer (reported, not fixed — decision change). Fix = default-off flag + 3-salt 26y paired run. Probably re-explains [[project-ratchet-freeze-real-data]] (attributed to anchor deadlock) and [[project_fallback_stop_half_book_band]]. Every record/band ran with it; relative reads are like-for-like on the defective system.

**Why:** user standing concern (09-26): stop methodology must work in a bumpy uptrend with pullbacks — it structurally cannot for ~1/3 of trades.
**How to apply:** treat any stop-width / stop-raise / exit-stack conclusion as conditional on this defect until the fix arm runs; queue the fix experiment ahead of stop-lever work.

**09-26 replay (#2974 comment 5852051573):** all-724 replay reproduces raised-vs-not 704/724 with the adjusted MA (code) vs 592 with consistent MA → confirmed; gap holds within every era. Also found: `n_stop_raises` off by one (EntryComplete carries no stop → first raise booked as install; real raised = 112 not 49); `Entered_tightening` raises silently; Tightened state frozen (anchor only moves down); correction not required to FOLLOW the peak (56 % of first raises = pure advance off the entry-bar low); `_margin_ok` docstring false (requires close ≤ MA). **Fix is not an obvious win:** consistent MA raises 97/602; the 33 later hit exit median +0.3 % / mean −2.8 % / p10 −14 % vs actual — no-ratchet may have been protecting the fat tail ([[project-edge-is-the-fat-tail]]). 4 % stop dies before the 8 % rule can act on 71 % of stop exits (<5 % stops) — incoherent preset (trader stop + investor ratchet), faithful per piece.

**09-27 status:** flag `stop_ma_same_basis` merged default-off (#2996, with `correction_must_follow_peak` + `tightened_can_ratchet`). First screen, 5y broad 2021-06→2026-06, s0, V6-paired vs `inv5-hybrid` (chain `/tmp/investor-run/chain-I.log`, pinned f5507ad86): hybrid −25.9 % / DD 39.5 / 196 trades → 9a −6.2 % / DD 38.6 / 191 trades (+19.7 pp); raised trades 34 → 45; realised +$100k, rest = end-window open value (859k vs 579k) → half unrealised, fragile. One salt one window = escalate only; 26y × 3 salts (QUEUE item 10) is the real test. #2982 stays OPEN until then.
