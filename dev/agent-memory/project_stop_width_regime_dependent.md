---
name: project_stop_width_regime_dependent
description: "Fixed-basis stop-width surface on the record convention (2026-09-03): initial_stop_buffer 0.98 (≈5.9% fallback) vs 1.0 (4%) is REGIME-DEPENDENT, not a default flip — 2000–04 wins 3/3 salts ex-monster with positive shared-trade drift and better maxDD; 2019–23 loses 3/3 ex-monster (its raw win is MSTR, wide-arm-only at every salt) with worse maxDD; structural footprint (−18…−29 stop exits per 5y window) identical in both"
metadata:
  type: project
---

**Measured 2026-09-03** (`dev/experiments/stop-width-surface-2026-09-03/`,
build e4984c5fe, record-baseline spec, warehouse, salts {0,1,2}; salt-0 nulls
= `record-rebase-2026-09-03` new arms):

| window | ex-monster Δ (wide − null) | shared-trade drift | maxDD wide − null | lopsided monster |
|---|---|---|---|---|
| 2019–23 top-3000-2019 | −$96k / −$269k / −$106k | −$67k / −$13k / −$62k | +9.6 / +11.9 / +9.6pp | MSTR 2020-10-12 (+$580k) wide-only every salt |
| 2000–04 top-3000-2000 | +$207k / +$150k / +$229k | +$78k / +$86k / +$87k | −7.8 / +1.0 / −7.7pp | IPIXQ 2004-04 (+$255k) null-only 2 of 3 salts |

26y confirmation (salt 0): wide 376.38% / 626 / 0.445 / maxDD 37.65 vs null
302.65 / 723 / 0.397 / 36.26 — +74pp, but shared drift −$34k and the gap is
wide-only monsters (MOS 2006 +$795k) plus larger shared monsters (NVDA, MKSI,
BPT); 93 fewer stops; maxDD +1.4pp. Pre-registered rule (≥2/3 salts on BOTH 5y
windows ex-monster, 26y maxDD not worse) NOT met. Merged as PR #2659 → 4de5236bd (2026-09-04). Both
windows show the same footprint (fewer whipsaw stop exits); whether the
survivors pay depends on the tape.

**Why:** a 4% stop is inside the daily noise of a 2000–04 bust/recovery tape
(shakeouts pierce it and the 5.9% stop survives — +1.2pp per shared trade),
but in the 2019–23 melt-up the extra room mostly delays the same exits at a
worse price and holds more drawdown. The level in each window is still set
by one monster's admission (MSTR / IPIXQ), so raw deltas are unreadable; the
shared-drift sign is the honest signal and it flips with regime.

**How to apply:** `initial_stop_buffer` stays at 1.0 by default; 0.98 is a
legitimate regime/preset dial (trader-mode percentage fallback, §5.3), not a
promotion candidate. Any future stop-width read must report shared-trade drift
and the ex-monster delta per salt, never the raw return. Related:
[[project_stop_anchor_surface_is_dds]] (cell-B base: the same width won 3/3
ex-monster on 2019–23 — base-dependent too), [[project_d1d2_mechanism_decomposition]],
[[project_fallback_stop_half_book_band]], [[project_edge_is_the_fat_tail]].
