(** Single-instrument Weinstein stage-timing strategy — see
    [spy_only_weinstein_strategy.mli]. *)

open Core
open Trading_strategy

type config = {
  symbol : string;
  stage_config : Stage.config;
  stops_config : Weinstein_stops.config;
  fallback_stop_buffer : float;
}

let name = "SpyOnlyWeinstein"
let default_symbol = "SPY"
let default_fallback_stop_buffer = 0.92

let default_config =
  {
    symbol = default_symbol;
    stage_config = Stage.default_config;
    stops_config = Weinstein_stops.default_config;
    fallback_stop_buffer = default_fallback_stop_buffer;
  }

(* Number of weekly bars fed to [Stage.classify]. The 30-week MA plus slope
   lookback need a comfortable margin; 60 weeks (~14 months) is enough to warm
   up the MA and still bound the read. *)
let _stage_weeks = 60

(* Overnight gap buffer for all-cash sizing, identical in spirit to
   [Bah_benchmark_strategy._entry_gap_buffer_pct]: size against
   [close * (1 + buffer)] so a small gap-up between today's sizing close and
   tomorrow's fill open does not bust the cash budget and stall the entry. *)
let _entry_gap_buffer_pct = 0.01

let _position_id_of_symbol (symbol : string) : string =
  Printf.sprintf "%s-spy-only-weinstein" symbol

let _is_weekly_close ~(date : Date.t) : bool =
  Date.day_of_week date |> Day_of_week.equal Day_of_week.Fri

(* All-cash sizing: whole shares affordable at [close_price], with the gap
   buffer applied. Returns [None] when the cash cannot buy a single share or
   inputs are non-positive. *)
let _shares_from_cash ~(cash : float) ~(close_price : float) : float option =
  if Float.(cash <= 0.0) || Float.(close_price <= 0.0) then None
  else
    let sizing_price = close_price *. (1.0 +. _entry_gap_buffer_pct) in
    let shares = Float.round_down (cash /. sizing_price) in
    Option.some_if Float.(shares > 0.0) shares

(* The strategy's single live position, if any, drawn from the portfolio
   snapshot. Returns the position only when it is in [Entering] or [Holding]
   for our configured symbol — a [Closed] / [Exiting] record is treated as "not
   live" so we neither double-enter nor re-exit. *)
let _live_position ~(symbol : string) ~(positions : Position.t String.Map.t) :
    Position.t option =
  Map.data positions
  |> List.find ~f:(fun (p : Position.t) ->
      String.equal p.symbol symbol
      &&
      match p.state with
      | Position.Entering _ | Position.Holding _ -> true
      | Position.Exiting _ | Position.Closed _ -> false)

(* True when [pos] is in [Holding] — the only state in which the trailing stop
   is live and an exit signal can fire. *)
let _holding_quantity (pos : Position.t) : float option =
  match pos.state with
  | Position.Holding h -> Some h.quantity
  | Position.Entering _ | Position.Exiting _ | Position.Closed _ -> None

(* The [(entry_price, entry_date)] of a [Holding] position — the anchor the
   initial stop's support floor is computed against (NOT today's close, which on
   a crash bar would place the stop far below the trigger and silently disarm
   it). Returns [None] for any non-[Holding] state. *)
let _holding_entry (pos : Position.t) : (float * Date.t) option =
  match pos.state with
  | Position.Holding h -> Some (h.entry_price, h.entry_date)
  | Position.Entering _ | Position.Exiting _ | Position.Closed _ -> None

(* Stage signal from the symbol's own weekly bars. [prior_stage] threads the
   previous classification for flat-MA Stage1/Stage3 disambiguation. Returns
   [None] when there are no weekly bars yet (warmup). *)
let _classify_stage ~config ~bar_reader ~prior_stage ~(as_of : Date.t) :
    Stage.result option =
  let bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol:config.symbol ~n:_stage_weeks
      ~as_of
  in
  match bars with
  | [] -> None
  | _ ->
      Some
        (Stage.classify ~config:config.stage_config ~bars
           ~prior_stage:!prior_stage)

(* A Weinstein "exit to flat" signal: the symbol has rolled from a topping
   Stage 3 into a declining Stage 4, or is already in Stage 4. Stage 1/2 and a
   bare Stage 3 (still topping, not yet broken) do not exit. *)
let _is_exit_signal (result : Stage.result) : bool =
  match result.stage with
  | Weinstein_types.Stage4 _ -> true
  | Weinstein_types.Stage3 _ | Weinstein_types.Stage2 _
  | Weinstein_types.Stage1 _ -> (
      match result.transition with
      | Some (Weinstein_types.Stage3 _, Weinstein_types.Stage4 _) -> true
      | _ -> false)

(* An entry signal: the symbol is in Stage 2 (advancing above a rising 30-week
   MA). The classifier already encodes "above rising MA"; we additionally
   require the MA itself to be rising so we never buy a flat-MA basing tape. *)
let _is_entry_signal (result : Stage.result) : bool =
  match result.stage with
  | Weinstein_types.Stage2 _ ->
      Weinstein_types.equal_ma_direction result.ma_direction
        Weinstein_types.Rising
  | Weinstein_types.Stage1 _ | Weinstein_types.Stage3 _
  | Weinstein_types.Stage4 _ ->
      false

(* Seed the initial trailing stop from a support-floor lookup on entry, falling
   back to the fixed buffer when no qualifying correction is found. Reads the
   accumulated daily bars for the symbol so the floor reflects real structure.
*)
let _seed_stop ~config ~bar_reader ~(entry_price : float) ~(as_of : Date.t) :
    Weinstein_stops.stop_state =
  let bars =
    Bar_reader.daily_bars_for bar_reader ~symbol:config.symbol ~as_of
  in
  Weinstein_stops.compute_initial_stop_with_floor ~config:config.stops_config
    ~side:Long ~entry_price ~bars ~as_of
    ~fallback_buffer:config.fallback_stop_buffer

(* Advance the trailing stop one tick on a held position and decide whether it
   triggers an exit. On a weekly close the state machine advances (raises /
   tightens); mid-week only the trigger check runs. Returns the (possibly
   updated) stop state and an optional exit transition. *)
let _step_stop ~config ~(stage_result : Stage.result option)
    ~(state : Weinstein_stops.stop_state) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) :
    Weinstein_stops.stop_state * Position.transition option =
  if Weinstein_stops.check_stop_hit ~state ~side:Long ~bar then
    ( state,
      Some
        (Spy_only_transitions.build_stop_exit ~pos ~bar
           ~stop_level:(Weinstein_stops.get_stop_level state)) )
  else if not (_is_weekly_close ~date:bar.date) then (state, None)
  else
    match stage_result with
    | None -> (state, None)
    | Some r ->
        let new_state, event =
          Weinstein_stops.update ~config:config.stops_config ~side:Long ~state
            ~current_bar:bar ~ma_value:r.ma_value ~ma_direction:r.ma_direction
            ~stage:r.stage
        in
        let exit_tr =
          match event with
          | Weinstein_stops.Stop_hit { stop_level; _ } ->
              Some (Spy_only_transitions.build_stop_exit ~pos ~bar ~stop_level)
          | Weinstein_stops.Stop_raised _ | Weinstein_stops.Entered_tightening _
          | Weinstein_stops.No_change ->
              None
        in
        (new_state, exit_tr)

