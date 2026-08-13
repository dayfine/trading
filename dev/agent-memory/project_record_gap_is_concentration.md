---
name: project-record-gap-is-concentration
description: "The record's ~9x return lead over the faithful arms is AXTI (last 4x) plus a 2.2x seeded 2000-2004 by running HALF the concurrent positions — concentration, not selection"
metadata: 
  node_type: memory
  type: project
  originSessionId: d7d8f2bb-6b58-4fde-8e01-c50e796e5faa
  modified: 2026-08-12T18:49:50.797Z
---

Decomposed 2026-08-12 from `record-nextopen` (+7,320.8%, realized $66.8M) vs
ladder-v4 cell 07 `maxstop50-diag` (+726.2%, realized $7.0M), same window,
same universe.

**1. AXTI is the last ~4x, not the gap.** One trade — entry 2025-06-30 at
$2.05, exit 2026-05-30 at $115.45, +5,531%, **$56.2M = 84% of the record's
realized PnL**. Real, not a split artifact (`adjusted_close == close`; volume
165k → 11M/day). It needed a **57.3% stop**, outside §5.1's 15% and outside
even the 50% diagnostic. Excluding it: record $18.0M vs ours $8.26M = **2.18x**,
matching the end-2024 equity ratio exactly.

**2. The 2.2x was seeded 2000-2004 and compounded.** Equity ratio 1.12x (2000)
→ 1.50x (2004) → 1.94x (2023) → 2.20x (2024). Not uniform: cell07 BEATS the
record in 2007 (+34.5 vs +8.0), 2016, 2018 (−2.5 vs −21.8), 2012, 2013.

**3. The cause is CONCENTRATION, not selection or exits.**

| | mean concurrent positions | peak | 2003 mean notional |
|---|---|---|---|
| record | **4.9** | 10 | $187,247 |
| cell07 | **10.6** | 22 | $94,997 |

Both run `max_position_pct_long=0.14` / `max_long_exposure=0.70`, so 70%
exposure fills with 5 positions. The record sits at that cap; cell07 spreads
across ~2x more names at ~half the size.

On trades both take, **pnl ratio ≈ quantity ratio** — we do not pick or exit
worse, we buy fewer shares: GE 3.05 vs 3.06, LOGI 1.28 vs 1.27. ADSK 2003 is
the top winner for BOTH, held ~460 days by both; the record had 2.6x the
notional and got 3.0x the PnL.

**How to apply:** `max_stop_distance_pct` is not only an admission filter, it is
a **concentration dial** — wider admission funds more candidates, which dilutes
every position, which halves what each monster contributes
([[project-edge-is-the-fat-tail]]). Any experiment that widens admission must be
read for its concentration side-effect, not just its selection effect. The
lever worth testing is explicit concentration (fewer, larger positions), which
[[project-capacity-concentration-surface]] left open with no promotable value.

**Separate, smaller channel:** premature stop-outs. BANB — same entry date,
similar size — record held 190 days for +101%; cell07 stopped out after **1
day** at +1.42%.

Caveat: cell07 is the `maxstop50` diagnostic and its
`stop_initial_distance_pct` is only 43% populated (issue #18), so stop-width
distribution comparisons against the record (100% populated) are unreliable.
