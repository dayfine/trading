(** Stop-decision emission. See [stop_decision_capture.mli]. *)

open Core
open Trading_strategy
module D = Weinstein_stops.Stop_decision

let _emit_one ~on_stop_decision ~stops_config ~advanced (pos : Position.t) =
  match (Position.get_state pos, Hashtbl.find advanced pos.symbol) with
  | Position.Holding _, Some step ->
      on_stop_decision
        (D.make ~config:stops_config ~side:pos.side ~position_id:pos.id step)
  | _ -> ()

let emit ~on_stop_decision ~stops_config ~positions ~advanced =
  Map.iter positions ~f:(_emit_one ~on_stop_decision ~stops_config ~advanced)
