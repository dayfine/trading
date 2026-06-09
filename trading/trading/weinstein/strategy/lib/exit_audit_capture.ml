(** Exit-side trade-audit capture. See [exit_audit_capture.mli]. *)

open Core
open Trading_strategy

(** Snapshot the macro state (trend + confidence) at exit time. Reads from
    [prior_macro_result] — the cached output of the most recent
    {!Macro.analyze_with_callbacks} run inside [Weinstein_strategy._run_screen].
    Falls back to [(Neutral, 0.0)] before the first Friday or when AD-breadth
    and ETF data were both skipped (in which case [_run_screen] never fired). *)
let _macro_snapshot_at_exit (prior : Macro.result option) =
  match prior with
  | Some r -> (r.trend, r.confidence)
  | None -> (Weinstein_types.Neutral, 0.0)

(** Run the stage classifier using [callbacks] and return [(close - ma) / ma].
    Returns [0.0] when the MA value is zero (warmup or missing bars). *)
let _pct_distance_from_callbacks ~(callbacks : Stage.callbacks) ~stage_config
    ~prior_stage =
  let result =
    Stage.classify_with_callbacks ~config:stage_config ~get_ma:callbacks.get_ma
      ~get_close:callbacks.get_close ~prior_stage
  in
  if Float.equal result.ma_value 0.0 then 0.0
  else
    let close =
      Option.value (callbacks.get_close ~week_offset:0) ~default:0.0
    in
    (close -. result.ma_value) /. result.ma_value

(** Compute [(close - ma) / ma] for [symbol] at [as_of] via the same panel-
    backed weekly view the stops loop reads. Returns [0.0] when the MA is
    unavailable (warmup, missing bars). *)
let _distance_from_ma_pct ?ma_cache ~stage_config ~lookback_bars ~bar_reader
    ~prior_stages ~symbol ~as_of () =
  let weekly =
    Bar_reader.weekly_view_for bar_reader ~symbol ~n:lookback_bars ~as_of
  in
  if weekly.n < stage_config.Stage.ma_period then 0.0
  else
    let prior_stage = Hashtbl.find prior_stages symbol in
    let callbacks =
      Panel_callbacks.stage_callbacks_of_weekly_view ?ma_cache ~symbol
        ~config:stage_config ~weekly ()
    in
    _pct_distance_from_callbacks ~callbacks ~stage_config ~prior_stage

(** Entry [(price, date)] for an open/closing position. [None] for [Entering]
    (not yet filled) — no hold window to measure excursions over. *)
let _entry_info (pos : Position.t) =
  match pos.state with
  | Position.Holding h -> Some (h.entry_price, h.entry_date)
  | Position.Exiting e -> Some (e.entry_price, e.entry_date)
  | Position.Closed c -> Some (c.entry_price, c.entry_date)
  | Position.Entering _ -> None

(** Number of weekly bars to request to span a hold of [entry_date..exit_date],
    with slack for the partial entry/exit weeks. *)
let _hold_weeks ~entry_date ~exit_date =
  Int.max 1 ((Date.diff exit_date entry_date / 7) + 5)

let _in_window ~entry_date ~exit_date (b : Types.Daily_price.t) =
  Date.( >= ) b.date entry_date && Date.( <= ) b.date exit_date

(** [(max weekly high, min weekly low)] over the hold window, or [None] when no
    weekly bar falls inside [[entry_date, exit_date]]. *)
let _hold_high_low ~bar_reader ~symbol ~entry_date ~exit_date =
  let n = _hold_weeks ~entry_date ~exit_date in
  let hold =
    Bar_reader.weekly_bars_for bar_reader ~symbol ~n ~as_of:exit_date
    |> List.filter ~f:(_in_window ~entry_date ~exit_date)
  in
  match hold with
  | [] -> None
  | _ ->
      let highs =
        List.map hold ~f:(fun (b : Types.Daily_price.t) -> b.high_price)
      in
      let lows =
        List.map hold ~f:(fun (b : Types.Daily_price.t) -> b.low_price)
      in
      Some
        (List.reduce_exn highs ~f:Float.max, List.reduce_exn lows ~f:Float.min)

