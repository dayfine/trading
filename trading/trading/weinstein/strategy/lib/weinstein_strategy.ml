(* @large-module: strategy composition point — wires screener, macro, stops,
   bar panels, and portfolio into one cohesive weekly cadence; splitting any
   of these concerns into a sibling module would create artificial boundaries
   between tightly coupled wiring logic. *)
open Core
open Trading_strategy
module Bar_reader = Bar_reader
module Stops_runner = Stops_runner

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
  }

let name = "Weinstein"

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _position_counter = ref 0

let _gen_position_id symbol =
  Int.incr _position_counter;
  Printf.sprintf "%s-wein-%d" symbol !_position_counter

(** Normalise (entry, stop) to the order [Portfolio_risk.compute_position_size]
    expects: entry first, stop below. For longs that's the identity (stop <
    entry); for shorts we swap (stop > entry → [max, min]). The result has the
    same absolute risk per share, so [sizing.shares] is unchanged between sides.
*)
let _normalised_entry_stop_for_sizing (cand : Screener.scored_candidate) =
  let open Trading_base.Types in
  match cand.side with
  | Long -> (cand.suggested_entry, cand.suggested_stop)
  | Short ->
      ( Float.max cand.suggested_entry cand.suggested_stop,
        Float.min cand.suggested_entry cand.suggested_stop )

(** Try to build a CreateEntering transition for one screened candidate.
    Registers the initial stop state as a side effect. Returns None if the
    candidate is un-sizeable (zero portfolio value or zero shares).

    The initial stop is derived via
    {!Weinstein_stops.compute_initial_stop_with_floor}, which — depending on
    [cand.side] — pulls either the prior correction low (long) or the prior
    counter-rally high (short) from the candidate's accumulated bar history;
    falls back to the fixed-buffer proxy when the lookback window holds no
    qualifying counter-move. *)
let _make_entry_transition ~config ~stop_states ~bar_reader ~portfolio_value
    ~current_date (cand : Screener.scored_candidate) =
  let entry_for_sizing, stop_for_sizing =
    _normalised_entry_stop_for_sizing cand
  in
  let sizing =
    Portfolio_risk.compute_position_size ~config:config.portfolio_config
      ~portfolio_value ~entry_price:entry_for_sizing ~stop_price:stop_for_sizing
      ()
  in
  if sizing.shares = 0 then None
  else
    let id = _gen_position_id cand.ticker in
    (* Stage 4 PR-A: read a daily view directly from panels — no
       [Daily_price.t list]. The view is windowed to [support_floor_lookback_bars]
       at construction, matching the wrapper [callbacks_from_bars] semantics. *)
    let daily_view =
      Bar_reader.daily_view_for bar_reader ~symbol:cand.ticker
        ~as_of:current_date
        ~lookback:config.stops_config.support_floor_lookback_bars
    in
    let callbacks =
      Panel_callbacks.support_floor_callbacks_of_daily_view daily_view
    in
    let initial_stop =
      Weinstein_stops.compute_initial_stop_with_floor_with_callbacks
        ~config:config.stops_config ~side:cand.side
        ~entry_price:cand.suggested_entry ~callbacks
        ~fallback_buffer:config.initial_stop_buffer
    in
    stop_states := Map.set !stop_states ~key:cand.ticker ~data:initial_stop;
    let description =
      Printf.sprintf "Weinstein %s: %s"
        (Weinstein_types.grade_to_string cand.grade)
        (String.concat ~sep:"; " cand.rationale)
    in
    let reasoning = Position.ManualDecision { description } in
    let kind =
      Position.CreateEntering
        {
          symbol = cand.ticker;
          side = cand.side;
          target_quantity = Float.of_int sizing.shares;
          entry_price = cand.suggested_entry;
          reasoning;
        }
    in
    Some { Position.position_id = id; date = current_date; kind }

(** Check that entry cost fits remaining cash; deduct if so. *)
let _check_cash_and_deduct remaining_cash (trans : Position.transition) =
  match trans.kind with
  | Position.CreateEntering e ->
      let cost = e.target_quantity *. e.entry_price in
      if Float.( > ) cost !remaining_cash then None
      else (
        remaining_cash := !remaining_cash -. cost;
        Some trans)
  | _ -> Some trans

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

(** Try to convert a single screener candidate to a kept transition. Returns
    [None] when the ticker is already held, when sizing rejects it, or when cash
    is insufficient. *)
