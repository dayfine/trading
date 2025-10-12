open Core
open Trading_base.Types
open Trading_orders.Types
open Types

type portfolio_manager = {
  portfolios : (portfolio_id, portfolio) Hashtbl.t;
}

let create () = {
  portfolios = Hashtbl.create (module String);
}

let create_portfolio manager portfolio_id initial_cash =
  let portfolio = create_portfolio portfolio_id initial_cash in
  Hashtbl.set manager.portfolios ~key:portfolio_id ~data:portfolio;
  portfolio_id

let get_portfolio manager portfolio_id =
  Hashtbl.find manager.portfolios portfolio_id

let list_portfolios manager =
  Hashtbl.fold manager.portfolios ~init:[] ~f:(fun ~key:_id ~data:portfolio acc ->
    portfolio :: acc)

let apply_order_execution manager portfolio_id order =
  match get_portfolio manager portfolio_id with
  | None -> manager (* Portfolio not found, no change *)
  | Some portfolio ->
      let updated_portfolio =
        match order.status with
        | Filled ->
            let trade_quantity = match order.side with
              | Buy -> order.quantity
              | Sell -> -. order.quantity
            in
            let trade_price = match order.avg_fill_price with
              | Some price -> price
              | None ->
                  (* Fallback to order price for market orders or when avg_fill_price is missing *)
                  match order.order_type with
                  | Market -> 0.0 (* This should ideally come from market data *)
                  | Limit price -> price
                  | Stop price -> price
                  | StopLimit (_, limit_price) -> limit_price
            in
            let cash_change = match order.side with
              | Buy -> -. (order.quantity *. trade_price)
              | Sell -> order.quantity *. trade_price
            in
            let portfolio_with_position = update_position portfolio order.symbol trade_quantity trade_price in
            update_cash portfolio_with_position (portfolio.cash +. cash_change)
        | PartiallyFilled filled_qty ->
            let trade_quantity = match order.side with
              | Buy -> filled_qty
              | Sell -> -. filled_qty
            in
            let trade_price = match order.avg_fill_price with
              | Some price -> price
              | None ->
                  match order.order_type with
                  | Market -> 0.0
                  | Limit price -> price
                  | Stop price -> price
                  | StopLimit (_, limit_price) -> limit_price
            in
            let cash_change = match order.side with
              | Buy -> -. (filled_qty *. trade_price)
              | Sell -> filled_qty *. trade_price
            in
            let portfolio_with_position = update_position portfolio order.symbol trade_quantity trade_price in
            update_cash portfolio_with_position (portfolio.cash +. cash_change)
        | Pending | Cancelled | Rejected _ ->
            portfolio (* No position or cash changes for these statuses *)
      in
      Hashtbl.set manager.portfolios ~key:portfolio_id ~data:updated_portfolio;
      manager

let check_buying_power manager portfolio_id order =
  match get_portfolio manager portfolio_id with
  | None -> false
  | Some portfolio ->
      match order.side with
      | Buy ->
          let estimated_price =
            match order.order_type with
            | Market ->
                (* For market orders, use avg_fill_price if available, otherwise estimate *)
                begin match order.avg_fill_price with
                | Some price -> price
                | None -> 1000.0 (* Conservative estimate for market orders *)
                end
            | Limit price -> price
            | Stop price -> price
            | StopLimit (_, limit_price) -> limit_price
          in
          let required_cash = order.quantity *. estimated_price in
          Float.(portfolio.cash >= required_cash)
      | Sell ->
          (* Check if we have enough position to sell *)
          match get_position portfolio order.symbol with
          | None -> false
          | Some position -> Float.(position.quantity >= order.quantity)

let get_portfolio_value manager portfolio_id market_prices =
  match get_portfolio manager portfolio_id with
  | None -> None
  | Some portfolio -> Some (calculate_portfolio_value portfolio market_prices)

let update_market_prices manager market_prices =
  let updated_portfolios = Hashtbl.create (module String) in
  Hashtbl.iteri manager.portfolios ~f:(fun ~key:portfolio_id ~data:portfolio ->
    let updated_portfolio = Types.update_market_prices portfolio market_prices in
    Hashtbl.set updated_portfolios ~key:portfolio_id ~data:updated_portfolio);
  { portfolios = updated_portfolios }

let get_cash_balance manager portfolio_id =
  match get_portfolio manager portfolio_id with
  | None -> None
  | Some portfolio -> Some portfolio.cash

let transfer_cash manager portfolio_id amount =
  match get_portfolio manager portfolio_id with
  | None -> manager
  | Some portfolio ->
      let updated_portfolio = update_cash portfolio (portfolio.cash +. amount) in
      Hashtbl.set manager.portfolios ~key:portfolio_id ~data:updated_portfolio;
      manager

let get_position manager portfolio_id symbol =
  match get_portfolio manager portfolio_id with
  | None -> None
  | Some portfolio -> get_position portfolio symbol

let list_positions manager portfolio_id =
  match get_portfolio manager portfolio_id with
  | None -> []
  | Some portfolio -> list_positions portfolio

let calculate_total_pnl manager portfolio_id market_prices =
  match get_portfolio manager portfolio_id with
  | None -> None
  | Some portfolio ->
      let updated_portfolio = Types.update_market_prices portfolio market_prices in
      let unrealized_pnl = Hashtbl.fold updated_portfolio.positions ~init:0.0
        ~f:(fun ~key:_symbol ~data:position acc -> acc +. position.unrealized_pnl) in
      Some (portfolio.realized_pnl, unrealized_pnl)