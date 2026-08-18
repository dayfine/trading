# G3 `reserve_cash_for_resting_tickets` — design

Implementation design for the axis the cohort measurement
(`dev/experiments/ticket-funding-cohort-2026-08-18/`) promoted to first place.
Behaviour half of `dev/plans/ticket-funding-2026-08-16.md`.

## Why this axis first

The measured failure is **aggregate over-commitment**, not per-ticket bad luck:
63% of the 3,530 rejections arrive in bursts against a single cash balance, and
the median rejected ticket is short **52%** of its cost. Reserving at placement
is the only one of the three axes that removes the over-commitment instead of
arbitrating it after the fact.

## Where the over-commitment comes from — the seam is one line

`Entry_audit_capture.check_cash_and_deduct` **already** enforces cash discipline
*within* a tick: the walk threads a `remaining_cash` ref, and each admitted
`CreateEntering` deducts `target_quantity * entry_price` from it, so the tickets
written on one Friday cannot collectively exceed that Friday's cash.

The leak is **across** ticks. The ref is re-seeded every tick from:

```ocaml
(* entry_walk.ml:168 *)
let spendable = portfolio.Portfolio_view.cash in
```

A ticket placed in week N and still resting in week N+1 has taken **no cash** —
it is a resting order, not a position — so week N+1's walk sees that money as
available again and spends it on new tickets. Repeat weekly and the book carries
far more claims than cash. When several of them trigger in one week, the first
few consume the balance and the rest are destroyed in arrival order. That is
exactly the burst structure the cohort measurement found.

## The change

```ocaml
let spendable =
  if config.reserve_cash_for_resting_tickets then
    Float.max 0.0 (portfolio.cash -. resting_long_ticket_cost portfolio)
  else portfolio.cash
```

with

```ocaml
(* Sum of designed cost over positions still in [Entering] — the claims the
   book has already written but not yet paid for. *)
let resting_long_ticket_cost (p : Portfolio_view.t) =
  Map.fold p.positions ~init:0.0 ~f:(fun ~key:_ ~data:pos acc ->
    match pos.status, pos.side with
    | Position.Entering e, Types.Long -> acc +. (e.target_quantity *. e.entry_price)
    | _ -> acc)
```

`Portfolio_view.positions` already carries non-`Holding` positions (only
`portfolio_value` filters to `Holding`), so no new plumbing is required.

**Config field** (`experiment-flag-discipline.md` R1/R2):

```ocaml
reserve_cash_for_resting_tickets : bool; [@sexp.default false]
```

Default `false` ⇒ `spendable` is `portfolio.cash` ⇒ bit-identical to today, so
every golden must stay put. It is a real `Weinstein_strategy.config` field, so
`((flag reserve_cash_for_resting_tickets) (values (true false)))` expands as a
`Variant_matrix` axis the day it lands.

## Four things to get right

1. **Do not double-count a ticket that triggers this tick.** If the simulator
   processes fills before `on_market_close`, a filling ticket has already left
   `Entering` *and* already debited cash — no double count. If the ordering is
   the other way, the ticket is still `Entering` while its cash is gone, and the
   reserve subtracts it twice. **Verify the ordering first**; this is the one
   correctness risk in the change, and it is a unit test, not a backtest.
2. **Longs only.** An entering short *credits* cash on fill; reserving against
   it would shrink the budget for a claim that pays in. The fold above already
   filters on `Long`.
3. **Interaction with leverage.** Under `leverage_enabled`,
   `_admit_and_deduct` lets `remaining_cash` go negative on purpose and the cap
   binds downstream instead. Reserving would then subtract from a number that is
   not the binding constraint. Scope the reserve to the cash-account path, or
   state explicitly why it composes.
4. **Reserve ≠ cash floor.** `cash_reserve_pct` was retired (#2286,
   `project_cash_reserve_rejected`) because a blanket idle-cash floor is a
   protection lever and the barbell dominates it. This is not that: the reserve
   here is **earmarked against specific written claims** and is released the
   moment a ticket fills or cancels. Say so in the `.mli`, or the next reader
   will recognise the shape and assume it was already rejected.

## What to measure, and the honest bar

**Primary (mechanism):** `rejected_fills` per run — the `WARN: portfolio
rejected fill` count the chain script already logs, and the `cancel_reason =
entry_fill_rejected_by_portfolio` population #2348 now writes into
`trade_audit.sexp`. If the flag is doing what it claims, this count collapses
toward zero. **If it does not, the mechanism is not working — stop before
reading any return number.**

**Secondary (the intended consequence):** ticket count written, concurrent
position count, and deployment against the exposure cap. The prediction from
`project_record_gap_is_concentration` is *fewer, better-funded tickets*, i.e. a
move toward the record arm's 4.9 concurrent positions against our 10.6.

**Top line:** not interpretable alone. The measured null on the ladder-v4 base
is **278pp** (`project_ladder_v4_null_278pp`), so a single draw says nothing.
Promotion needs the confirmation grid — ≥3 cells, one spanning a pre-2009 macro
regime (`promotion-confirmation.md`).

**The obvious cost, stated up front:** reserved cash is idle cash. Deployment
already sits at 70.2% against a 70% cap, so the reserve plausibly pushes
utilisation *below* the cap. That is the trade this axis is making — fewer
claims, each funded — and it is why deployment must be reported alongside the
return, not after it.
