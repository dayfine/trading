# Why zero AXTI tickets filled — the resting ticket dies silently on a cash shortfall

**Task 22 from `next-session-priorities-2026-08-16.md`, resolved.** The answer is
neither of the two candidates that doc listed (`entry_extension_max_pct` band,
"superseded"). It is a third thing, and it is systemic rather than AXTI-specific.

## The answer, in one line

The 2025-06-27 AXTI ticket **triggered and the engine filled it** — at 2.7475,
comfortably inside the 2.7642 do-not-chase cap — and then the **portfolio
rejected the fill for insufficient cash**, which silently destroyed the ticket:

```
WARN: portfolio rejected fill for AXTI (side=Types.Buy qty=44982.0000 price=2.7475):
  "Insufficient cash for trade. Required: 124038.83806625092,
   Available: 16531.08760660814, Unrealized loss drag: 0."
  Stranded position will be reverted for retry (see Cancel_handler).
```

It was not reverted for retry. AXTI then ran **2.03 → 11.76 (5.8×)** with zero
participation, and reappeared as a fresh candidate on 2025-10-31 (score 70),
skipped `Insufficient_cash` four more times.

## First: the premise in the priorities doc was a grep artifact

The 2026-08-15 diagnostic table read:

| arm | AXTI tickets | AXTI fills |
|---|---|---|
| core (`Window_extreme`) | 1 | 0 |
| nearfloor (`Nearest`) | 4 | 0 |
| nearfloor + `stop_anchor_at_entry_base` | 5 | 0 |

Those counts are `grep -c AXTI trade_audit.sexp`, which also counts rows where
AXTI appears inside some *other* ticket's `alternatives_considered` list. The
real counts (`grep -c '(symbol AXTI) (entry_date'`) are:

| arm | AXTI **tickets placed** | as skipped alternative | fills |
|---|---|---|---|
| core | **0** | 1 × `Stop_too_wide` (score 100) | 0 |
| nearfloor | **0** | 4 × `Stop_too_wide` | 0 |
| nearfloor + `stop_anchor_at_entry_base` | **1** | 4 × `Insufficient_cash` (all on 2025-10-31) | 0 |

So "stop-side fixes raise admissions 1 → 4 → 5" is wrong. The correct statement
is stronger and cleaner: **only the `stop_anchor_at_entry_base` arm ever placed
an AXTI ticket at all**; the other two arms rejected AXTI with `Stop_too_wide`
every time it screened. The stop-side fix is what got AXTI past the gate — the
defect-A evidence survives, restated.

(`feedback_always_dissect_before_reporting` again: the top-line count was never
the finding.)

## The mechanism, step by step

1. **2025-06-27** — ticket placed. `suggested_entry` 2.71, `close_at_decision`
   2.03, `ma_value` 1.673, `installed_stop` 2.6536 (`Buffer_fallback`),
   `initial_position_value` $121,901 → **44,982 shares, frozen at placement**.
   That same audit record shows 20 alternatives all skipped
   `Insufficient_cash`: the book was already cash-tight the day the ticket was
   written.
2. **No cash is reserved** for a resting ticket. Over the next eight weeks the
   portfolio deployed into AD ($123k), MLKN, AIT ($120k), RPM, O ($122k), DLX
   ($121k).
3. **~2025-08-22** — AXTI's weekly bar (open 2.06, high 2.85, close 2.82) crosses
   the 2.71 trigger. `Engine._would_fill_stop_limit` fills at **2.7475**, inside
   the `2.71 × 1.02 = 2.7642` cap. The do-not-chase band is *not* the blocker.
4. **`Engine._process_order_with_execution` marks the order `Filled`** the moment
   the fill function returns a trade — *before* the portfolio ever sees it.
5. **`Cancel_handler.apply_trades_best_effort`** then rejects the trade: needed
   $124,039, had $16,531.
6. **`transitions_for_rejected_trades`** emits a `CancelEntry` for the position.
   The ticket is gone. The order is gone (already `Filled`). Nothing is retried.

## Three distinct defects fall out of this — call them G1/G2/G3

### G1 — the audit cannot see it (emission)

`Simulator._process_fills_and_cancels` builds `cancel_transitions` and applies
them **locally**; `_notify_transitions` is called separately with the transitions
coming out of `Margin_runner.tick (strategy_transitions)`. The portfolio-rejection
`CancelEntry`s **never reach the audit observer**, so
`Ticket_lifecycle.ticket_age_weeks_at_cancel` is never stamped for them.

Measured on the diagnostic run (`d2-nf-anchor`, top-3000 × 2024-2026):

| | count |
|---|---|
| placements in `trade_audit.sexp` | 234 |
| with `ticket_age_weeks_at_fill` (round trips) | 166 |
| open at end of run | 7 |
| with `ticket_age_weeks_at_cancel` | **0** |
| **unaccounted for** | **61 (26%)** |

