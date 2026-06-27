open Core
open Trading_strategy

(** Build the [TriggerExit] transition for a liquidity-degradation exit. Same
    fill convention as {!Stage3_force_exit_runner._make_exit_transition} and
    {!Laggard_rotation_runner._make_exit_transition}: the exit fires at the
    close of the current bar (discretionary exit at the close).

    The emitted [exit_reason] uses the generic
    {!Position.exit_reason.StrategySignal} variant with
    [label = "liquidity_exit"] — this label surfaces in the [exit_trigger]
    column of [trades.csv]; [detail] carries the measured dollar-ADV for
    forensics. *)
let _make_exit_transition ~(pos : Position.t) ~current_date ~bar ~dollar_adv =
  let exit_price = bar.Types.Daily_price.close_price in
  let exit_reason =
    Position.StrategySignal
      {
        label = "liquidity_exit";
        detail = Some (Printf.sprintf "dollar_adv=%.1f" dollar_adv);
      }
  in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind = Position.TriggerExit { exit_reason; exit_price };
  }

(** Emit the exit transition when [get_price] has a bar, honouring the skip
    list. Returns [None] when the position is already exiting this tick or the
    bar is missing. *)
let _emit_exit_transition ~pos ~current_date ~get_price ~skip_position_ids
    ~dollar_adv =
  if Set.mem skip_position_ids pos.Position.id then None
  else
    Option.map (get_price pos.symbol) ~f:(fun bar ->
        _make_exit_transition ~pos ~current_date ~bar ~dollar_adv)

(** Decide whether a held position has degraded below the hold threshold and, if
    so, emit its exit. Returns [None] when the dollar-ADV reading is absent (no
    liquidity signal — never force a spurious exit) or still at/above the
    threshold. *)
let _exit_for_holding ~config ~bar_reader ~skip_position_ids ~get_price
    ~current_date (pos : Position.t) =
  let bars =
    Bar_reader.daily_bars_for bar_reader ~symbol:pos.symbol ~as_of:current_date
  in
  match
    Liquidity_metric.dollar_adv
      ~lookback_days:config.Liquidity_config.adv_lookback_days bars
  with
  | None -> None
  | Some dollar_adv ->
      if Float.( < ) dollar_adv config.Liquidity_config.min_hold_dollar_adv then
        _emit_exit_transition ~pos ~current_date ~get_price ~skip_position_ids
          ~dollar_adv
      else None

(** Process one position. Held positions on either side are eligible — an
    illiquid name is untradeable regardless of direction. *)
let _process_position ~config ~bar_reader ~skip_position_ids ~get_price
    ~current_date (pos : Position.t) =
  match Position.get_state pos with
  | Position.Holding _ ->
      _exit_for_holding ~config ~bar_reader ~skip_position_ids ~get_price
        ~current_date pos
  | _ -> None

let _fold_position ~config ~bar_reader ~skip_position_ids ~get_price
    ~current_date acc pos =
  match
    _process_position ~config ~bar_reader ~skip_position_ids ~get_price
      ~current_date pos
  with
  | Some t -> t :: acc
  | None -> acc

let update ~config ~is_screening_day ~positions ~bar_reader ~get_price
    ~skip_position_ids ~current_date =
  if Float.( <= ) config.Liquidity_config.min_hold_dollar_adv 0.0 then []
  else if not is_screening_day then []
  else if Map.is_empty positions then []
  else
    Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
        _fold_position ~config ~bar_reader ~skip_position_ids ~get_price
          ~current_date acc pos)
