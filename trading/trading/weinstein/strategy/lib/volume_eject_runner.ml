open Core
open Trading_strategy

let eject_label = "volume_eject"

(* Offset (in weekly bars, 0 = newest) up to which a fill week is still
   evaluated. Offset 0 is the fill week's own closing tick — the normal case
   under the next-open fill model, where the ticket fills early in the week and
   the week closes on the following screening tick. Offset 1 covers a fill that
   landed ON a screening day, whose week had therefore already closed when the
   position first appeared. Beyond that the ticket is no longer fresh: the
   verdict is a pure function of a fixed historical bar, so anything
   unconfirmed has already been ejected. *)
let _max_fill_week_offset = 1

(** Build the [TriggerExit] for a failed at-fill volume confirmation. Same fill
    convention as the sibling special-exit runners
    ({!Liquidity_exit_runner._make_exit_transition} et al.): the exit fires at
    the close of the current (screening) bar, so it executes on the next
    session. [detail] records which weekly bar was judged. *)
let _make_exit_transition ~(pos : Position.t) ~current_date ~bar
    ~fill_week_offset =
  let exit_reason =
    Position.StrategySignal
      {
        label = eject_label;
        detail = Some (Printf.sprintf "fill_week_offset=%d" fill_week_offset);
      }
  in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind =
      Position.TriggerExit
        { exit_reason; exit_price = bar.Types.Daily_price.close_price };
  }

(** Offset (0 = newest) of the weekly bar whose bucket contains [entry_date].
    Weekly bar dates are the last trading day of each bucket, so the containing
    bucket is the first one (chronologically) whose date is on or after
    [entry_date]. [None] when [weekly] is empty or [entry_date] falls outside
    the window. *)
let _fill_week_offset ~(weekly : Types.Daily_price.t list) ~entry_date :
    int option =
  let n = List.length weekly in
  List.findi weekly ~f:(fun _ (b : Types.Daily_price.t) ->
      Date.(b.date >= entry_date))
  |> Option.map ~f:(fun (idx, _) -> n - 1 - idx)

(** The §4.2 verdict for the fill week: [Some false] = confirmed by neither
    branch (eject), [Some true] = confirmed, [None] = not enough history to
    judge (hold — absence of evidence is not an unconfirmed breakout). *)
let _fill_week_verdict ~volume_config ~weekly ~event_offset : bool option =
  Volume.confirms_breakout ~config:volume_config
    ~callbacks:(Volume.callbacks_from_bars ~bars:weekly)
    ~event_offset

(** Turn a failed verdict into the eject transition. [None] when [get_price] has
    no bar for the symbol this tick — there is nothing to price the exit at. *)
let _eject_transition ~get_price ~current_date ~fill_week_offset
    (pos : Position.t) =
  Option.map (get_price pos.symbol) ~f:(fun bar ->
      _make_exit_transition ~pos ~current_date ~bar ~fill_week_offset)

(** Only an explicit [Some false] — the fill week was evaluated and confirmed by
    neither §4.2 branch — ejects. [Some true] holds; [None] (no verdict) holds
    too, fail-soft. *)
let _eject_of_verdict ~volume_config ~weekly ~fill_week_offset ~get_price
    ~current_date pos =
  match
    _fill_week_verdict ~volume_config ~weekly ~event_offset:fill_week_offset
  with
  | None | Some true -> None
  | Some false ->
      _eject_transition ~get_price ~current_date ~fill_week_offset pos

(** The completed weekly bars for [pos] plus the offset of the bar containing
    its fill, when that fill week is still inside the evaluation window. [None]
    otherwise — the single place the window rule is applied, shared by the eject
    path and the audit-verdict path so they can never judge different bars. *)
let _fill_week_window ~(config : Weinstein_strategy_config.config) ~bar_reader
    ~entry_date ~current_date (pos : Position.t) =
  let weekly =
    Bar_reader.weekly_bars_for bar_reader ~symbol:pos.symbol
      ~n:config.lookback_bars ~as_of:current_date
  in
  match _fill_week_offset ~weekly ~entry_date with
  | Some fill_week_offset when fill_week_offset <= _max_fill_week_offset ->
      Some (weekly, fill_week_offset)
  | _ -> None

(** Decide the eject for one freshly-filled holding. Reads the completed weekly
    bar containing [entry_date]; the caller has already established that this is
    a screening tick, so that bar is never partial. Fill weeks older than
    {!_max_fill_week_offset} are outside the evaluation window. *)
let _eject_for_holding ~config ~volume_config ~bar_reader ~get_price ~entry_date
    ~current_date (pos : Position.t) =
  match _fill_week_window ~config ~bar_reader ~entry_date ~current_date pos with
  | Some (weekly, fill_week_offset) ->
      _eject_of_verdict ~volume_config ~weekly ~fill_week_offset ~get_price
        ~current_date pos
  | None -> None

