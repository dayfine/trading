open Core
open Trading_strategy

type stop_update_cadence = Daily | Weekly [@@deriving show, eq, sexp]

(** Friday is the cadence anchor: the strategy's screening pass uses the same
    marker (see {!Weinstein_strategy._is_screening_day_view}). Keeping the
    runner's weekly-cadence check on Friday matches that authority — book
    §Stop-Loss Rules describes weekly re-evaluation, and Friday is the
    week-bucket boundary used everywhere else in the strategy. *)
let _is_weekly_close ~as_of =
  Date.day_of_week as_of |> Day_of_week.equal Day_of_week.Fri

(** Position-favourable stage + MA direction default for warmup periods (when
    fewer than [stage_config.ma_period] weekly bars are available). The return
    must drive {!Weinstein_stops.update} into a no-tighten branch:

    - {!Weinstein_stops._should_tighten_long} tightens on Stage 3 / Stage 4 and
      on Stage 2 + Flat-or-Declining MA (when [tighten_on_flat_ma] is true). The
      only no-tighten branch for a long is Stage 2 + Rising MA.
    - {!Weinstein_stops._should_tighten_short} tightens on Stage 1 / Stage 2 and
      on Stage 4 + Rising-or-Flat MA. The only no-tighten branch for a short is
      Stage 4 + Declining MA.

    Returning a position-favourable warmup default avoids the G1 short-stop
    pathology (see [dev/notes/short-side-gaps-2026-04-29.md]): hardcoding
    [Stage2 + Flat] for shorts triggered tightening on every warmup tick,
    dragging short stops below entry within one or two bars. *)
let _default_stage_and_ma_for_side = function
  | Trading_base.Types.Long ->
      ( Weinstein_types.Stage2 { weeks_advancing = 1; late = false },
        Weinstein_types.Rising )
  | Trading_base.Types.Short ->
      (Weinstein_types.Stage4 { weeks_declining = 1 }, Weinstein_types.Declining)

(** Compute MA direction, value, and stage for a symbol via panel-shaped
    callbacks. Reads and updates [prior_stages] so Stage1->Stage2 transition
    detection works across calls. Returns [(Flat, fallback_price, default)]
    where [default] is [_default_stage_and_ma_for_side ~side] when there aren't
    enough weekly bars yet for the MA — see G1 fix in
    [dev/notes/short-side-gaps-2026-04-29.md]: hardcoding [Stage2] for shorts
    triggered spurious tightening on every warmup tick, dragging short stops
    below entry. The position-favourable default keeps the state machine in its
    initial pose during warmup.

    Stage 4 PR-A: this no longer materialises a {!Daily_price.t list}. The
    weekly view is read directly from panels and threaded into a
    {!Stage.callbacks} bundle.

    Stage 4 PR-D: an optional [ma_cache] threads through to the panel callbacks.
    Mid-week stop adjustments miss the cache (Friday-aligned only) and fall back
    to inline; Friday-aligned calls hit the cache. *)
let _compute_ma_and_stage ?ma_cache ?prior_stage_ma_values
    ~(stage_config : Stage.config) ~lookback_bars ~bar_reader ~as_of
    ~prior_stages ~symbol ~side ~fallback_price () =
  let weekly =
    Bar_reader.weekly_view_for bar_reader ~symbol ~n:lookback_bars ~as_of
  in
  if weekly.n < stage_config.ma_period then
    let stage, ma_direction = _default_stage_and_ma_for_side side in
    (ma_direction, fallback_price, stage)
  else
    let prior_stage = Hashtbl.find prior_stages symbol in
    let callbacks =
      Panel_callbacks.stage_callbacks_of_weekly_view ?ma_cache ~symbol
        ~config:stage_config ~weekly ()
    in
    let result =
      Stage.classify_with_callbacks ~config:stage_config
        ~get_ma:callbacks.get_ma ~get_close:callbacks.get_close ~prior_stage
    in
    Hashtbl.set prior_stages ~key:symbol ~data:result.stage;
    Option.iter prior_stage_ma_values ~f:(fun tbl ->
        Hashtbl.set tbl ~key:symbol ~data:result.ma_value);
    (result.ma_direction, result.ma_value, result.stage)

(* Transition emission (worst-case fill price, exit/adjust builders, the
   trigger-only branch, and the stop_event → transitions mapping) lives in
   {!Stop_transitions} — including the G1 short-fill audit contract. *)

