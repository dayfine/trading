(** Single-instrument Weinstein stage-timing strategy — see
    [spy_only_weinstein_strategy.mli]. *)

open Core
open Trading_strategy

type config = {
  symbol : string;
  stage_config : Stage.config;
  stops_config : Weinstein_stops.config;
  fallback_stop_buffer : float;
  enable_stage4_short : bool;
}

let name = "SpyOnlyWeinstein"
let default_symbol = "SPY"
let default_fallback_stop_buffer = 0.92
let default_enable_stage4_short = false

let default_config =
  {
    symbol = default_symbol;
    stage_config = Stage.default_config;
    stops_config = Weinstein_stops.default_config;
    fallback_stop_buffer = default_fallback_stop_buffer;
    enable_stage4_short = default_enable_stage4_short;
  }

let config_with ?(symbol = default_symbol)
    ?(enable_stage4_short = default_enable_stage4_short) ~ma_period_weeks () =
  {
    default_config with
    symbol;
    stage_config =
      { default_config.stage_config with ma_period = ma_period_weeks };
    enable_stage4_short;
  }

(* Number of weekly bars fed to [Stage.classify]: twice the MA period (the MA
   plus an equal slope/prior-stage margin), floored at [_min_stage_weeks] so a
   short trader MA still warms up. 60 weeks at the 30-week investor default. *)
let _min_stage_weeks = 12

(* MA weeks plus an equal slope-lookback margin, i.e. 2x the MA period. *)
let _stage_weeks_ma_multiplier = 2

let _stage_weeks_of (config : config) : int =
  Int.max _min_stage_weeks
    (_stage_weeks_ma_multiplier * config.stage_config.ma_period)

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
   a crash bar would disarm the stop). [None] for any non-[Holding] state. *)
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
    Bar_reader.weekly_bars_for bar_reader ~symbol:config.symbol
      ~n:(_stage_weeks_of config) ~as_of
  in
  match bars with
  | [] -> None
  | _ ->
      Some
        (Stage.classify ~config:config.stage_config ~bars
           ~prior_stage:!prior_stage)

(* Seed the initial trailing stop from a support-floor lookup on entry, falling
   back to the fixed buffer when no qualifying correction is found. Long: stop
   below the correction low; short: above the counter-rally high ([side] is
   threaded into the stop module). *)
let _seed_stop ~config ~bar_reader ~(side : Position.position_side)
    ~(entry_price : float) ~(as_of : Date.t) : Weinstein_stops.stop_state =
  let bars =
    Bar_reader.daily_bars_for bar_reader ~symbol:config.symbol ~as_of
  in
  Weinstein_stops.compute_initial_stop_with_floor ~config:config.stops_config
    ~side ~entry_price ~bars ~as_of ~fallback_buffer:config.fallback_stop_buffer

(* Map a stop state-machine event to an optional exit transition: only a
   [Stop_hit] produces one. Kept separate so [_advance_stop] stays shallow. *)
let _exit_of_stop_event ~(pos : Position.t) ~(bar : Types.Daily_price.t)
    ~(event : Weinstein_stops.stop_event) : Position.transition option =
  match event with
  | Weinstein_stops.Stop_hit { stop_level; _ } ->
      Some (Spy_only_transitions.build_stop_exit ~pos ~bar ~stop_level)
  | Weinstein_stops.Stop_raised _ | Weinstein_stops.Entered_tightening _
  | Weinstein_stops.No_change ->
      None

(* Weekly-close advance: run the stop state machine one tick against the stage
   read [r] and report the (new state, optional exit). *)
let _advance_stop ~config ~(side : Position.position_side) ~(r : Stage.result)
    ~(state : Weinstein_stops.stop_state) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) :
    Weinstein_stops.stop_state * Position.transition option =
  let new_state, event =
    Weinstein_stops.update ~config:config.stops_config ~side ~state
      ~current_bar:bar ~ma_value:r.ma_value ~ma_direction:r.ma_direction
      ~stage:r.stage
  in
  (new_state, _exit_of_stop_event ~pos ~bar ~event)

(* Advance the trailing stop one tick on a held position and decide whether it
   triggers an exit. On a weekly close the state machine advances (for a short,
   ratchets the stop down); mid-week only the trigger check runs. [side] is the
   held position's side. *)
let _step_stop ~config ~(side : Position.position_side)
    ~(stage_result : Stage.result option) ~(state : Weinstein_stops.stop_state)
    ~(pos : Position.t) ~(bar : Types.Daily_price.t) :
    Weinstein_stops.stop_state * Position.transition option =
  if Weinstein_stops.check_stop_hit ~state ~side ~bar () then
    let stop_level = Weinstein_stops.get_stop_level state in
    (state, Some (Spy_only_transitions.build_stop_exit ~pos ~bar ~stop_level))
  else if not (_is_weekly_close ~date:bar.date) then (state, None)
  else
    match stage_result with
    | None -> (state, None)
    | Some r -> _advance_stop ~config ~side ~r ~state ~pos ~bar

(* Seed the stop the first time we observe the position in Holding (the entry
   tick created it in Entering; the fill lands the following tick). The seed
   anchors on the position's recorded entry price/date — not today's bar — so
   the support floor reflects the structure around entry. *)
let _seed_or_keep_stop ~config ~bar_reader ~stop_state
    ~(side : Position.position_side) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) : Weinstein_stops.stop_state =
  match !stop_state with
  | Some s -> s
  | None ->
      let entry_price, entry_date =
        Option.value (_holding_entry pos) ~default:(bar.close_price, bar.date)
      in
      _seed_stop ~config ~bar_reader ~side ~entry_price ~as_of:entry_date

