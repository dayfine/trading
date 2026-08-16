(** Defect B: §5.1's "prefer other candidates" as a rank demotion rather than a
    ban — {!Weinstein_strategy.Entry_stop_width_order} plus its wiring into the
    entry walk.

    Two layers are pinned:
    - the ordering pass itself: a wide-stop candidate is moved behind a
      narrow-stop one, and is left exactly where it was under the other two
      modes;
    - the walk: with only enough cash for one entry, the narrow-stop candidate
      is the one funded — which is the whole point of a demotion, and what a
      pure-ordering unit test cannot show.

    The fixture makes the two candidates differ on stop width the way the real
    screener does, not by stubbing the width: [NARROW]'s daily history contains
    a 9.1% correction inside the support-floor lookback, so a structural floor
    is found ~5% under entry; [WIDE] has a single flat bar, no correction to
    find, so the stop falls back to [initial_stop_buffer] and lands at 67% — far
    outside the 15% limit. The first assertion below checks that separation
    directly, so a fixture that stops separating them cannot masquerade as a
    passing demotion. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position

let _current_date = Date.of_string "2024-06-14"
let _narrow = "NARROW"
let _wide = "WIDE"

(* The stop the fallback installs for a symbol with no correction to anchor on.
   Chosen well outside [max_stop_distance_pct = 0.15] so [WIDE] is unambiguously
   over the book limit. Shared with the existing F3 fixture in
   [test_entry_audit_capture.ml]. *)
let _wide_buffer = 0.6667

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

(* Rise to a 110 peak, correct 9.1% to 100, recover to a 105 close. The peak
   must sit strictly {i before} the last bar: {!Support_floor} anchors on the
   window's highest high and then scans only the bars {i newer} than that anchor
   for the correction low, so a series whose final bar {i is} the high has an
   empty counter-move range and falls through to the buffer — which is how the
   first version of this fixture silently made both candidates wide.

   (110 - 100) / 110 = 9.1% clears [min_correction_pct = 0.08], so the floor
   anchors at 100 and the installed stop lands ~5% under the 105 entry: inside
   the 15% limit. *)
let _narrow_bars =
  let closes =
    [
      100.0;
      104.0;
      108.0;
      110.0;
      106.0;
      102.0;
      100.0;
      101.0;
      103.0;
      104.0;
      105.0;
    ]
  in
  List.mapi closes ~f:(fun i close ->
      _bar ~date:(Date.add_days _current_date (-10 + i)) ~close)

let _bar_reader =
  Bar_reader.of_in_memory_bars
    [
      (_narrow, _narrow_bars); (_wide, [ _bar ~date:_current_date ~close:100.0 ]);
    ]

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
    suggested_entry = 100.0;
    suggested_stop = 95.0;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

(* [WIDE] deliberately ranks FIRST, so leaving the order alone is observably
   different from demoting. *)
let _candidates = [ _candidate ~ticker:_wide; _candidate ~ticker:_narrow ]

let _config ~mode ~ceiling =
  {
    (Weinstein_strategy_config.default_config ~universe:[ _wide; _narrow ]
       ~index_symbol:"SPY")
    with
    initial_stop_buffer = _wide_buffer;
    stop_width_mode = mode;
    stop_width_size_down_max_pct = ceiling;
  }

let _order_under ~mode ~ceiling =
  Entry_stop_width_order.prefer_narrow_stops ~config:(_config ~mode ~ceiling)
    ~bar_reader:_bar_reader ~current_date:_current_date _candidates
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

(** The fixture is only meaningful if the two candidates really do land on
    opposite sides of the 15% limit. Asserted first, and separately, so a
    failure here reads as "the fixture stopped separating them" rather than as
    "the demotion broke". *)
let test_fixture_separates_the_two_candidates _ =
  assert_that
    (_order_under ~mode:Stop_width_mode.Demote_over_max ~ceiling:0.90)
    (elements_are [ equal_to _narrow; equal_to _wide ])

(** Identity under the two modes that do not demote — including [Size_down],
    which admits the same wide candidate but keeps its rank. This is the R1
    half: the default path is not reordered, and does not even pay for the
    per-candidate stop recomputation. *)
let test_other_modes_leave_the_order_untouched _ =
  assert_that
    [
      _order_under ~mode:Stop_width_mode.Drop_over_max ~ceiling:0.90;
      _order_under ~mode:Stop_width_mode.Size_down ~ceiling:0.90;
    ]
    (elements_are
       [
         elements_are [ equal_to _wide; equal_to _narrow ];
         elements_are [ equal_to _wide; equal_to _narrow ];
       ])

(** An unset ceiling makes the mode a no-op: with
    [stop_width_size_down_max_pct = 0.0] the ceiling falls back to
    [max_stop_distance_pct], so the wide candidate is dropped by the gate anyway
    and demoting it buys nothing. The ordering pass still runs (it is keyed on
    the mode, not the ceiling), which is why this is worth pinning — the reorder
    happens, the gate then discards the demoted candidate, and the observable
    outcome is the unarmed one. *)
let test_unset_ceiling_still_drops_the_wide_candidate _ =
  assert_that
    (Stop_width_mode.gate
       ~policy:
         { mode = Stop_width_mode.Demote_over_max; size_down_max_pct = 0.0 }
       ~max_stop_distance_pct:0.15 ~stop_distance_pct:0.36)
    (equal_to (Stop_width_mode.Drop : Stop_width_mode.outcome))

(** The three distance bands under [Demote_over_max] with a 0.90 ceiling.
    Crucially the middle band is [Admit], not [Admit_sized_down]: demotion
    changes order, never size — that is what separates it from [Size_down]. *)
let test_gate_demote_bands _ =
  assert_that
    ([ 0.10; 0.36; 0.95 ]
    |> List.map ~f:(fun stop_distance_pct ->
        Stop_width_mode.gate
          ~policy:
            { mode = Stop_width_mode.Demote_over_max; size_down_max_pct = 0.90 }
          ~max_stop_distance_pct:0.15 ~stop_distance_pct))
    (elements_are
       [
         equal_to (Stop_width_mode.Admit : Stop_width_mode.outcome);
         equal_to (Stop_width_mode.Admit : Stop_width_mode.outcome);
         equal_to (Stop_width_mode.Drop : Stop_width_mode.outcome);
       ])

let _entered_tickers ~mode ~cash =
  let portfolio =
    { Trading_strategy.Portfolio_view.cash; positions = String.Map.empty }
  in
  let stop_states = ref String.Map.empty in
  Entry_walk.entries_from_candidates
    ~config:(_config ~mode ~ceiling:0.90)
    ~candidates:_candidates ~stop_states ~bar_reader:_bar_reader ~portfolio
    ~get_price:(fun _ -> None)
    ~current_date:_current_date ()
  |> List.filter_map ~f:(fun (t : Position.transition) ->
      match t.kind with Position.CreateEntering e -> Some e.symbol | _ -> None)

(** The load-bearing wiring pin, and the reason a unit test of the ordering pass
    alone is not enough. Same candidates, same cash, same bars — only the
    reading of §5.1 differs, and the walk emits them in a different order:

    - [Drop_over_max] enters [NARROW] only; [WIDE] is excluded outright.
    - [Size_down] enters both, [WIDE] first — it kept its rank.
    - [Demote_over_max] enters both, [NARROW] first — the wide stop cost it
      priority, not existence.

    Emission order is the observable because the walk charges each entry against
    a shared budget {i in this order}: whoever is emitted first is whoever had
    first claim on the week's capital. Deleting the [Entry_stop_width_order]
    call from [entry_walk.ml] makes an armed [Demote_over_max] behave exactly
    like [Size_down], and every other test in this file still passes.

    Cash is deliberately ample so the assertion is about {i priority}, not about
    which of two specific position sizes happens to fit — the two candidates
    cost very different fractions of the book (risk-based sizing shrinks [WIDE]
    ~13x for its 67% stop), so a starvation-based test would pin an arithmetic
    coincidence rather than the ordering rule. *)
let test_walk_emits_the_narrow_stop_first _ =
  let cash = 1_000_000.0 in
  assert_that
    [
      _entered_tickers ~mode:Stop_width_mode.Drop_over_max ~cash;
      _entered_tickers ~mode:Stop_width_mode.Size_down ~cash;
      _entered_tickers ~mode:Stop_width_mode.Demote_over_max ~cash;
    ]
    (elements_are
       [
         elements_are [ equal_to _narrow ];
         elements_are [ equal_to _wide; equal_to _narrow ];
         elements_are [ equal_to _narrow; equal_to _wide ];
       ])

let suite =
  "entry_stop_width_order"
  >::: [
         "the fixture separates narrow from wide"
         >:: test_fixture_separates_the_two_candidates;
         "non-demoting modes leave the order untouched"
         >:: test_other_modes_leave_the_order_untouched;
         "an unset ceiling still drops the wide candidate"
         >:: test_unset_ceiling_still_drops_the_wide_candidate;
         "gate bands under Demote_over_max" >:: test_gate_demote_bands;
         "the walk emits the narrow stop first"
         >:: test_walk_emits_the_narrow_stop_first;
       ]

let () = run_test_tt_main suite
