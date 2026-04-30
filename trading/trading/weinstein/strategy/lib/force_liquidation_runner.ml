(** Force-liquidation policy applied to held positions. See
    [force_liquidation_runner.mli]. *)

open Core
open Trading_strategy
module FL = Portfolio_risk.Force_liquidation

(** Build a [Force_liquidation.position_input] for one Holding position when a
    current price is available. Returns [None] for non-Holding positions and for
    symbols without a price feed this tick. *)
let _position_input_of_holding ~get_price (pos : Position.t) :
    FL.position_input option =
  match pos.state with
  | Position.Holding { quantity; entry_price; _ } -> (
      match get_price pos.symbol with
      | Some (bar : Types.Daily_price.t) ->
          Some
            {
              symbol = pos.symbol;
              position_id = pos.id;
              side = pos.side;
              entry_price;
              current_price = bar.close_price;
              quantity;
            }
      | None -> None)
  | _ -> None

(** Compute portfolio mark-to-market value via the canonical
    [Portfolio_view.portfolio_value]. Long holdings contribute
    [+quantity * close_price]; shorts contribute [-quantity * close_price] (cash
    already reflects short-entry proceeds, so subtracting the buy-back liability
    is what makes mark-to-market track P&L correctly).

    G9 fix: previously this fold added [+quantity * close_price] for every
    Holding regardless of side, mirroring the pre-G8 bug in
    {!Portfolio_view._holding_market_value}. Delegating to
    [Portfolio_view.portfolio_value] eliminates the duplicate calculation so the
    sign convention has a single source of truth. *)
let _portfolio_value ~cash ~positions ~get_price =
  Portfolio_view.portfolio_value { cash; positions } ~get_price

(** Convert a force-liquidation event into a TriggerExit transition. The
    exit_reason is [Position.StopLoss] — the existing variant the position state
    machine + simulator already handle. The force-liquidation distinction is
    recorded separately via the audit recorder. *)
let _transition_of_event (e : FL.event) : Position.transition =
  let exit_reason =
    Position.StopLoss
      {
        stop_price = e.entry_price;
        actual_price = e.current_price;
        loss_percent = -.e.unrealized_pnl_pct *. 100.0;
      }
  in
  {
    Position.position_id = e.position_id;
    date = e.date;
    kind = Position.TriggerExit { exit_reason; exit_price = e.current_price };
  }

let update ~config ~positions ~get_price ~cash ~current_date ~peak_tracker
    ~audit_recorder =
  let inputs =
    Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
        match _position_input_of_holding ~get_price pos with
        | Some pi -> pi :: acc
        | None -> acc)
  in
  let portfolio_value = _portfolio_value ~cash ~positions ~get_price in
  let events =
    FL.check ~config ~date:current_date ~positions:inputs ~portfolio_value
      ~peak_tracker
  in
  List.iter events ~f:audit_recorder.Audit_recorder.record_force_liquidation;
  List.map events ~f:_transition_of_event
