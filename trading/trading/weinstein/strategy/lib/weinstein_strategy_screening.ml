(* @large-module: Friday screening + entry-walk orchestration. Holds the
   per-Friday seeding for cash / short-notional / sector-exposure accumulators
   and the Phase 1 / Phase 2 / cascade chain. Splitting would scatter the
   single-Friday entry-walk contract. *)
open Core
open Trading_strategy
open Weinstein_strategy_config

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

(** Classify one [candidate] through the entry gates against [state], pairing it
    with its decision. Mutates [state]'s accumulators in-place. *)
let _classify_one ~held_set ~make_entry ~portfolio_value
    ~(state : Screening_notional.entry_walk_state) candidate =
  ( candidate,
    Entry_audit_capture.classify_candidate
      ~leverage_enabled:state.leverage_enabled ~held_set ~make_entry
      ~remaining_cash:state.remaining_cash
      ~short_notional_acc:state.short_notional_acc
      ~short_notional_cap:state.short_notional_cap
      ~long_notional_acc:state.long_notional_acc
      ~long_notional_cap:state.long_notional_cap
      ~sector_exposure_acc:state.sector_exposure_acc
      ~max_sector_exposure_pct:state.max_sector_exposure_pct ~portfolio_value
      candidate )

(** Classify [candidates] (in order) through the entry gates against [state],
    pairing each with its decision. The walk mutates [state]'s accumulators
    in-place. *)
let _classify_candidates ~held_set ~make_entry ~portfolio_value ~state
    candidates =
  List.map candidates
    ~f:(_classify_one ~held_set ~make_entry ~portfolio_value ~state)

(** Classify [indexed_candidates] (in original order) while charging them
    against a side-specific [remaining_cash] budget [side_cash], reusing the
    shared [short_notional_acc] / [sector_exposure_acc] in [state] so the caps
    apply across both sides. Returns the [(index, candidate, decision)] triples
    keyed by the candidate's position in the original list. *)
let _walk_side ~held_set ~make_entry ~portfolio_value
    ~(state : Screening_notional.entry_walk_state) ~side_cash indexed_candidates
    =
  let side_state = { state with remaining_cash = ref side_cash } in
  let decisions =
    _classify_candidates ~held_set ~make_entry ~portfolio_value
      ~state:side_state
      (List.map indexed_candidates ~f:snd)
  in
  List.map2_exn indexed_candidates decisions ~f:(fun (i, c) (_, d) -> (i, c, d))

(** Reserved-short-sleeve walk (active when [short_sleeve_fraction > 0.0]).
    Partitions the per-Friday cash budget so longs cannot starve shorts:
    reserves [short_budget] for a short-only walk and walks longs against
    [long_cash]. Both walks reuse [state]'s shared [short_notional_acc] and
    [sector_exposure_acc] (caps apply across both sides) but carry independent
    [remaining_cash] refs. Decisions are re-ordered back into the original
    [candidates] order so emit/kept ordering matches the combined-walk path. See
    [project_short_funnel_crowded_out]. *)
let _sleeve_decisions ~held_set ~make_entry ~portfolio_value ~state ~long_cash
    ~short_budget candidates =
  let indexed = List.mapi candidates ~f:(fun i c -> (i, c)) in
  let is_short (_, (c : Screener.scored_candidate)) =
    Trading_base.Types.equal_position_side c.side Trading_base.Types.Short
  in
  let short_indexed, long_indexed = List.partition_tf indexed ~f:is_short in
  let walk = _walk_side ~held_set ~make_entry ~portfolio_value ~state in
  let long_walk = walk ~side_cash:long_cash long_indexed in
  let short_walk = walk ~side_cash:short_budget short_indexed in
  List.append long_walk short_walk
  |> List.sort ~compare:(fun (i, _, _) (j, _, _) -> Int.compare i j)
  |> List.map ~f:(fun (_, c, d) -> (c, d))

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
let entries_from_candidates ?sector_lookup ~config ~candidates ~stop_states
    ~bar_reader ~(portfolio : Portfolio_view.t) ~get_price ~current_date
    ?(audit_recorder = Audit_recorder.noop) ?macro () =
  let held_set = String.Set.of_list (held_symbols portfolio) in
  let portfolio_value = Portfolio_view.portfolio_value portfolio ~get_price in
  let make_entry (cand : Screener.scored_candidate) =
    Entry_audit_capture.make_entry_transition
      ~min_stop_distance_pct:
        (Entry_stop_distance.min_stop_distance_for ~config ~bar_reader
           ~current_date cand)
      ~portfolio_risk_config:(Scale_in_runner.entry_sizing_config config)
      ~stops_config:config.stops_config
      ~initial_stop_buffer:config.initial_stop_buffer ~stop_states ~bar_reader
      ~portfolio_value ~current_date cand
  in
  let spendable, state =
    Screening_notional.reserve_reduced_walk_state ~config ~portfolio
      ~portfolio_value ~sector_lookup
  in
  let decisions =
    if Float.( <= ) config.short_sleeve_fraction 0.0 then
      (* No-op default: single combined walk over [candidates], bit-identical
         to the pre-sleeve path. *)
      _classify_candidates ~held_set ~make_entry ~portfolio_value ~state
        candidates
    else
      (* Reserved short sleeve: partition the (reserve-reduced) cash budget
         between a long and a short walk that share [state]'s notional/sector
         accumulators. *)
      let short_budget = portfolio_value *. config.short_sleeve_fraction in
      let long_cash = Float.max 0.0 (spendable -. short_budget) in
      _sleeve_decisions ~held_set ~make_entry ~portfolio_value ~state ~long_cash
        ~short_budget candidates
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

(** Build the per-screen-pass [Stock_analysis.config]. Differs from
    {!Stock_analysis.default_config} only by (a) toggling the continuation
    detector based on [Weinstein_strategy_config.enable_continuation_buys] and
    threading the strategy's [continuation_config] (defaults to
    [Continuation.default_config], preserving bit-equality with prior baselines
    when the field is omitted from a scenario sexp), (b) overriding the
    resistance [min_history_bars] when
    [Weinstein_strategy_config.resistance_min_history_bars] is non-zero, and (c)
    threading the resistance-v2 [overhead_supply] +
    [virgin_crossing_readmission] knobs (both default off, bit-identical).

    The [min_history_bars] override sets [config.resistance.min_history_bars];
    because {!Stock_analysis} reuses the same [Resistance.config] record for the
    short-side support mirror ([_support_result] passes [config.resistance] to
    {!Support.analyze_with_callbacks}), the floor applies to both directions
    automatically without diverging the two records. Default [0] leaves
    {!Resistance.default_config}'s disabled check in place, so the built config
    is byte-identical to {!Stock_analysis.default_config} (PR #1941 semantics;
    [Weinstein_types.Insufficient_history]). *)
let _stock_analysis_config_for ~(config : Weinstein_strategy_config.config) :
    Stock_analysis.config =
  let base =
    {
      Stock_analysis.default_config with
      continuation =
        (if config.enable_continuation_buys then Some config.continuation_config
         else None);
      overhead_supply = config.overhead_supply;
      virgin_crossing_readmission = config.virgin_crossing_readmission;
    }
  in
  if config.resistance_min_history_bars = 0 then base
  else
    {
      base with
      resistance =
        {
          base.resistance with
          min_history_bars = config.resistance_min_history_bars;
        };
    }

(** Stage 4-5 PR-A Phase 2: build the full [Stock_analysis.callbacks] bundle
    (Stage / Rs / Volume / Resistance) for a survivor and run
    [Stock_analysis.analyze_with_callbacks]. This is the load-bearing allocation
    site: prior to PR-A it ran for every loaded symbol; now it runs only for
    survivors of [_survives_phase1]. The [prior_stage] passed here is the value
    Phase 1 captured before any [prior_stages] update — matches the pre-PR-A
    semantics where every per-symbol analysis on a given Friday saw the same
    "previous Friday" snapshot. *)
let _full_analysis_of_survivor ~stock_analysis_config ~resistance_lookback_bars
    ~bar_reader ~index_view
    ( ticker,
      (stock_view : Snapshot_runtime.Snapshot_bar_views.weekly_view),
      prior_stage,
      (_stage_result : Stage.result) ) =
  let as_of_date = stock_view.dates.(stock_view.n - 1) in
  (* Resistance-history feed: when armed (> 0), fetch a second, deeper weekly
     view for the resistance/support callbacks only. Survivors-only, so the
     extra view is fetched for the small Phase-1-surviving fraction. *)
  let resistance_stock =
    if resistance_lookback_bars <= 0 then None
    else
      Some
        (Bar_reader.weekly_view_for bar_reader ~symbol:ticker
           ~n:resistance_lookback_bars ~as_of:as_of_date)
  in
  let callbacks =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views
      ?ma_cache:(Bar_reader.ma_cache bar_reader)
      ?resistance_stock ~stock_symbol:ticker
      ?weekly_sidetable:
        (Bar_reader.weekly_sidetable_for bar_reader ~symbol:ticker)
      ~snapshot_cb:(Bar_reader.snapshot_callbacks bar_reader)
      ~config:stock_analysis_config ~stock:stock_view ~benchmark:index_view ()
  in
  Stock_analysis.analyze_with_callbacks ~config:stock_analysis_config ~ticker
    ~callbacks ~prior_stage ~as_of_date

(** Win #4: drop symbols from [universe] whose [active_through_for] returns
    [Some d] with [Core.Date.(d < fold_start_date)]. [None] symbols (no
    delisting marker — still trading or unknown) pass through unchanged.

    Point-in-time framing: this is NOT survivor bias. We filter on the FOLD
    start date, a date in the past relative to the present — symbols delisted
    later during the fold are kept and participate normally; only symbols
    already uninvestable AT THE TIME of the fold's start are dropped. Filtering
    on the current date would be survivor bias; that cut is NOT performed here.
    See Win #4 of [dev/plans/v7-sweep-speedup-2026-05-26.md].

    Public for testability — tests pin the predicate independent of the
    surrounding [_classify_all] / [screen_universe] wiring. *)
let prune_universe_by_active_through ~universe ~active_through_for
    ~fold_start_date =
  List.filter universe ~f:(fun symbol ->
      match active_through_for symbol with
      | None -> true
      | Some d -> Core.Date.( <= ) fold_start_date d)

(** Phase 1: classify every ticker in [config.universe] via the cheap stage-only
    pass. Returns the full classification result — non-survivors retained so the
    caller can update [prior_stages] in one pass after screening.

    Win #4: when [?active_through_for] and [?fold_start_date] are both supplied,
    [config.universe] is pre-pruned via {!_prune_universe_by_active_through}
    before the Phase-1 loop runs. Default (both unset) preserves baselines — the
    full [config.universe] is classified. *)
let _classify_all ?active_through_for ?fold_start_date ~config ~bar_reader
    ~prior_stages ~current_date () =
  let universe =
    match (active_through_for, fold_start_date) with
    | Some f, Some d ->
        prune_universe_by_active_through ~universe:config.universe
          ~active_through_for:f ~fold_start_date:d
    | _ -> config.universe
  in
  List.filter_map universe
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
    the .mli for the full contract.

    Win #4: [?active_through_for] and [?fold_start_date] are forwarded to
    {!_classify_all} for universe pre-pruning. Default (both unset) preserves
    baselines. *)