(** Advance the shared per-ticker stop state machine
    {b at most once per [update] call}. [advanced] memoizes
    [(pre_advance_state, event)] per ticker: the first position on a ticker
    advances the machine (persisting the new state into [stop_states] and the
    new stage into [prior_stages]); subsequent same-ticker positions (sibling
    positions, e.g. a scale-in add) replay the memoized event so each position
    still emits its own exit / adjust transition while the machine advances
    exactly once — {!Weinstein_stops.update}'s contract is one call per period,
    and a second call per tick would also double-age [weeks_advancing] in
    [prior_stages]. Sibling positions on one ticker share the position side (the
    memoized advance uses the first position's side). *)
let _advance_machine ?ma_cache ?prior_stage_ma_values ~stops_config
    ~stage_config ~lookback_bars ~(pos : Position.t) ~state ~bar ~stop_states
    ~ticker ~bar_reader ~as_of ~prior_stages () =
  let ma_direction, ma_value, stage =
    _compute_ma_and_stage ?ma_cache ?prior_stage_ma_values ~stage_config
      ~lookback_bars ~bar_reader ~as_of ~prior_stages ~symbol:ticker
      ~side:pos.Position.side ~fallback_price:bar.Types.Daily_price.close_price
      ()
  in
  let new_state, event =
    Weinstein_stops.update ~config:stops_config ~side:pos.Position.side ~state
      ~current_bar:bar ~ma_value ~ma_direction ~stage
  in
  stop_states := Map.set !stop_states ~key:ticker ~data:new_state;
  (state, event)

let _advance_ticker_once ?ma_cache ?prior_stage_ma_values ~advanced
    ~stops_config ~stage_config ~lookback_bars ~(pos : Position.t) ~state ~bar
    ~stop_states ~ticker ~bar_reader ~as_of ~prior_stages () =
  match Hashtbl.find advanced ticker with
  | Some memo -> memo
  | None ->
      let memo =
        _advance_machine ?ma_cache ?prior_stage_ma_values ~stops_config
          ~stage_config ~lookback_bars ~pos ~state ~bar ~stop_states ~ticker
          ~bar_reader ~as_of ~prior_stages ()
      in
      Hashtbl.set advanced ~key:ticker ~data:memo;
      memo

(** Daily-cadence branch (and Weekly-on-Friday): advance the state machine once
    per ticker (see {!_advance_ticker_once}) and emit this position's (exit,
    adjust) transition pair off the pre-advance state + event. *)
let _handle_stop_full ?ma_cache ?prior_stage_ma_values ~advanced ~stops_config
    ~stage_config ~lookback_bars ~(pos : Position.t)
    ~(risk_params : Position.risk_params) ~state ~bar ~stop_states ~ticker
    ~bar_reader ~as_of ~prior_stages ~current_date () =
  let pre_state, event =
    _advance_ticker_once ?ma_cache ?prior_stage_ma_values ~advanced
      ~stops_config ~stage_config ~lookback_bars ~pos ~state ~bar ~stop_states
      ~ticker ~bar_reader ~as_of ~prior_stages ()
  in
  Stop_transitions.of_stop_event
    ~on_close:stops_config.Weinstein_stops.trigger_on_weekly_close ~pos
    ~risk_params ~state:pre_state ~bar ~current_date ~event

(** Fast-crash absolute-stop exit, OR'd alongside the structural trigger.

    Build 2 (dev/notes/decline-character-exploration-2026-06-21-PM.md): when the
    position's market is in a fast-V decline ([catastrophic_armed]) and the
    [stops_config.catastrophic_stop_pct] knob is enabled, a long's bar low
    breaching [trailing_high *. (1 - pct)] (mirror for shorts) fires an exit
    even when the slower structural stop has not. The trail is read from [state]
    via {!Weinstein_stops.trailing_high_of_state} — only a [Trailing] state
    carries one, so the catastrophic stop is dormant until a trend leg exists.
    No exit when [catastrophic_armed = false] or [pct = 0.0] (the default), so
    existing callers / goldens are bit-identical. The exit fill price reuses the
    structural [Stop_transitions.make_exit_transition] (bar low for longs / high
    for shorts). *)
let _catastrophic_hit ~catastrophic_armed ~stops_config ~(pos : Position.t)
    ~state ~bar =
  match Weinstein_stops.Catastrophic_stop.trailing_high_of_state state with
  | None -> false
  | Some trailing_high ->
      Weinstein_stops.Catastrophic_stop.check_hit ~armed:catastrophic_armed
        ~pct:stops_config.Weinstein_stops.catastrophic_stop_pct ~trailing_high
        ~bar ~side:pos.Position.side

let _catastrophic_exit ~catastrophic_armed ~stops_config ~(pos : Position.t)
    ~state ~bar ~current_date =
  if _catastrophic_hit ~catastrophic_armed ~stops_config ~pos ~state ~bar then
    Some
      (Stop_transitions.make_exit_transition
         ~on_close:stops_config.Weinstein_stops.trigger_on_weekly_close ~pos
         ~current_date ~state ~bar ())
  else None

(** Process stop logic for one held position. Returns (exit_transition option,
    adjust_transition option).

    Under [Weekly] cadence with [as_of] not on a Friday, only the trigger check
    runs (see [Stop_transitions.handle_trigger_only]); the state machine is not
    advanced and [stop_states] is unchanged. Under [Daily] (or [Weekly] on
    Friday), the state machine runs as before via [_handle_stop_full].

    The fast-crash absolute stop ([_catastrophic_exit]) is OR'd alongside both
    branches: if the structural path produced no exit but the catastrophic stop
    fires, its exit is emitted instead. The structural exit takes precedence
    when both fire (same [TriggerExit] kind). *)
let _handle_stop ?ma_cache ?prior_stage_ma_values ?(stop_update_cadence = Daily)
    ?(catastrophic_armed = false) ~advanced ~stops_config ~stage_config
    ~lookback_bars ~(pos : Position.t) ~(risk_params : Position.risk_params)
    ~state ~bar ~stop_states ~ticker ~bar_reader ~as_of ~prior_stages () =
  let current_date = bar.Types.Daily_price.date in
  let advance_state_machine =
    match stop_update_cadence with
    | Daily -> true
    | Weekly -> _is_weekly_close ~as_of
  in
  let exit_tr, adjust_tr =
    if not advance_state_machine then
      Stop_transitions.handle_trigger_only
        ~on_close:stops_config.Weinstein_stops.trigger_on_weekly_close ~pos
        ~state ~bar ~current_date
    else
      _handle_stop_full ?ma_cache ?prior_stage_ma_values ~advanced ~stops_config
        ~stage_config ~lookback_bars ~pos ~risk_params ~state ~bar ~stop_states
        ~ticker ~bar_reader ~as_of ~prior_stages ~current_date ()
  in
  match exit_tr with
  | Some _ -> (exit_tr, adjust_tr)
  | None ->
      let catastrophic_tr =
        _catastrophic_exit ~catastrophic_armed ~stops_config ~pos ~state ~bar
          ~current_date
      in
      (catastrophic_tr, adjust_tr)

(** Process stop for one position; returns updated (exits, adjusts) accumulator.
*)
let _process_stop ?ma_cache ?prior_stage_ma_values ?stop_update_cadence
    ?catastrophic_armed ~advanced ~stops_config ~stage_config ~lookback_bars
    ~stop_states ~get_price ~bar_reader ~as_of ~prior_stages (pos : Position.t)
    (exits, adjusts) =
  let ticker = pos.symbol in
  match
    (Position.get_state pos, Map.find !stop_states ticker, get_price ticker)
  with
  | Position.Holding h, Some state, Some bar -> (
      match
        _handle_stop ?ma_cache ?prior_stage_ma_values ?stop_update_cadence
          ?catastrophic_armed ~advanced ~stops_config ~stage_config
          ~lookback_bars ~pos ~risk_params:h.risk_params ~state ~bar
          ~stop_states ~ticker ~bar_reader ~as_of ~prior_stages ()
      with
      | Some exit_tr, _ -> (exit_tr :: exits, adjusts)
      | _, Some adj_tr -> (exits, adj_tr :: adjusts)
      | None, None -> (exits, adjusts))
  | _ -> (exits, adjusts)

let update ?ma_cache ?stop_update_cadence ?prior_stage_ma_values
    ?catastrophic_armed ~stops_config ~stage_config ~lookback_bars ~positions
    ~get_price ~stop_states ~bar_reader ~as_of ~prior_stages () =
  (* Per-call memo: ticker -> (pre_advance_state, event). Ensures the shared
     per-ticker state machine advances once per tick even when several sibling
     positions hold the same ticker (see [_advance_ticker_once]). *)
  let advanced = Hashtbl.create (module String) in
  Map.fold positions ~init:([], []) ~f:(fun ~key:_ ~data:pos acc ->
      _process_stop ?ma_cache ?prior_stage_ma_values ?stop_update_cadence
        ?catastrophic_armed ~advanced ~stops_config ~stage_config ~lookback_bars
        ~stop_states ~get_price ~bar_reader ~as_of ~prior_stages pos acc)
