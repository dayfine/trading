---
name: project-stop-anchor-flag-already-exists
description: "The 'ignore prior support, install a flat % stop for fast movers' mechanism is ALREADY built as config.stop_anchor_at_entry_base (default-off since 2026-08-06) — no Cap_at_max needed; and the book's flat stop is 4-6%, not the 15% admission gate."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-19T08:13:58.869Z
---

**Do not build `Cap_at_max` or any new `Stop_width_mode` for wide stops.** The
mechanism exists, default-off, since 2026-08-06.

`entry_audit_helpers.ml:83`, `_maybe_reanchor_to_entry_base`:

```ocaml
let should_reanchor =
  reanchor && Float.( > ) dist stops_config.max_stop_distance_pct in
if not should_reanchor then (raw_stop, structural_kind)
else ... compute_initial_stop_with_floor_with_callbacks
         ~callbacks:empty_callbacks ~fallback_buffer:initial_stop_buffer
```

When the support-floor stop lands farther than `max_stop_distance_pct` from
entry, it **discards the structural floor and installs a plain
`entry × initial_stop_buffer` stop**. `~callbacks:empty_callbacks` is what makes
it ignore prior support (the stops layer sees no bars → buffer fallback).
In-limit candidates are returned verbatim. Gated by
`config.stop_anchor_at_entry_base` (`[@sexp.default false]`); the header records
"user go 2026-08-06". `Cap_at_max` with `initial_stop_buffer = 0.85` would be
bit-identical to arming it.

`initial_stop_buffer` is a **multiplier**, not a percentage: 0.92 = 8% below
entry, 0.85 = 15% below.

## The book grounding — two sections, opposite directions

- **§5.1** — *"if stop requires >15% risk from entry → prefer other
  candidates."* That is the shipped default (`Drop_over_max`,
  `weinstein_strategy_config.ml:249`; `max_stop_distance_pct = 0.15`,
  `stop_types.ml:67`). **Dropping the candidate is the faithful response to a
  far base**; re-anchoring is a departure from it.
- **§5.3 Trader Method** — *"use 4-6% initial stop if no nearby prior peak."*
  The book **does** sanction a flat non-structural stop — in the trader preset,
  conditioned on *no nearby prior peak*, at **4-6%**.

**15% is §5.1's rejection threshold, not a stop level the book ever recommends
placing.** Conflating the admission gate with a stop level is the trap; they
share a number by coincidence. The unsettled judgement is whether "structure
exists but sits 48% below E" (AXTI at E = 2.71, base ≈ 1.4) satisfies "no nearby
prior peak" — a `blind-judge` question, to settle *before* reading a surface as
a promotion case.

## The only open work

A surface with **zero new code** (both are real config fields → Variant_matrix
axes today):

```
((flag stop_anchor_at_entry_base) (values (false true)))
((flag initial_stop_buffer)       (values (0.85 0.92 0.94 0.96)))
```

Read **max single-trade P&L**, not the top line: a tighter flat stop admits the
fast movers the 15% gate drops but whipsaws them out
([[project-edge-is-the-fat-tail]]).

The companion "re-anchor the stop to the actual fill" idea is **dead** —
measured on `position_id`, n=1,133, mean drift +0.28pp, 0% beyond 20%.

Plan: `dev/plans/stop-anchoring-fast-movers-2026-08-19.md` (#2389).
Related: [[project-max-stop-filters-structural-stops]],
[[project-stop-gate-not-entry-anchor]],
[[feedback-grep-for-the-flag-before-designing-it]].
