open Core
open Trading_strategy
module Bar_history = Bar_history
module Stops_runner = Stops_runner

module Ad_bars = Ad_bars
(** NYSE advance/decline breadth data loader. Exposed as a top-level submodule
    so tests and external callers (e.g. live-mode boot) can load NYSE breadth
    data before wiring it into the strategy. *)

module Macro_inputs = Macro_inputs
(** Sector map + global index assembly from accumulated bar history. Exposes
    [spdr_sector_etfs] and [default_global_indices] as canonical constants for
    callers to use in {!config}. *)

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
  }

let name = "Weinstein"

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _position_counter = ref 0

let _gen_position_id symbol =
  Int.incr _position_counter;
  Printf.sprintf "%s-wein-%d" symbol !_position_counter

(** Try to build a CreateEntering transition for one screened candidate.
    Registers the initial stop state as a side effect. Returns None if the
    candidate is un-sizeable (zero portfolio value or zero shares).

    The initial stop is derived via
    {!Weinstein_stops.compute_initial_stop_with_floor}, which pulls the support
    floor (prior correction low) from the candidate's accumulated bar history;
    falls back to the fixed-buffer proxy
    ([suggested_entry *. initial_stop_buffer]) when the lookback window holds no
    qualifying correction. *)
let _make_entry_transition ~config ~stop_states ~bar_history ~portfolio_value
    ~current_date (cand : Screener.scored_candidate) =
  let sizing =
    Portfolio_risk.compute_position_size ~config:config.portfolio_config
      ~portfolio_value ~entry_price:cand.suggested_entry
      ~stop_price:cand.suggested_stop ()
  in
  if sizing.shares = 0 then None
  else
    let id = _gen_position_id cand.ticker in
    let daily_bars =
      Bar_history.daily_bars_for bar_history ~symbol:cand.ticker
    in
    let initial_stop =
      Weinstein_stops.compute_initial_stop_with_floor
        ~config:config.stops_config ~side:Trading_base.Types.Long
        ~entry_price:cand.suggested_entry ~bars:daily_bars ~as_of:current_date
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
          side = Trading_base.Types.Long;
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

    Bug fix (2026-04-17): previously returned every position in the portfolio
    regardless of state, including Closed. That permanently blacklisted every
    symbol the strategy had ever traded from re-entry via both [held_tickers]
    passed to the screener and the in-strategy candidate filter. See
    [dev/notes/strategy-dispatch-trace-2026-04-17.md] / PR #408.

    The match is exhaustive so a future state addition forces a compile error
    here, where the keep/drop decision must be re-examined. *)
let held_symbols (portfolio : Portfolio_view.t) =
  Map.data portfolio.positions
  |> List.filter_map ~f:(fun (p : Position.t) ->
      match p.state with
      | Entering _ | Holding _ | Exiting _ -> Some p.symbol
      | Closed _ -> None)

(** Generate CreateEntering transitions for top screener candidates. Tracks
    remaining cash to avoid generating orders that exceed funds. *)
let _entries_from_candidates ~config ~candidates ~stop_states ~bar_history
    ~(portfolio : Portfolio_view.t) ~get_price ~current_date =
  let held = held_symbols portfolio in
  let portfolio_value = Portfolio_view.portfolio_value portfolio ~get_price in
  let remaining_cash = ref portfolio.cash in
  let make_entry =
    _make_entry_transition ~config ~stop_states ~bar_history ~portfolio_value
      ~current_date
  in
  candidates
  |> List.filter ~f:(fun (c : Screener.scored_candidate) ->
      not (List.mem held c.ticker ~equal:String.equal))
  |> List.filter_map ~f:make_entry
  |> List.filter_map ~f:(_check_cash_and_deduct remaining_cash)

(** Screen the universe for buy candidates. Returns entry transitions. *)
let _screen_universe ~config ~index_bars ~macro_trend ~sector_map ~stop_states
    ~(portfolio : Portfolio_view.t) ~get_price ~bar_history ~prior_stages
    ~current_date =
  let _analyze_ticker ticker =
    let bars =
      Bar_history.weekly_bars_for bar_history ~symbol:ticker
        ~n:config.lookback_bars
    in
    if List.is_empty bars then None
    else
      let as_of_date =
        match List.last bars with
        | Some b -> b.Types.Daily_price.date
        | None -> current_date
      in
      let prior_stage = Hashtbl.find prior_stages ticker in
      let result =
        Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
          ~bars ~benchmark_bars:index_bars ~prior_stage ~as_of_date
      in
      Hashtbl.set prior_stages ~key:ticker ~data:result.stage.stage;
      Some result
  in
  let stocks = List.filter_map config.universe ~f:_analyze_ticker in
  let screen_result =
    Screener.screen ~config:config.screening_config ~macro_trend ~sector_map
      ~stocks ~held_tickers:(held_symbols portfolio)
  in
  _entries_from_candidates ~config
    ~candidates:screen_result.Screener.buy_candidates ~stop_states ~bar_history
    ~portfolio ~get_price ~current_date

