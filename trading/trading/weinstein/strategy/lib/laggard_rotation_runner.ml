open Core
open Trading_strategy

(** Compute the simple return over the rolling window from a list of weekly
    bars. Expects [List.length bars >= n + 1]; takes the close at index 0
    (oldest) and the close at index n (latest). Returns [None] if the list is
    shorter than [n + 1] or the oldest close is non-positive (avoids
    divide-by-zero on degenerate snapshots). *)
let _window_return ~(n : int) (bars : Types.Daily_price.t list) : float option =
  if List.length bars < n + 1 then None
  else
    let arr = Array.of_list bars in
    let oldest = arr.(0).close_price in
    let latest = arr.(Array.length arr - 1).close_price in
    if Float.( <= ) oldest 0.0 then None else Some ((latest /. oldest) -. 1.0)

(** Build the [TriggerExit] transition for a laggard-rotation exit. Same fill
    convention as {!Stage3_force_exit_runner._make_exit_transition}: the exit
    fires at the close of the current bar (discretionary exit at the close).

    The emitted [exit_reason] uses the generic
    {!Position.exit_reason.StrategySignal} variant with
    [label = "laggard_rotation"] — this label surfaces in the [exit_trigger]
    column of [trades.csv]. *)
let _make_exit_transition ~(pos : Position.t) ~current_date ~bar
    ~rs_13w_neg_weeks =
  let exit_price = bar.Types.Daily_price.close_price in
  let exit_reason =
    Position.StrategySignal
      {
        label = "laggard_rotation";
        detail = Some (Printf.sprintf "rs_13w_neg_weeks=%d" rs_13w_neg_weeks);
      }
  in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind = Position.TriggerExit { exit_reason; exit_price };
  }

(** Convert a [Laggard_exit] decision into a transition, respecting the
    skip-list collision filter and [get_price] availability. Returns [None] when
    the position is on the skip list or the bar is missing. *)
let _emit_exit_transition ~pos ~current_date ~get_price ~skip_position_ids
    ~rs_13w_neg_weeks =
  if Set.mem skip_position_ids pos.Position.id then None
  else
    Option.map (get_price pos.symbol) ~f:(fun bar ->
        _make_exit_transition ~pos ~current_date ~bar ~rs_13w_neg_weeks)

(** Run the detector on a long Holding position whose history covered the RS
    window. Returns [Some transition] only on [Laggard_exit] that survives the
    skip-list and [get_price] gates. *)
let _observe_and_emit ~config ~laggard_streaks ~benchmark_13w_return
    ~skip_position_ids ~get_price ~current_date ~position_13w_return
    (pos : Position.t) =
  let decision =
    Laggard_rotation.observe_position ~config ~state:laggard_streaks
      ~symbol:pos.symbol ~position_13w_return ~benchmark_13w_return
  in
  match decision with
  | Laggard_rotation.Hold -> None
  | Laggard_rotation.Laggard_exit { rs_13w_neg_weeks } ->
      _emit_exit_transition ~pos ~current_date ~get_price ~skip_position_ids
        ~rs_13w_neg_weeks

(** Process one position. Returns [Some transition] when the detector fires AND
    the position is not already exiting via an earlier exit channel (stops,
    force-liq, Stage-3) on this tick. Mutates [laggard_streaks] only when both
    the position and benchmark have enough history for a comparable RS read. *)
let _process_position ~config ~laggard_streaks ~benchmark_13w_return
    ~skip_position_ids ~bar_reader ~get_price ~current_date (pos : Position.t) =
  match (pos.side, Position.get_state pos) with
  | Trading_base.Types.Long, Position.Holding _ -> (
      let n = config.Laggard_rotation.rs_window_weeks in
      let pos_bars =
        Bar_reader.weekly_bars_for bar_reader ~symbol:pos.symbol ~n:(n + 1)
          ~as_of:current_date
      in
      match _window_return ~n pos_bars with
      | None -> None
      | Some position_13w_return ->
          _observe_and_emit ~config ~laggard_streaks ~benchmark_13w_return
            ~skip_position_ids ~get_price ~current_date ~position_13w_return pos
      )
  | _ -> None

let update ~config ~benchmark_symbol ~is_screening_day ~positions ~bar_reader
    ~get_price ~laggard_streaks ~skip_position_ids ~current_date =
  if not is_screening_day then []
  else if Map.is_empty positions then []
  else
    let n = config.Laggard_rotation.rs_window_weeks in
    let benchmark_bars =
      Bar_reader.weekly_bars_for bar_reader ~symbol:benchmark_symbol ~n:(n + 1)
        ~as_of:current_date
    in
    match _window_return ~n benchmark_bars with
    | None ->
        (* Missing benchmark history is a data gap, not a stage-recovery
           signal — leave the streak table untouched and emit nothing. *)
        []
    | Some benchmark_13w_return ->
        Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
            match
              _process_position ~config ~laggard_streaks ~benchmark_13w_return
                ~skip_position_ids ~bar_reader ~get_price ~current_date pos
            with
            | Some t -> t :: acc
            | None -> acc)
