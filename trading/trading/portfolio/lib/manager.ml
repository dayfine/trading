open Core
open Trading_base.Types
open Trading_orders.Types
open Types

type portfolio_manager = { portfolio : portfolio }

let create initial_cash =
  let now = Time_ns_unix.now () in
  {
    portfolio =
      {
        cash = initial_cash;
        positions = Hashtbl.create (module String);
        realized_pnl = 0.0;
        created_at = now;
        updated_at = now;
      };
  }

let get_portfolio manager = manager.portfolio

let get_position manager symbol =
  Hashtbl.find manager.portfolio.positions symbol

let update_position portfolio symbol quantity price =
  let now = Time_ns_unix.now () in
  let updated_position =
    match Hashtbl.find portfolio.positions symbol with
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
            ((existing.avg_cost *. existing.quantity) +. (price *. quantity))
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

let update_cash portfolio new_cash =
  let now = Time_ns_unix.now () in
  { portfolio with cash = new_cash; updated_at = now }

let apply_order_execution manager order =
  let portfolio = manager.portfolio in
  let updated_portfolio =
    match order.status with
    | Filled ->
        let trade_quantity =
          match order.side with
          | Buy -> order.quantity
          | Sell -> -.order.quantity
        in
        let trade_price =
          match order.avg_fill_price with
          | Some price -> price
          | None -> (
              (* Fallback to order price for market orders or when avg_fill_price is missing *)
              match order.order_type with
              | Market -> 0.0 (* This should ideally come from market data *)
              | Limit price -> price
              | Stop price -> price
              | StopLimit (_, limit_price) -> limit_price)
        in
        let cash_change =
          match order.side with
          | Buy -> -.(order.quantity *. trade_price)
          | Sell -> order.quantity *. trade_price
        in
        let portfolio_with_position =
          update_position portfolio order.symbol trade_quantity trade_price
        in
        update_cash portfolio_with_position (portfolio.cash +. cash_change)
    | PartiallyFilled filled_qty ->
        let trade_quantity =
          match order.side with Buy -> filled_qty | Sell -> -.filled_qty
        in
        let trade_price =
          match order.avg_fill_price with
          | Some price -> price
          | None -> (
              match order.order_type with
              | Market -> 0.0
              | Limit price -> price
              | Stop price -> price
              | StopLimit (_, limit_price) -> limit_price)
        in
        let cash_change =
          match order.side with
          | Buy -> -.(filled_qty *. trade_price)
          | Sell -> filled_qty *. trade_price
        in
        let portfolio_with_position =
          update_position portfolio order.symbol trade_quantity trade_price
        in
        update_cash portfolio_with_position (portfolio.cash +. cash_change)
    | Pending | Cancelled | Rejected _ ->
        portfolio (* No position or cash changes for these statuses *)
  in
  { portfolio = updated_portfolio }

let check_buying_power manager order =
  let portfolio = manager.portfolio in
  match order.side with
  | Buy ->
      let estimated_price =
        match order.order_type with
        | Market -> (
            (* For market orders, use avg_fill_price if available, otherwise estimate *)
            match order.avg_fill_price with
            | Some price -> price
            | None -> 1000.0 (* Conservative estimate for market orders *))
        | Limit price -> price
        | Stop price -> price
        | StopLimit (_, limit_price) -> limit_price
      in
      let required_cash = order.quantity *. estimated_price in
      Float.(portfolio.cash >= required_cash)
  | Sell -> (
      (* Check if we have enough position to sell *)
      match get_position manager order.symbol with
      | None -> false
      | Some position -> Float.(position.quantity >= order.quantity))

let list_positions manager =
  Hashtbl.fold manager.portfolio.positions ~init:[]
    ~f:(fun ~key:_symbol ~data:position acc -> position :: acc)