(* The stage-based exit when the stop did not fire: only on a weekly close, and
   only when the held [side]'s stage read warrants it (long Stage-4 exit / short
   Stage-4 cover). Clears [stop_state] on a fire so the next entry re-seeds. *)
let _stage_exit_when_holding ~stop_state ~(side : Position.position_side)
    ~(stage_result : Stage.result option) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) : Position.transition list =
  let label =
    if _is_weekly_close ~date:bar.date then
      Option.bind stage_result
        ~f:(Spy_only_signals.stage_exit_label_for_side ~side)
    else None
  in
  match label with
  | None -> []
  | Some label ->
      stop_state := None;
      [ Spy_only_transitions.build_exit ~pos ~bar ~label ]

(* Holding branch: run the stop, and on a weekly close also test the
   stage-based exit signal for the held [side]. The stop takes precedence — if
   it fires we exit on it and ignore the (less urgent) stage exit. Mutates
   [stop_state] / [prior_stage] for the next tick. *)
let _on_holding ~config ~bar_reader ~stop_state ~prior_stage ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) : Position.transition list =
  let side = pos.side in
  let stage_result =
    _classify_stage ~config ~bar_reader ~prior_stage ~as_of:bar.date
  in
  let state =
    _seed_or_keep_stop ~config ~bar_reader ~stop_state ~side ~pos ~bar
  in
  let new_state, stop_exit =
    _step_stop ~config ~side ~stage_result ~state ~pos ~bar
  in
  stop_state := Some new_state;
  Option.iter stage_result ~f:(fun r -> prior_stage := Some r.stage);
  match stop_exit with
  | Some t -> [ t ]
  | None -> _stage_exit_when_holding ~stop_state ~side ~stage_result ~pos ~bar

(* Build the (at most one) entry transition for [bar] on [side] when the
   all-cash sizing affords a whole share; otherwise no transition. The short
   side is sized identically to the long: [floor(cash / close)] notional. Kept
   separate so [_on_flat] stays shallow. *)
let _entry_transitions ~config ~(side : Position.position_side) ~(cash : float)
    ~(bar : Types.Daily_price.t) : Position.transition list =
  match _shares_from_cash ~cash ~close_price:bar.close_price with
  | None -> []
  | Some target_quantity ->
      let position_id = _position_id_of_symbol config.symbol in
      [
        Spy_only_transitions.build_entry ~position_id ~symbol:config.symbol
          ~side ~bar ~target_quantity;
      ]

(* Classify on this Friday, record [prior_stage], and resolve the flat-tape
   entry side (long on Stage 2; short on Stage 4 when enabled), or [None]. *)
let _flat_entry_side ~config ~bar_reader ~prior_stage
    ~(bar : Types.Daily_price.t) : Position.position_side option =
  let stage_result =
    _classify_stage ~config ~bar_reader ~prior_stage ~as_of:bar.date
  in
  Option.iter stage_result ~f:(fun r -> prior_stage := Some r.stage);
  Option.bind stage_result
    ~f:
      (Spy_only_signals.flat_entry_side
         ~enable_stage4_short:config.enable_stage4_short)

(* Flat branch: only act on a weekly close. Enter when the stage signal fires
   (long on Stage 2; short on Stage 4 when enabled). The stop is seeded later,
   on the first Holding tick. *)
let _on_flat ~config ~bar_reader ~prior_stage ~(cash : float)
    ~(bar : Types.Daily_price.t) : Position.transition list =
  if not (_is_weekly_close ~date:bar.date) then []
  else
    match _flat_entry_side ~config ~bar_reader ~prior_stage ~bar with
    | Some side -> _entry_transitions ~config ~side ~cash ~bar
    | None -> []

(* Dispatch one bar to the holding or flat branch based on the live position.
   A still-[Entering] position (awaiting fill) yields no transitions. Kept
   separate so [_on_market_close] stays shallow. *)
let _transitions_for_bar ~config ~bar_reader ~stop_state ~prior_stage
    ~(portfolio : Portfolio_view.t) ~(bar : Types.Daily_price.t) :
    Position.transition list =
  match _live_position ~symbol:config.symbol ~positions:portfolio.positions with
  | Some pos when Option.is_some (_holding_quantity pos) ->
      _on_holding ~config ~bar_reader ~stop_state ~prior_stage ~pos ~bar
  | Some _ -> []
  | None ->
      stop_state := None;
      _on_flat ~config ~bar_reader ~prior_stage ~cash:portfolio.cash ~bar

let _on_market_close config ~bar_reader ~stop_state ~prior_stage ~get_price
    ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  let transitions =
    match get_price config.symbol with
    | None -> []
    | Some bar ->
        _transitions_for_bar ~config ~bar_reader ~stop_state ~prior_stage
          ~portfolio ~bar
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
