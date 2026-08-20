open Core
open Trading_base.Types
open Types

(** {1 Path-based Fill Checking}

    The following functions check if orders would fill on a given intraday path.

    Fill logic:
    - Limit orders: Fill at limit price when crossing (conservative, guaranteed
      price)
    - Stop orders: Fill at current point price when triggered (natural slippage)
    - Market orders: Fill at first available point (open price)

    Natural slippage is modeled by path granularity: stop orders fill at the
    observed price when triggered, not the trigger price. (~390 points/day.) *)

let would_fill_market (path : intraday_path) : fill_result option =
  (* Market orders always fill at open *)
  match List.hd path with
  | Some point -> Some { price = point.price }
  | None -> None

let _meets_limit ~side ~limit_price price =
  match side with
  | Buy -> Float.(price <= limit_price)
  | Sell -> Float.(price >= limit_price)

let _crosses_limit ~side ~limit_price ~prev_price ~curr_price =
  match side with
  | Buy -> Float.(prev_price > limit_price && curr_price <= limit_price)
  | Sell -> Float.(prev_price < limit_price && curr_price >= limit_price)

let rec _search_order_fill ~(crosses : float -> float -> bool)
    ~(meets : float -> bool) ~cross_price ~(prev_point : path_point) = function
  | [] -> None
  | (curr_point : path_point) :: tail ->
      if crosses prev_point.price curr_point.price then
        (* Limit orders fill at limit price (conservative) *)
        Some { price = cross_price }
      else if meets curr_point.price then
        (* Price meets threshold exactly *)
        Some { price = curr_point.price }
      else
        _search_order_fill ~crosses ~meets ~cross_price ~prev_point:curr_point
          tail

let would_fill_limit ~(path : intraday_path) ~side ~limit_price :
    fill_result option =
  match path with
  | [] -> None
  | (first : path_point) :: rest ->
      let meets = _meets_limit ~side ~limit_price in
      if meets first.price then Some { price = first.price }
      else
        let crosses prev curr =
          _crosses_limit ~side ~limit_price ~prev_price:prev ~curr_price:curr
        in
        _search_order_fill ~crosses ~meets ~cross_price:limit_price
          ~prev_point:first rest

let _meets_stop ~side ~stop_price price =
  match side with
  | Buy -> Float.(price >= stop_price)
  | Sell -> Float.(price <= stop_price)

let _crosses_stop ~side ~stop_price ~prev_price ~curr_price =
  match side with
  | Buy -> Float.(prev_price < stop_price && curr_price >= stop_price)
  | Sell -> Float.(prev_price > stop_price && curr_price <= stop_price)

let rec _search_stop_with_path ~(crosses : float -> float -> bool)
    ~(meets : float -> bool) ~(prev_point : path_point) = function
  | [] -> None
  | (curr_point : path_point) :: _tail as remaining ->
      if crosses prev_point.price curr_point.price then
        (* Stop triggers, fill at current point price (natural slippage) *)
        Some ({ price = curr_point.price }, remaining)
      else if meets curr_point.price then
        (* Stop triggers at exact price *)
        Some ({ price = curr_point.price }, remaining)
      else _search_stop_with_path ~crosses ~meets ~prev_point:curr_point _tail

let _stop_activation_path ~(path : intraday_path) ~side ~stop_price :
    (fill_result * intraday_path) option =
  match path with
  | [] -> None
  | (first : path_point) :: _rest ->
      let meets = _meets_stop ~side ~stop_price in
      if meets first.price then
        let fill = { price = first.price } in
        Some (fill, path)
      else
        let crosses prev curr =
          _crosses_stop ~side ~stop_price ~prev_price:prev ~curr_price:curr
        in
        _search_stop_with_path ~crosses ~meets ~prev_point:first _rest

let would_fill_stop ~(path : intraday_path) ~side ~stop_price :
    fill_result option =
  match _stop_activation_path ~path ~side ~stop_price with
  | Some (fill, _) -> Some fill
  | None -> None

(* Outcome of evaluating a StopLimit against one bar's path. The two non-fill
   cases are NOT interchangeable: [Stop_not_triggered] means the market never
   reached the trigger (nothing happened), while [Limit_blocked] means the
   market DID trade through the trigger and ran past the limit — for an entry
   ticket that is the do-not-chase cap refusing a fill. Only the second is a
   cost of the cap, so they are distinguished at the single point that knows
   the difference rather than re-derived by a caller. *)
type stop_limit_outcome =
  | Fills of fill_result
  | Stop_not_triggered
  | Limit_blocked

let classify_stop_limit ~(path : intraday_path) ~side ~stop_price ~limit_price :
    stop_limit_outcome =
  (* Two-stage: first stop triggers, then limit must be reached *)
  match _stop_activation_path ~path ~side ~stop_price with
  | None -> Stop_not_triggered
  | Some (stop_fill, activation_path) -> (
      let meets_limit = _meets_limit ~side ~limit_price in
      if meets_limit stop_fill.price then
        (* Trigger price meets limit, fill at trigger price (natural slippage) *)
        Fills stop_fill
      else
        (* Trigger price doesn't meet limit; search remaining path for limit price *)
        match would_fill_limit ~path:activation_path ~side ~limit_price with
        | Some fill -> Fills fill
        | None -> Limit_blocked)

(* Kept as the single fill predicate, defined in terms of the classifier above
   so the two can never disagree: every [Fills] maps to [Some] and both
   non-fill cases map to [None], which is exactly the prior behaviour. *)
let would_fill_stop_limit ~(path : intraday_path) ~side ~stop_price ~limit_price
    : fill_result option =
  match classify_stop_limit ~path ~side ~stop_price ~limit_price with
  | Fills fill -> Some fill
  | Stop_not_triggered | Limit_blocked -> None