let survivors_for_screening ?active_through_for ?fold_start_date ?sector_map
    ~config ~bar_reader ~prior_stages ~current_date () :
    (string * Snapshot_runtime.Snapshot_bar_views.weekly_view * Stage.result)
    list =
  let classified =
    _classify_all ?active_through_for ?fold_start_date ~config ~bar_reader
      ~prior_stages ~current_date ()
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

(* Per-element predicates over the four-tuple shape so [screen_universe]'s
   cascade stays a flat pipeline (one filter per gate, no destructuring
   lambdas pushing nesting depth). *)
let _phase1_of (_, _, _, sr) = _survives_phase1 sr

let _sector_filter_of ~sector_map (ticker, view, _prior, sr) =
  _survives_sector_filter ~sector_map (ticker, view, sr)

(** P1 2026-05-15: resolve a symbol to its sector name via [sector_map] for the
    per-sector exposure accumulator seed. Same lookup the cascade uses for new
    candidates, so seed and per-tick bumps stay consistent. *)
let _sector_lookup_of ~sector_map symbol =
  Hashtbl.find sector_map symbol
  |> Option.map ~f:(fun (ctx : Screener.sector_context) -> ctx.sector_name)

(** Whether the current primary-index decline is a slow grind, for the faithful
    short's [enable_slow_grind_short_gate]. Classified from the {b current}
    cycle's macro result + index bars via {!Decline_character_wiring} — this is
    lookahead-free for an entry gate (entries already gate on the current
    [macro_trend]; the prior-cycle decline-character ref is the stops seam, not
    the entry seam). Only consulted when the gate is enabled; returns [true]
    otherwise so short admission stays bit-identical to the pre-gate behaviour
    (the screener ignores the value when the gate is off). The classification
    lives here, in the strategy lib (which depends on [weinstein.macro]), so the
    screener lib stays macro-agnostic — it receives a plain bool. *)