let _candidate_to_transition ~held_set ~make_entry ~remaining_cash
    (c : Screener.scored_candidate) =
  if Set.mem held_set c.ticker then None
  else Option.bind (make_entry c) ~f:(_check_cash_and_deduct remaining_cash)

(** Generate CreateEntering transitions for screener candidates. Tracks
    remaining cash to avoid generating orders that exceed funds.

    Public (see .mli) so callers running custom screening out-of-band can feed
    candidates through the same entry pipeline the strategy uses.

    Was: chained [List.filter |> List.filter_map |> List.filter_map] over
    [candidates] — three list traversals each allocating a fresh intermediate
    list. Now: one [List.fold] walks [candidates] once, calls
    [_candidate_to_transition] per element, and accumulates a single reversed
    output list. The cash-deduction side effect on [remaining_cash] runs in the
    same order it did before — every successful entry decrements
    [remaining_cash] before the next candidate is considered — so we preserve
    the "first-come keeps cash" tie-break. Per the perf followup notes under
    dev/notes/: List.filter was the top allocator on the strategy hot path. *)
let entries_from_candidates ~config ~candidates ~stop_states ~bar_reader
    ~(portfolio : Portfolio_view.t) ~get_price ~current_date =
  let held_set = String.Set.of_list (held_symbols portfolio) in
  let portfolio_value = Portfolio_view.portfolio_value portfolio ~get_price in
  let remaining_cash = ref portfolio.cash in
  let make_entry =
    _make_entry_transition ~config ~stop_states ~bar_reader ~portfolio_value
      ~current_date
  in
  List.fold candidates ~init:[] ~f:(fun acc c ->
      match
        _candidate_to_transition ~held_set ~make_entry ~remaining_cash c
      with
      | None -> acc
      | Some kept -> kept :: acc)
  |> List.rev

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
      (stock_view : Data_panel.Bar_panels.weekly_view),
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
    (string * Data_panel.Bar_panels.weekly_view * Stage.result) list =
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
let _screen_universe ~config ~index_view ~macro_trend ~sector_map ~stop_states
    ~(portfolio : Portfolio_view.t) ~get_price ~bar_reader ~prior_stages
    ~current_date =
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
    Screener.screen ~config:config.screening_config ~macro_trend ~sector_map
      ~stocks ~held_tickers:(held_symbols portfolio)
  in
  let combined_candidates =
    screen_result.Screener.buy_candidates
    @ screen_result.Screener.short_candidates
  in
  entries_from_candidates ~config ~candidates:combined_candidates ~stop_states
    ~bar_reader ~portfolio ~get_price ~current_date

(* ------------------------------------------------------------------ *)
(* make                                                                  *)
(* ------------------------------------------------------------------ *)

(** Stops are adjusted daily; screening runs only on Fridays (weekly review).

    Stage 4 PR-A: takes the panel weekly view directly. The screening day is the
    date of the most recent bar in the view (the Friday of the latest week, by
    week-bucket aggregation). *)
let _is_screening_day_view (view : Data_panel.Bar_panels.weekly_view) =
  if view.n = 0 then false
  else
    Date.day_of_week view.dates.(view.n - 1)
    |> Day_of_week.equal Day_of_week.Fri

(** Run the Friday macro + screener path and return entry transitions. Under all
    macro regimes (Bullish, Neutral, Bearish) the screener is invoked;
    macro-specific gating — longs blocked under Bearish, shorts blocked under
    Bullish — happens inside the screener. Under Bearish this yields short-side
    entries (per the bear-market shorting chapter), where previously the branch
    returned [] unconditionally.

    Filters [ad_bars] to dates [<= current_date] before constructing macro
    callbacks. The strategy's [make] function loads the full A-D breadth series
    once at construction time (via {!Ad_bars.load}); the composer-loaded
    synthetic series typically extends past the simulator's current tick.
    Without this filter the macro analyzer's [get_cumulative_ad ~week_offset:0]
    returns the cumulative as of the {b last loaded} bar rather than the current
    tick — leaking future breadth into the indicator readings and misclassifying
    real bear-market regimes as [Neutral] / [Bullish]. See
    [test_macro_panel_callbacks_real_data.ml]. *)
