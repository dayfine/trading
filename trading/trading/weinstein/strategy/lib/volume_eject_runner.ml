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

(** Decide the eject for one freshly-filled holding. Reads the completed weekly
    bar containing [entry_date]; the caller has already established that this is
    a screening tick, so that bar is never partial. Fill weeks older than
    {!_max_fill_week_offset} are outside the evaluation window. *)
let _eject_for_holding ~(config : Weinstein_strategy_config.config)
    ~volume_config ~bar_reader ~get_price ~entry_date ~current_date
    (pos : Position.t) =
  let weekly =
    Bar_reader.weekly_bars_for bar_reader ~symbol:pos.symbol
      ~n:config.lookback_bars ~as_of:current_date
  in
  match _fill_week_offset ~weekly ~entry_date with
  | Some fill_week_offset when fill_week_offset <= _max_fill_week_offset ->
      _eject_of_verdict ~volume_config ~weekly ~fill_week_offset ~get_price
        ~current_date pos
  | _ -> None

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
