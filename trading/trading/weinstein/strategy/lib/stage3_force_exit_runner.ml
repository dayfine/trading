open Core
open Trading_strategy

(** Build the [TriggerExit] transition for a Stage-3 force exit. The exit fires
    at the close of the current bar — same convention as a stop hit that fills
    at the bar's worst-case price (book §5.2 reads: "stop is hit → sell, no
    questions asked"). For a discretionary force exit at the close,
    [bar.close_price] is the most defensible fill marker.

    The emitted [exit_reason] uses the generic
    {!Position.exit_reason.StrategySignal} variant with
    [label = "stage3_force_exit"] — this label is the value surfaced in the
    [exit_trigger] column of [trades.csv]. *)
let _make_exit_transition ~(pos : Position.t) ~current_date ~bar
    ~weeks_in_stage3 =
  let exit_price = bar.Types.Daily_price.close_price in
  let exit_reason =
    Position.StrategySignal
      {
        label = "stage3_force_exit";
        detail = Some (Printf.sprintf "weeks_in_stage3=%d" weeks_in_stage3);
      }
  in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind = Position.TriggerExit { exit_reason; exit_price };
  }

(** Process one position. Returns [Some transition] when the detector fires AND
    the position is not already exiting via a stop hit this tick. The detector's
    streak counter is always mutated (in [stage3_streaks]) — even on a skipped
    emit — so the count remains accurate against the underlying stage stream. *)
let _process_position ~config ~stage3_streaks ~prior_stages
    ~stop_exit_position_ids ~get_price ~current_date (pos : Position.t) =
  match (pos.side, Position.get_state pos) with
  | Trading_base.Types.Long, Position.Holding _ -> (
      match Hashtbl.find prior_stages pos.symbol with
      | None -> None
      | Some current_stage -> (
          let decision =
            Stage3_force_exit.observe_position ~config ~state:stage3_streaks
              ~symbol:pos.symbol ~current_stage
          in
          match decision with
          | Stage3_force_exit.Hold -> None
          | Stage3_force_exit.Force_exit { weeks_in_stage3 } ->
              if Set.mem stop_exit_position_ids pos.id then None
              else
                Option.map (get_price pos.symbol) ~f:(fun bar ->
                    _make_exit_transition ~pos ~current_date ~bar
                      ~weeks_in_stage3)))
  | _ -> None

let update ~config ~is_screening_day ~positions ~get_price ~prior_stages
    ~stage3_streaks ~stop_exit_position_ids ~current_date =
  if not is_screening_day then []
  else
    Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
        match
          _process_position ~config ~stage3_streaks ~prior_stages
            ~stop_exit_position_ids ~get_price ~current_date pos
        with
        | Some t -> t :: acc
        | None -> acc)
