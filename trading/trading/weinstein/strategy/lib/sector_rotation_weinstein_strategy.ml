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

(* Overnight gap buffer for cash sizing — mirrors
   [Spy_only_weinstein_strategy._entry_gap_buffer_pct]. *)
let _entry_gap_buffer_pct = 0.01

let _position_id_of_symbol (symbol : string) : string =
  Printf.sprintf "%s-sector-rotation-weinstein" symbol

let _is_weekly_close ~(date : Date.t) : bool =
  Date.day_of_week date |> Day_of_week.equal Day_of_week.Fri

(* Whole shares affordable at [close_price] for [cash], gap buffer applied.
   [None] when the cash cannot buy a single share or inputs are non-positive. *)
let _shares_from_cash ~(cash : float) ~(close_price : float) : float option =
  if Float.(cash <= 0.0) || Float.(close_price <= 0.0) then None
  else
    let sizing_price = close_price *. (1.0 +. _entry_gap_buffer_pct) in
    let shares = Float.round_down (cash /. sizing_price) in
    Option.some_if Float.(shares > 0.0) shares

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

let _holding_quantity (pos : Position.t) : float option =
  match pos.state with
  | Position.Holding h -> Some h.quantity
  | Position.Entering _ | Position.Exiting _ | Position.Closed _ -> None

(* The [(entry_price, entry_date)] anchor of a [Holding] position — what the
   initial stop's support floor is computed against. [None] for any other
   state. *)
let _holding_entry (pos : Position.t) : (float * Date.t) option =
  match pos.state with
  | Position.Holding h -> Some (h.entry_price, h.entry_date)
  | Position.Entering _ | Position.Exiting _ | Position.Closed _ -> None

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

(* Seed the initial trailing stop for a long entry from the support-floor
   lookup, falling back to the fixed buffer. *)
let _seed_stop ~config ~bar_reader ~(symbol : string) ~(entry_price : float)
    ~(as_of : Date.t) : Weinstein_stops.stop_state =
  let bars = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of in
  Weinstein_stops.compute_initial_stop_with_floor ~config:config.stops_config
    ~side:Position.Long ~entry_price ~bars ~as_of
    ~fallback_buffer:config.fallback_stop_buffer

(* Map a stop state-machine event to an optional exit transition. *)
let _exit_of_stop_event ~(pos : Position.t) ~(bar : Types.Daily_price.t)
    ~(event : Weinstein_stops.stop_event) : Position.transition option =
  match event with
  | Weinstein_stops.Stop_hit { stop_level; _ } ->
      Some (Spy_only_transitions.build_stop_exit ~pos ~bar ~stop_level)
  | Weinstein_stops.Stop_raised _ | Weinstein_stops.Entered_tightening _
  | Weinstein_stops.No_change ->
      None

(* Weekly-close stop advance against the stage read [r]. *)
let _advance_stop ~config ~(r : Stage.result)
    ~(state : Weinstein_stops.stop_state) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) :
    Weinstein_stops.stop_state * Position.transition option =
  let new_state, event =
    Weinstein_stops.update ~config:config.stops_config ~side:Position.Long
      ~state ~current_bar:bar ~ma_value:r.ma_value ~ma_direction:r.ma_direction
      ~stage:r.stage
  in
  (new_state, _exit_of_stop_event ~pos ~bar ~event)

(* Advance the trailing stop one tick on a held long position and decide whether
   it triggers an exit. Intraday only the trigger check runs; on a weekly close
   the state machine also advances. *)
let _step_stop ~config ~(stage_result : Stage.result option)
    ~(state : Weinstein_stops.stop_state) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) :
    Weinstein_stops.stop_state * Position.transition option =
  if Weinstein_stops.check_stop_hit ~state ~side:Position.Long ~bar then
    let stop_level = Weinstein_stops.get_stop_level state in
    (state, Some (Spy_only_transitions.build_stop_exit ~pos ~bar ~stop_level))
  else if not (_is_weekly_close ~date:bar.date) then (state, None)
  else
    match stage_result with
    | None -> (state, None)
    | Some r -> _advance_stop ~config ~r ~state ~pos ~bar

