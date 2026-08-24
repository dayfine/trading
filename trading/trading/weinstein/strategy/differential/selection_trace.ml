(** Deterministic selection-path trace. See [selection_trace.mli]. *)

open Core
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Fixture parameters. Every literal is bound to a name so the fixture  *)
(* is readable as a specification rather than a pile of constants.      *)
(* ------------------------------------------------------------------ *)

let _as_of = Date.of_string "2024-01-05"

(* A Friday. The replay section below feeds one bar per element of a series
   straight into [on_market_close], and the strategy screens only on Fridays, so
   a Friday-aligned weekly series makes every replay step a screening day. *)
let _series_origin = Date.of_string "2020-01-03"
let _days_per_week = 7
let _base_volume = 1_000
let _spike_volume = 3_000

(* A weaker-but-still-present volume expansion. Yields a lower volume score than
   [_spike_volume], which is what gives the fixture a SECOND admitted score
   tier — without one, every cap in the sweep would cut inside a single tie
   group and a cross-tier ordering change would go unseen. *)
let _moderate_spike_volume = 1_800
let _intrabar_high_mult = 1.02
let _intrabar_low_mult = 0.98
let _index_symbol = "GSPCX"
let _portfolio_cash = 250_000.0
let _fill_volume = 1_000_000
let _score_probe_offsets = [ -1; 0; 1 ]

(* ------------------------------------------------------------------ *)
(* Bar construction                                                     *)
(* ------------------------------------------------------------------ *)

let _bar ~volume ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close *. _intrabar_high_mult;
    low_price = close *. _intrabar_low_mult;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

(** Weekly bars from [(close, volume)] pairs, one week apart from
    [_series_origin]. *)
let _weekly_bars closes_and_volumes =
  List.mapi closes_and_volumes ~f:(fun i (close, volume) ->
      let date = Date.add_days _series_origin (i * _days_per_week) in
      _bar ~volume ~date ~close)

(** [n] evenly spaced closes from [from_] to [to_] inclusive. *)
let _ramp ~n ~from_ ~to_ =
  let step = (to_ -. from_) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> from_ +. (Float.of_int i *. step))

(** Attach [_base_volume] to every close except [spike_idx], which gets
    [_spike_volume] — the volume expansion Weinstein requires at a breakout. *)
let _volumes_with_spike ?(spike = _spike_volume) ~spike_idx closes =
  List.mapi closes ~f:(fun i close ->
      (close, if i = spike_idx then spike else _base_volume))

(* ------------------------------------------------------------------ *)
(* Universe shapes                                                      *)
(* ------------------------------------------------------------------ *)

(* Must exceed [Weinstein_strategy] config's [lookback_bars = 52], or the
   replay's weekly window is shorter than the strategy's lookback and no symbol
   is ever classifiable — the replay then emits nothing on every step and the
   trace is stable because it is empty, not because the code agrees. *)
let _base_weeks = 60
let _advance_weeks = 8
let _late_advance_weeks = 24
let _base_price = 50.0
let _breakout_price = 90.0
let _late_top_price = 140.0
let _decline_top = 120.0
let _decline_bottom = 40.0
let _decline_weeks = 40

(** A Stage-1 base followed by a Stage-2 advance with a volume spike at the
    breakout bar. [advance_weeks] controls [weeks_advancing], which is what
    separates an early Stage 2 from a late one. *)
let _breakout_series ?spike ~advance_weeks ~top () =
  let base = List.init _base_weeks ~f:(fun _ -> _base_price) in
  let advance = _ramp ~n:advance_weeks ~from_:_base_price ~to_:top in
  _volumes_with_spike ?spike ~spike_idx:_base_weeks (base @ advance)
  |> _weekly_bars

(** A flat base with no advance — Stage 1, must never be admitted (spine item:
    buy only in Stage 2). *)
let _basing_series () =
  let base =
    List.init (_base_weeks + _advance_weeks) ~f:(fun _ -> _base_price)
  in
  List.map base ~f:(fun c -> (c, _base_volume)) |> _weekly_bars

(** A sustained decline below a falling MA — Stage 4, the short-side cohort. *)
let _declining_series () =
  let top = List.init _base_weeks ~f:(fun _ -> _decline_top) in
  let decline =
    _ramp ~n:_decline_weeks ~from_:_decline_top ~to_:_decline_bottom
  in
  _volumes_with_spike ~spike_idx:(_base_weeks + 1) (top @ decline)
  |> _weekly_bars

type shape =
  | Early_breakout
  | Modest_breakout
  | Late_breakout
  | Basing
  | Declining

let _series_of_shape = function
  | Early_breakout ->
      _breakout_series ~advance_weeks:_advance_weeks ~top:_breakout_price ()
  | Modest_breakout ->
      _breakout_series ~spike:_moderate_spike_volume
        ~advance_weeks:_advance_weeks ~top:_breakout_price ()
  | Late_breakout ->
      _breakout_series ~advance_weeks:_late_advance_weeks ~top:_late_top_price
        ()
  | Basing -> _basing_series ()
  | Declining -> _declining_series ()

