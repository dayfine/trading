open Core
open Trading_strategy

type suggested_order = {
  ticker : string;
  side : Trading_base.Types.side;
  order_type : Trading_base.Types.order_type;
  shares : int;
  rationale : string;
}
[@@deriving show, eq]

(** Derive share count from a position's current quantity. *)
let _shares_of_position (pos : Position.t) =
  match pos.state with
  | Position.Holding { quantity; _ } -> Int.of_float quantity
  | Position.Entering { target_quantity; _ } -> Int.of_float target_quantity
  | Position.Exiting { quantity; _ } -> Int.of_float quantity
  | Position.Closed _ -> 0

(** Map position side to broker buy/sell for an entry order. Long entries are
    buys; short entries are sells. *)
let _entry_side_of_position_side (ps : Position.position_side) =
  match ps with
  | Position.Long -> Trading_base.Types.Buy
  | Position.Short -> Trading_base.Types.Sell

(** Map position side to broker buy/sell for an exit order. Long exits are
    sells; short exits are buys (cover). *)
let _exit_side_of_position_side (ps : Position.position_side) =
  match ps with
  | Position.Long -> Trading_base.Types.Sell
  | Position.Short -> Trading_base.Types.Buy

(** Translate a single transition into a suggested_order option. Returns None
    for simulator-internal transitions or unhandled cases. *)
let _translate_transition ~(transition : Position.transition)
    ~(get_position : string -> Position.t option) : suggested_order option =
  match transition.kind with
  | Position.CreateEntering { symbol; side; target_quantity; entry_price; _ } ->
      let broker_side = _entry_side_of_position_side side in
      let shares = Int.of_float target_quantity in
      Some
        {
          ticker = symbol;
          side = broker_side;
          order_type = Trading_base.Types.StopLimit (entry_price, entry_price);
          shares;
          rationale =
            Printf.sprintf "New %s entry: %d shares at StopLimit $%.2f"
              (match side with Long -> "long" | Short -> "short")
              shares entry_price;
        }
  | Position.UpdateRiskParams
      { new_risk_params = { stop_loss_price = Some stop_price; _ } } -> (
      match get_position transition.position_id with
      | None -> None
      | Some pos ->
          let shares = _shares_of_position pos in
          let broker_side = _exit_side_of_position_side pos.side in
          Some
            {
              ticker = pos.symbol;
              side = broker_side;
              order_type = Trading_base.Types.Stop stop_price;
              shares;
              rationale =
                Printf.sprintf "Update stop to $%.2f (%d shares)" stop_price
                  shares;
            })
  | Position.UpdateRiskParams
      { new_risk_params = { stop_loss_price = None; _ } } ->
      (* No stop price update — nothing to send to broker *)
      None
  | Position.TriggerExit _ -> (
      match get_position transition.position_id with
      | None -> None
      | Some pos ->
          let shares = _shares_of_position pos in
          let broker_side = _exit_side_of_position_side pos.side in
          Some
            {
              ticker = pos.symbol;
              side = broker_side;
              order_type = Trading_base.Types.Market;
              shares;
              rationale =
                Printf.sprintf "Stop hit — exit %d shares at market" shares;
            })
  (* Simulator-internal transitions: not relevant to the live broker *)
  | Position.EntryFill _ | Position.EntryComplete _ | Position.CancelEntry _
  | Position.ExitFill _ | Position.ExitComplete ->
      None

let from_transitions ~transitions ~get_position =
  List.filter_map transitions ~f:(fun t ->
      _translate_transition ~transition:t ~get_position)
