(** Per-tick split-event detector and stop-state rescaler — see
    [stops_split_runner.mli]. *)

open Core
open Trading_strategy

(* Read [as_of]'s and the prior trading day's daily bars for [symbol]. The
   bar reader returns the full series up to [as_of] in chronological order;
   we take the final two entries when present. Returns [None] when fewer
   than two bars are available — first day of trading, symbol not in
   panel, or as_of out of calendar. *)
let _last_two_bars ~bar_reader ~symbol ~as_of =
  let bars = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of in
  match List.rev bars with curr :: prev :: _ -> Some (prev, curr) | _ -> None

(* Detect a split between yesterday's and today's bar for [symbol]. Returns
   [None] when no qualifying ratio fires; see [Types.Split_detector] for
   the snap-to-rational contract. *)
let _detect_split_for_symbol ~bar_reader ~symbol ~as_of =
  let%bind.Option prev, curr = _last_two_bars ~bar_reader ~symbol ~as_of in
  Types.Split_detector.detect_split ~prev ~curr ()

(* Rescale a single symbol's stop_state in place. No-ops when no entry is
   present in [stop_states] (position with no stop registered yet) or when
   no split is detected. *)
let _adjust_one ~bar_reader ~as_of ~stop_states symbol =
  match Map.find !stop_states symbol with
  | None -> ()
  | Some state -> (
      match _detect_split_for_symbol ~bar_reader ~symbol ~as_of with
      | None -> ()
      | Some factor ->
          let scaled = Weinstein_stops.Stop_split_adjust.scale ~factor state in
          stop_states := Map.set !stop_states ~key:symbol ~data:scaled)

let adjust ~positions ~stop_states ~bar_reader ~as_of =
  Map.iter positions ~f:(fun (pos : Position.t) ->
      _adjust_one ~bar_reader ~as_of ~stop_states pos.symbol)
