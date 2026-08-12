---
name: entry-e-stale-high-bug
description: "Entry level E (suggested_entry) is anchored to a stale year-old high (scan_max_high 8-60wks back), not the current base top — so E≫price in 35% of trades; the record only works by IGNORING E (market fill + support-floor stop); the book ticket fails by taking E literally. Root of the fill-model inversion."
metadata: 
  node_type: memory
  type: project
  originSessionId: 03225898-70ec-4699-ac13-8d00aa71b30f
---

**2026-08-08 trade-dissection (ladder v2) — the mechanism behind the fill-model
inversion, at trade level.** E (`suggested_entry`) is built from
`breakout_price = scan_max_high` over `base_end_offset_weeks(8)..+base_lookback_weeks(52)`
(`stock_analysis.ml:283`, `screener.ml:127`) — the **max high from ~2–14 months
back**. For any name that ran up, pulled back, then re-qualified Stage-2, that
window grabs a **stale year-old peak far above current price**.

**Quantified (record-nextopen, 1107 trades):** E ≥ 1.2× fill in **35%**; ≥1.5× in
14%; ≥1.9× in 7%; **mean E/fill = 1.29**. And `suggested_stop = entry×(1−pct)` off
E lands **ABOVE the fill in 64%** of trades — Support_floor rescues installed_stop
(above fill only 2%).

**Why record wins / book loses (AXTI 2025-06-27, the Rosetta):** close 2.03, E
4.05 (2×), Virgin_territory.
- record (Market): `effective_entry`=close (`entry_audit_helpers.ml:41-51`,
  `trigger_at_suggested=false`) → buys 2.05, deep Support_floor stop 1.728 (−16%,
  book-faithful) → rides to 115.45, +$56.2M (extension_stop).
- book (StopLimit at E=4.05): waits for a 2× move → fills 4.13 in Sept (2.5mo late)
  → base-anchored stop 3.966 (−4%) → whipsawed out next day at 4.00, −3%. Misses
  the 56× run.

**The 3 roles E is wrongly overloaded into:** screening/scoring (OK), entry trigger
(should be current-range top, not stale 52w top), and the STOP (should be support
floor, never E-derived). Book §5.1: stop = below support floor; ">15% risk → prefer
other candidates" = a **screening filter**, NOT the `stop_anchor_at_entry_base`
tighten-to-fit mechanism (which exists only to paper over inflated E). The record's
Support_floor stop is the book-faithful one; the "book ticket" stop is the
un-faithful invention.

**Also the "62% stops >15%" confound** ([[fill-model-inversion]] §4 RESOLVED) is the
same E inflation: `stop_initial_distance_pct` = |E−stop|/E is E-basis, so E≫price
makes stops LOOK deep. Fill-basis column shipped (#2242).

**FORWARD (plan `entry-ticket-right-basis-2026-08-08.md`):** faithful StopLimit at a
reachable current-range top + support-floor stop + 15%-as-candidate-filter; add
close/ma_value/local_range_top to the audit so E-provenance is visible. All
default-off → WF-CV + grid. Skill `trade-dissection` captures the method.
[[fill-model-inversion]] [[edge-is-the-fat-tail]]
