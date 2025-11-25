(** OHLC Price Path Simulator - generates synthetic intraday price paths from
    daily OHLC bars *)

open Core

(** {1 Types} *)

type path_point = { fraction_of_day : float; price : float }
[@@deriving show, eq]

type intraday_path = path_point list [@@deriving show, eq]

type fill_result = { price : float; fraction_of_day : float }
[@@deriving show, eq]

(** {1 Path Generation} *)

(** TODO: Implement more realistic price movement models:

    Current limitation: Discrete 4-point path (O→H→L→C or O→L→H→C)
    - Assumes price jumps between OHLC points
    - Orders fill exactly at limit/stop prices
    - No slippage or realistic spread modeling

    Future improvements:
    1. Random walk / Brownian bridge between OHLC points
       https://en.wikipedia.org/wiki/Brownian_bridge
    2. Realistic fill prices with slippage:
       - Limit buy at $100 might fill at $100.05 (slight overpay)
       - Stop sell at $95 might fill at $94.85 (slippage)
       - Larger slippage in volatile conditions (gaps)
    3. Volume-weighted execution modeling
    4. Bid-ask spread simulation
    5. Market impact for large orders

    These enhancements would provide more realistic backtest results,
    especially for strategies sensitive to execution costs. *)
let generate_path (daily : Types.Daily_price.t) : intraday_path =
  (* Determine order of H and L based on whether we moved up or down from open *)
  let open_to_close = daily.close_price -. daily.open_price in
  if Float.(open_to_close >= 0.0) then
    (* Upward day: O → H → L → C *)
    [
      { fraction_of_day = 0.0; price = daily.open_price };
      { fraction_of_day = 0.33; price = daily.high_price };
      { fraction_of_day = 0.66; price = daily.low_price };
      { fraction_of_day = 1.0; price = daily.close_price };
    ]
  else
    (* Downward day: O → L → H → C *)
    [
      { fraction_of_day = 0.0; price = daily.open_price };
      { fraction_of_day = 0.33; price = daily.low_price };
      { fraction_of_day = 0.66; price = daily.high_price };
      { fraction_of_day = 1.0; price = daily.close_price };
    ]

(** {1 Order Execution Helpers} *)

let _would_fill_market (path : intraday_path) : fill_result option =
  (* Market orders always fill at open *)
  match List.hd path with
  | Some point -> Some { price = point.price; fraction_of_day = 0.0 }
  | None -> None

let _would_fill_limit ~(path : intraday_path) ~side ~limit_price :
    fill_result option =
  (* Find first point where limit price is reached.

     IMPORTANT: For backtesting with discrete OHLC data, we conservatively
     assume the order fills at the limit price (not at a better market price).

     Example: Limit sell at $105, price moves 100→110
     - In reality: Order fills as price crosses $105, actual fill unknown
     - Our assumption: Fill at $105 (the limit)
     - Why: Conservative, guaranteed, standard backtesting practice

     TODO: With continuous price paths (random walk), we could model:
     - Actual fill price based on order book dynamics
     - Small price improvements (fill at $105.10 instead of $105.00)
     - Slippage in fast-moving markets *)
  let price_reached =
    match side with
    | Trading_base.Types.Buy -> fun price -> Float.(price <= limit_price)
    | Trading_base.Types.Sell -> fun price -> Float.(price >= limit_price)
  in
  List.find_map path ~f:(fun point ->
      if price_reached point.price then
        Some { price = limit_price; fraction_of_day = point.fraction_of_day }
      else None)

let _stop_trigger_predicate ~side ~stop_price =
  match side with
  | Trading_base.Types.Buy -> fun price -> Float.(price >= stop_price)
  | Trading_base.Types.Sell -> fun price -> Float.(price <= stop_price)

let _would_fill_stop ~(path : intraday_path) ~side ~stop_price :
    fill_result option =
  (* Find first point where stop is triggered.

     Stop orders become market orders when triggered, so they fill at the
     market price at the first point where the stop condition is met.

     Example: Stop sell at $98, price moves 100→110→95
     - Stop triggers when price reaches $95 (first point <= $98)
     - Order fills at $95 (the market price)

     TODO: In reality, stop orders often experience slippage:
     - Stop sell at $98 might fill at $97.80 (worse than trigger)
     - Larger slippage during gaps or fast markets
     - "Stop limit" can prevent excessive slippage but risks no fill *)
  let stop_triggered = _stop_trigger_predicate ~side ~stop_price in
  List.find_map path ~f:(fun point ->
      if stop_triggered point.price then
        Some { price = point.price; fraction_of_day = point.fraction_of_day }
      else None)

let _would_fill_stop_limit ~(path : intraday_path) ~side ~stop_price
    ~limit_price : fill_result option =
  (* Two-stage: first stop triggers, then limit must be reached *)
  let stop_reached = _stop_trigger_predicate ~side ~stop_price in
  let stop_triggered =
    List.exists path ~f:(fun point -> stop_reached point.price)
  in
  if stop_triggered then
    (* After stop triggers, check if limit price is reached *)
    _would_fill_limit ~path ~side ~limit_price
  else None

(** {1 Order Execution} *)

let would_fill ~path ~order_type ~side =
  match order_type with
  | Trading_base.Types.Market -> _would_fill_market path
  | Trading_base.Types.Limit limit_price ->
      _would_fill_limit ~path ~side ~limit_price
  | Trading_base.Types.Stop stop_price ->
      _would_fill_stop ~path ~side ~stop_price
  | Trading_base.Types.StopLimit (stop_price, limit_price) ->
      _would_fill_stop_limit ~path ~side ~stop_price ~limit_price
