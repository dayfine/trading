open Core
open Trading_base.Types

type portfolio_id = string [@@deriving show, eq]
type cash = float [@@deriving show, eq]
type realized_pnl = float [@@deriving show, eq]
type unrealized_pnl = float [@@deriving show, eq]

type portfolio_position = {
  symbol : symbol;
  quantity : quantity;
  avg_cost : price;
  market_value : price option;
  unrealized_pnl : unrealized_pnl;
}
[@@deriving show, eq]

type portfolio = {
  id : portfolio_id;
  cash : cash;
  positions : (symbol, portfolio_position) Hashtbl.t;
  realized_pnl : realized_pnl;
  created_at : Time_ns_unix.t;
  updated_at : Time_ns_unix.t;
}

let create_portfolio id initial_cash =
  let now = Time_ns_unix.now () in
  {
    id;
    cash = initial_cash;
    positions = Hashtbl.create (module String);
    realized_pnl = 0.0;
    created_at = now;
    updated_at = now;
  }

let get_position portfolio symbol =
  Hashtbl.find portfolio.positions symbol

let update_position portfolio symbol quantity price =
  let now = Time_ns_unix.now () in
  let updated_position =
    match get_position portfolio symbol with
    | None ->
        {
          symbol;
          quantity;
          avg_cost = price;
          market_value = None;
          unrealized_pnl = 0.0;
        }
    | Some existing ->
        let new_quantity = existing.quantity +. quantity in
        let new_avg_cost =
          if Float.equal new_quantity 0.0 then 0.0
          else
            (existing.avg_cost *. existing.quantity +. price *. quantity)
            /. new_quantity
        in
        {
          existing with
          quantity = new_quantity;
          avg_cost = new_avg_cost;
          unrealized_pnl = 0.0;
        }
  in
  Hashtbl.set portfolio.positions ~key:symbol ~data:updated_position;
  { portfolio with updated_at = now }

let calculate_portfolio_value portfolio market_prices =
  let price_map = Map.of_alist_exn (module String) market_prices in
  let position_values =
    Hashtbl.fold portfolio.positions ~init:0.0 ~f:(fun ~key:_symbol ~data:position acc ->
      let market_price = Map.find price_map position.symbol in
      match market_price with
      | Some price -> acc +. (position.quantity *. price)
      | None -> acc +. (position.quantity *. position.avg_cost))
  in
  portfolio.cash +. position_values

let get_cash_balance portfolio = portfolio.cash

let update_cash portfolio new_cash =
  let now = Time_ns_unix.now () in
  { portfolio with cash = new_cash; updated_at = now }

let list_positions portfolio =
  Hashtbl.fold portfolio.positions ~init:[] ~f:(fun ~key:_symbol ~data:position acc ->
    position :: acc)

let is_long position = Float.(position.quantity > 0.0)

let is_short position = Float.(position.quantity < 0.0)

let position_market_value position =
  match position.market_value with
  | Some price -> Some (position.quantity *. price)
  | None -> None

let update_market_prices portfolio market_prices =
  let now = Time_ns_unix.now () in
  let price_map = Map.of_alist_exn (module String) market_prices in

  let updated_positions = Hashtbl.create (module String) in
  Hashtbl.iteri portfolio.positions ~f:(fun ~key:symbol ~data:position ->
    let updated_position =
      match Map.find price_map symbol with
      | Some market_price ->
          let new_unrealized_pnl =
            (market_price -. position.avg_cost) *. position.quantity
          in
          { position with
            market_value = Some market_price;
            unrealized_pnl = new_unrealized_pnl }
      | None -> position
    in
    Hashtbl.set updated_positions ~key:symbol ~data:updated_position);

  { portfolio with
    positions = updated_positions;
    updated_at = now }