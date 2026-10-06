(** Deterministic selection-path trace. See [selection_trace.mli]. *)

open Core
open Selection_trace_fixtures
open Selection_trace_cases

(* ------------------------------------------------------------------ *)
(* Rendering                                                            *)
(* ------------------------------------------------------------------ *)

let _render_candidate (c : Screener.scored_candidate) =
  sprintf "      %-6s score=%3d grade=%-3s entry=%.4f stop=%.4f risk=%.6f"
    c.ticker c.score
    (Weinstein_types.grade_to_string c.grade)
    c.suggested_entry c.suggested_stop c.risk_pct

let _render_candidates label candidates =
  let header = sprintf "    %s (n=%d):" label (List.length candidates) in
  String.concat ~sep:"\n" (header :: List.map candidates ~f:_render_candidate)

let _render_diagnostics (d : Screener.cascade_diagnostics) =
  sprintf "    diagnostics: %s"
    (Sexp.to_string_mach (Screener.sexp_of_cascade_diagnostics d))

(** Only [CreateEntering] is rendered, and [position_id] is deliberately
    omitted: it is minted per entry and is not a selection outcome. Rendering it
    would make the trace differ between two identical builds. *)
let _render_transition (t : Trading_strategy.Position.transition) =
  match t.kind with
  | CreateEntering { symbol; side; target_quantity; entry_price; _ } ->
      Some
        (sprintf "      ENTER %-6s side=%s qty=%.4f price=%.4f" symbol
           (Trading_base.Types.show_position_side side)
           target_quantity entry_price)
  | _ -> None

(* ------------------------------------------------------------------ *)
(* Fixture exports (see the .mli)                                       *)
(* ------------------------------------------------------------------ *)

let as_of = _as_of
let stocks = _stocks
let universe_tickers = _universe_tickers
let sector_map = _sector_map
let tie_group = List.sort _tie_group_a ~compare:String.compare
let weak_sector_long = _weak_sector_long
let strong_sector_short = _strong_sector_short

let _all_cases () =
  List.concat
    [
      _macro_cases ();
      _ranking_cases ();
      _cap_cases ();
      _cooldown_cases ();
      _membership_cases ();
      _held_cases ();
      _score_boundary_cases ();
      _price_boundary_cases ();
    ]

let case_count = List.length (_all_cases ())

(* ------------------------------------------------------------------ *)
(* Execution                                                            *)
(* ------------------------------------------------------------------ *)

(** [None] when the case names no non-members, so the gate stays exactly as
    unsupplied as it is on the default path — an always-true closure would be
    functionally equivalent but would silently change which code path the other
    cases take. *)
let _membership_at case =
  if List.is_empty case.non_members then None
  else
    Some
      (fun ticker _date ->
        not (List.mem case.non_members ticker ~equal:String.equal))

let _run_screen case =
  if case.use_plain_screen then
    Screener.screen ~config:case.config ~macro_trend:case.macro
      ~sector_map:(_sector_map ()) ~stocks:_stocks ~held_tickers:case.held
  else
    Screener.screen_with_cooldown ?membership_at:(_membership_at case)
      ~config:case.config ~macro_trend:case.macro ~sector_map:(_sector_map ())
      ~stocks:_stocks ~held_tickers:case.held ~as_of:_as_of
      ~last_stop_out_dates:case.stop_outs ()

let _empty_portfolio : Trading_strategy.Portfolio_view.t =
  { cash = _portfolio_cash; positions = String.Map.empty }

let _get_price_of candidates symbol =
  List.find_map candidates ~f:(fun (c : Screener.scored_candidate) ->
      if String.equal c.ticker symbol then
        Some (_bar ~volume:_fill_volume ~date:_as_of ~close:c.suggested_entry)
      else None)

