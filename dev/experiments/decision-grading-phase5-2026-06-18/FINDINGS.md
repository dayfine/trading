# Phase 5 — did laggard-rotation pay? (paired counterfactual, 2026-06-18)

Phase 5 of the decision-grading lens. Laggard-rotation sells a lagging name to
free cash for the same-tick entry walk. The lens's per-decision view
(`decision-grading-deep-2026-06-18`) showed laggard exits have high mean realized
P&L (+12.8-16.9%) but slightly-negative net-value-add vs holding. Phase 5 asks
the sharper question the swap actually poses: **did the names we bought with the
freed cash beat the laggard we sold?**

No 1:1 sold→bought link exists (the runner frees cash into a pool the entry walk
draws from — `laggard_rotation_runner.mli`). So the pairing is per-event cohort:
each rotation exit vs the new entries opened within a 10-day allocation window
after it; both sides' forward return is the `Post_exit` continuation over the
same horizon. Tool: `Decision_grading.Laggard_cf` + `laggard_cf` bin.

## Result

**1998-2026 deep (multi-regime, 296 events, 260 with redeployment):**

| horizon | mean dumped fwd | mean funded fwd | mean paired diff | % paid | diff p10/p50/p90 |
|---|---|---|---|---|---|
| 4w | +1.0% | +0.7% | −0.3% | 53% | −16.5 / +0.8 / +12.7 |
| 13w | +2.5% | +3.8% | +1.3% | 50% | −21.4 / −0.1 / +25.4 |
| 26w | +5.2% | +6.0% | +0.8% | 51% | −39.4 / +1.0 / +35.7 |

**2011-2026 bull (220 events, 198 with redeployment):**

| horizon | mean paired diff | % paid | diff p10/p50/p90 |
|---|---|---|---|
| 13w | +5.6% | 57% | −20.8 / +3.1 / +30.3 |
| 26w | +6.0% | 56% | −32.4 / +3.9 / +43.2 |

## Verdict — the swap is a coin flip; the value is recycling, not selection

- **Per-swap, laggard-rotation is ≈ a coin flip with a thin positive mean.**
  Across the full multi-regime window the funded cohort beats the dumped laggard
  only ~50-53% of the time, mean paired diff ≈ +1% over a quarter, with huge
  dispersion (p10 −20 to −39%, p90 +13 to +36%). In the bull-only window it pays
  more (+5-6%, 56-57%) — i.e. the modest edge is regime-dependent (fresher names
  run in a bull tape) and **evaporates once dot-com+GFC are included**.
- **This re-derives the harvest-rotate rejection** (`project_harvest_rotate_rejected`:
  "per-event rotation diff ≈ coin flip with fat-left tail") from the *realized*
  laggard mechanism — independent confirmation, not the same data.
- **Reconciliation with "laggard = profit engine":** the +12.8-16.9% mean realized
  of laggard-exited trades is the gain those names had *already accumulated*
  before stalling; rotation harvests it and keeps capital deployed. The rotation
  *decision* (which name to swap into) adds ~nothing reliable on top. So
  laggard-rotation's value is **capital-recycling / freshness** — not letting
  capital rot in dead names, staying in the fat-tail game — **not** swap
  selection.

## Forward guidance (transferable why)

1. **Do not tune the rotation selection** (which laggard, when, into what). It is
   a coin flip per event; the same fat-tail-unpredictability that kills
   entry-selection (`project_accuracy_is_unreachable_diversify_instead`) and
   harvest-rotate kills swap-selection. Expected marginal gain ≈ 0.
2. **Keep laggard-rotation on** — it is roughly neutral-to-positive per swap and
   its recycling role is real; it is not a tax (unlike the stop's per-decision
   whipsaw cost). This is the third winner-touching mechanism confirmed as
   "neutral selection, value is elsewhere," tightening `project_edge_is_the_fat_tail`.
3. **Bias the next lever to a diversifying layer (long-short, Initiative B)** — an
   offsetting return stream — over any more entry/exit/rotation selection tuning.

## Caveats (per `mechanism-validation-rigor`)

- Cohort pairing, not strict 1:1 (no engine link exists); an entry may fund more
  than one rotation event (shared pool). The paired diff is per rotation event vs
  the redeployment pool available to it — the faithful proxy, not a controlled
  swap.
- Forward return = `Post_exit` continuation (price path), not realized P&L with
  stops; it measures the names' market moves, the right quantity for "which name
  was better," but not the strategy's actual realized capture on each.
- 36/296 (deep) and 22/220 (2011) rotations had no redeployment in the 10-day
  window (cash redeployed later or sat) — excluded from the paired stats.
