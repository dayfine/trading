# The demoted-wide cohort needs no schema change — it is already derivable

The 08-18 priorities list carried this as a build item:

> Make the demoted-wide cohort greppable before `Demote_over_max` (#2352) is
> swept. Today a wide-but-under-ceiling entry traces as `"Pass"` with
> `sized_down_wide_stop = false`, so the population is unattributable in the
> audit. Needs a third trace outcome or an audit field — a schema decision.

The premise is right; the conclusion is not. **No schema decision is needed.**

## Why the population looked unattributable

`Stop_width_mode.gate` returns `Admit` for a wide-but-under-ceiling stop under
`Demote_over_max` — demotion reorders the walk, it does not change sizing, so the
candidate flows through the identical `build ~sized_down:false` path as a
normal-width admit (`entry_audit_capture.ml:139-140`). The two persisted F3
markers are therefore both blind to it: the trace outcome is `"Pass"` and
`ticket_lifecycle.sized_down_wide_stop` is `false`.

## Why it is nonetheless recoverable

The gate's own input is a pure function of two values the audit **already**
persists per entry:

```
stop_distance_pct = |installed_stop - effective_entry| / effective_entry
                                  -- entry_audit_helpers.stop_distance_pct
```

`installed_stop` is an `entry_decision` field. `effective_entry` is
`suggested_entry` when `sim_entry_trigger_at_suggested = true`, and
`close_at_decision` otherwise (itself falling back to `suggested_entry` when the
bar reader had no close) — all persisted, and the flag is a run-level config
constant. `max_stop_distance_pct` is likewise a run constant. So the
demoted cohort of any `Demote_over_max` arm is exactly

```
admitted entries whose derived stop_distance_pct > max_stop_distance_pct
```

with no new field, no third trace outcome, and no migration of an on-disk schema.

### Verified against a real artifact

Derived over all 1,425 placed tickets of ladder-v4 cell 00 (`Drop_over_max`, the
default, `max_stop_distance_pct = 0.15`):

```
p1 = 2.08%   p50 = 2.36%   p90 = 14.17%   p99 = 14.92%   max = 14.99%
entries over the 15% ceiling: 0
```

Zero over the ceiling and a maximum a hundredth of a point under it is the gate
reproducing itself — the derivation matches what the strategy computed, not an
approximation of it. On a `Demote_over_max` arm the same expression returns the
demoted population instead of the empty set.

## Two findings that fell out of the derivation

**1. The width distribution is bimodal, and the split is the stop construction.**

| `stop_floor_kind` | n | mean stop distance | within 1pp of the 15% gate |
|---|---|---|---|
| `Buffer_fallback` | 867 | **2.3%** | 1 |
| `Support_floor`   | 558 | **13.2%** | 167 |

Banded: 861 under 5%, only 19 in 5–10%, 377 in 10–14%, 168 in 14–15%. The valley
is not noise — it is two different stops. A buffer under the entry is narrow by
construction; a stop at the structural base is wide by construction.

**2. `max_stop_distance_pct` is not a generic risk cap — it is a filter on
structurally-anchored entries.** Essentially every candidate the 15% gate can
reach carries a `Support_floor` stop, i.e. the stop placed the way the book
places it. 167 of the 558 structural entries sit within one point of the gate, so
the gate's edge is crowded: a small ceiling move re-admits or drops a large block
at once.

On the **dropped** side the evidence is weaker, and is stated as such. The 1,425
tickets measured above are the gate's **survivors**; the `Stop_too_wide` cohort
is a different, unmeasured set, and the only case traced end-to-end is AXTI
(21× `Stop_too_wide`, `dev/notes/axti-entry-construction-from-raw-bars-2026-08-18.md`),
whose stop is structural. So the supported claim is that what the gate drops
should be **predominantly** book-faithful — by the arithmetic that a fast mover
off a deep base has a structural stop far below its breakout — not that it is
*never* from the buffer population. A `Buffer_fallback` stop can exceed the
ceiling in principle, and one already sits within a point of it. The dropped
cohort is derivable from the same artifact by the same expression; until it is
enumerated, "never" is not earned.

That is the same structural exclusion `project_faithful_ticket_structural_exclusion`
recorded from the ladder-v3 side, arrived at here from the artifact rather than
from one symbol — and it is the mechanism behind `max_stop_distance_pct` reading
as a concentration dial in `project_record_gap_is_concentration`.

## Calibration — what these numbers may not be used for

- **The ceiling check is one-sided.** Under `Drop_over_max` @ 0.15, "entries over
  the 15% ceiling: 0" is **true by construction** for the surviving population:
  the gate already removed anything above the ceiling, so the derivation cannot
  fail that check by running systematically *low*. It is a necessary condition,
  not a two-sided validation. What actually discriminates is the **boundary
  crowding** — max 14.99%, p99 14.92%, 168 entries in the 14–15% band. A
  derivation that were merely approximate would not pile up against the ceiling
  and stop a hundredth of a point short of it. Read §"Verified against a real
  artifact" as *"consistent with reproducing the gate, on the strength of the
  boundary behaviour"*, not as a proof of exactness.
- **One arm, one universe, one window.** Everything here is ladder-v4 cell 00
  (26y, top-3000, `Drop_over_max` @ 0.15). The bimodality and the 867/558 split
  are properties of that arm's stop construction; neither the split ratio nor
  the 2.3% / 13.2% means are claimed to transfer to another cell. The
  *derivability* argument — the mechanical point this note exists to make — does
  transfer, because it rests on which fields the audit persists, not on their
  values.
- **Survivors only.** Every distribution above is over admitted tickets. No
  claim about the dropped `Stop_too_wide` cohort is measured here; see the hedge
  in §2.
- **No P&L claim is made or possible.** Nothing here says the demoted or dropped
  cohorts would have been profitable. The note's conclusion is about *schema*
  (no new field is needed), not about whether the ceiling should move.

## What to do instead of the schema change

- Sweep `Demote_over_max` when its turn comes; attribute the cohort with the
  derivation above (the extractor in
  `dev/experiments/ticket-funding-cohort-2026-08-18/cohort_from_audit.sh` reads
  the same records and is the place to add the column).
- Keep `sized_down_wide_stop` as-is. It is not redundant: it records that sizing
  *was shrunk*, which the derivation cannot recover — the mode is what
  distinguishes them, and the mode is a run constant.
- If a future mode makes the width relation ambiguous per-entry (e.g. a mode
  selected per candidate rather than per run), revisit — that, not this, is what
  would force a schema field.
