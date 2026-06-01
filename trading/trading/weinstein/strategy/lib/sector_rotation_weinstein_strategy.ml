(** Sector-rotation Weinstein stage-timing strategy — see
    [sector_rotation_weinstein_strategy.mli]. *)

open Core
open Trading_strategy

type config = {
  symbols : string list;
  benchmark_symbol : string;
  k : int;
  stage_config : Stage.config;
  stops_config : Weinstein_stops.config;
  rs_config : Rs.config;
  fallback_stop_buffer : float;
}

let name = "SectorRotationWeinstein"

(* The 11 SPDR sector ETFs (full GICS taxonomy). The benchmark (SPY) is
   deliberately NOT in this list — it is used only for RS ranking. *)
let default_symbols =
  [
    "XLK"; "XLF"; "XLI"; "XLV"; "XLE"; "XLP"; "XLY"; "XLU"; "XLB"; "XLRE"; "XLC";
  ]

let default_benchmark_symbol = "SPY"
let default_k = 1
let default_fallback_stop_buffer = 0.92

let default_config =
  {
    symbols = default_symbols;
    benchmark_symbol = default_benchmark_symbol;
    k = default_k;
    stage_config = Stage.default_config;
    stops_config = Weinstein_stops.default_config;
    rs_config = Rs.default_config;
    fallback_stop_buffer = default_fallback_stop_buffer;
  }

let config_with ?(symbols = default_symbols)
    ?(benchmark_symbol = default_benchmark_symbol) ~k ~ma_period_weeks () =
  {
    default_config with
    symbols;
    benchmark_symbol;
    k;
    stage_config =
      { default_config.stage_config with ma_period = ma_period_weeks };
  }

(* Number of weekly bars fed to [Stage.classify] / [Rs.analyze]: twice the MA
   period (MA plus an equal slope/prior-stage margin), floored at
   [_min_stage_weeks] so a short trader MA still warms up. The RS analyzer needs
   [rs_config.rs_ma_period] aligned weeks; we read at least that many too. *)
let _min_stage_weeks = 12
let _stage_weeks_ma_multiplier = 2

let _weekly_window (config : config) : int =
  Int.max
    (Int.max _min_stage_weeks
       (_stage_weeks_ma_multiplier * config.stage_config.ma_period))
    config.rs_config.rs_ma_period

let _is_weekly_close ~(date : Date.t) : bool =
  Date.day_of_week date |> Day_of_week.equal Day_of_week.Fri

(* The strategy's live position for [symbol], if any — only [Entering] /
   [Holding] count as live. *)
let _live_position ~(symbol : string) ~(positions : Position.t String.Map.t) :
    Position.t option =
  Map.data positions
  |> List.find ~f:(fun (p : Position.t) ->
      String.equal p.symbol symbol
      &&
      match p.state with
      | Position.Entering _ | Position.Holding _ -> true
      | Position.Exiting _ | Position.Closed _ -> false)

(* The live (Entering/Holding) positions this strategy owns, keyed by symbol. *)
let _live_holdings ~config ~(positions : Position.t String.Map.t) :
    Position.t String.Map.t =
  List.filter_map config.symbols ~f:(fun symbol ->
      _live_position ~symbol ~positions |> Option.map ~f:(fun p -> (symbol, p)))
  |> String.Map.of_alist_exn

(* Weekly stage read for [symbol] from its own weekly bars. [prior] threads the
   previous classification for flat-MA disambiguation. [None] on warmup. *)
let _classify_stage ~config ~bar_reader ~(prior : Weinstein_types.stage option)
    ~(symbol : string) ~(as_of : Date.t) : Stage.result option =
  match
    Bar_reader.weekly_bars_for bar_reader ~symbol ~n:(_weekly_window config)
      ~as_of
  with
  | [] -> None
  | bars ->
      Some (Stage.classify ~config:config.stage_config ~bars ~prior_stage:prior)

(* RS of [symbol] vs the benchmark on weekly bars, as the normalized score the
   ranking uses. [None] when either series is too short to compute RS. *)
let _normalized_rs ~config ~bar_reader ~(symbol : string) ~(as_of : Date.t) :
    float option =
  let weekly s =
    Bar_reader.weekly_bars_for bar_reader ~symbol:s ~n:(_weekly_window config)
      ~as_of
  in
  Rs.analyze ~config:config.rs_config ~stock_bars:(weekly symbol)
    ~benchmark_bars:(weekly config.benchmark_symbol)
  |> Option.map ~f:(fun (r : Rs.result) -> r.current_normalized)

