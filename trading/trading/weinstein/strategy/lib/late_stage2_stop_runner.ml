open Core
open Trading_strategy

(** Build the [UpdateRiskParams] transition that raises [pos]'s stop to
    [new_level]. Mirrors {!Stops_runner._make_adjust_transition}: the
    take-profit and max-hold fields are carried through unchanged so only the
    stop level moves. *)
let _make_adjust_transition ~(pos : Position.t)
    ~(risk_params : Position.risk_params) ~current_date ~new_level =
  let new_risk_params =
    {
      Position.stop_loss_price = Some new_level;
      take_profit_price = risk_params.take_profit_price;
      max_hold_days = risk_params.max_hold_days;
    }
  in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind = Position.UpdateRiskParams { new_risk_params };
  }

(** [true] iff [stage] is [Stage2 { late = true }] — the only stage that
    triggers a late-stage tighten. Every other stage (incl.
    [Stage2 { late = false }]) is a no-op. *)
let _is_late_stage2 = function
  | Weinstein_types.Stage2 { late; _ } -> late
  | Stage1 _ | Stage3 _ | Stage4 _ -> false

(** Emit a tighten transition for a held long [pos] in late Stage 2 when the
    tightened candidate stop sits strictly above the existing stop.

    The candidate is [close *. (1.0 -. buffer_pct)] — a fixed fraction below the
    current close (structural: below recent support). The never-lowered
    invariant is enforced here: a position with no stop yet always tightens; a
    position whose existing stop already sits at or above the candidate is left
    untouched. *)
let _tighten_if_higher ~buffer_pct ~risk_params ~current_date ~close
    (pos : Position.t) =
  let candidate = close *. (1.0 -. buffer_pct) in
  let raises =
    match risk_params.Position.stop_loss_price with
    | None -> true
    | Some existing -> Float.(candidate > existing)
  in
  if raises then
    Some
      (_make_adjust_transition ~pos ~risk_params ~current_date
         ~new_level:candidate)
  else None

(** Current close for [pos] when it is held in late Stage 2 — i.e. its stage
    (read from [prior_stages]) is [Stage2 { late = true }] and [get_price] has a
    bar; [None] otherwise. Extracted so {!_tighten_held_long} stays a shallow,
    flat match. *)
let _late_stage2_close ~get_price ~prior_stages (pos : Position.t) =
  match Hashtbl.find prior_stages pos.symbol with
  | Some stage when _is_late_stage2 stage ->
      Option.map (get_price pos.symbol) ~f:(fun bar ->
          bar.Types.Daily_price.close_price)
  | Some _ | None -> None

(** Tighten a held long [pos]'s stop when it is in late Stage 2 and a bar is
    available. Split out of {!_process_position} so the side/state match and the
    stage match each sit at shallow nesting. *)
let _tighten_held_long ~buffer_pct ~get_price ~prior_stages ~current_date
    ~risk_params (pos : Position.t) =
  match _late_stage2_close ~get_price ~prior_stages pos with
  | Some close ->
      _tighten_if_higher ~buffer_pct ~risk_params ~current_date ~close pos
  | None -> None

(** Process one position. Returns [Some transition] only for a held long
    position whose current stage is [Stage2 { late = true }], that has a bar in
    [get_price], and whose tightened stop would rise. Short positions and
    non-[Holding] states are skipped. *)
let _process_position ~buffer_pct ~get_price ~prior_stages ~current_date
    (pos : Position.t) =
  match (pos.side, Position.get_state pos) with
  | Trading_base.Types.Long, Position.Holding { risk_params; _ } ->
      _tighten_held_long ~buffer_pct ~get_price ~prior_stages ~current_date
        ~risk_params pos
  | _ -> None

let _fold_position ~buffer_pct ~get_price ~prior_stages ~current_date acc pos =
  match
    _process_position ~buffer_pct ~get_price ~prior_stages ~current_date pos
  with
  | Some t -> t :: acc
  | None -> acc

let update ~buffer_pct ~is_screening_day ~positions ~get_price ~prior_stages
    ~current_date =
  if not is_screening_day then []
  else
    Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
        _fold_position ~buffer_pct ~get_price ~prior_stages ~current_date acc
          pos)
