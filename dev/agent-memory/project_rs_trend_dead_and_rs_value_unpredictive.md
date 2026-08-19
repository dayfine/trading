---
name: project-rs-trend-dead-and-rs-value-unpredictive
description: "RS trend classification is structurally dead (lookback_bars=52 vs rs_ma_period=52 leaves a 1-element history) so every candidate scores Positive_flat forever; and rs_value carries no ranking signal — powered negative, permutation p=0.182."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-18T22:54:46.437Z
---

Two findings from 2026-08-18, issue **#2380**. They point in opposite
directions and both matter.

## 1. The trend classifier is dead by construction

`Rs._classify_trend` returns **`Positive_flat` unconditionally**, always, in
every run.

- `lookback_bars = 52` (`weinstein_strategy_config.ml:183`)
- `rs_ma_period = 52` (`rs.ml:15`)
- An SMA of period 52 over 52 aligned weeks yields **1 output**, so the history
  handed to `_classify_trend` has length 1 and hits its `n < 2` guard.
- Minimum viable `lookback_bars` = **56** (`ma-1 + trend_lookback + 1`).

Confirmed empirically: **0 `Bullish_crossover` and 0 `Positive_rising` across
4,231 tickets in three arms**; 1,456 of 1,466 recorded `Positive_flat`.

**Consumers that have therefore never fired:**

- `screener_scoring.ml:126` — every long lands on the `Positive_flat` branch, so
  the RS term is a **constant** `w_positive_rs / 2` contributing zero ranking
  information. Visible live: every A+ in the 2026-08-14 picks scores
  `85 = 15 + 20 + 10 + 30 + 10`, that 10 identical down the list.
- `sector.ml:68` — sector RS pinned at 0.7 (ratings still differentiate via
  stage + constituent%).
- `entry_ticket_tags.ml:30` — §4.5 `rs_zero_cross` unreachable, so
  `triple_confirmation` is a **double** and the 3-signal cohort does not exist.
- `screener_admission.ml:70` is `rs_blocks_short` — **short-side only**. Long
  admission never reads `rs_trend`, so the candidate *set* is unaffected.

Invisible because `rs_value` is populated and plausible; only the enum is
degenerate, and `Positive_flat` looks like a measurement rather than a fallback.
Nothing asserts the *distribution* of an enum, so no gate could catch it.

## 2. But `rs_value` carries no ranking signal — powered negative

Before assuming a working classifier would help, measure the live continuous
value. n=1,146 filled tickets, `position_id`-keyed, **`pnl_percent`** (dollars
are confounded by book growth $1M → $3.8M over 26y).

- 87% of the mass (rs_value 0.9–1.3) is flat at **+1.1% to +2.0%** mean with no
  trend.
- **`p90 %` does not rise with rs_value** (14.7 / 12.7 / 11.1 / 16.9 / 16.2) —
  the decisive test given [[project-edge-is-the-fat-tail]]: **RS does not select
  the tail.**
- ReLU knee sweep: at knee **1.0 the sign is backwards** (below +1.56% vs above
  +1.16%); gap sign flips across {0.90, 0.95, 1.00, 1.05, 1.10}.
- Permutation test on the one right-signed knee (0.90): observed +1.78%, null
  p90 = **+2.30%**, **p = 0.182** over 20,000 shuffles.

**So do not reshape the RS score** — continuous, ReLU, or re-weighted. There is
no monotonicity and no threshold to hinge on. Component-level confirmation of
[[project-entry-selection-closed-powered]].

**Scope limit:** measured on **admitted and filled** candidates only. It shows
RS is useless for *ranking* among candidates already through the screen; it does
**not** show RS is useless as an *admission* filter — the rejected population is
absent, and range restriction is what a working filter looks like afterwards.

## How to apply

Fix #2380 for **correctness, not returns**. The two real justifications:

1. The live weekly report **prints a falsehood** — ~45% of admitted candidates
   have `rs_value < 1.0` yet every pick shows rationale `"RS positive"`.
2. §4.5 stays blocked until `rs_zero_cross` can fire.

It re-pins goldens, so land it as a measured change. Expect **no** return
improvement, and say so up front so the re-pin is not misread as a regression.

One consequence worth a re-test afterwards:
[[project-entry-selection-closed-powered]] and
[[project-cascade-selection-inversion]] were both measured with a scorer whose
RS component was a constant. Those findings stand as measured, but the scorer
becomes a different function after the fix.

Method note: fixed-width bins beat deciles here — deciles stretched the 0.9–1.3
mass across six buckets and made noise look like structure
([[feedback-always-dissect-before-reporting]]).