(* Seed the stop the first time we observe the position in Holding, anchoring on
   the recorded entry price/date (not today's bar). *)
let _seed_or_keep_stop ~config ~bar_reader ~(symbol : string)
    ~(existing : Weinstein_stops.stop_state option) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) : Weinstein_stops.stop_state =
  match existing with
  | Some s -> s
  | None ->
      let entry_price, entry_date =
        Option.value (_holding_entry pos) ~default:(bar.close_price, bar.date)
      in
      _seed_stop ~config ~bar_reader ~symbol ~entry_price ~as_of:entry_date

(* The per-symbol weekly stage read, recording the new prior stage. Used by the
   holding branch (the flat/rotation branch reads via [_target_set]). *)
let _holding_stage_read ~config ~bar_reader ~prior_stage ~(symbol : string)
    ~(as_of : Date.t) : Stage.result option =
  let prior = Map.find !prior_stage symbol in
  let r = _classify_stage ~config ~bar_reader ~prior ~symbol ~as_of in
  Option.iter r ~f:(fun r ->
      prior_stage := Map.set !prior_stage ~key:symbol ~data:r.stage);
  r

(* The Friday stage-or-rotation exit for a held long when the stop did not fire:
   exit when the held stage read warrants it (Stage-4 roll-over) OR the symbol
   has left the top-[k] target set. [None] outside a weekly close. *)
let _stage_or_rotation_exit ~(in_target : bool)
    ~(stage_result : Stage.result option) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) : Position.transition option =
  if not (_is_weekly_close ~date:bar.date) then None
  else
    let stage_exit =
      Option.bind stage_result
        ~f:(Spy_only_signals.stage_exit_label_for_side ~side:Position.Long)
    in
    match stage_exit with
    | Some label -> Some (Spy_only_transitions.build_exit ~pos ~bar ~label)
    | None ->
        if in_target then None
        else
          Some (Spy_only_transitions.build_exit ~pos ~bar ~label:"rotation_out")

(* Holding branch for one symbol: run the stop, and on a Friday also test the
   stage / rotation exit. The stop takes precedence. Mutates [stop_state] /
   [prior_stage]; clears [stop_state] for the symbol on any exit so a re-entry
   re-seeds. Returns the (at most one) exit transition. *)
let _on_holding_symbol ~config ~bar_reader ~stop_state ~prior_stage ~target
    ~(symbol : string) ~(pos : Position.t) ~(bar : Types.Daily_price.t) :
    Position.transition list =
  let stage_result =
    _holding_stage_read ~config ~bar_reader ~prior_stage ~symbol ~as_of:bar.date
  in
  let state =
    _seed_or_keep_stop ~config ~bar_reader ~symbol
      ~existing:(Map.find !stop_state symbol)
      ~pos ~bar
  in
  let new_state, stop_exit =
    _step_stop ~config ~stage_result ~state ~pos ~bar
  in
  let in_target = Set.mem target symbol in
  let exit =
    match stop_exit with
    | Some _ -> stop_exit
    | None -> _stage_or_rotation_exit ~in_target ~stage_result ~pos ~bar
  in
  (match exit with
  | Some _ -> stop_state := Map.remove !stop_state symbol
  | None -> stop_state := Map.set !stop_state ~key:symbol ~data:new_state);
  Option.to_list exit

(* Run the holding branch for every live holding, accumulating exits. The target
   set is empty off a weekly close (no rotation decision is made then), so the
   only mid-week exit path is the trailing stop. *)
let _holding_exits ~config ~bar_reader ~stop_state ~prior_stage ~target
    ~(holdings : Position.t String.Map.t)
    ~(get_price : string -> Types.Daily_price.t option) :
    Position.transition list =
  Map.to_alist holdings
  |> List.concat_map ~f:(fun (symbol, pos) ->
      match (_holding_quantity pos, get_price symbol) with
      | Some _, Some bar ->
          _on_holding_symbol ~config ~bar_reader ~stop_state ~prior_stage
            ~target ~symbol ~pos ~bar
      | _ -> [])

(* Build the entry transitions for target symbols not yet held. Cash is split
   equally across the open slots being filled this Friday — degenerating to
   all-cash sizing when one slot is open (k = 1). Symbols with no price today, or
   too little per-slot cash for a whole share, are skipped. *)
let _entry_transitions ~(cash : float) ~(target : String.Set.t)
    ~(holdings : Position.t String.Map.t)
    ~(get_price : string -> Types.Daily_price.t option) :
    Position.transition list =
  let to_enter =
    Set.to_list target |> List.filter ~f:(fun s -> not (Map.mem holdings s))
  in
  let open_slots = List.length to_enter in
  if open_slots = 0 then []
  else
    let per_slot_cash = cash /. Float.of_int open_slots in
    List.filter_map to_enter ~f:(fun symbol ->
        match get_price symbol with
        | None -> None
        | Some bar ->
            _shares_from_cash ~cash:per_slot_cash ~close_price:bar.close_price
            |> Option.map ~f:(fun target_quantity ->
                Spy_only_transitions.build_entry
                  ~position_id:(_position_id_of_symbol symbol)
                  ~symbol ~side:Position.Long ~bar ~target_quantity))

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
    _holding_exits ~config ~bar_reader ~stop_state ~prior_stage ~target
      ~holdings ~get_price
  in
  let entries = _entry_transitions ~cash ~target ~holdings ~get_price in
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
