---
name: project-max-stop-filters-structural-stops
description: "Stop width is bimodal by stop construction — Buffer_fallback 2.3% vs Support_floor 13.2% — so max_stop_distance_pct filters almost exclusively the book-faithful structural stops; and the demoted-wide cohort is derivable from persisted fields, no schema field needed."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-18T06:18:28.733Z
---

Derived 2026-08-18 (PR #2371,
`dev/notes/demoted-wide-cohort-derivable-2026-08-18.md`) over all 1,425 placed
tickets of ladder-v4 cell 00.

**No schema change is needed to attribute the `Demote_over_max` cohort.**
`stop_distance_pct = |installed_stop - effective_entry| / effective_entry`
(`entry_audit_helpers.stop_distance_pct`) is a pure function of two fields the
audit already persists — `installed_stop`, and `effective_entry` =
`suggested_entry` when `sim_entry_trigger_at_suggested`, else
`close_at_decision`. The demoted cohort of any `Demote_over_max` arm is
therefore *admitted entries whose derived distance exceeds
`max_stop_distance_pct`*. Verified: on a `Drop_over_max` arm the derivation
gives max **14.99%** and **zero** entries over the 15% gate — it reproduces the
gate rather than approximating it. This retires the planned "third trace outcome
or audit field" item. Keep `sized_down_wide_stop`: it records that sizing *was
shrunk*, which the derivation cannot recover.

**The width distribution is bimodal, and the split is the stop construction:**

| `stop_floor_kind` | n | mean distance | within 1pp of the 15% gate |
|---|---|---|---|
| `Buffer_fallback` | 867 | **2.3%** | 1 |
| `Support_floor` | 558 | **13.2%** | 167 |

Banded: 861 under 5%, only 19 in 5–10% (the valley is two different stops, not
noise), 377 in 10–14%, 168 in 14–15%.

**Why it matters.** `max_stop_distance_pct` is **not a generic risk cap** — it
is a filter on structurally-anchored entries. Every candidate it can reach
carries a `Support_floor` stop, i.e. the stop placed the way the book places it,
and 30% of that population sits within one point of the gate, so a small ceiling
move re-admits or drops a large block at once. Everything it drops
(`Stop_too_wide`, AXTI 21×) comes from the book-faithful population, never from
the buffer population.

Same structural exclusion as
[[project-faithful-ticket-structural-exclusion]], reached from the artifact
rather than from one symbol, and the mechanism behind the knob reading as a
concentration dial in [[project-record-gap-is-concentration]]. Pairs with
[[project-stop-gate-not-entry-anchor]]: the gate, not the anchor, is what
rejects.