(* Holding branch: run the stop, and on a weekly close also test the
   stage-based exit signal. The stop takes precedence — if it fires we exit on
   it and ignore the (less urgent) stage exit. Mutates [stop_state] /
   [prior_stage] for the next tick. *)
let _on_holding ~config ~bar_reader ~stop_state ~prior_stage ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) : Position.transition list =
  let as_of = bar.date in
  let stage_result = _classify_stage ~config ~bar_reader ~prior_stage ~as_of in
  (* Seed the stop the first time we observe the position in Holding (the entry
     tick created it in Entering; the fill lands the following tick). The seed
     anchors on the position's recorded entry price/date — not today's bar — so
     the support floor reflects the structure around entry. *)
  let state =
    match !stop_state with
    | Some s -> s
    | None ->
        let entry_price, entry_date =
          Option.value (_holding_entry pos) ~default:(bar.close_price, as_of)
        in
        _seed_stop ~config ~bar_reader ~entry_price ~as_of:entry_date
  in
  let new_state, stop_exit =
    _step_stop ~config ~stage_result ~state ~pos ~bar
  in
  stop_state := Some new_state;
  Option.iter stage_result ~f:(fun r -> prior_stage := Some r.stage);
  match stop_exit with
  | Some t -> [ t ]
  | None -> (
      let is_friday = _is_weekly_close ~date:bar.date in
      match (is_friday, stage_result) with
      | true, Some r when _is_exit_signal r ->
          stop_state := None;
          [ Spy_only_transitions.build_exit ~pos ~bar ~label:"stage4_exit" ]
      | _ -> [])

(* Flat branch: only act on a weekly close. Classify, and enter when the stage
   signal fires. The stop is seeded later, on the first Holding tick. *)
let _on_flat ~config ~bar_reader ~prior_stage ~(cash : float)
    ~(bar : Types.Daily_price.t) : Position.transition list =
  if not (_is_weekly_close ~date:bar.date) then []
  else
    let stage_result =
      _classify_stage ~config ~bar_reader ~prior_stage ~as_of:bar.date
    in
    Option.iter stage_result ~f:(fun r -> prior_stage := Some r.stage);
    match stage_result with
    | Some r when _is_entry_signal r -> (
        match _shares_from_cash ~cash ~close_price:bar.close_price with
        | None -> []
        | Some target_quantity ->
            [
              Spy_only_transitions.build_entry
                ~position_id:(_position_id_of_symbol config.symbol)
                ~symbol:config.symbol ~bar ~target_quantity;
            ])
    | _ -> []

let _on_market_close config ~bar_reader ~stop_state ~prior_stage ~get_price
    ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  let transitions =
    match get_price config.symbol with
    | None -> []
    | Some bar -> (
        match
          _live_position ~symbol:config.symbol ~positions:portfolio.positions
        with
        | Some pos when Option.is_some (_holding_quantity pos) ->
            _on_holding ~config ~bar_reader ~stop_state ~prior_stage ~pos ~bar
        | Some _ ->
            (* Position exists but is still Entering (awaiting fill) — nothing to
               do until it reaches Holding. *)
            []
        | None ->
            stop_state := None;
            _on_flat ~config ~bar_reader ~prior_stage ~cash:portfolio.cash ~bar)
  in
  Result.return { Strategy_interface.transitions }

let make ?(config = default_config) ~bar_reader () :
    (module Strategy_interface.STRATEGY) =
  let stop_state : Weinstein_stops.stop_state option ref = ref None in
  let prior_stage : Weinstein_types.stage option ref = ref None in
  let module M = struct
    let on_market_close =
      _on_market_close config ~bar_reader ~stop_state ~prior_stage

    let name = name
  end in
  (module M : Strategy_interface.STRATEGY)
