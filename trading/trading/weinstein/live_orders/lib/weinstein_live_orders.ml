(** Live order path. See .mli. *)

open Core
open Trading_strategy

type tick = {
  transitions : Position.transition list;
  positions_after : Position.t list;
}

let _level_of stop_states ticker =
  Map.find stop_states ticker |> Option.map ~f:Weinstein_stops.get_stop_level

let _find_position positions position_id =
  List.find positions ~f:(fun (p : Position.t) ->
      String.equal p.Position.id position_id)

let orders_for_tick ?entry_extension_max_pct ~stop_states_before
    ~stop_states_after { transitions; positions_after } =
  let stop_sync =
    {
      Weinstein_order_gen.positions = positions_after;
      stop_level_before = _level_of stop_states_before;
      stop_level_after = _level_of stop_states_after;
    }
  in
  Weinstein_order_gen.from_transitions ?entry_extension_max_pct ~stop_sync
    ~transitions
    ~get_position:(_find_position positions_after)
    ()

let run_tick ?entry_extension_max_pct ~stop_states step =
  let stop_states_before = !stop_states in
  let tick = step () in
  orders_for_tick ?entry_extension_max_pct ~stop_states_before
    ~stop_states_after:!stop_states tick
