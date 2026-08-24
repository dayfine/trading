---
name: project-fallback-stop-half-book-band
description: "floor_stop.ml's fallback initial stop is entry×1.02×0.96 = 2.08% below entry — HALF the book §5.3 4-6% band — because _fallback_reference pushes the support-level stand-in ABOVE a long's entry before the 4% haircut. Pervasive COMMON-PATH bug (control arm without stop_anchor_at_entry_base still 40/63 tight): the 90-bar ≥8% support scan finds nothing for most breakout candidates. Pinned by test_fallback_stop_width.ml."
metadata:
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-23T06:01:28.728Z
---

**2026-08-22 addendum — the fallback stop also FREEZES the trailing ratchet
(issue #2486).** Found by the #2485 rework agent building a synthetic fixture:
with a fallback stop, `_completed_cycle_stop` seeds `last_correction_extreme`
from the entry-bar low, `_advance_tracking` only lowers it, and the candidate
`anchor × 0.99` sits permanently BELOW the fallback stop — the first correction
cycle can never fire, so the stop never rises above its initial level no matter
how far price advances (proven across 5 fixture shapes incl. a 9-week advance).
Since fallback is the COMMON path, most positions may not be trailing at all.
Unverified on real data — #2486 asks for the per-position measurement (did the
installed stop ever rise, split by fallback-vs-support-derived). Interacts with
the `initial_stop_buffer` flip decision.

**The buffer-fallback initial stop is half the book's flat-stop band, and the
cause is a direction error.** In `floor_stop.ml`, when the 90-bar scan finds no
qualifying counter-move:

```
_fallback_reference (Long): reference = entry × initial_stop_buffer (1.02)   ← ABOVE entry
compute_initial_stop:       stop = reference × (1 − min_correction_pct/2)    (−4%)
net: entry × 0.9792 → 2.08% stop   (book §5.3 band: 4–6%)
```

The reference stands in for a *support level* — below a long's entry — but is
inflated 2% above it. Counterfactuals through the same `compute_initial_stop`:
reference = entry ⇒ 4.00%; reference = entry/1.02 ⇒ 5.88% — either is in-band.
Short side symmetric (~1.96–2.04% incl. round-number nudge).

Verified arithmetic-exact on ADP 2019-02-22 (`installed_stop 150.777216` =
153.98 × 1.02 × 0.96, `Buffer_fallback`). In the 6-mo inspection arm
(`inspect-6mo-arc`): 42/59 trades at exactly 0.0208; 23 of 24 stop_loss exits
in that cohort at 17% win rate = essentially the whole loss. Distribution is
bimodal (nothing between 0.04 and 0.124), so the cohort is cutoff-robust.

**Pervasive common-path bug, NOT arc-induced.** The `inspect-6mo-nobasestop`
control (flag off) still shows 40/63 trades at 0.0208, `Buffer_fallback` 73:23:
for most breakout candidates the 90-bar ≥8%-pullback support scan finds no
qualifying counter-move, so the fallback fires in any config.
`stop_anchor_at_entry_base` touches only the rare >15% `Stop_too_wide` cases.
Companion control `inspect-6mo-novolconf`: removing the volume eject restores
holding (mean 4.4→15.0 days, CHDN rides to period end) but return stays −4.5% —
the eject caps the tail, this stop does the bleeding; fixing the eject alone
does not stop the bleed.

**Why tests missed it** (corrected by QC — my first framing was wrong):
`test_support_floor.ml` rebuilds its expectation from its own local `1.02`
literal, so a direction flip in `_fallback_reference` WOULD break it — it pins
the reference *convention*. What no assertion anywhere expressed is whether the
produced stop WIDTH is in-band; the convention tests are hand-re-baselined
against whatever the code produces. Too-narrow predicate, same class as
[[feedback-pin-every-element-of-a-category]].

**Pinned:** `trading/weinstein/stops/test/test_fallback_stop_width.ml` — exact
level + below-band + counterfactuals.

**Fix is ZERO-CODE and verified:** `initial_stop_buffer` is already a config
field; the defect is its default *value*. The `inspect-6mo-bookstop` arm set
`((initial_stop_buffer 1.0))` (reference = entry → 4.0% stop, band low): modal
stop moved 0.0208 → **0.0400 exactly** (25/39), stop_loss exits 24 → 4, return
−4.17% → +4.83% on the same window. Armed in the arc bundle (#2452). The
**global default flip** (1.02 → 1.0) moves every fallback-path golden and
breaks record-baseline comparability — open USER decision.

Related: [[project-stop-anchor-flag-already-exists]] (book flat stop = §5.3's
4-6%), [[project-max-stop-filters-structural-stops]],
[[project-edge-is-the-fat-tail]].
