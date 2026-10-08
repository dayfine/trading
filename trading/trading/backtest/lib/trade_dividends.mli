(** Cash dividends earned by one round trip (issue #3175).

    Under [dividend_crediting] the simulator credits dividends straight to cash,
    outside any trade's [pnl_dollars], so a round trip's price-only P&L can sit
    beside a larger dividend on the same position. This module recomputes the
    per-trip figure for [trades.csv]'s [dividends_received] column from the same
    source and with the same conventions as
    {!Trading_simulation_dividends.Dividend_crediting}.

    {b Convention.} A trip earns a dividend iff its ex-date [d] satisfies
    [entry_date < d <= exit_date] (a buy filling on the ex-date gets nothing; a
    sale filling on the ex-date still gets it) and [d >= start_date] (warmup
    earns nothing). Amount = [unadjusted_amount * quantity]; rows with no
    [unadjusted_amount] are skipped. Long trips are positive, short trips
    negative (the short pays).

    {b Approximation.} [quantity] is restated onto the exit leg's split basis
    while [unadjusted_amount] is the raw per-share amount, so a trip held across
    a split is mis-scaled for dividends paid before that split. Such trips are
    rare; the simulator's cash is unaffected (it uses live position sizes). *)

open Core

type t
(** Per-run state: the loader and a per-symbol cache. *)

val create :
  load:(string -> Corporate_actions.dividend list Status.status_or) ->
  start_date:Date.t ->
  t
(** [load] is called at most once per symbol. A [NotFound] or any other error
    reads as "no dividends" (the simulator already failed the run on a malformed
    file; this is a report column). *)

val received : t -> Trading_simulation.Metrics.trade_metrics -> float
(** Dividend cash for the trip, signed as above. [0.0] when none. *)