let _run_screen ~config ~ad_bars ~stop_states ~prior_macro ~bar_reader
    ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio
    ~current_date ~index_view =
  let index_prior_stage = Hashtbl.find prior_stages config.indices.primary in
  let global_index_views =
    Macro_inputs.build_global_index_views ~lookback_bars:config.lookback_bars
      ~global_index_symbols:config.indices.global ~bar_reader
      ~as_of:current_date
  in
  let ma_cache = Bar_reader.ma_cache bar_reader in
  let ad_bars_until_now =
    Macro_inputs.ad_bars_at_or_before ~ad_bars ~as_of:current_date
  in
  let macro_callbacks =
    Panel_callbacks.macro_callbacks_of_weekly_views ?ma_cache
      ~index_symbol:config.indices.primary ~config:config.macro_config
      ~index:index_view ~globals:global_index_views ~ad_bars:ad_bars_until_now
      ()
  in
  let macro_result =
    Macro.analyze_with_callbacks ~config:config.macro_config
      ~callbacks:macro_callbacks ~prior_stage:index_prior_stage ~prior:None
  in
  prior_macro := macro_result.trend;
  let sector_map =
    Macro_inputs.build_sector_map ?ma_cache ~stage_config:config.stage_config
      ~lookback_bars:config.lookback_bars ~sector_etfs:config.sector_etfs
      ~bar_reader ~as_of:current_date ~sector_prior_stages ~index_view
      ~ticker_sectors ()
  in
  _screen_universe ~config ~index_view ~macro_trend:macro_result.trend
    ~sector_map ~stop_states ~portfolio ~get_price ~bar_reader ~prior_stages
    ~current_date

let _on_market_close ~config ~ad_bars ~stop_states ~prior_macro ~bar_reader
    ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price
    ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  let positions = portfolio.positions in
  let current_date =
    match get_price config.indices.primary with
    | Some bar -> bar.Types.Daily_price.date
    | None -> Date.today ~zone:Time_float.Zone.utc
  in
  let exit_transitions, adjust_transitions =
    Stops_runner.update
      ?ma_cache:(Bar_reader.ma_cache bar_reader)
      ~stops_config:config.stops_config ~stage_config:config.stage_config
      ~lookback_bars:config.lookback_bars ~positions ~get_price ~stop_states
      ~bar_reader ~as_of:current_date ~prior_stages ()
  in
  (* Stage 4 PR-A: read the primary index as a weekly view directly. The
     Friday detection uses the view's latest date; the screener path consumes
     the same view to avoid building two parallel inputs. *)
  let index_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:config.indices.primary
      ~n:config.lookback_bars ~as_of:current_date
  in
  let entry_transitions =
    if not (_is_screening_day_view index_view) then []
    else
      _run_screen ~config ~ad_bars ~stop_states ~prior_macro ~bar_reader
        ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio
        ~current_date ~index_view
  in
  Ok
    {
      Strategy_interface.transitions =
        exit_transitions @ adjust_transitions @ entry_transitions;
    }

let make ?(initial_stop_states = String.Map.empty) ?(ad_bars = [])
    ?(ticker_sectors = Hashtbl.create (module String)) ?bar_panels config =
  let stop_states = ref initial_stop_states in
  let prior_macro : Weinstein_types.market_trend ref =
    ref Weinstein_types.Neutral
  in
  (* Stage 4 PR-D: when bar_panels are present, also create a [Weekly_ma_cache]
     scoped to this strategy and bundle it into the [Bar_reader]. The cache
     is read by [Panel_callbacks.stage_callbacks_of_weekly_view] (and
     transitively by Stock_analysis / Sector / Macro / Stops_runner) so
     per-symbol weekly MA values are computed once, not per Friday tick.

     The cache is opt-in (only when bar_panels are passed) so test
     fixtures using [Bar_reader.empty ()] aren't affected. *)
  let bar_reader =
    match bar_panels with
    | Some p ->
        let ma_cache = Weekly_ma_cache.create p in
        Bar_reader.of_panels ~ma_cache p
    | None -> Bar_reader.empty ()
  in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let sector_prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  (* Macro.analyze requires weekly-cadence ad_bars (see Macro.ad_bar's
     cadence contract). Loaders like Ad_bars.Unicorn return daily bars, so
     normalize once at load time — not on every on_market_close call. *)
  let weekly_ad_bars = Ad_bars_aggregation.daily_to_weekly ad_bars in
  let module M = struct
    let name = name

    let on_market_close =
      _on_market_close ~config ~ad_bars:weekly_ad_bars ~stop_states ~prior_macro
        ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors
  end in
  (module M : Strategy_interface.STRATEGY)
