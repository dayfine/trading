(* @large-module: top-level strategy entry point — on_market_close orchestrates
   stops + macro + screener + force-liquidation + stage3-exit + laggard-rotation
   passes through closure-scoped state; closes 2026-05-12 Portfolio_floor
   death-loop fix in _maybe_reset_halt + _run_macro_and_entries *)
open Core
open Trading_strategy
module Bar_reader = Bar_reader
module Spy_only_weinstein_strategy = Spy_only_weinstein_strategy
module Sector_rotation_weinstein_strategy = Sector_rotation_weinstein_strategy
module Breaker_spy_strategy = Breaker_spy_strategy
module Stops_runner = Stops_runner
module Stops_split_runner = Stops_split_runner
module Force_liquidation_runner = Force_liquidation_runner
module Stage3_force_exit_runner = Stage3_force_exit_runner
module Late_stage2_stop_runner = Late_stage2_stop_runner
module Harvest_rotate_runner = Harvest_rotate_runner
module Harvest_rotate_wiring = Harvest_rotate_wiring
module Macro_bearish_trim_runner = Macro_bearish_trim_runner
module Macro_bearish_trim_wiring = Macro_bearish_trim_wiring
module Laggard_rotation_runner = Laggard_rotation_runner
module Special_exits = Special_exits
module Liquidity_config = Liquidity_config
module Scale_in_detector = Scale_in_detector
module Scale_in_runner = Scale_in_runner
module Liquidity_metric = Liquidity_metric
module Liquidity_exit_runner = Liquidity_exit_runner
module Extension_stop_runner = Extension_stop_runner
module Stage3_force_exit = Stage3_force_exit
module Laggard_rotation = Laggard_rotation
module Ad_bars = Ad_bars
module Ad_series_cache = Ad_series_cache
module Macro_inputs = Macro_inputs
module Panel_callbacks = Panel_callbacks
module Resistance_sketch_reader = Resistance_sketch_reader
module Weekly_sidetable_reader = Weekly_sidetable_reader
module Weekly_ma_cache = Weekly_ma_cache
module Audit_recorder = Audit_recorder
module Entry_audit_capture = Entry_audit_capture
module Screening_notional = Screening_notional
module Long_buying_power = Long_buying_power
module Short_borrow_gate = Short_borrow_gate
module Exit_audit_capture = Exit_audit_capture
include Weinstein_strategy_config
module Weinstein_strategy_macro = Weinstein_strategy_macro
module Weinstein_strategy_config = Weinstein_strategy_config
module S = Weinstein_strategy_screening

let held_symbols = Entry_walk.held_symbols
let entries_from_candidates = Entry_walk.entries_from_candidates
let survivors_for_screening = S.survivors_for_screening
let prune_universe_by_active_through = S.prune_universe_by_active_through
let stock_analysis_config_for = S._stock_analysis_config_for

let _positions_minus_exited ~(positions : Position.t Map.M(String).t)
    ~(stop_exit_transitions : Position.transition list) :
    Position.t Map.M(String).t =
  let exited_ids =
    Transition_assembly.trigger_exit_ids_of stop_exit_transitions
  in
  if Set.is_empty exited_ids then positions
  else
    Map.filter positions ~f:(fun (p : Position.t) ->
        not (Set.mem exited_ids p.id))

(* Transition-only reset — see .mli for full contract. *)
let _maybe_reset_halt ~peak_tracker ~prior_macro ~current_macro =
  let open Weinstein_types in
  match (prior_macro, current_macro) with
  | Bearish, (Bullish | Neutral) ->
      Portfolio_risk.Force_liquidation.Peak_tracker.reset peak_tracker
  | _ -> ()

let _symbol_of_position_id ~(positions : Position.t Map.M(String).t) id =
  Map.data positions
  |> List.find ~f:(fun (p : Position.t) -> String.equal p.id id)
  |> Option.map ~f:(fun (p : Position.t) -> p.symbol)

let _handle_stop_out_transition ~last_stop_out_dates ~positions ~current_date
    (t : Position.transition) =
  match t.kind with
  | Position.TriggerExit { exit_reason = Position.StopLoss _; _ } -> (
      match _symbol_of_position_id ~positions t.position_id with
      | Some symbol ->
          Hashtbl.set last_stop_out_dates ~key:symbol ~data:current_date
      | None -> ())
  | _ -> ()

(* Stamp the cooldown table for one position-id, no-op when the position has
   already been pruned. Extracted from [_record_force_exit] so the nested
   match against [_symbol_of_position_id] doesn't push depth past the linter's
   max-5 ceiling. *)

