(** Per-macro-state fallback stop width, pinned {b through the entry walk}:
    {!Weinstein_strategy.Entry_walk.entries_from_candidates} resolves
    [config.initial_stop_buffer_by_macro_state] against the [breadth_state] of
    the [?macro] result it is handed, and installs the resulting stop.

    Plan: [dev/plans/stop-width-by-macro-state-2026-09-06.md]. The resolver
    itself is pinned in [test_stop_buffer_by_state.ml]; this file pins the two
    things only the walk can show:

    - the {b installed stop level} moves with the macro state (and does not move
      at the default empty map — R1), and
    - the [Demote_over_max] ordering pass measures the {b same} per-state buffer
      the ticket builder installs. [entry_stop_width_order.mli] calls that "the
      contract"; before this PR both sides read one scalar, so nothing could
      break it. Now they read a resolved float, and a wiring that threads it to
      only one of the two would put a candidate in the narrow group whose real
      stop is wide.

    Every candidate here is a {b flat-bar} symbol: one bar, no correction for
    the support-floor scan to anchor on, so the stop is the
    [initial_stop_buffer] fallback and is a pure function of the buffer. That is
    the common path in production — 88.7% of entries take the fallback
    ([dev/agent-memory/project_fallback_stop_half_book_band.md]) — and it is the
    only path this knob touches at all. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _current_date = Date.of_string "2024-06-14"
let _entry_close = 100.0

(* [config.initial_stop_buffer]'s shipped default: the fallback reference sits
   at the entry price, so the stop lands [min_correction_pct /. 2] = 4% under
   it (book §5.3's band floor). *)
let _scalar_buffer = 1.0

(* The 2026-09-05 surface's wide slot — a candidate value, not a default. *)
let _wide_buffer = 0.9167

(* Wider than [max_stop_distance_pct = 0.15], so a candidate resolving to it is
   over the book §5.1 limit and the ordering pass must demote it. *)
let _over_limit_buffer = 0.80

(* The installed stop for a fallback-path long at [_entry_close] under each
   buffer. Derivation (all three steps are exact in binary floating point at
   these values, so these are equalities, not approximations):

   reference = entry *. buffer;  raw = reference *. (1 - min_correction_pct/2)
   = reference *. 0.96;  stop = nudge_round_number raw.

   The nudge pulls a raw stop within [round_number_nudge = 0.125] of the nearest
   half-dollar to [that half-dollar - 0.125] for a long, which is what makes
   these exact:
   - buffer 1.0    -> 96.0     -> nearest half 96.0 -> 95.875
   - buffer 0.9167 -> 88.0032  -> nearest half 88.0 -> 87.875 *)
let _stop_at_scalar_buffer = 95.875
let _stop_at_wide_buffer = 87.875

(* [NARROW]'s stop, which is {b structural} and therefore buffer-independent:
   its history corrects 9.1% from a 110 peak to a 100 low, clearing
   [min_correction_pct = 0.08], so the support floor anchors at 100.0 and the
   stop is [100.0 *. 0.96] = 96.0, nudged to 95.875. It coincides numerically
   with [_stop_at_scalar_buffer] only because that candidate's entry is also
   100.0; the two are computed on different branches. *)
let _narrow_structural_stop = 95.875

let _bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* A single flat bar: nothing for the support-floor scan to anchor on, so the
   stop falls through to the buffer. *)
let _flat_bars = [ _bar ~date:_current_date ~close:_entry_close ]

(* [FALLBACK] takes the buffer path and therefore moves with the macro state.
   [NARROW] carries a real 9.1% correction inside the support-floor lookback, so
   a structural floor anchors ~5% under entry and its stop does NOT move with
   the buffer — it is the fixed reference point the ordering test partitions
   against. The peak must sit strictly before the last bar or the counter-move
   scan range is empty and the floor is never found. *)
let _fallback = "FALLBACK"
let _narrow = "NARROW"

let _narrow_bars =
  [
    100.0; 104.0; 108.0; 110.0; 106.0; 102.0; 100.0; 101.0; 103.0; 104.0; 105.0;
  ]
  |> List.mapi ~f:(fun i close ->
      _bar ~date:(Date.add_days _current_date (-10 + i)) ~close)

let _bar_reader =
  Bar_reader.of_in_memory_bars
    [ (_fallback, _flat_bars); (_narrow, _narrow_bars) ]

let _stage_result : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
    ma_value = 100.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 8;
  }

let _stock_analysis ~ticker : Stock_analysis.t =
  {
    ticker;
    stage = _stage_result;
    rs = None;
    volume = None;
    resistance = None;
    support = None;
    breakout_price = None;
    breakdown_price = None;
    local_range_top = None;
    prior_stage = None;
    continuation = None;
    supply = None;
    virgin_readmission = false;
    range_top_freshness = None;
    require_breakout_volume = true;
    current_close = None;
    as_of_date = _current_date;
  }

let _sector_context : Screener.sector_context =
  {
    sector_name = "Test";
    rating = Neutral;
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
  }

let _candidate ~ticker : Screener.scored_candidate =
  {
    ticker;
    analysis = _stock_analysis ~ticker;
    sector = _sector_context;
    side = Trading_base.Types.Long;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = _entry_close;
    suggested_stop = 95.0;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

(* A macro result in the given breadth state. Only [breadth_state] is read by
   the code under test; the rest is the minimum that type-checks. *)
let _macro_in ~state : Macro.result =
  {
    index_stage = _stage_result;
    indicators = [];
    trend = Weinstein_types.market_trend_of_breadth_state state;
    breadth_state = state;
    confidence = 0.5;
    regime_changed = false;
    rationale = [];
  }

let _config ?(map = Stop_buffer_by_state.default)
    ?(mode = Stop_width_mode.Drop_over_max) ?(ceiling = 0.0) ~universe () =
  let base =
    Weinstein_strategy_config.default_config ~universe ~index_symbol:"SPY"
  in
  {
    base with
    initial_stop_buffer = _scalar_buffer;
    initial_stop_buffer_by_macro_state = map;
    stop_width_mode = mode;
    stop_width_size_down_max_pct = ceiling;
  }

(* Run one entry walk and report (installed stop levels by ticker, emitted
   order). [?macro] is genuinely omitted when [state] is [None], which is the
   several-callers-have-no-macro case the [.mli] carves out. *)
let _walk ?state ?map ?mode ?ceiling ~candidates () =
  let universe =
    List.map candidates ~f:(fun (c : Screener.scored_candidate) -> c.ticker)
  in
  let config = _config ?map ?mode ?ceiling ~universe () in
  let portfolio =
    {
      Trading_strategy.Portfolio_view.cash = 1_000_000.0;
      positions = String.Map.empty;
    }
  in
  let stop_states = ref String.Map.empty in
  let macro = Option.map state ~f:(fun state -> _macro_in ~state) in
  let entered =
    Entry_walk.entries_from_candidates ~config ~candidates ~stop_states
      ~bar_reader:_bar_reader ~portfolio
      ~get_price:(fun _ -> None)
      ~current_date:_current_date ?macro ()
    |> List.filter_map ~f:(fun (t : Trading_strategy.Position.transition) ->
        match t.kind with
        | Trading_strategy.Position.CreateEntering e -> Some e.symbol
        | _ -> None)
  in
  (entered, !stop_states)

let _installed_stop ?state ?map ?mode ?ceiling ticker =
  let _entered, stops =
    _walk ?state ?map ?mode ?ceiling ~candidates:[ _candidate ~ticker ] ()
  in
  Map.find stops ticker |> Option.map ~f:Weinstein_stops.get_stop_level

let _entered_order ?state ?map ?mode ?ceiling ~candidates () =
  fst (_walk ?state ?map ?mode ?ceiling ~candidates ())

(** R1 through the walk: at the shipped empty map the installed stop is the
    scalar-buffer stop in {b every} macro state, and in the no-[?macro] case
    too. Five states plus the absent-macro case, because a resolver that wired
    one slot wrong would change the width in exactly one regime — the shape a
    spot check misses.

    This is also the assertion that fails if the fallback path stops being the
    fallback path: [_stop_at_scalar_buffer] is derived from
    [initial_stop_buffer], not read back from the code. *)
let test_the_default_map_installs_the_scalar_stop_in_every_state _ =
  let states : Weinstein_types.breadth_state list =
    [
      Bullish_breadth;
      Neutral_breadth;
      Deteriorating;
      Recovering;
      Bearish_breadth;
    ]
  in
  assert_that
    (_installed_stop _fallback
    :: List.map states ~f:(fun state -> _installed_stop ~state _fallback))
    (elements_are
       (List.init 6 ~f:(fun _ ->
            is_some_and (float_equal _stop_at_scalar_buffer))))

(** The mechanism: with the [deteriorating] slot armed, the
    {b same candidate on the same bars} installs a stop ~12% under entry when
    breadth is Deteriorating and the unchanged ~4% stop when it is Bullish (an
    unset slot). Exact levels, not just "wider", so a wiring that resolved the
    map but then installed some other buffer would fail. *)
let test_an_armed_slot_widens_the_installed_stop_for_that_state_only _ =
  let map =
    { Stop_buffer_by_state.default with deteriorating = _wide_buffer }
  in
  assert_that
    [
      _installed_stop ~map ~state:Weinstein_types.Deteriorating _fallback;
      _installed_stop ~map ~state:Weinstein_types.Bullish_breadth _fallback;
    ]
    (elements_are
       [
         is_some_and (float_equal _stop_at_wide_buffer);
         is_some_and (float_equal _stop_at_scalar_buffer);
       ])

(** The ordering pass reads the {b same} resolved buffer as the ticket builder.

    Under [Demote_over_max] with a 0.90 ceiling, [FALLBACK] is offered first and
    [NARROW] second. With the [deteriorating] slot at a buffer that puts the
    fallback stop past the 15% §5.1 limit, [FALLBACK] must be demoted behind
    [NARROW] — but {i only} in the Deteriorating state; under Bullish the same
    map leaves it at the scalar buffer, inside the limit, and the offered order
    stands.

    Threading the resolved buffer to the ticket builder alone (leaving
    [prefer_narrow_stops] on [config.initial_stop_buffer]) makes both arms come
    back in the offered order and fails the first element — which is the wiring
    mistake this test exists for. *)
let test_the_demotion_pass_follows_the_per_state_buffer _ =
  let map =
    { Stop_buffer_by_state.default with deteriorating = _over_limit_buffer }
  in
  let order state =
    _entered_order ~map ~state ~mode:Stop_width_mode.Demote_over_max
      ~ceiling:0.90
      ~candidates:[ _candidate ~ticker:_fallback; _candidate ~ticker:_narrow ]
      ()
  in
  assert_that
    [
      order Weinstein_types.Deteriorating; order Weinstein_types.Bullish_breadth;
    ]
    (elements_are
       [
         elements_are [ equal_to _narrow; equal_to _fallback ];
         elements_are [ equal_to _fallback; equal_to _narrow ];
       ])

(** A structural (support-floor) stop is not this knob's business: [NARROW]'s
    stop anchors on its own 9.1% correction low, so it is identical under an
    armed [deteriorating] slot and under the empty map. The [.mli] says the
    multiplier "is read only on the fallback branch"; this is that claim. *)
let test_a_structural_stop_ignores_the_per_state_buffer _ =
  let map =
    { Stop_buffer_by_state.default with deteriorating = _wide_buffer }
  in
  assert_that
    [
      _installed_stop ~map ~state:Weinstein_types.Deteriorating _narrow;
      _installed_stop ~state:Weinstein_types.Deteriorating _narrow;
    ]
    (elements_are
       [
         is_some_and (float_equal _narrow_structural_stop);
         is_some_and (float_equal _narrow_structural_stop);
       ])

let suite =
  "stop_width_by_macro_state"
  >::: [
         "the default map installs the scalar stop in every state"
         >:: test_the_default_map_installs_the_scalar_stop_in_every_state;
         "an armed slot widens the installed stop for that state only"
         >:: test_an_armed_slot_widens_the_installed_stop_for_that_state_only;
         "the demotion pass follows the per-state buffer"
         >:: test_the_demotion_pass_follows_the_per_state_buffer;
         "a structural stop ignores the per-state buffer"
         >:: test_a_structural_stop_ignores_the_per_state_buffer;
       ]

let () = run_test_tt_main suite
