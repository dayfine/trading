open Core
open Status
open Types

type t = {
  initial_cash : cash;
  trade_history : Trading_base.Types.trade list;
  (* Computed state - maintained for performance *)
  current_cash : cash;
  positions : (Trading_base.Types.symbol, portfolio_position) Hashtbl.t;
}

let create ~initial_cash =
  {
    initial_cash;
    trade_history = [];
    current_cash = initial_cash;
    positions = Hashtbl.create (module String);
  }

let get_cash portfolio = portfolio.current_cash
let get_initial_cash portfolio = portfolio.initial_cash
let get_trade_history portfolio = portfolio.trade_history
let get_position portfolio symbol = Hashtbl.find portfolio.positions symbol

let update_position_with_trade positions (trade : Trading_base.Types.trade) :
    unit status_or =
  let symbol = trade.symbol in
  let trade_quantity =
    match trade.side with Buy -> trade.quantity | Sell -> -.trade.quantity
  in

  match Hashtbl.find positions symbol with
  | None when Float.(trade_quantity > 0.0) ->
      (* New long position *)
      let position =
        { symbol; quantity = trade_quantity; avg_cost = trade.price }
      in
      Hashtbl.set positions ~key:symbol ~data:position;
      Ok ()
  | None ->
      (* Trying to sell without position *)
      error_invalid_argument
        ("Cannot sell " ^ symbol ^ " without existing position")
  | Some existing ->
      let new_quantity = existing.quantity +. trade_quantity in
      if Float.(new_quantity < 0.0) then
        error_invalid_argument
          ("Insufficient position in " ^ symbol ^ " to sell "
          ^ Float.to_string trade.quantity)
      else if Float.(new_quantity = 0.0) then (
        (* Position closed *)
        Hashtbl.remove positions symbol;
        Ok ())
      else
        (* Update existing position with new average cost *)
        let new_avg_cost =
          if Float.(trade_quantity > 0.0) then
            (* Adding to position *)
            ((existing.avg_cost *. existing.quantity)
            +. (trade.price *. trade_quantity))
            /. new_quantity
          else
            (* Reducing position - keep existing average cost *)
            existing.avg_cost
        in
        let updated_position =
          { existing with quantity = new_quantity; avg_cost = new_avg_cost }
        in
        Hashtbl.set positions ~key:symbol ~data:updated_position;
        Ok ()

let apply_single_trade (portfolio : t) (trade : Trading_base.Types.trade) :
    t status_or =
  let cash_change =
    match trade.side with
    | Buy -> -.((trade.quantity *. trade.price) +. trade.commission)
    | Sell -> (trade.quantity *. trade.price) -. trade.commission
  in

  let new_cash = portfolio.current_cash +. cash_change in
  if Float.(new_cash < 0.0) then
    error_invalid_argument
      ("Insufficient cash for trade. Required: "
      ^ Float.to_string (-.cash_change)
      ^ ", Available: "
      ^ Float.to_string portfolio.current_cash)
  else
    let new_positions = Hashtbl.copy portfolio.positions in
    match
      update_position_with_trade new_positions
        (trade : Trading_base.Types.trade)
    with
    | Ok () ->
        Ok
          {
            portfolio with
            current_cash = new_cash;
            positions = new_positions;
            trade_history = portfolio.trade_history @ [ trade ];
          }
    | Error _ as err -> err

let apply_trades portfolio trades =
  List.fold trades ~init:(Result.Ok portfolio) ~f:(fun acc trade ->
      match acc with
      | Ok p -> apply_single_trade p trade
      | Error _ as err -> err)

let list_positions portfolio =
  Hashtbl.fold portfolio.positions ~init:[]
    ~f:(fun ~key:_symbol ~data:position acc -> position :: acc)

(* Reconstruct portfolio from scratch for validation *)
let reconstruct_from_history initial_cash trades =
  let empty_portfolio = create ~initial_cash in
  apply_trades empty_portfolio trades

let validate portfolio =
  match
    reconstruct_from_history portfolio.initial_cash portfolio.trade_history
  with
  | Error _ as err -> err
  | Ok reconstructed ->
      let cash_matches =
        Float.equal portfolio.current_cash reconstructed.current_cash
      in

      let positions_match =
        let current_symbols =
          Hashtbl.keys portfolio.positions |> Set.of_list (module String)
        in
        let reconstructed_symbols =
          Hashtbl.keys reconstructed.positions |> Set.of_list (module String)
        in

        if not (Set.equal current_symbols reconstructed_symbols) then false
        else
          Set.for_all current_symbols ~f:(fun symbol ->
              match
                ( Hashtbl.find portfolio.positions symbol,
                  Hashtbl.find reconstructed.positions symbol )
              with
              | Some curr, Some recon ->
                  Float.equal curr.quantity recon.quantity
                  && Float.equal curr.avg_cost recon.avg_cost
              | _ -> false)
      in

      if cash_matches && positions_match then Ok ()
      else
        error_invalid_argument
          ("Portfolio validation failed: cash_matches="
          ^ Bool.to_string cash_matches
          ^ ", positions_match="
          ^ Bool.to_string positions_match)
