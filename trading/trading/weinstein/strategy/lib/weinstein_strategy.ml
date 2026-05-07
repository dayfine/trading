(* @large-module: strategy composition point — wires screener, macro, stops,
   bar panels, and portfolio into one cohesive weekly cadence; splitting any
   of these concerns into a sibling module would create artificial boundaries
   between tightly coupled wiring logic. *)
open Core
open Trading_strategy
module Bar_reader = Bar_reader
module Stops_runner = Stops_runner
module Stops_split_runner = Stops_split_runner
module Force_liquidation_runner = Force_liquidation_runner
module Stage3_force_exit_runner = Stage3_force_exit_runner
module Laggard_rotation_runner = Laggard_rotation_runner

module Stage3_force_exit = Stage3_force_exit
(** Pure Stage-3 force-exit detector (issue #872). See [stage3_force_exit.mli]
    for the contract. *)

module Laggard_rotation = Laggard_rotation
(** Pure laggard-rotation detector (issue #887). See [laggard_rotation.mli] for
    the contract. *)

module Ad_bars = Ad_bars
(** NYSE advance/decline breadth data loader. Exposed as a top-level submodule
    so tests and external callers (e.g. live-mode boot) can load NYSE breadth
    data before wiring it into the strategy. *)

module Macro_inputs = Macro_inputs
(** Sector map + global index assembly from accumulated bar history. Exposes
    [spdr_sector_etfs] and [default_global_indices] as canonical constants for
    callers to use in {!config}. *)

module Panel_callbacks = Panel_callbacks
(** Panel-shaped callback-bundle constructors for the strategy's callees. Stage
    4 PR-A. *)

module Weekly_ma_cache = Weekly_ma_cache
(** Per-symbol weekly MA cache (Stage 4 PR-D). Memoises Stage / Macro / Sector /
    Stops MA reads keyed by [(symbol, ma_type, period)]. *)

module Audit_recorder = Audit_recorder
(** Decision-trail recorder. See [audit_recorder.mli]. *)

module Entry_audit_capture = Entry_audit_capture
(** Per-candidate entry construction + audit emission. *)

module Exit_audit_capture = Exit_audit_capture
(** Exit-side trade-audit capture. *)

type index_config = { primary : string; global : (string * string) list }
[@@deriving sexp]

type config = {
  universe : string list;
  indices : index_config;
  sector_etfs : (string * string) list;
  stage_config : Stage.config;
  macro_config : Macro.config;
  screening_config : Screener.config;
  portfolio_config : Portfolio_risk.config;
  stops_config : Weinstein_stops.config;
  initial_stop_buffer : float;
  lookback_bars : int;
  bar_history_max_lookback_days : int option;
  skip_ad_breadth : bool;
  skip_sector_etf_load : bool;
  universe_cap : int option;
  full_compute_tail_days : int option;
  enable_short_side : bool; [@sexp.default true]
  stop_update_cadence : Stops_runner.stop_update_cadence;
      [@sexp.default Stops_runner.Daily]
      (** Cadence for trailing-stop trail advancement (G11). [Daily] (the
          default) preserves all existing baselines: the trail can tighten on
          every daily bar. [Weekly] only advances the state machine on Friday
          ticks, matching Weinstein Ch. 6 §Stop-Loss Rules ("trail moves only on
          weekly close"). Trigger logic stays continuous in both modes. *)
  stage3_force_exit_config : Stage3_force_exit.config;
      [@sexp.default Stage3_force_exit.default_config]
      (** Stage-3 force-exit detector parameters (issue #872). Default
          [{ hysteresis_weeks = 2 }] — fires on the second consecutive Friday
          Stage-3 classification of a held long position. *)
  enable_stage3_force_exit : bool; [@sexp.default false]
      (** Master switch for the Stage-3 force-exit runner. Default [false]
          preserves all existing baselines: the runner is a no-op and the
          strategy emits no [StrategySignal "stage3_force_exit"] transitions.
          Flipping to [true] activates {!Stage3_force_exit_runner.update} on
          every Friday tick. *)
  stage3_reentry_cooldown_weeks : int; [@sexp.default 0]
      (** Reserved for future tuning — currently unwired (default [0] = no
          cooldown applied). Once wired, would suppress cascade re-admission of
          a symbol force-exited under Stage 3 for [N] weeks beyond the existing
          stop-out cooldown surface (#718). [0] is the book-aligned default
          (§5.2 "STATE: EXITED — IF whipsaw … acceptable to re-buy"). The knob
          exists on [config] so future tuning can flip it via sexp override
          without a code change. *)
  laggard_rotation_config : Laggard_rotation.config;
      [@sexp.default Laggard_rotation.default_config]
      (** Laggard-rotation detector parameters (issue #887). Default
          [{ hysteresis_weeks = 4; rs_window_weeks = 13 }] — fires on the fourth
          consecutive Friday observation of negative
          relative-strength-vs-benchmark over a rolling 13-week window. *)
  enable_laggard_rotation : bool; [@sexp.default false]
      (** Master switch for the laggard-rotation runner (issue #887). Default
          [false] preserves all existing baselines: the runner is a no-op and
          the strategy emits no [StrategySignal "laggard_rotation"] transitions.
      *)
  laggard_reentry_cooldown_weeks : int; [@sexp.default 0]
      (** Reserved for future tuning — currently unwired (default [0] = no
          cooldown applied beyond the existing stop-out cooldown surface #718).
          The knob exists on [config] so future tuning can flip it via sexp
          override without a code change. *)
}
[@@deriving sexp]

let default_config ~universe ~index_symbol =
  {
    universe;
    indices = { primary = index_symbol; global = [] };
    sector_etfs = [];
    stage_config = Stage.default_config;
    macro_config = Macro.default_config;
    screening_config = Screener.default_config;
    portfolio_config = Portfolio_risk.default_config;
    stops_config = Weinstein_stops.default_config;
    initial_stop_buffer = 1.02;
    lookback_bars = 52;
    bar_history_max_lookback_days = None;
    skip_ad_breadth = false;
    skip_sector_etf_load = false;
    universe_cap = None;
    full_compute_tail_days = None;
    enable_short_side = true;
    stop_update_cadence = Stops_runner.Daily;
    stage3_force_exit_config = Stage3_force_exit.default_config;
    enable_stage3_force_exit = false;
    stage3_reentry_cooldown_weeks = 0;
    laggard_rotation_config = Laggard_rotation.default_config;
    enable_laggard_rotation = false;
    laggard_reentry_cooldown_weeks = 0;
  }

let name = "Weinstein"

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

(** Collect ticker symbols of positions the strategy is still holding (or still
    trying to enter/exit). Closed positions are excluded — the strategy has no
    stake in them and must be free to re-enter the symbol.

    Bug fix: previously returned every position in the portfolio regardless of
    state, including Closed. That permanently blacklisted every symbol the
    strategy had ever traded from re-entry via both [held_tickers] passed to the
    screener and the in-strategy candidate filter.

    The match is exhaustive so a future state addition forces a compile error
    here, where the keep/drop decision must be re-examined. *)
let held_symbols (portfolio : Portfolio_view.t) =
  Map.data portfolio.positions
  |> List.filter_map ~f:(fun (p : Position.t) ->
      match p.state with
      | Entering _ | Holding _ | Exiting _ -> Some p.symbol
      | Closed _ -> None)

(** Generate CreateEntering transitions for screener candidates. Tracks
    remaining cash to avoid generating orders that exceed funds.

    Public (see .mli) so callers running custom screening out-of-band can feed
    candidates through the same entry pipeline the strategy uses.

    The walk produces a tagged decision list (see
    {!Entry_audit_capture.candidate_decision}). After the walk, kept candidates
    are emitted to [audit_recorder.record_entry] with the rivals they outranked
    — this is the PR-2 entry-capture site. The output transition list (in
    original screener order) is bit-equivalent to the pre-audit shape: same
    candidates, same transitions, same side-effects on [stop_states] and
    [remaining_cash]. *)
let entries_from_candidates ~config ~candidates ~stop_states ~bar_reader
    ~(portfolio : Portfolio_view.t) ~get_price ~current_date
    ?(audit_recorder = Audit_recorder.noop) ?macro () =
  let held_set = String.Set.of_list (held_symbols portfolio) in
  let portfolio_value = Portfolio_view.portfolio_value portfolio ~get_price in
  let remaining_cash = ref portfolio.cash in
  (* G15 step 2: seed the short-notional accumulator with the current
     entry-price-denominated short notional across all open Holding shorts.
     This is intentionally entry-price-denominated rather than current-price
     so the cap measures committed-at-entry exposure (which is what we know
     when sizing), not mtm liability. The strategy bumps the accumulator
     each time a short is admitted within this Friday's entry walk. *)
  let short_notional_acc =
    ref
      (Map.fold portfolio.positions ~init:0.0 ~f:(fun ~key:_ ~data:pos acc ->
           match (pos.side, pos.state) with
           | ( Trading_base.Types.Short,
               Position.Holding { quantity; entry_price; _ } ) ->
               acc +. (Float.abs quantity *. entry_price)
           | _ -> acc))
  in
  let short_notional_cap =
    portfolio_value *. config.portfolio_config.max_short_notional_fraction
  in
  let make_entry =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:config.portfolio_config
      ~stops_config:config.stops_config
      ~initial_stop_buffer:config.initial_stop_buffer ~stop_states ~bar_reader
      ~portfolio_value ~current_date
  in
  let decisions =
    List.map candidates ~f:(fun c ->
        ( c,
          Entry_audit_capture.classify_candidate ~held_set ~make_entry
            ~remaining_cash ~short_notional_acc ~short_notional_cap c ))
  in
  let kept =
    List.filter_map decisions ~f:(fun (_, d) ->
        match d with
        | Entry_audit_capture.Kept (trans, _) -> Some trans
        | Skipped _ -> None)
  in
  Entry_audit_capture.emit_entries ~audit_recorder ~macro ~current_date
    ~decisions;
  kept

(** Stage 4-5 PR-A: a symbol survives Phase 1 only when its stage could in
    principle yield a screener candidate ([Stage2 _] for longs; [Stage4 _] for
    shorts). [Stage1] / [Stage3] cannot satisfy
    {!Stock_analysis.is_breakout_candidate} or {!is_breakdown_candidate}, so the
    screener would reject them downstream. Filter is over-broad versus the
    screener's full rules (volume / RS / prior_stage); staying broad on stage
    alone preserves bit-equality with the bar-list output. *)
let _survives_phase1 (stage_result : Stage.result) : bool =
  match stage_result.stage with
  | Weinstein_types.Stage2 _ | Weinstein_types.Stage4 _ -> true
  | Weinstein_types.Stage1 _ | Weinstein_types.Stage3 _ -> false

(** PR-B sector pre-filter: drop a Phase 1 survivor whose sector would cause an
    automatic screener rejection ([Weak] for Stage2 longs per
    {!Screener._long_candidate}; [Strong] for Stage4 shorts per
    {!Screener._short_candidate}). Tickers absent from [sector_map] default to
    PASS, matching {!Screener._resolve_sector}'s [Neutral] fallback. *)
let _survives_sector_filter ~sector_map (ticker, _view, stage_result) =
  match Hashtbl.find sector_map ticker with
  | None -> true
  | Some (sector_ctx : Screener.sector_context) -> (
      match (stage_result.Stage.stage, sector_ctx.rating) with
      | Weinstein_types.Stage2 _, Screener.Weak -> false
      | Weinstein_types.Stage4 _, Screener.Strong -> false
      | _ -> true)

(** Stage 4-5 PR-A Phase 1: classify the ticker via the cheap stage callback
    bundle (cache-aware via PR-D) and return
    [(ticker, weekly_view, prior_stage, stage_result)] when the weekly view is
    non-empty. The [prior_stage] (the entry from [prior_stages] read at Phase 1
    time, before any update) is threaded forward so Phase 2's [Stock_analysis]
    receives the same prior-stage context the original pre-PR-A path saw —
    necessary for the screener's Stage1→Stage2 / Stage3→Stage4 transition
    signals to fire correctly.

    [prior_stages] is NOT updated here; the update happens after Phase 2 (or in
    a dedicated update pass for non-survivors below) so that within a single
    Friday tick every per-symbol classification reads the same "previous
    Friday's stage" snapshot. *)
let _classify_stage_for_screening ~config ~bar_reader ~prior_stages
    ~current_date ticker =
  let stock_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:ticker ~n:config.lookback_bars
      ~as_of:current_date
  in
  if stock_view.n = 0 then None
  else
    let prior_stage = Hashtbl.find prior_stages ticker in
    let stage_callbacks =
      Panel_callbacks.stage_callbacks_of_weekly_view
        ?ma_cache:(Bar_reader.ma_cache bar_reader)
        ~symbol:ticker ~config:config.stage_config ~weekly:stock_view ()
    in
    let stage_result =
      Stage.classify_with_callbacks ~config:config.stage_config
        ~get_ma:stage_callbacks.get_ma ~get_close:stage_callbacks.get_close
        ~prior_stage
    in
    Some (ticker, stock_view, prior_stage, stage_result)

(** Stage 4-5 PR-A Phase 2: build the full [Stock_analysis.callbacks] bundle
    (Stage / Rs / Volume / Resistance) for a survivor and run
    [Stock_analysis.analyze_with_callbacks]. This is the load-bearing allocation
    site: prior to PR-A it ran for every loaded symbol; now it runs only for
    survivors of [_survives_phase1]. The [prior_stage] passed here is the value
    Phase 1 captured before any [prior_stages] update — matches the pre-PR-A
    semantics where every per-symbol analysis on a given Friday saw the same
    "previous Friday" snapshot. *)
let _full_analysis_of_survivor ~bar_reader ~index_view
    ( ticker,
      (stock_view : Snapshot_runtime.Snapshot_bar_views.weekly_view),
      prior_stage,
      (_stage_result : Stage.result) ) =
  let as_of_date = stock_view.dates.(stock_view.n - 1) in
  let callbacks =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views
      ?ma_cache:(Bar_reader.ma_cache bar_reader)
      ~stock_symbol:ticker ~config:Stock_analysis.default_config
      ~stock:stock_view ~benchmark:index_view ()
  in
  Stock_analysis.analyze_with_callbacks ~config:Stock_analysis.default_config
    ~ticker ~callbacks ~prior_stage ~as_of_date

(** Phase 1: classify every ticker in [config.universe] via the cheap stage-only
    pass. Returns the full classification result — non-survivors retained so the
    caller can update [prior_stages] in one pass after screening. *)
let _classify_all ~config ~bar_reader ~prior_stages ~current_date =
  List.filter_map config.universe
    ~f:
      (_classify_stage_for_screening ~config ~bar_reader ~prior_stages
         ~current_date)

(** Advance [prior_stages] in one pass — matches the pre-PR-A semantics where
    every per-symbol analysis on a given Friday observed the previous Friday's
    stage snapshot, and the table only advanced once at the end of the universe
    loop. *)
let _commit_prior_stages ~prior_stages classified =
  List.iter classified ~f:(fun (ticker, _view, _prior, stage_result) ->
      Hashtbl.set prior_stages ~key:ticker ~data:stage_result.Stage.stage)

(** Public for testability. See {!Weinstein_strategy.survivors_for_screening} in
    the .mli for the full contract. *)
let survivors_for_screening ?sector_map ~config ~bar_reader ~prior_stages
    ~current_date () :
    (string * Snapshot_runtime.Snapshot_bar_views.weekly_view * Stage.result)
    list =
  let classified =
    _classify_all ~config ~bar_reader ~prior_stages ~current_date
  in
  let final_survivors =
    classified
    |> List.filter_map ~f:(fun (ticker, view, _prior, sr) ->
        if _survives_phase1 sr then Some (ticker, view, sr) else None)
    |> fun stage_survivors ->
    match sector_map with
    | None -> stage_survivors
    | Some m ->
        List.filter stage_survivors ~f:(_survives_sector_filter ~sector_map:m)
  in
  _commit_prior_stages ~prior_stages classified;
  final_survivors

(** Screen the universe via the lazy cascade (Phase 1 stage filter → PR-B sector
    pre-filter → Phase 2 full {!Stock_analysis}). Macro-trend gating lives in
    the screener; concatenating [buy_candidates] + [short_candidates] yields the
    right shape per regime. *)
let _screen_universe ~config ~index_view ~(macro_result : Macro.result)
    ~sector_map ~stop_states ~last_stop_out_dates
    ~(portfolio : Portfolio_view.t) ~get_price ~bar_reader ~prior_stages
    ~current_date ~audit_recorder =
  let classified =
    _classify_all ~config ~bar_reader ~prior_stages ~current_date
  in
  (* Cascade: Phase 1 stage filter → PR-B sector pre-filter → Phase 2 full
     analysis. The four-tuple shape is preserved through both filters so
     [prior_stage] stays threaded into [_full_analysis_of_survivor]. *)
  let stocks =
    classified
    |> List.filter ~f:(fun (_, _, _, sr) -> _survives_phase1 sr)
    |> List.filter ~f:(fun (ticker, view, _prior, sr) ->
        _survives_sector_filter ~sector_map (ticker, view, sr))
    |> List.map ~f:(_full_analysis_of_survivor ~bar_reader ~index_view)
  in
  _commit_prior_stages ~prior_stages classified;
  let screen_result =
    Screener.screen_with_cooldown ~config:config.screening_config
      ~macro_trend:macro_result.trend ~sector_map ~stocks
      ~held_tickers:(held_symbols portfolio) ~as_of:current_date
      ~last_stop_out_dates:(Hashtbl.to_alist last_stop_out_dates)
  in
  let combined_candidates =
    if config.enable_short_side then
      screen_result.Screener.buy_candidates
      @ screen_result.Screener.short_candidates
    else screen_result.Screener.buy_candidates
  in
  let entries =
    entries_from_candidates ~config ~candidates:combined_candidates ~stop_states
      ~bar_reader ~portfolio ~get_price ~current_date ~audit_recorder
      ~macro:macro_result ()
  in
  (* Per-Friday cascade-rejection capture. Fires after the entry walk so the
     [entered] count reflects actual transitions emitted, not just the
     screener's top-N output. Recorder is [Audit_recorder.noop] in non-audit
     contexts (live mode, tests) — zero cost. *)
  audit_recorder.Audit_recorder.record_cascade_summary
    {
      date = current_date;
      diagnostics = screen_result.Screener.cascade_diagnostics;
      entered = List.length entries;
    };
  entries

(* ------------------------------------------------------------------ *)
(* make                                                                  *)
(* ------------------------------------------------------------------ *)

(** Stops are adjusted daily; screening runs only on Fridays (weekly review).

    Stage 4 PR-A: takes the panel weekly view directly. The screening day is the
    date of the most recent bar in the view (the Friday of the latest week, by
    week-bucket aggregation). *)
let _is_screening_day_view
    (view : Snapshot_runtime.Snapshot_bar_views.weekly_view) =
  if view.n = 0 then false
  else
    Date.day_of_week view.dates.(view.n - 1)
    |> Day_of_week.equal Day_of_week.Fri

(** Compute the macro result for [current_date] and update the strategy's macro
    refs. Cheap relative to [_run_screen_after_macro] — touches only the index,
    globals, AD bars, and the macro analyser. Runs unconditionally on every
    Friday (including when the halt is active) so [_maybe_reset_halt] can
    consult the freshest macro trend even when the universe screen is gated off.
*)
let _run_macro_only ~config ~ad_bars ~prior_macro ~prior_macro_result
    ~bar_reader ~prior_stages ~current_date ~index_view =
  let index_prior_stage = Hashtbl.find prior_stages config.indices.primary in
  (* Phase F.3.d-2 caller migration: the global-index view assembly reads
     through {!Snapshot_runtime.Snapshot_callbacks} directly via the
     [*_of_snapshot_views] API rather than re-routing through the
     bar_reader's panel-shaped views. The cb is exposed by the
     snapshot-backed [Bar_reader.t] (production runner uses
     {!Bar_reader.of_snapshot_views} post-#864). *)
  let cb = Bar_reader.snapshot_callbacks bar_reader in
  let global_index_views =
    Macro_inputs.build_global_index_views_of_snapshot_views
      ~lookback_bars:config.lookback_bars
      ~global_index_symbols:config.indices.global ~cb ~as_of:current_date
  in
  let ma_cache = Bar_reader.ma_cache bar_reader in
  let ad_bars =
    Macro_inputs.ad_bars_at_or_before ~ad_bars ~as_of:current_date
  in
  let macro_callbacks =
    Panel_callbacks.macro_callbacks_of_weekly_views ?ma_cache
      ~index_symbol:config.indices.primary ~config:config.macro_config
      ~index:index_view ~globals:global_index_views ~ad_bars ()
  in
  let macro_result =
    Macro.analyze_with_callbacks ~config:config.macro_config
      ~callbacks:macro_callbacks ~prior_stage:index_prior_stage ~prior:None
  in
  prior_macro := macro_result.trend;
  prior_macro_result := Some macro_result;
  macro_result

(** Run the Friday universe screener path given an already-computed
    [macro_result]. Under all macro regimes (Bullish, Neutral, Bearish) the
    screener is invoked; macro-specific gating — longs blocked under Bearish,
    shorts blocked under Bullish — happens inside the screener. Under Bearish
    this yields short-side entries (per the bear-market shorting chapter). *)
let _run_screen_after_macro ~config ~stop_states ~last_stop_out_dates
    ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price
    ~portfolio ~current_date ~index_view ~audit_recorder ~macro_result =
  let ma_cache = Bar_reader.ma_cache bar_reader in
  (* Phase F.3.d-2 caller migration: the sector ETF analysis reads through
     {!Snapshot_runtime.Snapshot_callbacks} directly via the
     [*_of_snapshot_views] API. See [_run_macro_only] for context on the
     cb-from-bar_reader plumbing. *)
  let cb = Bar_reader.snapshot_callbacks bar_reader in
  let sector_map =
    Macro_inputs.build_sector_map_of_snapshot_views ?ma_cache
      ~stage_config:config.stage_config ~lookback_bars:config.lookback_bars
      ~sector_etfs:config.sector_etfs ~cb ~as_of:current_date
      ~sector_prior_stages ~index_view ~ticker_sectors ()
  in
  _screen_universe ~config ~index_view ~macro_result ~sector_map ~stop_states
    ~last_stop_out_dates ~portfolio ~get_price ~bar_reader ~prior_stages
    ~current_date ~audit_recorder

(** Filter the position map down to symbols not yet exited on this tick. The
    force-liquidation pass runs after [Stops_runner.update] but before the
    [TriggerExit] transitions are applied to position state, so a position that
    already received a stop-out exit transition this tick must NOT be
    double-exited via force-liquidation. *)
let _positions_minus_exited ~(positions : Position.t Map.M(String).t)
    ~(stop_exit_transitions : Position.transition list) :
    Position.t Map.M(String).t =
  let exited_ids =
    List.filter_map stop_exit_transitions ~f:(fun (t : Position.transition) ->
        match t.kind with
        | Position.TriggerExit _ -> Some t.position_id
        | _ -> None)
    |> String.Set.of_list
  in
  if Set.is_empty exited_ids then positions
  else
    Map.filter positions ~f:(fun (p : Position.t) ->
        not (Set.mem exited_ids p.id))

(** When the macro flips off Bearish, reset the force-liquidation halt so the
    strategy can resume opening new positions. Bearish-window peak drawdowns are
    exactly when the halt fires; once macro recovers we trust the standard
    cascade gating again. *)
let _maybe_reset_halt ~peak_tracker
    ~(macro_trend : Weinstein_types.market_trend) =
  match macro_trend with
  | Weinstein_types.Bearish -> ()
  | Weinstein_types.Bullish | Weinstein_types.Neutral ->
      Portfolio_risk.Force_liquidation.Peak_tracker.reset peak_tracker

(** Update [last_stop_out_dates] from any [TriggerExit] transitions whose
    [exit_reason] is [StopLoss] — i.e. only stop-machinery exits, not
    take-profit / signal-reversal / time-expired / force-liquidation /
    rebalancing. The mutated map is consumed by [Screener.screen_with_cooldown]
    on the same Friday tick (and on every subsequent Friday until the cooldown
    elapses). Looks up the symbol via [position_id] -> position.symbol from the
    snapshot taken before the stops pass. *)
let _record_stop_outs ~last_stop_out_dates
    ~(positions : Position.t Map.M(String).t)
    ~(exit_transitions : Position.transition list) ~current_date =
  List.iter exit_transitions ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.TriggerExit { exit_reason = Position.StopLoss _; _ } -> (
          match
            Map.data positions
            |> List.find ~f:(fun (p : Position.t) ->
                String.equal p.id t.position_id)
          with
          | Some pos ->
              Hashtbl.set last_stop_out_dates ~key:pos.symbol ~data:current_date
          | None -> ())
      | _ -> ())

let _on_market_close ~config ~ad_bars ~stop_states ~last_stop_out_dates
    ~prior_macro ~prior_macro_result ~peak_tracker ~bar_reader ~prior_stages
    ~sector_prior_stages ~ticker_sectors ~stage3_streaks ~laggard_streaks
    ~audit_recorder ~get_price ~get_indicator:_ ~(portfolio : Portfolio_view.t)
    =
  let positions = portfolio.positions in
  (* G13: non-trading-day short-circuit. The simulator iterates calendar
     days (Mon-Fri including holidays), so [_on_market_close] is invoked on
     days that have no bar in the snapshot. When [get_price] returns [None]
     for the primary index, every other [get_price] this tick also returns
     [None], so:

       1. [current_date] would fall back to [Date.today] — a meaningless
          date that contaminates [last_stop_out_dates], cascade-summary
          dates, and audit records.
       2. [Force_liquidation_runner.update] would be called with cash that
          contains accumulated short proceeds but [_holding_market_value]
          returns 0.0 for every position (no [get_price] this tick), so
          [Portfolio_view.portfolio_value] degenerates to bare [cash] —
          well above the true mtm-aware value. [Peak_tracker.observe]
          phantom-spikes the peak by exactly the absolute mtm contribution
          of every short open at this point. On the next real trading day,
          true [pv] is far below the inflated peak and [Portfolio_floor]
          fires for every Holding position.

     Empirically (sp500-2019-2023, post-G12): the peak got bumped ~$770K
     every weekend a new short opened, eventually pinned at $2.74M; floor
     at 0.4×peak = $1.096M; real-day pv ≈ $1M; cascade fired every Monday
     for 449 spurious [Portfolio_floor] events in the post-G12 baseline.

     The strategy has no business making decisions when there's no primary-
     index bar — there's no market state to observe. Return empty
     transitions and skip every side-effect (stops, FL, splits, macro,
     screener) for this tick. *)
  match get_price config.indices.primary with
  | None -> Ok { Strategy_interface.transitions = [] }
  | Some primary_bar ->
      let current_date = primary_bar.Types.Daily_price.date in
      (* Rescale stop_states for any held symbol that just split. Runs BEFORE
     Stops_runner.update so the state machine sees post-split-comparable
     stop levels. No-ops on non-split days and on positions without a
     [stop_states] entry. See [Stops_split_runner] for the full contract. *)
      Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
        ~as_of:current_date;
      let exit_transitions, adjust_transitions =
        Stops_runner.update
          ?ma_cache:(Bar_reader.ma_cache bar_reader)
          ~stop_update_cadence:config.stop_update_cadence
          ~stops_config:config.stops_config ~stage_config:config.stage_config
          ~lookback_bars:config.lookback_bars ~positions ~get_price ~stop_states
          ~bar_reader ~as_of:current_date ~prior_stages ()
      in
      (* Track per-symbol last stop-out date for the cascade post-stop-out
     cooldown gate. Walks [exit_transitions] before they are applied to the
     position state — looks up symbols from the [positions] snapshot. *)
      _record_stop_outs ~last_stop_out_dates ~positions ~exit_transitions
        ~current_date;
      List.iter exit_transitions
        ~f:
          (Exit_audit_capture.emit_exit_audit ~audit_recorder
             ~prior_macro_result ~stage_config:config.stage_config
             ~lookback_bars:config.lookback_bars ~bar_reader ~prior_stages
             ~positions);
      (* Force-liquidation pass: defense in depth beyond stops (G4). Runs AFTER
     [Stops_runner.update] but operates on the FULL pre-tick portfolio (cash
     + all positions) so [Portfolio_view.portfolio_value] is consistent with
     [portfolio.cash] (which has not yet been updated for this tick's
     stop-exits). Mixing pre-tick cash with a stop-filtered position map
     phantom-spikes [portfolio_value] when shorts stop out — a short's
     negative contribution disappears but its buy-back debit has not yet
     posted — permanently inflating [peak_tracker.peak] and triggering
     spurious [Portfolio_floor] breaches on subsequent days (G12,
     2026-04-30). Double-exit avoidance is done by filtering the returned
     transitions instead of by hiding positions from the runner. Updates
     the peak tracker and may flip the halt state to [Halted] for the
     portfolio-floor case. *)
      let raw_force_exit_transitions =
        Force_liquidation_runner.update
          ~config:config.portfolio_config.force_liquidation ~positions
          ~get_price ~cash:portfolio.cash ~current_date ~peak_tracker
          ~audit_recorder
      in
      let stop_exited_ids =
        List.filter_map exit_transitions ~f:(fun (t : Position.transition) ->
            match t.kind with
            | Position.TriggerExit _ -> Some t.position_id
            | _ -> None)
        |> String.Set.of_list
      in
      let force_exit_transitions =
        if Set.is_empty stop_exited_ids then raw_force_exit_transitions
        else
          List.filter raw_force_exit_transitions
            ~f:(fun (t : Position.transition) ->
              not (Set.mem stop_exited_ids t.position_id))
      in
      (* Stage 4 PR-A: read the primary index as a weekly view directly. The
     Friday detection uses the view's latest date; the screener path consumes
     the same view to avoid building two parallel inputs. *)
      let index_view =
        Bar_reader.weekly_view_for bar_reader ~symbol:config.indices.primary
          ~n:config.lookback_bars ~as_of:current_date
      in
      (* Stage-3 force-exit pass (issue #872). Reads per-position stages from
     [prior_stages] (just refreshed by [Stops_runner.update]) and emits
     [TriggerExit] transitions for held longs whose Stage-3 streak has
     reached [config.stage3_force_exit_config.hysteresis_weeks]. The runner
     filters out positions already exiting via stops on this tick (see
     [stop_exited_ids]) so a stop-out and a Stage-3 fire on the same
     position the same week resolve to a single exit. The runner is
     conditionally enabled via [config.enable_stage3_force_exit] (default
     [false]) so existing baselines are bit-equivalent until callers opt
     in. *)
      let stage3_force_exit_transitions =
        if config.enable_stage3_force_exit then
          let is_screening_day = _is_screening_day_view index_view in
          Stage3_force_exit_runner.update
            ~config:config.stage3_force_exit_config ~is_screening_day ~positions
            ~get_price ~prior_stages ~stage3_streaks
            ~stop_exit_position_ids:stop_exited_ids ~current_date
        else []
      in
      (* Strip force-liq transitions for positions the Stage-3 runner just
     exited — same double-exit hazard the [stop_exited_ids] filter handles
     for stops above. Re-using a fresh union of exited ids covers both. *)
      let stage3_exited_ids =
        List.filter_map stage3_force_exit_transitions
          ~f:(fun (t : Position.transition) ->
            match t.kind with
            | Position.TriggerExit _ -> Some t.position_id
            | _ -> None)
        |> String.Set.of_list
      in
      let force_exit_transitions =
        if Set.is_empty stage3_exited_ids then force_exit_transitions
        else
          List.filter force_exit_transitions
            ~f:(fun (t : Position.transition) ->
              not (Set.mem stage3_exited_ids t.position_id))
      in
      (* Laggard-rotation pass (issue #887). Reads per-position 13-week
     returns vs the primary index over the rolling
     [config.laggard_rotation_config.rs_window_weeks] window and emits
     [TriggerExit] transitions for held longs whose consecutive-negative-
     RS streak has reached [config.laggard_rotation_config.hysteresis_weeks].
     The runner skips positions already exiting via stops or Stage-3
     force-exit on this tick (see the [skip_position_ids] union below) so a
     collision the same week resolves to a single exit. The runner is
     conditionally enabled via [config.enable_laggard_rotation] (default
     [false]) so existing baselines are bit-equivalent until callers opt
     in. *)
      let laggard_rotation_transitions =
        if config.enable_laggard_rotation then
          let is_screening_day = _is_screening_day_view index_view in
          let skip_position_ids = Set.union stop_exited_ids stage3_exited_ids in
          Laggard_rotation_runner.update ~config:config.laggard_rotation_config
            ~benchmark_symbol:config.indices.primary ~is_screening_day
            ~positions ~bar_reader ~get_price ~laggard_streaks
            ~skip_position_ids ~current_date
        else []
      in
      (* Strip force-liq transitions for positions the laggard runner just
     exited — same double-exit hazard the [stop_exited_ids] /
     [stage3_exited_ids] filters handle above. *)
      let laggard_exited_ids =
        List.filter_map laggard_rotation_transitions
          ~f:(fun (t : Position.transition) ->
            match t.kind with
            | Position.TriggerExit _ -> Some t.position_id
            | _ -> None)
        |> String.Set.of_list
      in
      let force_exit_transitions =
        if Set.is_empty laggard_exited_ids then force_exit_transitions
        else
          List.filter force_exit_transitions
            ~f:(fun (t : Position.transition) ->
              not (Set.mem laggard_exited_ids t.position_id))
      in
      (* On every Friday — including Fridays where the force-liquidation halt is
     active — run the cheap macro-only path and consult [_maybe_reset_halt]
     BEFORE deciding whether to invoke the universe screen. This preserves the
     contract claim that the halt clears when macro flips off Bearish: if we
     short-circuited on [halted = true] before updating [prior_macro], the
     halt would latch permanently because no path would ever observe the new
     macro trend. The macro-only path is a strict subset of the full screen
     and adds no work over the buggy short-circuit when no halt is active. *)
      let is_screening_day = _is_screening_day_view index_view in
      let macro_result_opt =
        if is_screening_day then
          Some
            (_run_macro_only ~config ~ad_bars ~prior_macro ~prior_macro_result
               ~bar_reader ~prior_stages ~current_date ~index_view)
        else None
      in
      if is_screening_day then
        _maybe_reset_halt ~peak_tracker ~macro_trend:!prior_macro;
      (* New entries are blocked entirely while the halt is active — that is the
     portfolio-floor trigger's purpose. The halt clears when macro flips off
     Bearish (the typical condition under which the floor fires). *)
      let halted =
        match
          Portfolio_risk.Force_liquidation.Peak_tracker.halt_state peak_tracker
        with
        | Halted -> true
        | Active -> false
      in
      let entry_transitions =
        match (halted, is_screening_day, macro_result_opt) with
        | false, true, Some macro_result ->
            _run_screen_after_macro ~config ~stop_states ~last_stop_out_dates
              ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors
              ~get_price ~portfolio ~current_date ~index_view ~audit_recorder
              ~macro_result
        | _ -> []
      in
      Ok
        {
          Strategy_interface.transitions =
            exit_transitions @ stage3_force_exit_transitions
            @ laggard_rotation_transitions @ force_exit_transitions
            @ adjust_transitions @ entry_transitions;
        }

let make ?(initial_stop_states = String.Map.empty) ?(ad_bars = [])
    ?(ticker_sectors = Hashtbl.create (module String)) ?bar_reader
    ?(audit_recorder = Audit_recorder.noop) config =
  (* Phase F.3.a-4 retired the legacy [?bar_panels] parameter and its
     [Bar_reader.of_panels] constructor. The strategy's bar reads now route
     exclusively through the snapshot path; callers without a bar source
     fall back to {!Bar_reader.empty}, which returns the empty list / empty
     view on every read (safe for tests that never reach a bar consumer). *)
  let bar_reader =
    match bar_reader with Some r -> r | None -> Bar_reader.empty ()
  in
  let stop_states = ref initial_stop_states in
  (* [last_stop_out_dates] feeds [Screener.screen_with_cooldown] for the
     cascade post-stop-out cooldown gate. Mutated in place by
     [_record_stop_outs] after each [Stops_runner.update] tick. Empty at
     construction is bit-equivalent to no cooldown effect. *)
  let last_stop_out_dates : Date.t Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let prior_macro : Weinstein_types.market_trend ref =
    ref Weinstein_types.Neutral
  in
  (* G4 force-liquidation peak tracker — per-strategy-instance state. *)
  let peak_tracker = Portfolio_risk.Force_liquidation.Peak_tracker.create () in
  (* Cached macro result for exit-time audit capture. Held as option until
     first Friday so an exit firing before the first screen gets a stable
     [Neutral / 0.0] snapshot. *)
  let prior_macro_result : Macro.result option ref = ref None in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let sector_prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  (* Per-symbol consecutive-Stage-3-Friday counter consumed by
     {!Stage3_force_exit_runner} (issue #872). Empty at construction →
     every position starts with a streak of zero, matching the no-stage-3
     baseline. *)
  let stage3_streaks : int Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  (* Per-symbol consecutive-negative-RS-Friday counter consumed by
     {!Laggard_rotation_runner} (issue #887). Empty at construction →
     every position starts with a streak of zero, matching the no-laggard
     baseline. *)
  let laggard_streaks : int Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  (* Macro.analyze requires weekly-cadence ad_bars; normalize once at load
     time, not on every [on_market_close] call. *)
  let weekly_ad_bars = Ad_bars_aggregation.daily_to_weekly ad_bars in
  let module M = struct
    let name = name

    let on_market_close =
      _on_market_close ~config ~ad_bars:weekly_ad_bars ~stop_states
        ~last_stop_out_dates ~prior_macro ~prior_macro_result ~peak_tracker
        ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors
        ~stage3_streaks ~laggard_streaks ~audit_recorder
  end in
  (module M : Strategy_interface.STRATEGY)

(** Test-only entry point. Exposes [_on_market_close] with all closure-scoped
    refs / hashtables passed in explicitly so tests can pin the macro / halt /
    screening-day gating without the indirection of going through {!make}. Not
    intended for production use — public callers must use {!make} instead. *)
module Internal_for_test = struct
  let on_market_close = _on_market_close
  let maybe_reset_halt = _maybe_reset_halt
  let positions_minus_exited = _positions_minus_exited
end
