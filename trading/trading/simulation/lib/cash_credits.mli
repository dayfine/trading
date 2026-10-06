(** The simulator's per-step cash credits that do not come from trades (issue
    #3137): interest on positive cash and cash dividends on held positions. Both
    are default-off; with neither armed {!step} and {!add_metrics} are the
    identity, so the run is bit-identical to the pre-#3137 simulator.

    {b Step slot.} {!step} runs at the start of [Simulator._process_step_day]:
    after the day's split adjustment and forced exits (delisted / stale), and
    before pending-order fills, the strategy call and margin/stop handling.
    Inside it, cash interest accrues first (on the pre-dividend balance), then
    dividends are credited / charged on the positions held at that point. The
    strategy therefore sees the day's interest and dividends in its cash. *)

type t = {
  cash_yield : Trading_simulation_cash_yield.Cash_yield.Accrual.t option;
      (** Interest on positive cash; [None] = off. *)
  dividends : Trading_simulation_dividends.Dividend_crediting.t option;
      (** Dividend crediting; [None] = off. *)
}

val step :
  t ->
  date:Core.Date.t ->
  Trading_portfolio.Portfolio.t ->
  Trading_portfolio.Portfolio.t Status.status_or
(** Accrue [date]'s interest, then credit [date]'s dividends (see the module
    doc). Fails with the first error of either. *)

val add_metrics :
  t ->
  Trading_simulation_types.Metric_types.metric_set ->
  Trading_simulation_types.Metric_types.metric_set
(** Add [CashInterestTotal] when interest is armed, and [DividendIncomeTotal],
    [DividendPaidShortTotal], [DividendSkippedNoAmountCount],
    [DividendMissingFileCount] when dividends are armed. Unarmed parts add no
    key. *)