(** Drive the entry walk on the screener's own output. This is the surface #2500
    threaded [?on_candidates_considered] through, and the transitions it emits —
    not the screener's top-N — are the actual selection outcome. *)
let _run_entry_walk (result : Screener.result) =
  let candidates = result.buy_candidates @ result.short_candidates in
  let config =
    Weinstein_strategy.default_config ~universe:_universe_tickers
      ~index_symbol:_index_symbol
  in
  let stop_states = ref String.Map.empty in
  Weinstein_strategy.entries_from_candidates ~config ~candidates ~stop_states
    ~bar_reader:(Weinstein_strategy.Bar_reader.empty ())
    ~portfolio:_empty_portfolio ~get_price:(_get_price_of candidates)
    ~current_date:_as_of ()

let _render_case case =
  let result = _run_screen case in
  let transitions = _run_entry_walk result in
  let entries = List.filter_map transitions ~f:_render_transition in
  String.concat ~sep:"\n"
    ([
       sprintf "  case %s" case.label;
       _render_candidates "buy" result.buy_candidates;
       _render_candidates "short" result.short_candidates;
       _render_diagnostics result.cascade_diagnostics;
       sprintf "    watchlist: %d" (List.length result.watchlist);
       sprintf "    entries (n=%d):" (List.length entries);
     ]
    @ entries)

(* ------------------------------------------------------------------ *)
(* Replay: the composed strategy path                                   *)
(* ------------------------------------------------------------------ *)

(* The sections above drive [Screener.screen*] and [entries_from_candidates] as
   separate units. This one drives them the way production does — through
   [Weinstein_strategy.on_market_close], which is what actually calls
   [screen_universe], the single function whose body BOTH #2500 and #2501
   edited. Without this section the differential would be measuring the parts
   while leaving the composition (and the [Cascade_trace] handle threaded
   through it) unmeasured. *)

(* The strategy accumulates DAILY bars and converts them to weekly itself
   ([Time_period.Conversion.daily_to_weekly]). Feeding it one bar per week
   therefore starves it: 70 weekly bars read as 70 daily bars ≈ 14 weeks, never
   reaching the 30-week MA warmup, and the replay emits nothing at every step —
   a trace that is stable for the wrong reason. Each weekly bar is expanded into
   a Mon-Fri run at the same close, which preserves every volume RATIO (all
   symbols are scaled by the same factor) while giving the weekly aggregation
   real weeks to build from. *)
let _trading_days_per_week = 5
let _daily_origin = Date.of_string "2020-01-06"

let _daily_of_weekly weekly =
  List.concat_mapi weekly ~f:(fun week (b : Types.Daily_price.t) ->
      List.init _trading_days_per_week ~f:(fun day ->
          let date =
            Date.add_days _daily_origin ((week * _days_per_week) + day)
          in
          { b with date }))

(* Long enough to span every symbol's series, so the macro tape never goes dark
   partway through the replay. *)
let _index_weeks = _base_weeks + _decline_weeks

let _index_series ~rising =
  let from_, to_ =
    if rising then (_base_price, _breakout_price)
    else (_breakout_price, _base_price)
  in
  _ramp ~n:_index_weeks ~from_ ~to_
  |> List.map ~f:(fun c -> (c, _base_volume))
  |> _weekly_bars

let _bars_by_symbol ~rising =
  (_index_symbol, _daily_of_weekly (_index_series ~rising))
  :: List.map _universe_spec ~f:(fun (t, shape) ->
      (t, _daily_of_weekly (_series_of_shape shape)))

(** Every date any symbol has a bar on, ascending and de-duplicated. *)
let _replay_dates ~rising =
  List.concat_map (_bars_by_symbol ~rising) ~f:(fun (_, bars) ->
      List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.date))
  |> List.dedup_and_sort ~compare:Date.compare

let _price_at ~rising date symbol =
  List.find_map (_bars_by_symbol ~rising) ~f:(fun (sym, bars) ->
      if String.equal sym symbol then
        List.find bars ~f:(fun (b : Types.Daily_price.t) ->
            Date.equal b.date date)
      else None)