let _prior_stage_of_shape = function
  | Early_breakout | Modest_breakout | Late_breakout | Basing ->
      Some (Stage1 { weeks_in_base = _base_weeks })
  | Declining -> Some (Stage3 { weeks_topping = _advance_weeks })

let _analysis ~ticker ~shape =
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
    ~bars:(_series_of_shape shape) ~benchmark_bars:[]
    ~prior_stage:(_prior_stage_of_shape shape)
    ~as_of_date:_as_of

(* ------------------------------------------------------------------ *)
(* The universe                                                         *)
(* ------------------------------------------------------------------ *)

(* Tie groups are the load-bearing part of this fixture. Members of a group
   share a shape verbatim, so their analyses — and therefore their scores — are
   exactly equal, and only the ticker distinguishes them. Two things become
   observable that generic random input hides:

   - the equal-score tiebreak (a change reorders the group), and
   - the top-N cap when it cuts THROUGH a group (a >= / > flip at the cap, or a
     reorder, changes WHICH member survives).

   Tickers are deliberately listed out of alphabetical order so "the order the
   screener emitted" and "the order they were fed in" cannot be confused. *)
let _tie_group_a = [ "TIEM"; "TIEA"; "TIEZ"; "TIEC"; "TIEQ" ]
let _tie_group_b = [ "MIDX"; "MIDB"; "MIDN" ]
let _late_group = [ "LATEP"; "LATED" ]
let _short_group = [ "FALLR"; "FALLA"; "FALLK" ]

let _universe_spec =
  List.concat
    [
      List.map _tie_group_a ~f:(fun t -> (t, Early_breakout));
      List.map _tie_group_b ~f:(fun t -> (t, Modest_breakout));
      List.map _late_group ~f:(fun t -> (t, Late_breakout));
      List.map _short_group ~f:(fun t -> (t, Declining));
      [ ("BASE1", Basing); ("BASE2", Basing) ];
    ]

let _stocks =
  List.map _universe_spec ~f:(fun (ticker, shape) -> _analysis ~ticker ~shape)

let _universe_tickers = List.map _universe_spec ~f:fst

(* Sector ratings are assigned by group, not round-robin, so each group probes a
   distinct arm of the sector gate: Weak blocks longs, Strong blocks shorts. *)
let _sector ~rating name : Screener.sector_context =
  {
    sector_name = name;
    rating;
    stage = Stage2 { weeks_advancing = 5; late = false };
  }

let _sector_of_ticker ticker =
  if List.mem _tie_group_a ticker ~equal:String.equal then
    _sector ~rating:Screener.Strong "Technology"
  else if List.mem _tie_group_b ticker ~equal:String.equal then
    _sector ~rating:Screener.Neutral "Industrials"
  else if List.mem _short_group ticker ~equal:String.equal then
    _sector ~rating:Screener.Weak "Energy"
  else _sector ~rating:Screener.Neutral "Utilities"

let _sector_map () =
  let m = Hashtbl.create (module String) in
  List.iter _universe_tickers ~f:(fun t ->
      Hashtbl.set m ~key:t ~data:(_sector_of_ticker t));
  m

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
(* Cases                                                                *)
(* ------------------------------------------------------------------ *)

type case = {
  label : string;
  config : Screener.config;
  macro : market_trend;
  held : string list;
  stop_outs : (string * Date.t) list;
  use_plain_screen : bool;
      (** [true] drives {!Screener.screen} directly rather than
          {!Screener.screen_with_cooldown}, so the thin wrapper is covered as
          its own entry point rather than assumed equivalent. *)
}

let _case ?(held = []) ?(stop_outs = []) ?(use_plain_screen = false) ~label
    ~config ~macro () =
  { label; config; macro; held; stop_outs; use_plain_screen }

let _base_config = Screener.default_config
let _all_trends = [ Bullish; Neutral; Bearish ]

(** Macro gate x plain-vs-cooldown entry point. The macro gate is an
    unconditional spine item, so every trend is walked. *)
let _macro_cases () =
  List.concat_map _all_trends ~f:(fun macro ->
      let name = Sexp.to_string (sexp_of_market_trend macro) in
      [
        _case
          ~label:(sprintf "macro/%s/screen" name)
          ~config:_base_config ~macro ~use_plain_screen:true ();
        _case
          ~label:(sprintf "macro/%s/cooldown" name)
          ~config:_base_config ~macro ();
      ])

(** Ranking modes: a tiebreak change is invisible unless the tie group is ranked
    under each mode the config can express. *)
let _ranking_cases () =
  List.map
    [ Screener.Alphabetical; Screener.Quality; Screener.Quality_earliness ]
    ~f:(fun ranking ->
      let label =
        sprintf "ranking/%s"
          (Sexp.to_string (Screener.sexp_of_candidate_ranking ranking))
      in
      _case ~label
        ~config:{ _base_config with candidate_ranking = ranking }
        ~macro:Bullish ())

(** Cap sweep. [max_buy_candidates] is walked across the whole universe size so
    that at least one cap lands strictly inside a tie group — the case where a
    reorder or an off-by-one at the cap changes which symbol is selected. *)
let _cap_cases () =
  List.init
    (List.length _universe_tickers + 1)
    ~f:(fun cap ->
      _case
        ~label:(sprintf "cap/max_buy=%d" cap)
        ~config:{ _base_config with max_buy_candidates = cap }
        ~macro:Bullish ())

(** Held / cooldown gates. The cooldown boundary is probed at exactly
    [cooldown_weeks] before [_as_of] — a [>=] / [>] flip at that edge admits or
    blocks the symbol. *)
let _cooldown_cases () =
  let weeks = 4 in
  let exact = Date.add_days _as_of (-weeks * _days_per_week) in
  let victim = List.hd_exn _tie_group_a in
  List.concat_map
    [ (-1, "inside"); (0, "exact"); (1, "outside") ]
    ~f:(fun (shift, name) ->
      let d = Date.add_days exact (shift * _days_per_week) in
      [
        _case
          ~label:(sprintf "cooldown/%s" name)
          ~config:{ _base_config with cascade_post_stop_cooldown_weeks = weeks }
          ~macro:Bullish
          ~stop_outs:[ (victim, d) ]
          ();
      ])

let _held_cases () =
  [
    _case ~label:"held/one" ~config:_base_config ~macro:Bullish
      ~held:[ List.hd_exn _tie_group_a ]
      ();
    _case ~label:"held/all-ties" ~config:_base_config ~macro:Bullish
      ~held:_tie_group_a ();
  ]

(* ------------------------------------------------------------------ *)
(* Boundary cases derived from the fixture's own observed values        *)
(* ------------------------------------------------------------------ *)

let _reference_result () =
  Screener.screen ~config:_base_config ~macro_trend:Neutral
    ~sector_map:(_sector_map ()) ~stocks:_stocks ~held_tickers:[]

let _observed_scores () =
  let r = _reference_result () in
  List.map (r.buy_candidates @ r.short_candidates) ~f:(fun c ->
      c.Screener.score)
  |> List.dedup_and_sort ~compare:Int.compare

let _observed_breakout_prices () =
  List.filter_map _stocks ~f:(fun (a : Stock_analysis.t) -> a.breakout_price)
  |> List.dedup_and_sort ~compare:Float.compare

(** Score-floor and score-ceiling probes at, just below, and just above every
    score the fixture actually produces. [min_score_override] is a [score >= n]
    gate and [max_score_override] a [score < m] gate, so an inclusive/exclusive
    flip in either shows up as a candidate appearing or vanishing at exactly one
    of these offsets. *)
let _score_boundary_cases () =
  List.concat_map (_observed_scores ()) ~f:(fun score ->
      List.concat_map _score_probe_offsets ~f:(fun offset ->
          let n = score + offset in
          [
            _case
              ~label:(sprintf "score/min>=%d" n)
              ~config:{ _base_config with min_score_override = Some n }
              ~macro:Bullish ();
            _case ~label:(sprintf "score/max<%d" n)
              ~config:{ _base_config with max_score_override = Some n }
              ~macro:Bullish ();
          ]))

(** Price-floor probes at exactly each observed breakout price. [min_price] is a
    [p >= floor] gate; setting the floor to a candidate's own breakout price is
    the single input that distinguishes [>=] from [>]. *)
let _price_boundary_cases () =
  List.map (_observed_breakout_prices ()) ~f:(fun price ->
      _case
        ~label:(sprintf "price/min=%.6f" price)
        ~config:{ _base_config with min_price = price }
        ~macro:Bullish ())

(* ------------------------------------------------------------------ *)
(* Fixture exports (see the .mli)                                       *)
(* ------------------------------------------------------------------ *)

let as_of = _as_of
let stocks = _stocks
let universe_tickers = _universe_tickers
let sector_map = _sector_map
let tie_group = List.sort _tie_group_a ~compare:String.compare

let _all_cases () =
  List.concat
    [
      _macro_cases ();
      _ranking_cases ();
      _cap_cases ();
      _cooldown_cases ();
      _held_cases ();
      _score_boundary_cases ();
      _price_boundary_cases ();
    ]

let case_count = List.length (_all_cases ())

(* ------------------------------------------------------------------ *)
(* Execution                                                            *)
(* ------------------------------------------------------------------ *)

let _run_screen case =
  if case.use_plain_screen then
    Screener.screen ~config:case.config ~macro_trend:case.macro
      ~sector_map:(_sector_map ()) ~stocks:_stocks ~held_tickers:case.held
  else
    Screener.screen_with_cooldown ~config:case.config ~macro_trend:case.macro
      ~sector_map:(_sector_map ()) ~stocks:_stocks ~held_tickers:case.held
      ~as_of:_as_of ~last_stop_out_dates:case.stop_outs ()

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
