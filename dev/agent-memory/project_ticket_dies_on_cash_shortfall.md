---
name: project-ticket-dies-on-cash-shortfall
description: "~25% of resting entry tickets are silently destroyed when they trigger into a cash-short book; the audit records nothing, and the promised retry does not exist on the entry side."
metadata: 
  node_type: memory
  type: project
  originSessionId: f3803253-a181-4a9d-88bc-d6fadb39647f
  modified: 2026-08-16T05:43:29.307Z
---

A resting entry ticket that triggers when the portfolio cannot fund it is
**destroyed, not retried**, and leaves **no trace in any artifact**. Confirmed
2026-08-16 on the AXTI 2025-06-27 ticket (task 22 of the 08-16 priorities doc).

**The chain.** `Engine._process_order_with_execution` marks the order `Filled`
as soon as the fill function returns a trade — *before* the portfolio sees it.
`Cancel_handler.apply_trades_best_effort` then rejects it for cash and
`transitions_for_rejected_trades` emits a `CancelEntry`, deleting the ticket.
The order is already `Filled`, so there is nothing left to re-offer.

Three separable defects (G1/G2/G3 in
`dev/notes/ticket-death-on-cash-2026-08-16.md`):

- **G1 emission.** `Simulator._process_fills_and_cancels` applies its
  `cancel_transitions` locally; `_notify_transitions` is only called with
  `Margin_runner.tick`'s output. So these cancels never reach the audit and
  `Ticket_lifecycle.ticket_age_weeks_at_cancel` is written **zero times** in a
  whole run. In the 2.5y diag run: 234 placements, 166 filled, 7 open, **61
  (26%) unaccounted for**.
- **G2 no retry.** The WARN literally says "Stranded position will be reverted
  for retry" — that revert path (#1553) is **exit-side only**. Shortfalls as
  small as **$397 on $138,244 (0.3%)** kill a ticket outright.
- **G3 frozen size.** `target_quantity` is fixed at placement-week equity/price;
  no cash reservation, no re-size at fill, no partial fill.

**Systemic, ~25% everywhere.** `grep -c "WARN: portfolio rejected fill"` over
the confirmation-grid runs: sp500 26y core 269/277/283 against ~1,040 round
trips; top-3000 16y core 217/213 against ~780; diag 2.5y 44/166.

**Why it matters.** It is a mechanism for [[project-record-gap-is-concentration]]
— we write more tickets than the book can fund, and selection at the moment of
triggering is by **arrival order, not rank** (AXTI was score 100 / A_plus and
lost its ticket to whatever triggered first that week). It is also
**tail-preserving** in the sense of [[project-edge-is-the-fat-tail]]: the
destroyed population is breakouts that actually broke out — AXTI went 2.03 →
11.76 (5.8×) in four months after its ticket died.

**How to apply.** Land G1 (pure emission, no golden movement) before measuring
anything; then the "what did we give up" question is answerable from the
artifact instead of stderr greps. G2/G3 are behaviour changes and need
default-off flags plus a real surface per
[[project-experiment-platform]] discipline.

**Two corrections to the 2026-08-15 record this produced:** the AXTI
"1/4/5 tickets" table was a `grep -c AXTI` artifact that counted
`alternatives_considered` rows (real counts: 0 / 0 / 1 ticket); and the audit
does **not** omit `ma_value` / `close_at_decision` / `local_range_top` — it
carries all of them on every placement row. The real emission gap is ticket
**resolution**. See [[feedback-always-dissect-before-reporting]].