(** Max favourable / adverse excursion over the hold window
    [[entry_date, exit_date]], as a fraction of entry price. Favourable is in
    the trade's direction (high for long, low for short); adverse is against it
    (typically negative). Returns [(0.0, 0.0)] when entry price is non-positive
    or no bars cover the window.

    Uses {b weekly} bars (the strategy's native granularity): weekly highs/lows
    are the week's true intra-week extremes, and [weekly_bars_for ~n] reaches
    back a controlled [n] weeks regardless of the daily reader's bounded
    resident window — [daily_bars_for] only returns a recent fixed-width window,
    which truncated long holds to a few bars near the exit. *)
let _excursions ~bar_reader ~symbol ~(side : Position.position_side)
    ~entry_price ~entry_date ~exit_date =
  if Float.( <= ) entry_price 0.0 then (0.0, 0.0)
  else
    match _hold_high_low ~bar_reader ~symbol ~entry_date ~exit_date with
    | None -> (0.0, 0.0)
    | Some (max_high, min_low) -> (
        let pct from = (from -. entry_price) /. entry_price in
        match side with
        | Trading_base.Types.Long -> (pct max_high, pct min_low)
        (* Short: favourable is a drop, adverse a rise — mirror around entry. *)
        | Trading_base.Types.Short -> (-.pct min_low, -.pct max_high))

(** Construct the [exit_event] record from the position and computed fields. *)
let _make_exit_event ~(trans : Position.transition) ~(pos : Position.t)
    ~exit_reason ~exit_price ~macro_trend ~macro_confidence ~stage_at_exit
    ~distance_from_ma_pct ~max_favorable_excursion_pct
    ~max_adverse_excursion_pct : Audit_recorder.exit_event =
  {
    position_id = trans.position_id;
    symbol = pos.symbol;
    exit_date = trans.date;
    exit_price;
    exit_reason;
    macro_trend_at_exit = macro_trend;
    macro_confidence_at_exit = macro_confidence;
    stage_at_exit;
    rs_trend_at_exit = None;
    distance_from_ma_pct;
    max_favorable_excursion_pct;
    max_adverse_excursion_pct;
  }

(** [(MFE, MAE)] for [pos]'s hold ending at [exit_date]; [(0.0, 0.0)] when the
    position has no fill yet. *)
let _pos_excursions ~bar_reader ~(pos : Position.t) ~exit_date =
  match _entry_info pos with
  | None -> (0.0, 0.0)
  | Some (entry_price, entry_date) ->
      _excursions ~bar_reader ~symbol:pos.symbol ~side:pos.side ~entry_price
        ~entry_date ~exit_date

(** Look up [pos] in [positions] for a [TriggerExit] transition and, if found,
    compute exit-time state and record the audit event. *)
let _handle_trigger_exit ~audit_recorder ~prior_macro_result ~stage_config
    ~lookback_bars ~bar_reader ~prior_stages ~positions
    ~(trans : Position.transition) ~exit_reason ~exit_price =
  let ma_cache = Bar_reader.ma_cache bar_reader in
  let _dist ~symbol ~as_of =
    _distance_from_ma_pct ?ma_cache ~stage_config ~lookback_bars ~bar_reader
      ~prior_stages ~symbol ~as_of ()
  in
  match Map.find positions trans.position_id with
  | None -> ()
  | Some (pos : Position.t) ->
      let macro_trend, macro_confidence =
        _macro_snapshot_at_exit !prior_macro_result
      in
      let stage_at_exit =
        Hashtbl.find prior_stages pos.symbol
        |> Option.value ~default:(Weinstein_types.Stage1 { weeks_in_base = 0 })
      in
      let distance_from_ma_pct = _dist ~symbol:pos.symbol ~as_of:trans.date in
      let max_favorable_excursion_pct, max_adverse_excursion_pct =
        _pos_excursions ~bar_reader ~pos ~exit_date:trans.date
      in
      let event =
        _make_exit_event ~trans ~pos ~exit_reason ~exit_price ~macro_trend
          ~macro_confidence ~stage_at_exit ~distance_from_ma_pct
          ~max_favorable_excursion_pct ~max_adverse_excursion_pct
      in
      audit_recorder.Audit_recorder.record_exit event

let emit_exit_audit ~(audit_recorder : Audit_recorder.t) ~prior_macro_result
    ~stage_config ~lookback_bars ~bar_reader ~prior_stages ~positions
    (trans : Position.transition) =
  match trans.kind with
  | Position.TriggerExit { exit_reason; exit_price } ->
      _handle_trigger_exit ~audit_recorder ~prior_macro_result ~stage_config
        ~lookback_bars ~bar_reader ~prior_stages ~positions ~trans ~exit_reason
        ~exit_price
  | _ -> ()
