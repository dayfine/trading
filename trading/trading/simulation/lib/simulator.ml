(** Simulation engine for backtesting trading strategies *)

open Core

(** {1 Input Types} *)

type symbol_prices = { symbol : string; prices : Types.Daily_price.t list }
[@@deriving show, eq]

type config = { start_date : Date.t; end_date : Date.t; initial_cash : float }
[@@deriving show, eq]

type dependencies = {
  prices : symbol_prices list;
  order_manager : Trading_orders.Manager.order_manager;
  engine : Trading_engine.Engine.t;
}

(** {1 Simulator Types} *)

type step_result = {
  date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  trades : Trading_base.Types.trade list;
}
[@@deriving show, eq]

type step_outcome =
  | Stepped of t * step_result
  | Completed of Trading_portfolio.Portfolio.t

and t = {
  config : config;
  deps : dependencies;
  current_date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
}

(** {1 Creation} *)

let create ~config ~deps =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:config.initial_cash ()
  in
  { config; deps; current_date = config.start_date; portfolio }

(** {1 Order Management} *)

let submit_orders t orders =
  let statuses =
    Trading_orders.Manager.submit_orders t.deps.order_manager orders
  in
  (t, statuses)

(** {1 Running} *)

let _is_complete t = Date.( >= ) t.current_date t.config.end_date

(** Helper: Find price data for a symbol on a given date *)
let _get_prices_for_date deps symbol date =
  match List.find deps.prices ~f:(fun sp -> String.equal sp.symbol symbol) with
  | None -> None
  | Some symbol_prices -> (
      match
        List.find symbol_prices.prices ~f:(fun p ->
            Date.equal p.Types.Daily_price.date date)
      with
      | Some price_data -> Some price_data
      | None -> None)

(** Helper: Check if an order would fill using Price_path *)
let _check_fill (order : Trading_orders.Types.order) price_data =
  let path = Price_path.generate_path price_data in
  Price_path.would_fill ~path ~order_type:order.order_type ~side:order.side

(** Helper: Process all pending orders and return executed trades *)
let _process_orders t =
  let pending_orders =
    Trading_orders.Manager.list_orders ~filter:ActiveOnly t.deps.order_manager
  in
  (* Check which orders would fill using Price_path *)
  let fillable_orders =
    List.filter_map pending_orders ~f:(fun order ->
        match _get_prices_for_date t.deps order.symbol t.current_date with
        | None -> None
        | Some price_data -> (
            match _check_fill order price_data with
            | None -> None
            | Some fill_result -> Some (order, fill_result)))
  in
  (* Create price_quotes for the engine based on fill prices *)
  let quotes =
    List.map fillable_orders ~f:(fun (order, fill_result) ->
        let fill_price = fill_result.Price_path.price in
        Trading_engine.Types.
          {
            symbol = order.symbol;
            bid = Some fill_price;
            ask = Some fill_price;
            last = Some fill_price;
          })
  in
  (* Update engine market with fill prices *)
  Trading_engine.Engine.update_market t.deps.engine quotes;
  (* Let engine process orders - it will create trades and update statuses *)
  match
    Trading_engine.Engine.process_orders t.deps.engine t.deps.order_manager
  with
  | Error err ->
      (* Log error but continue - return empty trades list *)
      let _ = err in
      []
  | Ok execution_reports ->
      (* Extract trades from execution reports *)
      List.concat_map execution_reports ~f:(fun report -> report.trades)

let step t =
  if _is_complete t then Ok (Completed t.portfolio)
  else
    (* Process pending orders and execute against price paths *)
    let trades = _process_orders t in
    (* Apply trades to portfolio *)
    match Trading_portfolio.Portfolio.apply_trades t.portfolio trades with
    | Error err -> Error err
    | Ok updated_portfolio ->
        let step_result =
          { date = t.current_date; portfolio = updated_portfolio; trades }
        in
        let next_date = Date.add_days t.current_date 1 in
        let t' =
          { t with current_date = next_date; portfolio = updated_portfolio }
        in
        Ok (Stepped (t', step_result))

let run t =
  let rec loop t acc =
    match step t with
    | Error e -> Error e
    | Ok (Completed portfolio) -> Ok (List.rev acc, portfolio)
    | Ok (Stepped (t', step_result)) -> loop t' (step_result :: acc)
  in
  loop t []
