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

val generate_mini_bars :
  Types.Daily_price.t -> Trading_engine.Types.mini_bar list
(** Generate a sequence of mini-bars from daily OHLC data.

    The mini-bar sequence:
    - Starts at market open (time_fraction = 0.0)
    - Ends at market close (time_fraction = 1.0)
    - Touches all OHLC price points (Open, High, Low, Close)
    - Follows deterministic path: O→H→L→C (upward) or O→L→H→C (downward)

    Path selection:
    - If Close > Open: O → H → L → C (upward day)
    - If Close < Open: O → L → H → C (downward day)
    - If Close = Open: O → H → L → C (default)

    Example for O=100, H=105, L=95, C=102:
    {[
      [
        { time_fraction = 0.00; open_price = 100; close_price = 100 };
        (* Open *)
        { time_fraction = 0.25; open_price = 100; close_price = 105 };
        (* → High *)
        { time_fraction = 0.50; open_price = 105; close_price = 95 };
        (* → Low *)
        { time_fraction = 0.75; open_price = 95; close_price = 102 };
        (* → Close *)
        { time_fraction = 1.00; open_price = 102; close_price = 102 };
        (* Close *)
      ]
    ]}

    Each mini-bar represents a price movement that the engine can process
    sequentially for order execution. *)

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
[@@deprecated
  "Use Engine.process_mini_bars instead - execution logic belongs in engine"]
(** [DEPRECATED] Determine if and when an order would fill during the given
    price path.

    This function will be removed in a future version. Order execution logic
    should be handled by the engine module using mini-bars.

    Returns [Some fill_result] if the order would execute, [None] otherwise.

    Execution logic:
    - [Market]: Always fills at open price (fraction_of_day = 0.0)
    - [Limit buy]: Fills when path reaches or goes below limit price
    - [Limit sell]: Fills when path reaches or goes above limit price
    - [Stop buy]: Fills when path reaches or goes above stop price
    - [Stop sell]: Fills when path reaches or goes below stop price
    - [StopLimit]: Two-stage execution (stop triggers, then limit fills)

    Returns the first point where execution would occur. *)