(** Record stage3 / laggard force-exit dates into [last_stop_out_dates] when the
    corresponding reentry cooldown knob is enabled. Re-uses the existing
    [Screener.screen_with_cooldown] gate (which keys on [last_stop_out_dates])
    instead of adding a separate map / cooldown knob. When the per-source
    cooldown knob is [0] (default), this is a no-op — preserves the pre-feature
    goldens bit-equal. Decoupling from the screener-level
    [cascade_post_stop_cooldown_weeks] is the responsibility of a follow-up: the
    screener applies a single window today; widening that to a per-source window
    is out of scope for the continuation-buys PR (issue #889). *)
let _stamp_cooldown ~last_stop_out_dates ~positions ~current_date position_id =
  match _symbol_of_position_id ~positions position_id with
  | Some symbol ->
      Hashtbl.set last_stop_out_dates ~key:symbol ~data:current_date
  | None -> ()

let _record_force_exit ~last_stop_out_dates ~positions ~current_date
    ~cooldown_weeks ~(label : string) (t : Position.transition) =
  if cooldown_weeks <= 0 then ()
  else
    match t.kind with
    | Position.TriggerExit
        { exit_reason = Position.StrategySignal { label = l; _ }; _ }
      when String.equal l label ->
        _stamp_cooldown ~last_stop_out_dates ~positions ~current_date
          t.position_id
    | _ -> ()

let _run_stops_pass ~config ~positions ~stop_states ~bar_reader ~prior_stages
    ~prior_stage_ma_values ~get_price ~last_stop_out_dates ~audit_recorder
    ~prior_macro_result ~prior_decline_character ~current_date =
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:current_date;
  (* Arm the fast-crash absolute stop from the PRIOR cycle's decline-character
     (strictly past — this cycle's classify runs later, at the macro step; a
     plain bool keeps the stops lib macro-agnostic). *)
  let catastrophic_armed =
    phys_equal !prior_decline_character Decline_character.Fast_v
  in
  let exit_transitions, adjust_transitions =
    Stops_runner.update
      ?ma_cache:(Bar_reader.ma_cache bar_reader)
      ~stop_update_cadence:config.stop_update_cadence ~prior_stage_ma_values
      ~catastrophic_armed ~stops_config:config.stops_config
      ~stage_config:config.stage_config ~lookback_bars:config.lookback_bars
      ~positions ~get_price ~stop_states ~bar_reader ~as_of:current_date
      ~prior_stages ()
  in
  List.iter exit_transitions
    ~f:
      (_handle_stop_out_transition ~last_stop_out_dates ~positions ~current_date);
  Exit_audit_capture.emit_for_list ~config ~audit_recorder ~prior_macro_result
    ~bar_reader ~prior_stages ~positions exit_transitions;
  (exit_transitions, adjust_transitions)

(** Run the late-Stage-2 trailing-stop tightening dial (P1 stage-accuracy). On
    Friday ticks, when [config.enable_late_stage2_stop_tighten = true], raise
    the trailing stop of every held [Stage2 { late = true }] long. Returns
    [UpdateRiskParams] adjust transitions (never exits). The flag default-off
    short-circuits to [[]], so the disabled path is bit-identical to baseline.
    See {!Late_stage2_stop_runner}. *)
let _run_late_stage2_tighten ~config ~positions ~get_price ~prior_stages
    ~index_view ~current_date =
  if not config.enable_late_stage2_stop_tighten then []
  else
    let is_friday =
      Weinstein_strategy_screening.is_screening_day_view index_view
    in
    Late_stage2_stop_runner.update
      ~buffer_pct:config.late_stage2_stop_buffer_pct ~is_screening_day:is_friday
      ~positions ~get_price ~prior_stages ~current_date

(** The two weekly held-position dials (both Friday-gated, default-off):
    late-Stage-2 stop-tighten ([UpdateRiskParams]) and harvest-rotate
    ([TriggerPartialExit]). Returns [(late_tighten_ts, harvest_rotate_ts)].
    Extracted so {!_process_market_day} stays within the function-length limit.
*)
let _run_held_position_dials ~config ~positions ~get_price ~prior_stages
    ~index_view ~audit_recorder ~prior_macro_result ~bar_reader ~current_date =
  ( _run_late_stage2_tighten ~config ~positions ~get_price ~prior_stages
      ~index_view ~current_date,
    Harvest_rotate_wiring.run ~config ~positions ~get_price ~prior_stages
      ~index_view ~audit_recorder ~prior_macro_result ~bar_reader ~current_date
  )

(** Compute the macro result for [current_date] (Friday only) and run the
    halt-reset side effect. Returns [None] on non-screening days. Mutates
    [prior_macro] / [prior_macro_result] via {!run_macro_only}. Hoisted out of
    {!_run_macro_and_entries} so the macro trend is available to the
    macro-bearish trim pass (which runs before the entry walk) without computing
    the macro result twice. *)
let _run_macro ~config ~ad_series ~prior_macro ~prior_macro_result ~peak_tracker
    ~bar_reader ~prior_stages ~current_date ~index_view ~is_screening_day =
  if not is_screening_day then None
  else
    let prev = !prior_macro in
    let r =
      Weinstein_strategy_macro.run_macro_only ~config ~ad_series ~prior_macro
        ~prior_macro_result ~bar_reader ~prior_stages ~current_date ~index_view
    in
    _maybe_reset_halt ~peak_tracker ~prior_macro:prev ~current_macro:r.trend;
    Some r

let _run_entries ~fold_start_date ~config ~stop_states ~last_stop_out_dates
    ~peak_tracker ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors
    ~get_price ~portfolio ~current_date ~index_view ~audit_recorder
    ~is_screening_day ~macro_result_opt =
  let halted =
    match
      Portfolio_risk.Force_liquidation.Peak_tracker.halt_state peak_tracker
    with
    | Halted -> true
    | Active -> false
  in
  Weinstein_strategy_macro.entry_transitions_if_active ~fold_start_date ~halted
    ~is_screening_day ~macro_result_opt ~config ~stop_states
    ~last_stop_out_dates ~bar_reader ~prior_stages ~sector_prior_stages
    ~ticker_sectors ~get_price ~portfolio ~current_date ~index_view
    ~audit_recorder

(** Compute the macro result (mutating the macro refs via {!_run_macro}) and run
    the macro-bearish trim pass, returning both. Extracted from
    {!_process_market_day} so that function stays within the length / nesting
    limits; the skip-id union (stop / Stage-3 / laggard / force-liq exits) is
    assembled here. *)
let _run_macro_and_trim ~config ~ad_series ~positions ~portfolio ~prior_macro
    ~prior_macro_result ~prior_decline_character ~peak_tracker ~bar_reader
    ~prior_stages ~get_price ~current_date ~index_view ~is_screening_day
    ~stop_exited_ids ~stage3_exited_ids ~laggard_exited_ids
    ~force_exit_transitions =
  let macro_result_opt =
    _run_macro ~config ~ad_series ~prior_macro ~prior_macro_result ~peak_tracker
      ~bar_reader ~prior_stages ~current_date ~index_view ~is_screening_day
  in
  (* Re-classify the index's decline character (strictly-past read by the next
     tick's stops pass to arm the fast-crash absolute stop — Build 2). *)
  Decline_character_wiring.update_ref
    ~fast_v_arm_on_rate_alone:config.fast_v_arm_on_rate_alone
    ~fast_v_min_rate_pct:config.fast_v_min_rate_pct ~prior_decline_character
    ~macro_result_opt ~index_view;
  let skip_ids =
    Set.union_list
      (module String)
      [
        stop_exited_ids;
        stage3_exited_ids;
        laggard_exited_ids;
        Transition_assembly.trigger_exit_ids_of force_exit_transitions;
      ]
  in
  let macro_trim_transitions =
    Macro_bearish_trim_wiring.run ~config ~positions ~portfolio ~get_price
      ~bar_reader ~current_date ~is_screening_day ~macro_result_opt ~skip_ids
  in
  (macro_result_opt, macro_trim_transitions)

(** Scale-in add pass (default-off). Runs BEFORE the fresh-entry walk; returns
    the add transitions plus the cash they consume so the entry walk sees a
    reduced budget — a revealed-strength add outranks an unproven fresh entry
    for scarce cash (plan §3.3). [([], 0.)] when [enable_scale_in] is off. *)
let _run_scale_in ~config ~positions ~portfolio ~get_price ~bar_reader
    ~prior_stages ~prior_stage_ma_values ~stop_states ~scale_in_added
    ~peak_tracker ~macro_result_opt ~is_screening_day ~current_date =
  let halted =
    match
      Portfolio_risk.Force_liquidation.Peak_tracker.halt_state peak_tracker
    with
    | Halted -> true
    | Active -> false
  in
  Scale_in_runner.run ~config ~positions ~portfolio ~get_price ~bar_reader
    ~prior_stages ~prior_stage_ma_values ~stop_states ~scale_in_added
    ~macro_result_opt ~is_screening_day ~halted ~current_date

(** Run the held-position dials (late-Stage-2 tighten + harvest-rotate), the
    scale-in add pass, and the entry walk. Returns
    [(late_tighten, harvest_rotate, entries)] with the adds prepended to the
    entries. Extracted from {!_process_market_day} so that coordinator stays
    within the function-length limit. *)
let _run_dials_and_entries ~fold_start_date ~config ~stop_states
    ~last_stop_out_dates ~peak_tracker ~bar_reader ~prior_stages
    ~prior_stage_ma_values ~scale_in_added ~sector_prior_stages ~ticker_sectors
    ~get_price ~(portfolio : Portfolio_view.t) ~current_date ~index_view
    ~audit_recorder ~prior_macro_result ~is_screening_day ~macro_result_opt
    ~positions =
  let late_tighten_transitions, harvest_rotate_transitions =
    _run_held_position_dials ~config ~positions ~get_price ~prior_stages
      ~index_view ~audit_recorder ~prior_macro_result ~bar_reader ~current_date
  in
  let scale_in_transitions, scale_in_cash =
    _run_scale_in ~config ~positions ~portfolio ~get_price ~bar_reader
      ~prior_stages ~prior_stage_ma_values ~stop_states ~scale_in_added
      ~peak_tracker ~macro_result_opt ~is_screening_day ~current_date
  in
  let entry_portfolio =
    { portfolio with Portfolio_view.cash = portfolio.cash -. scale_in_cash }
  in
  let entry_transitions =
    _run_entries ~fold_start_date ~config ~stop_states ~last_stop_out_dates
      ~peak_tracker ~bar_reader ~prior_stages ~sector_prior_stages
      ~ticker_sectors ~get_price ~portfolio:entry_portfolio ~current_date
      ~index_view ~audit_recorder ~is_screening_day ~macro_result_opt
  in
  ( late_tighten_transitions,
    harvest_rotate_transitions,
    scale_in_transitions @ entry_transitions )

let _process_market_day ~fold_start_date ~config ~ad_series ~stop_states
    ~last_stop_out_dates ~prior_macro ~prior_macro_result
    ~prior_decline_character ~peak_tracker ~bar_reader ~prior_stages
    ~prior_stage_ma_values ~scale_in_added ~sector_prior_stages ~ticker_sectors
    ~stage3_streaks ~laggard_streaks ~audit_recorder ~get_price
    ~(portfolio : Portfolio_view.t) ~current_date =
  let positions = portfolio.positions in
  let exit_transitions, adjust_transitions =
    _run_stops_pass ~config ~positions ~stop_states ~bar_reader ~prior_stages
      ~prior_stage_ma_values ~get_price ~last_stop_out_dates ~audit_recorder
      ~prior_macro_result ~prior_decline_character ~current_date
  in
  let index_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:config.indices.primary
      ~n:config.lookback_bars ~as_of:current_date
  in
  let ( force_exit_transitions,
        stage3_force_exit_transitions,
        laggard_rotation_transitions,
        stop_exited_ids,
        stage3_exited_ids,
        laggard_exited_ids ) =
    Special_exits.run ~config ~record_force_exit:_record_force_exit ~positions
      ~last_stop_out_dates ~portfolio ~get_price ~peak_tracker ~audit_recorder
      ~prior_macro_result ~prior_stages ~prior_stage_ma_values ~stage3_streaks
      ~laggard_streaks ~bar_reader ~index_view ~exit_transitions ~current_date
  in
  let is_screening_day =
    Weinstein_strategy_screening.is_screening_day_view index_view
  in
  let macro_result_opt, macro_trim_transitions =
    _run_macro_and_trim ~config ~ad_series ~positions ~portfolio ~prior_macro
      ~prior_macro_result ~prior_decline_character ~peak_tracker ~bar_reader
      ~prior_stages ~get_price ~current_date ~index_view ~is_screening_day
      ~stop_exited_ids ~stage3_exited_ids ~laggard_exited_ids
      ~force_exit_transitions
  in
  let late_tighten_transitions, harvest_rotate_transitions, entry_transitions =
    _run_dials_and_entries ~fold_start_date ~config ~stop_states
      ~last_stop_out_dates ~peak_tracker ~bar_reader ~prior_stages
      ~prior_stage_ma_values ~scale_in_added ~sector_prior_stages
      ~ticker_sectors ~get_price ~portfolio ~current_date ~index_view
      ~audit_recorder ~prior_macro_result ~is_screening_day ~macro_result_opt
      ~positions
  in
  Transition_assembly.assemble_output ~exit_transitions
    ~stage3_force_exit_transitions ~laggard_rotation_transitions
    ~force_exit_transitions ~macro_trim_transitions ~harvest_rotate_transitions
    ~adjust_transitions:(adjust_transitions @ late_tighten_transitions)
    ~entry_transitions ~stop_exited_ids ~stage3_exited_ids ~laggard_exited_ids

let _on_market_close ~fold_start_date ~config ~ad_series ~stop_states
    ~last_stop_out_dates ~prior_macro ~prior_macro_result
    ~prior_decline_character ~peak_tracker ~bar_reader ~prior_stages
    ~prior_stage_ma_values ~scale_in_added ~sector_prior_stages ~ticker_sectors
    ~stage3_streaks ~laggard_streaks ~audit_recorder ~get_price ~get_indicator:_
    ~(portfolio : Portfolio_view.t) =
  match get_price config.indices.primary with
  | None -> Ok { Strategy_interface.transitions = [] }
  | Some primary_bar ->
      let current_date = primary_bar.Types.Daily_price.date in
      _process_market_day ~fold_start_date ~config ~ad_series ~stop_states
        ~last_stop_out_dates ~prior_macro ~prior_macro_result
        ~prior_decline_character ~peak_tracker ~bar_reader ~prior_stages
        ~prior_stage_ma_values ~scale_in_added ~sector_prior_stages
        ~ticker_sectors ~stage3_streaks ~laggard_streaks ~audit_recorder
        ~get_price ~portfolio ~current_date

let make ?(initial_stop_states = String.Map.empty) ?(ad_bars = [])
    ?(ticker_sectors = Hashtbl.create (module String)) ?bar_reader
    ?(audit_recorder = Audit_recorder.noop) ?fold_start_date config =
  let bar_reader =
    match bar_reader with Some r -> r | None -> Bar_reader.empty ()
  in
  let ( stop_states,
        last_stop_out_dates,
        prior_macro,
        peak_tracker,
        prior_macro_result,
        prior_decline_character,
        prior_stages,
        prior_stage_ma_values,
        sector_prior_stages,
        stage3_streaks,
        laggard_streaks,
        weekly_ad_bars ) =
    Weinstein_strategy_state.init ~initial_stop_states ~ad_bars
  in
  (* Precompute the A-D cumulative + momentum series ONCE; the weekly A-D bars
     are fixed for the whole run, so per-tick macro work reads from this cache
     in O(log n) instead of re-folding the full list every Friday. *)
  let ad_series =
    Ad_series_cache.of_weekly_ad_bars
      ~momentum_period:config.macro_config.indicator_thresholds.momentum_period
      weekly_ad_bars
  in
  (* Scale-in add bookkeeping (symbol -> adds emitted). Closure state like
     [laggard_streaks]; not persisted (backtests are single-process; the live
     weekly generator is a one-shot). *)
  let scale_in_added : int Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let module M = struct
    let name = name

    let on_market_close =
      _on_market_close ~fold_start_date ~config ~ad_series ~stop_states
        ~last_stop_out_dates ~prior_macro ~prior_macro_result
        ~prior_decline_character ~peak_tracker ~bar_reader ~prior_stages
        ~prior_stage_ma_values ~scale_in_added ~sector_prior_stages
        ~ticker_sectors ~stage3_streaks ~laggard_streaks ~audit_recorder
  end in
  (module M : Strategy_interface.STRATEGY)

module Internal_for_test = struct
  (* Tests pass the weekly A-D bar list directly; build the per-run cache from
     it here so the test seam keeps its [~ad_bars] signature while the strategy
     hot path consumes the precomputed [Ad_series_cache.t]. *)
  let on_market_close ~fold_start_date ~config ~ad_bars =
    let ad_series =
      Ad_series_cache.of_weekly_ad_bars
        ~momentum_period:
          config.macro_config.indicator_thresholds.momentum_period ad_bars
    in
    let scale_in_added : int Hashtbl.M(String).t =
      Hashtbl.create (module String)
    in
    _on_market_close ~fold_start_date ~config ~ad_series ~scale_in_added

  let maybe_reset_halt = _maybe_reset_halt
  let positions_minus_exited = _positions_minus_exited
  let record_force_exit = _record_force_exit
end
