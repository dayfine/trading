open Core

let cash_key = "__CASH__"

let _make_cash_position cash =
  {
    Position.id = cash_key;
    symbol = cash_key;
    side = Long;
    entry_reasoning = ManualDecision { description = "Cash balance" };
    exit_reason = None;
    state =
      Holding
        {
          quantity = cash;
          entry_price = 1.0;
          entry_date = Date.of_string "2000-01-01";
          risk_params =
            {
              stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = Date.of_string "2000-01-01";
    portfolio_lot_ids = [];
  }

let inject_cash ~cash positions =
  Map.set positions ~key:cash_key ~data:(_make_cash_position cash)

let extract_cash positions =
  match Map.find positions cash_key with
  | Some { Position.state = Holding { quantity; _ }; _ } -> quantity
  | _ -> 0.0

let _holding_value (pos : Position.t) ~get_price =
  if String.equal pos.symbol cash_key then
    match pos.state with Holding { quantity; _ } -> quantity | _ -> 0.0
  else
    match pos.state with
    | Holding { quantity; _ } -> (
        match get_price pos.symbol with
        | Some (bar : Types.Daily_price.t) -> quantity *. bar.close_price
        | None -> 0.0)
    | _ -> 0.0

let compute_portfolio_value positions ~get_price =
  Map.fold positions ~init:0.0 ~f:(fun ~key:_ ~data:pos acc ->
      acc +. _holding_value pos ~get_price)

let positions_only positions = Map.remove positions cash_key
