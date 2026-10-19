(** Ex-dividend reduction of a held long's resting sell-stop (issue #3174).

    {b The defect.} The simulator holds positions at raw prices, and a raw price
    drops by the dividend at the open of the ex-date. A protective stop left at
    its pre-dividend level therefore sees a drop that is not a loss: AD
    2025-08-20 paid a $23.00 special (30 % of the price), opened at 51.26
    against a 67.46 stop and was sold at the open, while the dividend itself was
    credited the same morning. BKE 2021-12-17 ($6.00 special, stop 45.76, open
    40.58) is the second specimen.

    {b Broker practice.} FINRA Rule 5330 (Adjustment of Open Orders): on the
    ex-date, before the order can execute, a resting {e sell stop} (and sell
    stop limit, and buy limit) is reduced by the cash dividend, and the result
    is rounded down to the next lower minimum quotation variation, unless the
    order is marked "do not reduce". A dividend below one cent is not adjusted.
    Buy stops and sell limits are not adjusted: the ex-date drop moves the price
    away from them. This module encodes the sell-stop case only, which is the
    protective stop of a long; a short's protective stop is a buy stop and is
    left alone.

    {b Amount.} [unadjusted_amount], the cash per share on the ex-date, because
    stops and bars are raw. A row without it is skipped and counted, never
    replaced by [adjusted_amount] (restated for later splits), the same rule as
    [Dividend_crediting].

    {b Missing data.} A symbol with no readable [dividends.csv] keeps its stop
    unchanged and is counted once in {!counts}. Files are read lazily, only for
    a held long, and cached for the life of the value. *)

open Core

val min_adjusted_amount : float
(** [0.01]: FINRA 5330's de-minimis threshold. A dividend below one cent does
    not move the order. *)

val reduce_stop_level : stop_level:float -> amount:float -> float
(** [reduce_stop_level ~stop_level ~amount] is the sell-stop level after one
    cash dividend of [amount] per share: [stop_level -. amount] rounded down to
    the cent, never below [0.0]. [stop_level] unchanged when
    [amount < min_adjusted_amount]. *)

val reduce_for_dividends :
  dividends:Corporate_actions.dividend list ->
  after:Date.t ->
  through:Date.t ->
  float ->
  float
(** [reduce_for_dividends ~dividends ~after ~through stop_level] applies
    {!reduce_stop_level} for each dividend whose [ex_date] is in
    [(after, through]], in ex-date order. Rows without [unadjusted_amount]
    are skipped. *)

type loader = string -> Corporate_actions.dividend list Status.status_or
(** Reads one symbol's dividends; [NotFound] means "no file". *)

type t
(** Per-run state: the loader, a per-symbol cache and the counts. *)

val create : load:loader -> t
(** Fresh state. [load] is called at most once per symbol. *)

val of_data_dir : data_dir:Fpath.t -> t
(** {!create} with {!Corporate_actions.read_dividends} on the [TRADING_DATA_DIR]
    store [data_dir], not the snapshot warehouse. *)

val adjust :
  t -> symbol:string -> after:Date.t -> through:Date.t -> float -> float
(** [adjust t ~symbol ~after ~through stop_level] is {!reduce_for_dividends}
    over [symbol]'s vendor dividends; [stop_level] unchanged when the symbol
    has no readable file or no ex-date in [(after, through]]. Each call
    reduces again, so the caller asks once per window. *)

type counts = {
  reduced : int;
      (** Distinct [(symbol, ex_date)] dividends that reduced a stop. *)
  skipped_no_amount : int;
      (** Distinct [(symbol, ex_date)] dividends in a window with no
          [unadjusted_amount]; the stop was left as it was for them. *)
  no_files : int;
      (** Distinct held-long symbols with a missing or unreadable
          [dividends.csv]. *)
}
[@@deriving show, eq]

val counts : t -> counts
(** Counts so far. *)