(* ------------------------------------------------------------------ *)
(* make                                                                  *)
(* ------------------------------------------------------------------ *)

(** Stops are adjusted daily; screening runs only on Fridays (weekly review). *)
let _is_screening_day index_bars =
  match List.last index_bars with
  | None -> false
  | Some bar ->
      Date.day_of_week bar.Types.Daily_price.date
      |> Day_of_week.equal Day_of_week.Fri

(** Collect every symbol the strategy needs bar history for: universe tickers,
    the primary index, each sector ETF, and each global index. *)
let _all_accumulated_symbols ~(config : config) : string list =
  let sector_symbols = List.map config.sector_etfs ~f:fst in
  let global_symbols = List.map config.indices.global ~f:fst in
  (config.indices.primary :: config.universe) @ sector_symbols @ global_symbols

(** Run the Friday macro + screener path and return entry transitions. Returns
    [] if macro is Bearish (no new buys). *)
let _run_screen ~config ~ad_bars ~stop_states ~prior_macro ~bar_history
    ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio
    ~current_date ~index_bars =
  let index_prior_stage = Hashtbl.find prior_stages config.indices.primary in
  let global_index_bars =
    Macro_inputs.build_global_index_bars ~lookback_bars:config.lookback_bars
      ~global_index_symbols:config.indices.global ~bar_history
  in
  let macro_result =
    Macro.analyze ~config:config.macro_config ~index_bars ~ad_bars
      ~global_index_bars ~prior_stage:index_prior_stage ~prior:None
  in
  prior_macro := macro_result.trend;
  if Weinstein_types.(equal_market_trend !prior_macro Bearish) then []
  else
    let sector_map =
      Macro_inputs.build_sector_map ~stage_config:config.stage_config
        ~lookback_bars:config.lookback_bars ~sector_etfs:config.sector_etfs
        ~bar_history ~sector_prior_stages ~index_bars ~ticker_sectors
    in
    _screen_universe ~config ~index_bars ~macro_trend:macro_result.trend
      ~sector_map ~stop_states ~portfolio ~get_price ~bar_history ~prior_stages
      ~current_date

let _on_market_close ~config ~ad_bars ~stop_states ~prior_macro ~bar_history
    ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price
    ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  let positions = portfolio.positions in
  let all_symbols = _all_accumulated_symbols ~config in
  Bar_history.accumulate bar_history ~get_price ~symbols:all_symbols;
  let current_date =
    match get_price config.indices.primary with
    | Some bar -> bar.Types.Daily_price.date
    | None -> Date.today ~zone:Time_float.Zone.utc
  in
  let exit_transitions, adjust_transitions =
    Stops_runner.update ~stops_config:config.stops_config
      ~stage_config:config.stage_config ~lookback_bars:config.lookback_bars
      ~positions ~get_price ~stop_states ~bar_history ~prior_stages
  in
  let index_bars =
    Bar_history.weekly_bars_for bar_history ~symbol:config.indices.primary
      ~n:config.lookback_bars
  in
  let entry_transitions =
    if not (_is_screening_day index_bars) then []
    else
      _run_screen ~config ~ad_bars ~stop_states ~prior_macro ~bar_history
        ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio
        ~current_date ~index_bars
  in
  Ok
    {
      Strategy_interface.transitions =
        exit_transitions @ adjust_transitions @ entry_transitions;
    }

let make ?(initial_stop_states = String.Map.empty) ?(ad_bars = [])
    ?(ticker_sectors = Hashtbl.create (module String)) config =
  let stop_states = ref initial_stop_states in
  let prior_macro : Weinstein_types.market_trend ref =
    ref Weinstein_types.Neutral
  in
  let bar_history = Bar_history.create () in
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
        ~bar_history ~prior_stages ~sector_prior_stages ~ticker_sectors
  end in
  (module M : Strategy_interface.STRATEGY)
