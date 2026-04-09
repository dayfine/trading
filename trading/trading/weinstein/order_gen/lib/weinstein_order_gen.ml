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

let _position_side_name (ps : Position.position_side) =
  match ps with Position.Long -> "long" | Position.Short -> "short"

let _entry_order symbol side target_quantity entry_price =
  let shares = Int.of_float target_quantity in
  Some
    {
      ticker = symbol;
      side = _entry_side_of_position_side side;
      order_type = Trading_base.Types.StopLimit (entry_price, entry_price);
      shares;
      rationale =
        Printf.sprintf "New %s entry: %d shares at StopLimit $%.2f"
          (_position_side_name side) shares entry_price;
    }

let _stop_order_for_pos pos stop_price =
  let shares = _shares_of_position pos in
  Some
    {
      ticker = pos.symbol;
      side = _exit_side_of_position_side pos.side;
      order_type = Trading_base.Types.Stop stop_price;
      shares;
      rationale =
        Printf.sprintf "Update stop to $%.2f (%d shares)" stop_price shares;
    }

let _market_exit_for_pos pos =
  let shares = _shares_of_position pos in
  Some
    {
      ticker = pos.symbol;
      side = _exit_side_of_position_side pos.side;
      order_type = Trading_base.Types.Market;
      shares;
      rationale = Printf.sprintf "Stop hit — exit %d shares at market" shares;
    }

(** Translate a single transition into a suggested_order option. Returns None
    for simulator-internal transitions or unhandled cases. *)
let _translate_transition ~(transition : Position.transition)
    ~(get_position : string -> Position.t option) : suggested_order option =
  match transition.kind with
  | Position.CreateEntering { symbol; side; target_quantity; entry_price; _ } ->
      _entry_order symbol side target_quantity entry_price
  | Position.UpdateRiskParams
      { new_risk_params = { stop_loss_price = Some stop_price; _ } } ->
      Option.bind (get_position transition.position_id) ~f:(fun pos ->
          _stop_order_for_pos pos stop_price)
  | Position.UpdateRiskParams
      { new_risk_params = { stop_loss_price = None; _ } } ->
      (* No stop price update — nothing to send to broker *)
      None
  (* TriggerExit is internal accounting for when the strategy detects a stop
     breach. In live trading the GTC Stop order sent via UpdateRiskParams is
     already working at the broker and will execute automatically — no
     additional order is needed here. *)
  | Position.TriggerExit _
  (* Simulator-internal transitions: not relevant to the live broker *)
  | Position.EntryFill _ | Position.EntryComplete _ | Position.CancelEntry _
  | Position.ExitFill _ | Position.ExitComplete ->
      None

let from_transitions ~transitions ~get_position =
  List.filter_map transitions ~f:(fun t ->
      _translate_transition ~transition:t ~get_position)