(** Process one position. LONG holdings only — F5 is a property of the long-side
    E-anchored breakout ticket — and never one already exiting via another
    channel this tick. *)
let _process_position ~config ~volume_config ~bar_reader ~get_price
    ~skip_position_ids ~current_date (pos : Position.t) =
  if Set.mem skip_position_ids pos.Position.id then None
  else
    match (pos.Position.side, Position.get_state pos) with
    | Position.Long, Position.Holding { entry_date; _ } ->
        _eject_for_holding ~config ~volume_config ~bar_reader ~get_price
          ~entry_date ~current_date pos
    | _ -> None

let _fold_position ~config ~volume_config ~bar_reader ~get_price
    ~skip_position_ids ~current_date acc pos =
  match
    _process_position ~config ~volume_config ~bar_reader ~get_price
      ~skip_position_ids ~current_date pos
  with
  | Some t -> t :: acc
  | None -> acc

let update ~(config : Weinstein_strategy_config.config) ~volume_config
    ~is_screening_day ~positions ~bar_reader ~get_price ~skip_position_ids
    ~current_date =
  if not (Weinstein_strategy_config.volume_confirm_at_fill_armed config) then []
  else if not is_screening_day then []
  else if Map.is_empty positions then []
  else
    Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
        _fold_position ~config ~volume_config ~bar_reader ~get_price
          ~skip_position_ids ~current_date acc pos)

(* ------------------------------------------------------------------ *)
(* Audit surface — the same verdict, named rather than thresholded      *)
(* ------------------------------------------------------------------ *)

(** The §4.2 classification of [weekly]'s bar at [event_offset]. [None] is the
    {b no-verdict} case ([Volume.classify_breakout] found neither branch
    evaluable) and is deliberately preserved as data rather than collapsed. *)
let _classification_at ~volume_config ~weekly ~event_offset =
  Volume.classify_breakout ~config:volume_config
    ~callbacks:(Volume.callbacks_from_bars ~bars:weekly)
    ~event_offset

let _row_of_window ~volume_config ~position_id (weekly, event_offset) =
  (position_id, _classification_at ~volume_config ~weekly ~event_offset)

(** [(position_id, classification)] for one position, or [None] when it is not
    an evaluable freshly-filled LONG holding. *)
let _confirmation_for_position ~config ~volume_config ~bar_reader ~current_date
    (pos : Position.t) =
  match (pos.Position.side, Position.get_state pos) with
  | Position.Long, Position.Holding { entry_date; _ } ->
      _fill_week_window ~config ~bar_reader ~entry_date ~current_date pos
      |> Option.map
           ~f:(_row_of_window ~volume_config ~position_id:pos.Position.id)
  | _ -> None

let _fold_confirmation ~config ~volume_config ~bar_reader ~current_date acc pos
    =
  match
    _confirmation_for_position ~config ~volume_config ~bar_reader ~current_date
      pos
  with
  | Some row -> row :: acc
  | None -> acc

let fill_week_confirmations ~(config : Weinstein_strategy_config.config)
    ~volume_config ~is_screening_day ~positions ~bar_reader ~current_date =
  if not (Weinstein_strategy_config.volume_confirm_at_fill_armed config) then []
  else if not is_screening_day then []
  else
    Map.fold_right positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
        _fold_confirmation ~config ~volume_config ~bar_reader ~current_date acc
          pos)

(** What the eject path actually did with [position_id] this tick, read off the
    two id sets the caller observed — never inferred from the verdict. An
    [Unconfirmed] fill on a position already leaving via another channel is
    [Skipped_other_exit], not [Ejected]. *)
let _outcome_for ~ejected_position_ids ~skip_position_ids position_id :
    Audit_recorder.fill_volume_outcome =
  if Set.mem ejected_position_ids position_id then Ejected
  else if Set.mem skip_position_ids position_id then Skipped_other_exit
  else Held

(* Extracted: an inline record literal inside the [List.iter] closure nests
   past the linter's depth limit. *)
let _event_of ~ejected_position_ids ~skip_position_ids
    (position_id, confirmation) =
  {
    Audit_recorder.position_id;
    confirmation;
    outcome = _outcome_for ~ejected_position_ids ~skip_position_ids position_id;
  }

let emit_fill_week_audit ~config ~(audit_recorder : Audit_recorder.t)
    ~volume_config ~is_screening_day ~positions ~bar_reader ~skip_position_ids
    ~ejected_position_ids ~current_date =
  fill_week_confirmations ~config ~volume_config ~is_screening_day ~positions
    ~bar_reader ~current_date
  |> List.map ~f:(_event_of ~ejected_position_ids ~skip_position_ids)
  |> List.iter ~f:audit_recorder.record_fill_volume
