# Stop anchoring for fast movers — two separable ideas

**User, 2026-08-18:** *"if a symbol is going off quickly, e.g. AXTI when E = 2.7,
where its most recent base is 1.4X, it should really be treated as something
that's moving very fast, so directionally its stop loss should be local (15%
down) … whether in that case the prior support should be ignored, and we just
install a plain 15% stop instead — and maybe this stop should be dynamically
adjusted on-fill to be exactly / closer to -15% of the actual fill."*

Two ideas, separable. The second turned out not to be a defect at all
(withdrawn below), and the first turned out **not to need building** — see the
banner immediately after this line.

---

> ## ⚠ Idea A is already implemented — 2026-08-19
>
> **No new `Stop_width_mode` case is needed.** The mechanism this plan proposes
> exists, default-off, and has since 2026-08-06.
>
> `entry_audit_helpers.ml:83`, `_maybe_reanchor_to_entry_base`:
>
> ```ocaml
> let should_reanchor =
>   reanchor
>   && Float.( > ) dist stops_config.Weinstein_stops.max_stop_distance_pct
> in
> if not should_reanchor then (raw_stop, structural_kind)
> else ... compute_initial_stop_with_floor_with_callbacks
>          ~callbacks:empty_callbacks ~fallback_buffer:initial_stop_buffer
> ```
>
> Read literally: **when the support-floor stop lands farther than
> `max_stop_distance_pct` from entry, discard the structural floor and install a
> plain `entry × initial_stop_buffer` percentage stop.** Passing
> `~callbacks:empty_callbacks` is precisely what makes it ignore prior support —
> the stops layer sees no bars and takes its buffer fallback. Candidates whose
> floor is already inside the limit are returned verbatim, so armed/off differ
> only on the over-wide cohort.
>
> That is the user's proposal, including the "ignore the prior support" part.
> It is gated by `config.stop_anchor_at_entry_base` (`[@sexp.default false]`),
> and the function header already records *"user go 2026-08-06"* — it was
> greenlit once before, landed default-off per R1, and was never surfaced.
> `Cap_at_max` with `initial_stop_buffer = 1 − max_stop_distance_pct = 0.85`
> would be **bit-identical** to arming this flag.
>
> The remaining work is therefore a **surface, with zero new code** — both knobs
> are already `Weinstein_strategy.config` fields, so both are
> `Variant_matrix`-expressible today:
>
> ```
> ((flag stop_anchor_at_entry_base) (values (false true)))
> ((flag initial_stop_buffer)       (values (0.85 0.92 0.94 0.96)))
> ```
>
> ### What the book actually licenses here
>
> Both halves matter and they pull in different directions:
>
> - **§5.1** — *"Pre-calculate stop before buying. If stop requires >15% risk
>   from entry → prefer other candidates."* That is exactly today's
>   `Drop_over_max` default (verified: `weinstein_strategy_config.ml:249`, with
>   `max_stop_distance_pct = 0.15` at `stop_types.ml:67`), and it is why the
>   faithful arm passes on AXTI. **Dropping the candidate is the book-faithful
>   response to a far base; re-anchoring is a departure from it.**
> - **§5.3, Trader Method** — *"Use 4-6% initial stop if no nearby prior peak."*
>   The book **does** sanction a flat percentage stop divorced from structure —
>   but inside the trader preset, conditioned on *no nearby prior peak*, and at
>   **4-6%**.
>
> So the *shape* of the idea is book-supported; the *value* proposed is not.
> **15% is §5.1's rejection threshold, not a stop level the book ever recommends
> placing.** Conflating "the 15% admission gate" with "install a 15% stop" is
> the error to avoid — two different quantities that happen to share a number.
> Hence the grid above spans `0.94 / 0.96` (the book's 4-6%), `0.92` (8%, the
> value the existing tests exercise) and `0.85` (15%, included to *test* the
> user's number, not because the book endorses it).
>
> One thing the book does not settle: its trigger is "no nearby prior peak" (no
> usable structure at all), while the flag's trigger is "structure exists but is
> far away". AXTI at E = 2.71 with its base near 1.4 has structure 48% away.
> Whether that counts as "no nearby prior peak" is a judgement call, and it is
> the one question worth putting to `blind-judge` before promoting anything.
>
> **What to read in the surface.** The tradeoff is predictable in advance: a
> tighter flat stop admits the fast movers the 15% gate currently drops
> (`project_max_stop_filters_structural_stops`) but stops them out on ordinary
> volatility. Since this strategy's return is a fat-tail phenomenon
> (`project_edge_is_the_fat_tail`, 11+ confirmations), a stop tight enough to
> whipsaw a monster out early is the failure mode to watch — read **max single-
> trade P&L**, not just the top line.

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

## Idea B — re-anchor the stop to the actual fill (WITHDRAWN — not a defect)

Independent of A, and **not a proposal so much as a bug report**.

The stop is computed at placement against **E** (the ticket's trigger price).
The position is then filled at whatever the market gives — which under the
StopLimit family can be up to `entry_extension_max_pct` above E. The stop is
not re-anchored, so realised risk drifts from designed risk.

### ⚠ WITHDRAWN 2026-08-19 — the measurement was a mis-join

**The claimed defect is not real.** The original figures came from a join keyed
on **symbol**, with `sort -u -k1,1` on the fill side — which keeps one fill per
symbol while the audit holds 1,466 tickets across only 802 symbols. Rows were
therefore paired arbitrarily. Re-run keyed on **`position_id`** (unique per
ticket):

| | claimed (symbol join) | correct (`position_id` join) |
|---|---|---|
| n | 924 | 1,133 |
| mean (realised − designed) | **+7.02pp** | **+0.28pp** |
| median | — | +0.09pp |
| p90 | — | +0.85pp |
| >20% wider than designed | 29% | 11% |
| realised distance beyond 20% | **16%** | **0%** |

**Zero fills end up with a realised stop distance beyond 20%**, so the headline
claim — that `max_stop_distance_pct` is enforced at design time and violated at
fill time — is **false**. The realised stop distance essentially equals the
designed one (median drift +0.09pp).

Split by construction, the drift is negligible for both kinds:
`Buffer_fallback` +0.30pp (n=685), `Support_floor` +0.26pp (n=448).

**Why the drift is small, in hindsight:** it is bounded by how far a fill can
land above E, and under the StopLimit family most fills land at or very near
the trigger. The mechanism for a large drift exists but almost never fires.

### What survives

Not the defect claim. What survives is a **design observation**, and it is worth
recording only because it is now measured rather than assumed:

- For a **percentage** stop (`Buffer_fallback`), the level's only meaning is
  "X% of risk", so anchoring it to E rather than the fill is arguably wrong in
  principle — but empirically worth +0.30pp, i.e. nothing.
- For a **structural** stop (`Support_floor`), the level is a real support
  price. It *should not* follow the fill; moving it would destroy its meaning.
  So "re-anchor" was never the right verb for this half.

**No build is justified.** This is a no-build on measurement, not on priors.

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

**Neither is a build.** The original sequencing put B first on the strength of a
+7.02pp measurement that turned out to be a mis-join; with the correct figure
(+0.28pp) there is nothing to fix. A then turned out to be already implemented
(banner at the top), so it is not a build either.

What is left is one **surface** over two existing knobs —
`stop_anchor_at_entry_base × initial_stop_buffer` — and one **judgement**: does
"structure exists but sits 48% away" satisfy the book's "no nearby prior peak"
condition, or does §5.1's *prefer other candidates* govern? Settle the
judgement before reading the surface as a promotion case, not after; otherwise
the numbers decide a question the book already has an opinion about.

Promotion, if it ever comes, still routes through the normal gate: ledger
ACCEPT, then the confirmation grid (`promotion-confirmation.md`) with one cell
spanning a pre-2009 macro regime.

**Method note worth keeping.** The withdrawn measurement failed the way two
other artifacts failed this week: joined on a non-unique key. In this codebase
**`position_id` is the only safe join key** between `trade_audit.sexp` and
`trades.csv`; `symbol` repeats (802 symbols across 1,466 tickets) and
`sort -u -k1,1` on it silently drops rows rather than erroring.
