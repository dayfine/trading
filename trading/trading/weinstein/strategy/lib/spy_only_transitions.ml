(** Position-transition builders for the SPY-only Weinstein strategy — see
    [spy_only_transitions.mli]. *)

open Trading_strategy

let _entry_reasoning : Position.entry_reasoning =
  TechnicalSignal
    {
      indicator = "Stage";
      description = "SPY-only Weinstein: Stage 2 entry on rising 30-week MA";
    }

(* The transition [kind] for a Stage-2 long entry, built flat so [build_entry]
   stays shallow. *)
let _entry_kind ~(symbol : string) ~(entry_price : float)
    ~(target_quantity : float) : Position.transition_kind =
  CreateEntering
    {
      symbol;
      side = Long;
      target_quantity;
      entry_price;
      reasoning = _entry_reasoning;
    }

(* The transition [kind] for a stage-based exit (a [StrategySignal] reason). *)
let _exit_kind ~(label : string) ~(exit_price : float) :
    Position.transition_kind =
  let exit_reason : Position.exit_reason =
    StrategySignal { label; detail = Some "side=long" }
  in
  TriggerExit { exit_reason; exit_price }

(* The transition [kind] for a stop-triggered exit (a [StopLoss] reason). *)
let _stop_exit_kind ~(stop_level : float) ~(exit_price : float) :
    Position.transition_kind =
  let exit_reason : Position.exit_reason =
    StopLoss
      { stop_price = stop_level; actual_price = exit_price; loss_percent = 0.0 }
  in
  TriggerExit { exit_reason; exit_price }

let build_entry ~(position_id : string) ~(symbol : string)
    ~(bar : Types.Daily_price.t) ~(target_quantity : float) :
    Position.transition =
  let kind =
    _entry_kind ~symbol ~entry_price:bar.close_price ~target_quantity
  in
  { Position.position_id; date = bar.date; kind }

let build_exit ~(pos : Position.t) ~(bar : Types.Daily_price.t)
    ~(label : string) : Position.transition =
  let kind = _exit_kind ~label ~exit_price:bar.close_price in
  { Position.position_id = pos.id; date = bar.date; kind }

let build_stop_exit ~(pos : Position.t) ~(bar : Types.Daily_price.t)
    ~(stop_level : float) : Position.transition =
  let kind = _stop_exit_kind ~stop_level ~exit_price:bar.close_price in
  { Position.position_id = pos.id; date = bar.date; kind }
