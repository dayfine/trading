# Stop anchoring for fast movers — two separable ideas

**User, 2026-08-18:** *"if a symbol is going off quickly, e.g. AXTI when E = 2.7,
where its most recent base is 1.4X, it should really be treated as something
that's moving very fast, so directionally its stop loss should be local (15%
down) … whether in that case the prior support should be ignored, and we just
install a plain 15% stop instead — and maybe this stop should be dynamically
adjusted on-fill to be exactly / closer to -15% of the actual fill."*

Two ideas, separable, and the second is already a **measured defect**.

---

## Idea A — cap the stop instead of refusing the candidate

### The geometry the current rule gets wrong

The book anchors the initial stop below **the base low or the MA**
(`weinstein-faithful-core.md` spine item 5). That works when the breakout is
near its base. For a stock that has already run far, both anchors are far:
AXTI at E = 2.71 had base lows of 1.13–1.47, i.e. a stop **34–58%** away, and
its 30-week MA was comparably distant. There is no near anchor to find, so
`Drop_over_max` refuses the candidate — 21 times, in AXTI's case.

The user's point is that the *question* has changed. For a name that has moved
140% off its base, "will it revert to the base" is not the live risk; "will it
break down from here" is. The base is history, not support.

### The system already has flat-percentage stops

This is what makes the idea cheap rather than novel: **`Buffer_fallback` already
installs `entry × initial_stop_buffer`** whenever no structural floor is found.
On the 2026-08-14 live picks that is **13 of 20 candidates**, spanning
2.08–4.57%. A non-structural stop is not foreign to this system — it is the
majority case.

The current rule just triggers it for the wrong reason:

| condition today | stop used |
|---|---|
| no structural floor found | flat `entry × buffer` |
| floor found, within the cap | the structural floor |
| **floor found, beyond the cap** | **candidate refused entirely** |

The third row is the one under discussion. "Unusably far" and "not found" are
arguably the same situation from the risk side, and today they are treated
oppositely.

### Shape: a fourth `Stop_width_mode`

`Stop_width_mode` already enumerates what to do with an over-cap candidate.
This is the missing member:

| mode | behaviour when the structural stop exceeds `max_stop_distance_pct` |
|---|---|
| `Drop_over_max` (default) | refuse the candidate |
| `Size_down` | admit; fixed-risk sizing shrinks the share count |
| `Demote_over_max` | admit; demote its rank in the entry walk |
| **`Cap_at_max`** (proposed) | **admit; replace the stop with one at exactly the cap** |

Default-off, no-op preserved, expressible as a `Variant_matrix` axis — the same
discipline as its three siblings (`experiment-flag-discipline.md` R1/R2).

### Faithfulness — this is the part to argue honestly

A flat percentage stop **is** a departure from spine item 5 as literally
written ("risk is defined at entry by the base low or the MA, not an arbitrary
percentage divorced from structure"). Two defences, and they should be stated
rather than assumed:

1. **It is a fallback, not a replacement.** The structural rule still governs
   every candidate whose floor is usable. `Cap_at_max` fires only where the
   book's own anchor is unusable, which is exactly where `Buffer_fallback`
   already fires for a different reason.
2. **The alternative is not "a faithful stop" — it is no trade at all.** The
   honest comparison is `Cap_at_max` vs `Drop_over_max`, not vs some faithful
   stop we are giving up. We are not loosening a stop; we are choosing between
   a capped position and no position.

That said, `blind-judge` is the right instrument here: the question *"would a
careful reader of the book place a 15% stop on this, or pass?"* is precisely
what that skill exists to answer, and our own reading is self-interested.

### Prior art to respect

`Nearest` (`support_floor_anchor_scope`) already tries "use a closer structural
floor" and **failed its promotion grid 0-of-3**
(`project_nearfloor_is_risk_not_return`). `Cap_at_max` is a different object —
it abandons structure rather than seeking nearer structure — but the failure is
a warning that the near-anchor family has not paid.

Counter-consideration, and it is a real one: `project_edge_is_the_fat_tail`
plus the AXTI arithmetic say the over-cap population is exactly the
crash-recovery / fast-mover cohort where the monsters live. A 15% stop on a
name whose normal weekly range is 20% may simply harvest the position before
the move — converting "no trade" into "a small loss", which is worse than
either. **That is the primary risk of this idea and the thing the surface must
measure**, not the return.

---

## Idea B — re-anchor the stop to the actual fill (a measured defect)

Independent of A, and **not a proposal so much as a bug report**.

The stop is computed at placement against **E** (the ticket's trigger price).
The position is then filled at whatever the market gives — which under the
StopLimit family can be up to `entry_extension_max_pct` above E. The stop is
not re-anchored, so realised risk drifts from designed risk.

### Measured, arm 00, 924 fills joined designed-vs-realised

| | |
|---|---|
| mean (realised − designed) stop distance | **+7.02pp wider** |
| fills whose realised distance is >20% wider than designed | **268 (29%)** |
| fills whose realised stop distance exceeds 20% | **152 (16%)** |

The last row is the sharp one. **`max_stop_distance_pct` is enforced at design
time and then violated at fill time.** The gate refuses candidates whose
*designed* stop exceeds 15%, and then admits candidates that end up past 20%
because the fill landed above E. The cap is not doing what its name says.

### Why this is worth fixing regardless of Idea A

- It makes **realised risk match designed risk**, which is what fixed-risk
  sizing already assumes. Sizing computes shares from the *designed* stop
  distance; if the realised distance is 7pp wider on average, every position is
  carrying more risk than its sizing believes.
- It is **faithfulness-neutral** — re-anchoring a structural stop to the fill
  is not abandoning structure, it is applying the same rule to the price that
  actually happened.
- It interacts with the **P2 live/backtest gate question**: part of what makes
  the 15% gate look arbitrary is that it is not actually binding on realised
  positions.

### Shape

`reanchor_stop_at_fill : bool [@sexp.default false]` — on fill, recompute the
installed stop against the realised fill price rather than E, preserving the
*distance* the design chose. Note this is **not** the same as
`stop_anchor_at_entry_base` (which re-anchors to the base for E-family entries);
this re-anchors to the **fill**.

Open question the surface must answer: preserve the designed *distance*, or
preserve the designed *level*? Distance keeps risk-per-trade honest; level keeps
the structural meaning. They diverge exactly when the fill gaps.

---

## Sequencing

**B before A.** B is a defect with a measurement already in hand and no
faithfulness argument to win; A is a genuine strategy change that needs the
book question settled and carries a real fat-tail risk. Fixing B also changes
the population A would act on — after re-anchoring, fewer positions sit beyond
the cap, so A's cohort shrinks and its measurement gets cleaner.

Both are default-off flags and axes before either is a default.
