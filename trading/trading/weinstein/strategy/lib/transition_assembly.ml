open Core
open Trading_strategy

let trigger_exit_ids_of (ts : Position.transition list) : String.Set.t =
  List.filter_map ts ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.TriggerExit _ -> Some t.position_id
      | _ -> None)
  |> String.Set.of_list

let filter_out_exited_ids exited_ids (ts : Position.transition list) :
    Position.transition list =
  if Set.is_empty exited_ids then ts
  else
    List.filter ts ~f:(fun (t : Position.transition) ->
        not (Set.mem exited_ids t.position_id))

let assemble_output ~exit_transitions ~stage3_force_exit_transitions
    ~laggard_rotation_transitions ~force_exit_transitions
    ~macro_trim_transitions ~harvest_rotate_transitions ~adjust_transitions
    ~entry_transitions ~stop_exited_ids ~stage3_exited_ids ~laggard_exited_ids =
  let force_liq_exited_ids = trigger_exit_ids_of force_exit_transitions in
  let macro_trim_exited_ids = trigger_exit_ids_of macro_trim_transitions in
  let all_exited_ids =
    Set.union_list
      (module String)
      [
        stop_exited_ids;
        stage3_exited_ids;
        laggard_exited_ids;
        force_liq_exited_ids;
        macro_trim_exited_ids;
      ]
  in
  let adjust_transitions =
    filter_out_exited_ids all_exited_ids adjust_transitions
  in
  (* Drop a harvest-trim for any position already fully exited this tick (a stop
     hit / Stage-3 / laggard / force-liq / macro-bearish exit) — that position is
     closing, so there is nothing left to trim. *)
  let harvest_rotate_transitions =
    filter_out_exited_ids all_exited_ids harvest_rotate_transitions
  in
  Ok
    {
      Strategy_interface.transitions =
        exit_transitions @ stage3_force_exit_transitions
        @ laggard_rotation_transitions @ force_exit_transitions
        @ macro_trim_transitions @ harvest_rotate_transitions
        @ adjust_transitions @ entry_transitions;
    }