let _decline_is_slow_grind ~config ~macro_result ~index_view =
  if not config.enable_slow_grind_short_gate then true
  else
    let classifier_config =
      Decline_character_wiring.classifier_config
        ~fast_v_arm_on_rate_alone:config.fast_v_arm_on_rate_alone
        ~fast_v_min_rate_pct:config.fast_v_min_rate_pct
    in
    match
      Decline_character_wiring.classify ~config:classifier_config
        ~macro:macro_result ~index_view
    with
    | Decline_character.Slow_grind -> true
    | Decline_character.Fast_v | Decline_character.Not_declining -> false

(** Run the cascade screener over the Phase-2 [stocks], threading the top-level
    [neutral_blocks_longs] / [neutral_blocks_shorts] entry-gate flags and the
    [enable_slow_grind_short_gate] decline-character gate into the screener
    config so they are expressible as [Weinstein_strategy.config] flag axes.
    Default [false] on all three leaves the screener config untouched
    bit-equally. Factored out of {!screen_universe} to keep that function under
    the 50-line linter cap. *)
let _run_screener ?membership_at ~config ~(macro_result : Macro.result)
    ~index_view ~sector_map ~stocks ~portfolio ~last_stop_out_dates
    ~current_date () =
  let screening_config =
    {
      config.screening_config with
      Screener.neutral_blocks_longs = config.neutral_blocks_longs;
      Screener.neutral_blocks_shorts = config.neutral_blocks_shorts;
      Screener.enable_slow_grind_short_gate =
        config.enable_slow_grind_short_gate;
    }
  in
  let decline_is_slow_grind =
    _decline_is_slow_grind ~config ~macro_result ~index_view
  in
  Screener.screen_with_cooldown ?membership_at ~decline_is_slow_grind
    ~config:screening_config ~macro_trend:macro_result.Macro.trend ~sector_map
    ~stocks ~held_tickers:(held_symbols portfolio) ~as_of:current_date
    ~last_stop_out_dates:(Hashtbl.to_alist last_stop_out_dates)
    ()

