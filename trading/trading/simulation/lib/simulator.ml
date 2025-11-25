(** Simulation engine for backtesting trading strategies *)

open Core

(** {1 Input Types} *)

type symbol_prices = { symbol : string; prices : Types.Daily_price.t list }
[@@deriving show, eq]

type config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  commission : Trading_engine.Types.commission_config;
}
[@@deriving show, eq]

type dependencies = { prices : symbol_prices list } [@@warning "-69"]

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
  order_manager : Trading_orders.Manager.order_manager;
}

(** {1 Creation} *)

let create ~config ~deps =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:config.initial_cash ()
  in
  let order_manager = Trading_orders.Manager.create () in
  { config; deps; current_date = config.start_date; portfolio; order_manager }

(** {1 Order Management} *)

let submit_orders t orders =
  let statuses = Trading_orders.Manager.submit_orders t.order_manager orders in
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

(** Helper: Create a trade from an order and fill result *)
let _create_trade (order : Trading_orders.Types.order) fill_result
    commission_config =
  let open Trading_base.Types in
  let quantity = order.quantity in
  let price = fill_result.Price_path.price in
  let commission_raw =
    Float.max
      (commission_config.Trading_engine.Types.per_share *. quantity)
      commission_config.minimum
  in
  let commission = Float.round_decimal ~decimal_digits:2 commission_raw in
  {
    id = order.id ^ "_trade";
    order_id = order.id;
    symbol = order.symbol;
    side = order.side;
    quantity;
    price;
    commission;
    timestamp = Time_ns_unix.now ();
  }

(** Helper: Execute a single order against price data *)
let _execute_order (order : Trading_orders.Types.order) price_data
    commission_config =
  let path = Price_path.generate_path price_data in
  match
    Price_path.would_fill ~path ~order_type:order.order_type ~side:order.side
  with
  | None -> None
  | Some fill_result ->
      let trade = _create_trade order fill_result commission_config in
      Some trade

(** Helper: Process all pending orders and return executed trades *)
let _process_orders t =
  let pending_orders =
    Trading_orders.Manager.list_orders ~filter:ActiveOnly t.order_manager
  in
  let trades_and_orders =
    List.filter_map pending_orders ~f:(fun order ->
        match _get_prices_for_date t.deps order.symbol t.current_date with
        | None -> None
        | Some price_data -> (
            match _execute_order order price_data t.config.commission with
            | None -> None
            | Some trade -> Some (trade, order)))
  in
  let trades = List.map trades_and_orders ~f:fst in
  (* Update order statuses to Filled *)
  List.iter trades_and_orders ~f:(fun (trade, order) ->
      let open Trading_base.Types in
      let updated_order =
        {
          order with
          status = Filled;
          filled_quantity = order.quantity;
          avg_fill_price = Some trade.price;
        }
      in
      let (_ : Status.status) =
        Trading_orders.Manager.update_order t.order_manager updated_order
      in
      ());
  trades

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
