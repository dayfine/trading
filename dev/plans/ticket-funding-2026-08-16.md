# Plan — what happens to a triggered ticket the book cannot fund (G2/G3)

Follows `dev/notes/ticket-death-on-cash-2026-08-16.md`. G1 (make it visible) is
PR #2348. This plan is the behaviour half, and it is deliberately **three
independent axes**, not one fix — they are different strategies with different
failure modes, and the record suggests at least one of them is a fat-tail tax.

## What the current code does

1. `Engine._process_order_with_execution` marks the resting order **`Filled`**
   the moment the fill function returns a trade — *before* the portfolio sees it.
2. `Cancel_handler.apply_trades_best_effort` then refuses the trade if the
   portfolio cannot fund it.
3. `transitions_for_rejected_trades` emits `CancelEntry`, deleting the position.
4. Nothing is retried. The order is gone (step 1), the ticket is gone (step 3).

So **one cash-tight instant permanently destroys a ticket** that may have rested
for months, and the margin of destruction can be arbitrarily small — from the
2.5-year diagnostic run, `PRGS` needed \$138,244 and had \$137,847: **short by
\$397, or 0.3%**.

Rate: **~25% of would-be entries**, stable across universes and periods
(sp500 26y 269/277/283 against ~1,040 round trips; top-3000 16y 217/213 against
~780; diag 2.5y 44/166).

## The three axes

Each is a separate default-off config field, and each is a genuinely different
policy — they are **not** three implementations of one idea, and the grid should
be able to tell them apart.

### G2a — `entry_fill_reject_retries` (int, default 0)

On a portfolio rejection, put the ticket **back**: revert the position to
`Entering` and re-offer the order on the next tick, up to N times. This is the
entry-side mirror of what `Cancel_handler.revert_rejected_exits` already does for
exits (#1553), and it is what the WARN string has been promising all along.

- **Argument for:** the setup did not stop being valid; only the cash timing was
  wrong. A ticket that survived a re-screen has already been re-validated.
- **Argument against:** it changes *when* we enter, and the entry price it
  eventually gets is worse than the one it triggered at — the do-not-chase cap
  (`entry_extension_max_pct`) then starts refusing the retry, which is exactly
  the entry-side fat-tail tax the StopLimit surface already found
  (`project_sim_entry_stoplimit_reject`). **This axis is the one most likely to
  fail**, and for a known reason.
- **Implementation note:** step 1 above must change too, or there is no order
  left to re-offer. Marking `Filled` before the portfolio accepts is arguably a
  defect in its own right.

### G2b — `entry_fill_size_to_available` (bool, default false)

Fill what the book *can* afford instead of refusing the whole ticket: clamp the
quantity to the available cash (and the position/exposure caps), subject to a
minimum viable size.

- **Argument for:** it is the smallest possible change to the failure mode, and
  the 0.3%-shortfall cases become no-ops. It also keeps the entry at the price
  the ticket triggered at, so it does not pay the retry's timing tax.
- **Argument against:** it silently breaks fixed-risk sizing — the position no
  longer carries `risk_per_trade_pct` of the book — and a systematically
  undersized entry into the largest winners is its own tail tax. A minimum
  viable size (as a fraction of the designed size) is the obvious guard and is
  the thing to sweep.
- **Interacts with** `Stop_width_mode.Size_down`, which also decouples size from
  the design. Do not arm both in one cell without saying why.

### G3 — `reserve_cash_for_resting_tickets` (bool, default false)

Reserve the ticket's designed cost at **placement**, so the cash is still there
when it triggers.

- **Argument for:** it is the only one of the three that removes the failure
  rather than handling it, and it makes the walk's ranking mean what it appears
  to mean.
- **Argument against:** it is the most invasive, and it has an obvious cost —
  reserved cash is idle cash. With ~10 concurrent positions and a 70% exposure
  cap this could easily reduce deployment below the cap, which the utilization
  work says we are already close to (70.2% against a 70% cap).
- **Watch:** this axis plausibly *reduces* the number of tickets written, which
  interacts with `project_record_gap_is_concentration` — fewer, larger positions
  is the direction the record arm runs.

## Why this matters beyond bookkeeping

`project_record_gap_is_concentration` established that the record arm runs 4.9
concurrent positions against our 10.6 at the same exposure, and that the gap is
dilution rather than selection. This is a **mechanism** for that: we write more
tickets than the book can fund, and a quarter of them are destroyed at the moment
of triggering — with selection **by arrival order, not by rank**. AXTI was
cascade score 100 / grade A_plus at placement and lost its ticket to whatever
happened to trigger first that week.

It is also a **tail-preserving** lever in the sense of
`project_edge_is_the_fat_tail`: the destroyed population is breakouts *that
actually broke out*. AXTI's post-rejection path was 2.03 → 11.76 (5.8×) in four
months. Every prior rejected lever taxed the tail deliberately; this one taxes it
by accident, which is the first time that has been true.

That is the argument for expecting a real effect — and it is exactly the kind of
argument that has been wrong before, so it does not substitute for the grid.

## Sequencing

1. **G1 must land first** (#2348). Until `ticket_age_weeks_at_cancel` and
   `cancel_reason` are written, the population these axes act on is not
   measurable from artifacts, and "did it help?" can only be answered by the
   top-line — which the 132.5pp null makes uninterpretable at this scale.
2. **Then measure the cohort**, from the artifact rather than from stderr greps:
   how many rejections, at what shortfall, on which cascade grades, and what the
   rejected symbols did afterwards. `screen-rigor` applies — report the
   distribution of the shortfall, not its median, and be explicit that
   "what we gave up" is a counterfactual, not a measurement.
3. **Only then build**, one axis at a time behind its own flag, each an axis the
   day it lands (`experiment-flag-discipline.md` R1/R2).
4. **One grid over all three**, since they are alternatives rather than
   complements, plus the null. Promotion needs the confirmation grid
   (`promotion-confirmation.md`), and the standing warning applies: the
   nearfloor mechanism looked strong on one window and failed 0-of-3 cells.

## What is not in scope

- Changing `min_cash_pct` or the exposure caps. Those are the *reason* cash runs
  out; this plan is about what happens when it does.
- Partial-fill accounting for exits. The exit side already has its revert path.
- The `Filled`-before-portfolio-acceptance ordering as a standalone fix. It is a
  prerequisite for G2a and should land with it, not before it — on its own it
  changes nothing observable.
