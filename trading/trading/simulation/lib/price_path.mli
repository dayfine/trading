(** OHLC Price Path Simulator - generates synthetic intraday price paths from
    daily OHLC bars *)

(** {1 Types} *)

type path_point = {
  fraction_of_day : float;
      (** Time within trading day: 0.0 = open, 1.0 = close *)
  price : float;  (** Price at this point in time *)
}
[@@deriving show, eq]
(** A single point on the intraday price path *)

type intraday_path = path_point list
(** Complete intraday price path from open to close *)

(** {1 Path Generation} *)

val generate_path : Types.Daily_price.t -> intraday_path
(** Generate a synthetic intraday price path from daily OHLC data.

    The generated path:
    - Starts at the open price (fraction_of_day = 0.0)
    - Ends at the close price (fraction_of_day = 1.0)
    - Touches both the high and low prices
    - Follows a realistic sequence (e.g., O→H→L→C or O→L→H→C)

    Path generation is deterministic for reproducible backtesting. *)

(** {1 Order Execution} *)

type fill_result = {
  price : float;  (** Price at which order would fill *)
  fraction_of_day : float;  (** When during the day the fill would occur *)
}
[@@deriving show, eq]
(** Result when an order would fill *)

val would_fill :
  path:intraday_path ->
  order_type:Trading_base.Types.order_type ->
  side:Trading_base.Types.side ->
  fill_result option
(** Determine if and when an order would fill during the given price path.

    Returns [Some fill_result] if the order would execute, [None] otherwise.

    Execution logic:
    - [Market]: Always fills at open price (fraction_of_day = 0.0)
    - [Limit buy]: Fills when path reaches or goes below limit price
    - [Limit sell]: Fills when path reaches or goes above limit price
    - [Stop buy]: Fills when path reaches or goes above stop price
    - [Stop sell]: Fills when path reaches or goes below stop price
    - [StopLimit]: Two-stage execution (stop triggers, then limit fills)

    Returns the first point where execution would occur. *)