(* A Stage-2-eligible candidate for [symbol] on this Friday, if it is Stage 2 on
   a rising MA AND its RS is computable. Records the new prior stage. *)
let _candidate_for ~config ~bar_reader ~prior_stage ~(symbol : string)
    ~(as_of : Date.t) : Sector_rotation_signals.candidate option =
  let prior = Map.find !prior_stage symbol in
  let stage_result =
    _classify_stage ~config ~bar_reader ~prior ~symbol ~as_of
  in
  Option.iter stage_result ~f:(fun r ->
      prior_stage := Map.set !prior_stage ~key:symbol ~data:r.stage);
  match stage_result with
  | Some r when Sector_rotation_signals.is_stage2_advance r ->
      _normalized_rs ~config ~bar_reader ~symbol ~as_of
      |> Option.map ~f:(fun normalized_rs ->
          { Sector_rotation_signals.symbol; normalized_rs })
  | Some _ | None -> None

(* The target set this Friday: the top-[k] Stage-2 symbols by RS. Mutates
   [prior_stage] for every tradable symbol as a side effect of classifying. *)
let _target_set ~config ~bar_reader ~prior_stage ~(as_of : Date.t) :
    String.Set.t =
  let candidates =
    List.filter_map config.symbols ~f:(fun symbol ->
        _candidate_for ~config ~bar_reader ~prior_stage ~symbol ~as_of)
  in
  Sector_rotation_signals.rank_top_k ~candidates ~k:config.k

(* The target set for this tick: the top-[k] Stage-2 names on a weekly close
   (which also refreshes [prior_stage] for all symbols), else empty (no rotation
   decision mid-week). [as_of] anchors the weekly reads. *)
let _target_for_tick ~config ~bar_reader ~prior_stage ~(as_of : Date.t) :
    String.Set.t =
  if _is_weekly_close ~date:as_of then
    _target_set ~config ~bar_reader ~prior_stage ~as_of
  else String.Set.empty

(* One tick's transitions, anchored at [date]: exit rotated-out / Stage-4 /
   stopped holdings, then enter target symbols not yet held. Off a weekly close
   the target set is empty, so no rotation and no entries occur — only the daily
   per-symbol trailing stop can exit. *)
let _transitions_for_tick ~config ~bar_reader ~stop_state ~prior_stage
    ~(holdings : Position.t String.Map.t) ~(cash : float)
    ~(get_price : string -> Types.Daily_price.t option) ~(date : Date.t) :
    Position.transition list =
  let target = _target_for_tick ~config ~bar_reader ~prior_stage ~as_of:date in
  let exits =
    Sector_rotation_transitions.holding_exits ~stops_config:config.stops_config
      ~stage_config:config.stage_config ~weekly_window:(_weekly_window config)
      ~bar_reader ~fallback_buffer:config.fallback_stop_buffer ~stop_state
      ~prior_stage ~target ~holdings ~get_price
  in
  let entries =
    Sector_rotation_transitions.entry_transitions ~cash ~target ~holdings
      ~get_price
  in
  exits @ entries

let _on_market_close config ~bar_reader ~stop_state ~prior_stage ~get_price
    ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  let holdings = _live_holdings ~config ~positions:portfolio.positions in
  (* A representative date for the weekly-close test: any tradable symbol's bar.
     The simulator advances all symbols on the same calendar day, so any present
     bar's date is the tick's date. *)
  let as_of =
    List.find_map config.symbols ~f:(fun s ->
        get_price s |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.date))
  in
  let transitions =
    match as_of with
    | None -> []
    | Some date ->
        _transitions_for_tick ~config ~bar_reader ~stop_state ~prior_stage
          ~holdings ~cash:portfolio.cash ~get_price ~date
  in
  Result.return { Strategy_interface.transitions }

let make ?(config = default_config) ~bar_reader () :
    (module Strategy_interface.STRATEGY) =
  let stop_state : Weinstein_stops.stop_state String.Map.t ref =
    ref String.Map.empty
  in
  let prior_stage : Weinstein_types.stage String.Map.t ref =
    ref String.Map.empty
  in
  let module M = struct
    let on_market_close =
      _on_market_close config ~bar_reader ~stop_state ~prior_stage

    let name = name
  end in
  (module M : Strategy_interface.STRATEGY)