`ticket_age_weeks_at_cancel` is written **zero times in the entire run**. With
`entry_order_ttl_weeks = 0` there are no strategy-side cancels, so the only
cancels that exist are exactly the ones the observer cannot see. A reader of the
artifact cannot distinguish "still resting at end of run" from "killed by a cash
collision" — which is why yesterday's session had to call the zero fills
"unexplained".

### G2 — the retry the code promises does not happen (behaviour)

The WARN string says *"Stranded position will be reverted for retry (see
Cancel_handler)"*. That revert path (`Cancel_handler.revert_rejected_exits`,
`Exiting → Holding`, #1553) is **exit-side only**. On the entry side the same
rejection routes to `CancelEntry`, which deletes the ticket. And because step 4
already marked the resting order `Filled`, there is no order left to re-offer
next tick either.

**One cash-tight instant permanently destroys a ticket** that may have rested for
months. The margin of destruction can be arbitrarily small — from the same run:

| symbol | needed | had | shortfall |
|---|---|---|---|
| PRGS | 138,244 | 137,847 | **$397 (0.3%)** |
| LSCC | 135,491 | 131,739 | $3,752 (2.8%) |
| KFY | 119,963 | 115,731 | $4,232 (3.5%) |
| BP | 135,109 | 130,601 | $4,509 (3.3%) |
| TTC | 139,534 | 130,601 | $8,933 (6.4%) |

A 0.3% shortfall killing a ticket outright is not a risk rule; it is an
all-or-nothing artifact of sizing frozen at placement.

### G3 — size is frozen at placement, cash is not reserved (design)

`CreateEntering` carries `target_quantity` computed against the equity and price
of the *placement* week. Eight weeks later that quantity is re-priced at the fill
(44,982 × 2.7475 = $124k against a $121.9k design) and matched against whatever
cash survived the intervening weeks. There is no reservation, no re-size, no
partial fill. The three plausible fixes (reserve at placement / re-size at fill /
allow partial) are materially different strategies and want a real experiment,
not a patch.

## It is systemic, not an AXTI anecdote

`grep -c "WARN: portfolio rejected fill"` over the confirmation-grid runs:

| run | rejected fills | round trips |
|---|---|---|
| gridB-sp500-core-s0 (26y) | 269 | 1041 |
| gridB-sp500-core-s1 | 277 | 1066 |
| gridB-sp500-core-s2 | 283 | 1035 |
| gridB-sp500-nearfloor-s0 | 233 | 982 |
| gridC-t3k2010-core-s0 (16y) | 217 | 799 |
| gridC-t3k2010-core-s1 | 213 | 759 |
| gridC-t3k2010-nearfloor-s0 | 148 | — |
| d2-nf-anchor (2.5y, top-3000) | 44 | 166 |

Consistently **~25% of would-be entries die this way**, across universes, periods
and arms. Nothing in any artifact records it.

## Why this matters beyond bookkeeping

`project_record_gap_is_concentration` established that the record arm runs 4.9
concurrent positions against our 10.6 — same exposure, roughly double the size
each — and that the gap is dilution, not selection. G2/G3 are a *mechanism* for
that: we write more tickets than the book can fund, they trigger into a starved
book, and a quarter of them are destroyed at the moment of triggering — with
selection **by arrival order, not by rank**. AXTI (cascade score 100, grade
A_plus at placement) lost its ticket to whatever happened to trigger first that
week.

This is also a **tail-preserving** lever, which matters given
`project_edge_is_the_fat_tail`: the population being destroyed is breakouts
*that actually broke out*. AXTI's post-rejection path was 5.8× in four months.
Every prior rejected lever taxed the tail; this one currently taxes it by
accident.

## What to do, in order

1. **G1 first — make it visible.** Route the rejection `CancelEntry`s through
   `_notify_transitions` so `ticket_age_weeks_at_cancel` is stamped, and add a
   `cancel_reason` to the lifecycle record so `Portfolio_rejected` is separable
   from a TTL cancel. Pure emission, no behaviour change, no golden movement.
   This is the honest scope of defect **F**.
2. **Then measure.** With G1 landed, the question "what would we have made on the
   ~25% we destroy" is answerable from the artifact instead of from stderr greps.
3. **Only then G2/G3**, as default-off flags with a real surface
   (`experiment-flag-discipline.md`): re-offer the order after a rejection;
   size-to-available-cash at fill; reserve at placement. Three axes, one grid.

## Corrections to the record

- The AXTI ticket/fill table in `next-session-priorities-2026-08-16.md` is a grep
  artifact; corrected above.
- The audit does **not** omit `ma_value` / `close_at_decision` / the resistance
  price. `Trade_audit.entry_decision` carries `ma_value`, `close_at_decision`,
  `local_range_top`, `suggested_entry`, `suggested_stop`, `installed_stop`,
  `stop_floor_kind` on every placement row — verified on this run's
  `trade_audit.sexp`. The real emission gap is ticket **resolution**, not
  placement provenance. Defect F should be re-scoped to G1.