let _no_indicator _symbol _name _period _cadence = None

(* A recorder that keeps each screening day's cascade diagnostics. Built by
   functional update from [Audit_recorder.noop] rather than as a record literal:
   the record has gained fields over the window this differential spans, and a
   literal would fail to compile at the older commits — which would silently
   reduce the differential to "the harness didn't build there". *)
let _capturing_recorder events =
  {
    Weinstein_strategy.Audit_recorder.noop with
    record_cascade_summary =
      (fun (e : Weinstein_strategy.Audit_recorder.cascade_event) ->
        events := (e.date, e.diagnostics, e.entered) :: !events);
  }

(** One replay step. Returns [None] on a non-screening day: stops still run, but
    no selection happens, so rendering those rows would quintuple the trace with
    lines that cannot distinguish two builds of the selection path. *)
let _replay_step (module S : Trading_strategy.Strategy_interface.STRATEGY)
    ~rising ~events date =
  let result =
    S.on_market_close ~get_price:(_price_at ~rising date)
      ~get_indicator:_no_indicator ~portfolio:_empty_portfolio
  in
  if not (Day_of_week.equal (Date.day_of_week date) Day_of_week.Fri) then None
  else
    match result with
    | Error e ->
        Some (sprintf "      %s ERROR %s" (Date.to_string date) (Status.show e))
    | Ok out ->
        let symbols =
          List.filter_map out.transitions
            ~f:(fun (t : Trading_strategy.Position.transition) ->
              match t.kind with
              | CreateEntering { symbol; _ } -> Some symbol
              | _ -> None)
        in
        (* The cascade funnel, not just the entry list. A week that enters
           nothing still has a funnel, and a refactor that moved an admission
           boundary shows up in the phase counts even when no entry fires. *)
        let funnel =
          match !events with
          | (d, diag, entered) :: _ when Date.equal d date ->
              sprintf " entered=%d %s" entered
                (Sexp.to_string_mach
                   (Screener.sexp_of_cascade_diagnostics diag))
          | _ -> " no-screen"
        in
        Some
          (sprintf "      %s enter=[%s]%s" (Date.to_string date)
             (String.concat ~sep:";" symbols)
             funnel)

(** Replay the whole series through one strategy instance. The portfolio is held
    constant (no fills are simulated), so every Friday re-screens the same
    universe — which is exactly what makes each step an independent observation
    of the selection path rather than a walk down one funded trajectory. *)
let _render_replay ~label ~rising =
  let config =
    Weinstein_strategy.default_config
      ~universe:(_index_symbol :: _universe_tickers)
      ~index_symbol:_index_symbol
  in
  let events = ref [] in
  (* The bar reader must be SUPPLIED. [on_market_close] does not accumulate
     history from [get_price] — with a default-empty reader the index weekly
     view stays empty, [is_screening_day_view] is never true, and the replay
     silently never screens at all. *)
  let s =
    Weinstein_strategy.make
      ~bar_reader:
        (Weinstein_strategy.Bar_reader.of_in_memory_bars
           (_bars_by_symbol ~rising))
      ~audit_recorder:(_capturing_recorder events)
      config
  in
  let steps =
    List.filter_map (_replay_dates ~rising) ~f:(_replay_step s ~rising ~events)
  in
  String.concat ~sep:"\n"
    (sprintf "  replay %s (%d screening days):" label (List.length steps)
    :: steps)

let _replays () =
  [
    _render_replay ~label:"index-rising" ~rising:true;
    _render_replay ~label:"index-falling" ~rising:false;
  ]

let render () =
  let cases = _all_cases () in
  let header =
    [
      "selection-trace v1";
      sprintf "universe: %d symbols" (List.length _universe_tickers);
      sprintf "cases: %d" (List.length cases);
    ]
  in
  String.concat ~sep:"\n" (header @ List.map cases ~f:_render_case @ _replays ())
  ^ "\n"
