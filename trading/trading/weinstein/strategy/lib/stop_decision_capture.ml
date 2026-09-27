(** Stop-decision emission. See [stop_decision_capture.mli]. *)

open Core
open Trading_strategy
module D = Weinstein_stops.Stop_decision

let _should_emit ~is_week_close (d : D.t) =
  is_week_close || not (D.is_hold d.reason)

let _emit_one ~on_stop_decision ~stops_config ~is_week_close ~advanced
    (pos : Position.t) =
  match (Position.get_state pos, Hashtbl.find advanced pos.symbol) with
  | Position.Holding _, Some step ->
      let d =
        D.make ~config:stops_config ~side:pos.side ~position_id:pos.id step
      in
      if _should_emit ~is_week_close d then on_stop_decision d
  | _ -> ()

let emit ~on_stop_decision ~stops_config ~is_week_close ~positions ~advanced =
  Map.iter positions
    ~f:
      (_emit_one ~on_stop_decision ~stops_config ~is_week_close ~advanced)
