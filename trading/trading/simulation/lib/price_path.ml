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

let _meets_limit ~side ~limit_price price =
  match side with
  | Trading_base.Types.Buy -> Float.(price <= limit_price)
  | Trading_base.Types.Sell -> Float.(price >= limit_price)

let _crosses_limit ~side ~limit_price ~prev_price ~curr_price =
  match side with
  | Trading_base.Types.Buy ->
      Float.(prev_price > limit_price && curr_price <= limit_price)
  | Trading_base.Types.Sell ->
      Float.(prev_price < limit_price && curr_price >= limit_price)

(* Search forward through the path to find the first bar where [crosses] or
   [meets] succeeds. When a crossing occurs, the fill price snaps to
   [cross_price] (e.g. a limit/stop threshold); otherwise the observed price is
   preserved. The helper returns both the fill information and the tail of the
   path starting at the bar that satisfied the predicate, which allows callers
   like stop-limits to resume processing from that point. *)
let rec _search_order_fill_with_path ~(crosses : float -> float -> bool)
    ~(meets : float -> bool) ~cross_price ~(prev_point : path_point) = function
  | [] -> None
  | (curr_point : path_point) :: tail ->
      if crosses prev_point.price curr_point.price then
        Some
          ( {
              price = cross_price;
              fraction_of_day = curr_point.fraction_of_day;
            },
            curr_point :: tail )
      else if meets curr_point.price then
        Some
          ( {
              price = curr_point.price;
              fraction_of_day = curr_point.fraction_of_day;
            },
            curr_point :: tail )
      else
        _search_order_fill_with_path ~crosses ~meets ~cross_price
          ~prev_point:curr_point tail

let _search_order_fill ~(crosses : float -> float -> bool) ~(meets : float -> bool)
    ~cross_price ~(prev_point : path_point) remaining =
  match
    _search_order_fill_with_path ~crosses ~meets ~cross_price ~prev_point
      remaining
  with
  | Some (fill, _) -> Some fill
  | None -> None

let _would_fill_limit ~(path : intraday_path) ~side ~limit_price :
    fill_result option =
  (* Hybrid approach mirroring stop orders:
     - If the limit price is crossed inside a bar, record the fill at the limit
       level (conservative assumption).
     - If the market is already beyond the limit at the start of the bar,
       assume we receive the observed price (captures favorable fills & slippage
       when using discrete OHLC points). *)
  match path with
  | [] -> None
  | (first : path_point) :: rest ->
      let meets = _meets_limit ~side ~limit_price in
      if meets first.price then
        Some { price = first.price; fraction_of_day = first.fraction_of_day }
      else
        let crosses prev curr =
          _crosses_limit ~side ~limit_price ~prev_price:prev ~curr_price:curr
        in
        _search_order_fill ~crosses ~meets ~cross_price:limit_price
          ~prev_point:first rest

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

(* Locate the first point where the stop condition is satisfied and return both
   the stop fill (respecting the hybrid gap/cross logic) and the remainder of
   the path starting at that bar. This enables building higher-order orders such
   as stop-limits that first trigger the stop and then continue scanning forward
   for a limit fill. *)
let _stop_activation_path ~(path : intraday_path) ~side ~stop_price :
    (fill_result * intraday_path) option =
  match path with
  | [] -> None
  | (first : path_point) :: rest ->
      let meets = _meets_stop ~side ~stop_price in
      if meets first.price then
        let fill =
          { price = first.price; fraction_of_day = first.fraction_of_day }
        in
        Some (fill, path)
      else
        let crosses prev curr =
          _crosses_stop ~side ~stop_price ~prev_price:prev ~curr_price:curr
        in
        _search_order_fill_with_path ~crosses ~meets ~cross_price:stop_price
          ~prev_point:first rest

let _would_fill_stop ~(path : intraday_path) ~side ~stop_price :
    fill_result option =
  (* Hybrid approach: if the stop is crossed within a bar, fill at the stop
     price; if the market gaps beyond the stop, fill at the observed price to
     reflect slippage. *)
  match _stop_activation_path ~path ~side ~stop_price with
  | Some (fill, _) -> Some fill
  | None -> None

let _would_fill_stop_limit ~(path : intraday_path) ~side ~stop_price
    ~limit_price : fill_result option =
  (* Two-stage: first stop triggers, then limit must be reached *)
  match _stop_activation_path ~path ~side ~stop_price with
  | None -> None
  | Some (stop_fill, activation_path) ->
      let meets_limit = _meets_limit ~side ~limit_price in
      if meets_limit stop_fill.price then Some stop_fill
      else
        (* Limit not satisfied immediately; wait for the limit price after stop
           activation. *)
        _would_fill_limit ~path:activation_path ~side ~limit_price

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
