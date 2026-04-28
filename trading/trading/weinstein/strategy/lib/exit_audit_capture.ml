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
    let result =
      Stage.classify_with_callbacks ~config:stage_config
        ~get_ma:callbacks.get_ma ~get_close:callbacks.get_close ~prior_stage
    in
    if Float.equal result.ma_value 0.0 then 0.0
    else
      let close =
        Option.value (callbacks.get_close ~week_offset:0) ~default:0.0
      in
      (close -. result.ma_value) /. result.ma_value

let emit_exit_audit ~(audit_recorder : Audit_recorder.t) ~prior_macro_result
    ~stage_config ~lookback_bars ~bar_reader ~prior_stages ~positions
    (trans : Position.transition) =
  match trans.kind with
  | Position.TriggerExit { exit_reason; exit_price } -> (
      match Map.find positions trans.position_id with
      | None -> ()
      | Some (pos : Position.t) ->
          let macro_trend, macro_confidence =
            _macro_snapshot_at_exit !prior_macro_result
          in
          let stage_at_exit =
            Hashtbl.find prior_stages pos.symbol
            |> Option.value
                 ~default:(Weinstein_types.Stage1 { weeks_in_base = 0 })
          in
          let ma_cache = Bar_reader.ma_cache bar_reader in
          let distance_from_ma_pct =
            _distance_from_ma_pct ?ma_cache ~stage_config ~lookback_bars
              ~bar_reader ~prior_stages ~symbol:pos.symbol ~as_of:trans.date ()
          in
          let event : Audit_recorder.exit_event =
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
            }
          in
          audit_recorder.record_exit event)
  | _ -> ()
