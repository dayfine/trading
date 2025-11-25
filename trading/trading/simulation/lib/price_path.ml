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

    Future improvements: 1. Random walk / Brownian bridge between OHLC points
    https://en.wikipedia.org/wiki/Brownian_bridge 2. Realistic fill prices with
    slippage:
    - Limit buy at $100 might fill at $100.05 (slight overpay)
    - Stop sell at $95 might fill at $94.85 (slippage)
    - Larger slippage in volatile conditions (gaps) 3. Volume-weighted execution
      modeling 4. Bid-ask spread simulation 5. Market impact for large orders

    These enhancements would provide more realistic backtest results, especially
    for strategies sensitive to execution costs. *)
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

let _meets_stop ~side ~stop_price price =
  match side with
  | Trading_base.Types.Buy -> Float.(price >= stop_price)
  | Trading_base.Types.Sell -> Float.(price <= stop_price)

let _crosses_stop ~side ~stop_price ~prev_price ~curr_price =
  match side with
  | Trading_base.Types.Buy ->
      Float.(prev_price < stop_price && curr_price >= stop_price)
  | Trading_base.Types.Sell ->
      Float.(prev_price > stop_price && curr_price <= stop_price)

let rec _search_stop_fill ~side ~stop_price ~(prev_point : path_point) =
  function
  | [] -> None
  | (curr_point : path_point) :: tail ->
      if
        _crosses_stop ~side ~stop_price ~prev_price:prev_point.price
          ~curr_price:curr_point.price
      then
        Some
          { price = stop_price; fraction_of_day = curr_point.fraction_of_day }
      else if _meets_stop ~side ~stop_price curr_point.price then
        Some
          {
            price = curr_point.price;
            fraction_of_day = curr_point.fraction_of_day;
          }
      else _search_stop_fill ~side ~stop_price ~prev_point:curr_point tail

let _would_fill_stop ~(path : intraday_path) ~side ~stop_price :
    fill_result option =
  (* Hybrid approach: if the stop is crossed within a bar, fill at the stop
     price; if the market gaps beyond the stop, fill at the observed price to
     reflect slippage. *)
  match path with
  | [] -> None
  | (first : path_point) :: rest ->
      if _meets_stop ~side ~stop_price first.price then
        Some { price = first.price; fraction_of_day = first.fraction_of_day }
      else _search_stop_fill ~side ~stop_price ~prev_point:first rest

let _would_fill_stop_limit ~(path : intraday_path) ~side ~stop_price
    ~limit_price : fill_result option =
  (* Two-stage: first stop triggers, then limit must be reached *)
  if _would_fill_stop ~path ~side ~stop_price |> Option.is_some then
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
