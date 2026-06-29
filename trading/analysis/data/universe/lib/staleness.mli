(** Freshness primitives + the active-filter staleness report for
    {!Build_eligible_universe}.

    Splits the data-freshness logic out of the builder: the trading-day-lateness
    count, the freshness gate itself, and the {!staleness_report} observability
    record. A "trading day" here is a {b weekday} (Mon–Fri); market holidays are
    not modelled (see the [Build_eligible_universe] freshness-gate docs). *)

open Core
module CI = Composition_inputs

val is_fresh_enough :
  date:Date.t -> max_staleness_trading_days:int -> CI.inventory_entry -> bool
(** [is_fresh_enough ~date ~max_staleness_trading_days entry] is [true] when the
    entry's last bar ([data_end_date]) is on / after [date], or stale by at most
    [max_staleness_trading_days] trading days (weekdays) before [date]. With the
    no-op [max_staleness_trading_days = 0] this reduces to
    [data_end_date >= date]. *)

type staleness_report = { excluded_count : int; sample : string list }
[@@deriving sexp, show, eq]
(** Observability for the active-filter's freshness gate: how many symbols were
    excluded {b specifically} because their latest bar is stale.
    [excluded_count] is the total such symbols; [sample] is a small,
    deterministic (inventory-order) prefix of their tickers for logging. A
    non-zero count is the signal that a partial / lagging data refresh shrank
    the universe. *)

val sample_size : int
(** Maximum number of tickers carried in {!staleness_report.sample}. *)

val report : excluded:string list -> staleness_report
(** [report ~excluded] packages the staleness-excluded symbols (in inventory
    order) into a {!staleness_report}: [excluded_count] is their length and
    [sample] the first {!sample_size} tickers. *)
