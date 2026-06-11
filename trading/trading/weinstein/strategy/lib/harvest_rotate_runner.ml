open Core
open Trading_strategy

(** Build the [TriggerPartialExit] transition that trims [target_quantity] of
    [pos] at [exit_price = close]. The trim fires at the current bar's close —
    same convention as {!Stage3_force_exit_runner._make_exit_transition}: for a
    discretionary trim at the close, [close] is the most defensible fill marker.

    The [exit_reason] uses the generic {!Position.exit_reason.StrategySignal}
    variant with [label = "harvest_rotate"] — the value surfaced in the
    [exit_trigger] column of [trades.csv]. *)
let _make_trim_transition ~(pos : Position.t) ~current_date ~close
    ~target_quantity =
  let exit_reason =
    Position.StrategySignal
      {
        label = "harvest_rotate";
        detail = Some (Printf.sprintf "harvest_qty=%.4f" target_quantity);
      }
  in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind =
      Position.TriggerPartialExit
        { exit_reason; exit_price = close; target_quantity };
  }

(** [true] iff [stage] is [Stage2 { late = true }] — the only stage that
    triggers a harvest trim. Every other stage (incl. [Stage2 { late = false }])
    is a no-op. *)
let _is_late_stage2 = function
  | Weinstein_types.Stage2 { late; _ } -> late
  | Stage1 _ | Stage3 _ | Stage4 _ -> false

(** Current close for [pos] when it is held in late Stage 2 — i.e. its stage
    (read from [prior_stages]) is [Stage2 { late = true }] and [get_price] has a
    bar; [None] otherwise. Mirrors {!Late_stage2_stop_runner._late_stage2_close}
    so {!_trim_held_long} stays a shallow, flat match. *)
let _late_stage2_close ~get_price ~prior_stages (pos : Position.t) =
  match Hashtbl.find prior_stages pos.symbol with
  | Some stage when _is_late_stage2 stage ->
      Option.map (get_price pos.symbol) ~f:(fun bar ->
          bar.Types.Daily_price.close_price)
  | Some _ | None -> None

(** Trim a held long [pos] when it is in late Stage 2 and a bar is available.
    The trimmed quantity is [held_quantity *. effective_fraction] where
    [effective_fraction = Float.min 1.0 harvest_fraction] (a fraction >= 1.0
    trims the whole position, identical to a full exit). [held_quantity] is read
    from the [Holding] state passed by {!_process_position}. *)
let _trim_held_long ~effective_fraction ~get_price ~prior_stages ~current_date
    ~held_quantity (pos : Position.t) =
  match _late_stage2_close ~get_price ~prior_stages pos with
  | Some close ->
      let target_quantity = held_quantity *. effective_fraction in
      Some (_make_trim_transition ~pos ~current_date ~close ~target_quantity)
  | None -> None

(** Process one position. Returns [Some transition] only for a held long
    position whose current stage is [Stage2 { late = true }] and that has a bar
    in [get_price]. Short positions and non-[Holding] states are skipped. *)
let _process_position ~effective_fraction ~get_price ~prior_stages ~current_date
    (pos : Position.t) =
  match (pos.side, Position.get_state pos) with
  | Trading_base.Types.Long, Position.Holding { quantity; _ } ->
      _trim_held_long ~effective_fraction ~get_price ~prior_stages ~current_date
        ~held_quantity:quantity pos
  | _ -> None

let _fold_position ~effective_fraction ~get_price ~prior_stages ~current_date
    acc pos =
  match
    _process_position ~effective_fraction ~get_price ~prior_stages ~current_date
      pos
  with
  | Some t -> t :: acc
  | None -> acc

let update ~harvest_fraction ~is_screening_day ~positions ~get_price
    ~prior_stages ~current_date =
  if (not is_screening_day) || Float.(harvest_fraction <= 0.0) then []
  else
    let effective_fraction = Float.min 1.0 harvest_fraction in
    Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
        _fold_position ~effective_fraction ~get_price ~prior_stages
          ~current_date acc pos)
