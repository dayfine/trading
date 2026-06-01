(** Pure stage-signal predicates for the SPY-only Weinstein strategy — see
    [spy_only_signals.mli]. *)

open Trading_strategy

let is_exit_signal (result : Stage.result) : bool =
  match result.stage with
  | Weinstein_types.Stage4 _ -> true
  | Weinstein_types.Stage3 _ | Weinstein_types.Stage2 _
  | Weinstein_types.Stage1 _ -> (
      match result.transition with
      | Some (Weinstein_types.Stage3 _, Weinstein_types.Stage4 _) -> true
      | _ -> false)

let is_entry_signal (result : Stage.result) : bool =
  match result.stage with
  | Weinstein_types.Stage2 _ ->
      Weinstein_types.equal_ma_direction result.ma_direction
        Weinstein_types.Rising
  | Weinstein_types.Stage1 _ | Weinstein_types.Stage3 _
  | Weinstein_types.Stage4 _ ->
      false

let is_cover_signal (result : Stage.result) : bool =
  match result.stage with
  | Weinstein_types.Stage1 _ | Weinstein_types.Stage2 _ -> true
  | Weinstein_types.Stage3 _ | Weinstein_types.Stage4 _ -> false

let stage_exit_label_for_side ~(side : Position.position_side)
    (r : Stage.result) : string option =
  match side with
  | Position.Long -> if is_exit_signal r then Some "stage4_exit" else None
  | Position.Short -> if is_cover_signal r then Some "stage4_cover" else None

let flat_entry_side ~(enable_stage4_short : bool) (r : Stage.result) :
    Position.position_side option =
  if is_entry_signal r then Some Position.Long
  else if enable_stage4_short && is_exit_signal r then Some Position.Short
  else None
