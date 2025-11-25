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
  (* Find first point where limit price is reached *)
  match side with
  | Trading_base.Types.Buy ->
      (* Buy limit: execute when price <= limit_price *)
      List.find_map path ~f:(fun point ->
          if Float.(point.price <= limit_price) then
            Some
              { price = limit_price; fraction_of_day = point.fraction_of_day }
          else None)
  | Trading_base.Types.Sell ->
      (* Sell limit: execute when price >= limit_price *)
      List.find_map path ~f:(fun point ->
          if Float.(point.price >= limit_price) then
            Some
              { price = limit_price; fraction_of_day = point.fraction_of_day }
          else None)

let _would_fill_stop ~(path : intraday_path) ~side ~stop_price :
    fill_result option =
  (* Find first point where stop is triggered *)
  match side with
  | Trading_base.Types.Buy ->
      (* Stop buy: trigger when price >= stop_price, fill at stop or higher *)
      List.find_map path ~f:(fun point ->
          if Float.(point.price >= stop_price) then
            Some
              { price = point.price; fraction_of_day = point.fraction_of_day }
          else None)
  | Trading_base.Types.Sell ->
      (* Stop sell: trigger when price <= stop_price, fill at stop or lower *)
      List.find_map path ~f:(fun point ->
          if Float.(point.price <= stop_price) then
            Some
              { price = point.price; fraction_of_day = point.fraction_of_day }
          else None)

let _would_fill_stop_limit ~(path : intraday_path) ~side ~stop_price
    ~limit_price : fill_result option =
  (* Two-stage: first stop triggers, then limit must be reached *)
  let stop_triggered =
    match side with
    | Trading_base.Types.Buy ->
        List.exists path ~f:(fun point -> Float.(point.price >= stop_price))
    | Trading_base.Types.Sell ->
        List.exists path ~f:(fun point -> Float.(point.price <= stop_price))
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
