---
name: project-26y-path-noise-floor
description: 26y path noise: below about 0.2 log untraced deltas are noise, not the 0.044 salt range (one draw) — one list name moved the end NAV 0.204 log (#3266 rerun 10-23)
metadata:
  type: project
---
#3266 rerun (2026-10-23, `dev/experiments/verify-3266-rerun-2026-10-22/` §3.4): the same 26y spec with vs without CMN in
five pit-v12 lists was identical to the cent through 2009-11-06, then ended **0.204 log** apart (1,521.64 vs 1,222.29 %).
The twin leg itself made +$28.7k; the cash it took cancelled ASR and pre-empted a CRM ticket (+$425k). A $68.58 cash
shortfall on FDX 2026-04 moved the end NAV another 0.037 log. Salt ranges (N 0.044, chain V M 0.044) are near-replicate
paths and understate this.

**Why:** the cash-pool cascade turns any candidate-set or cash change into a different tail draw
([[project_funding_grid_monster_lottery]], [[project_edge_is_the_fat_tail]]).
**Superseded in part (10-28):** the measured 26y seed SD is 0.225, so the single-cell floor is ~0.45 log at 2 SD ([[project-record-kseed-band]]).
**How to apply:** a 26y level delta below ~0.45 log that is not traced to the lever's own trades is path noise. Read only
within-tree pairs with trade-level traces; optionally measure a perturbation null (3–5 inert single-name deletions) once.
Any twin dedupe (#3388) re-draws the record path. Measured 2026-10-31 (#3489): the full dedupe re-drew it as a few local steps that re-synchronise, |d| <= 0.048 per seed, because no tail trade moved. A universe change moves the record by how far its cascade reaches a tail trade, not by how many names it removes.
**Nested windows re-synchronise too (11-14, #3610):** a sub-window cell started from cash on its parent's seeds converged on the parent's positions within 2–6 years (Seeded hashes seed|date|ticker; sizes are NAV fractions), so it re-measures the parent rather than replicating it. Period cells must be disjoint.