(* Assemble the final entry-candidate list: merge longs + shorts (short-side
   gate), then apply the entry liquidity gate ({!Entry_liquidity_gate.apply} —
   no-op at the default config, no lookahead). *)

(** Screen the universe via the lazy cascade (Phase 1 stage filter → PR-B sector
    pre-filter → Phase 2 full {!Stock_analysis}). Macro-trend gating lives in
    the screener; concatenating [buy_candidates] + [short_candidates] yields the
    right shape per regime.

    Win #4: when [?active_through_for] and [?fold_start_date] are both supplied,
    [config.universe] is pre-pruned (point-in-time, not survivor bias) before
    Phase 1 runs. Symbols whose [active_through < fold_start_date] are dropped
    from the per-Friday classification loop, eliminating the Phase-1 cost on
    symbols that cannot contribute to the fold. *)

let screen_universe ?active_through_for ?fold_start_date ?membership_at ~config
    ~index_view ~(macro_result : Macro.result) ~sector_map ~stop_states
    ~last_stop_out_dates ~(portfolio : Portfolio_view.t) ~get_price ~bar_reader
    ~prior_stages ~current_date ~audit_recorder () =
  let classified =
    _classify_all ?active_through_for ?fold_start_date ~config ~bar_reader
      ~prior_stages ~current_date ()
  in
  let stock_analysis_config = _stock_analysis_config_for ~config in
  (* Bind Phase-2 closure outside the pipeline (depth-5 ceiling). *)
  let analyze =
    _full_analysis_of_survivor ~stock_analysis_config
      ~resistance_lookback_bars:config.resistance_lookback_bars ~bar_reader
      ~index_view
  in
  let stocks =
    classified |> List.filter ~f:_phase1_of
    |> List.filter ~f:(_sector_filter_of ~sector_map)
    |> List.map ~f:analyze
  in
  _commit_prior_stages ~prior_stages classified;
  let screen_result =
    _run_screener ?membership_at ~config ~macro_result ~index_view ~sector_map
      ~stocks ~portfolio ~last_stop_out_dates ~current_date ()
  in
  let combined_candidates =
    Entry_assembly.assemble ~config ~bar_reader ~current_date screen_result
  in
  let entries =
    entries_from_candidates
      ~sector_lookup:(_sector_lookup_of ~sector_map)
      ~config ~candidates:combined_candidates ~stop_states ~bar_reader
      ~portfolio ~get_price ~current_date ~audit_recorder ~macro:macro_result ()
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

(** Stops are adjusted daily; screening runs only on Fridays (weekly review).

    Stage 4 PR-A: takes the panel weekly view directly. The screening day is the
    date of the most recent bar in the view (the Friday of the latest week, by
    week-bucket aggregation). *)
let is_screening_day_view
    (view : Snapshot_runtime.Snapshot_bar_views.weekly_view) =
  view.n > 0
  && Day_of_week.equal Day_of_week.Fri
       (Date.day_of_week view.dates.(view.n - 1))
