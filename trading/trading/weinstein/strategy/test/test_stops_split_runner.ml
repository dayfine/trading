(** Tests for {!Weinstein_strategy.Stops_split_runner}.

    These tests pin three contracts:

    - On a non-split day (yesterday's bar and today's bar move within the
      ordinary dividend / drift band), [stop_states] is left untouched.
    - On a forward 4:1 split day (today's raw close is 25% of yesterday's;
      adjusted_close is continuous), every absolute price field of the affected
      symbol's stop_state is divided by 4.
    - The strategy-level regression: a held position with a pre-split
      [stop_level] of $440 sees its stop scaled to $110 by [adjust], so the
      post-split bar's [low_price] (around $124) does NOT trip
      {!Weinstein_stops.check_stop_hit}. The control case — a post-split bar
      with a [low_price] below the {b adjusted} stop — DOES trip
      [check_stop_hit] as expected.

    The fixture mirrors the AAPL 2020-08-31 4:1 split bars used in the
    simulator's [test_split_day_mtm.ml] — same shape, slightly different numeric
    scale to make the assertions readable. *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Stops_split_runner = Weinstein_strategy.Stops_split_runner
module Position = Trading_strategy.Position

(* ------------------------------------------------------------------ *)
(* Fixture builders                                                     *)
(* ------------------------------------------------------------------ *)

let _make_bar ~date ~open_ ~high ~low ~close ~adjusted_close ~volume =
  Types.Daily_price.
    {
      date;
      open_price = open_;
      high_price = high;
      low_price = low;
      close_price = close;
      adjusted_close;
      volume;
    }

(** Build a snapshot-backed [Bar_reader.t] from a single-symbol bar series. *)
let _bar_reader_of_one_symbol ~symbol bars =
  Bar_reader.of_in_memory_bars [ (symbol, bars) ]

(** Build a Holding-state position for [symbol] — minimal scaffold to feed
    [Stops_split_runner.adjust]. We only need [symbol]; the state machine
    transitions don't matter here. *)
let _make_holding_pos ~symbol ~entry_price ~entry_date =
  let pos_id = symbol in
  let make_trans kind =
    Position.{ position_id = pos_id; date = entry_date; kind }
  in
  let unwrap = function Ok p -> p | Error _ -> assert_failure "pos setup" in
  let p =
    Position.create_entering
      (make_trans
         (Position.CreateEntering
            {
              symbol;
              side = Trading_base.Types.Long;
              target_quantity = 100.0;
              entry_price;
              reasoning =
                Position.ManualDecision { description = "test fixture" };
            }))
    |> unwrap
  in
  let p =
    Position.apply_transition p
      (make_trans
         (Position.EntryFill
            { filled_quantity = 100.0; fill_price = entry_price }))
    |> unwrap
  in
  Position.apply_transition p
    (make_trans
       (Position.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(* Synthetic bars: 2 pre-split + 1 split day + 1 post-split day. The split
   day's raw close is 1/4 of yesterday's; adjusted_close is continuous.
   Detector contract: split_factor = adj_ratio /. raw_ratio = 1.0 /. 0.25
   = 4.0. *)
let _split_bars ~symbol:_ =
  [
    _make_bar
      ~date:(Date.of_string "2024-08-26")
      ~open_:498.0 ~high:502.0 ~low:495.0 ~close:500.0 ~adjusted_close:125.0
      ~volume:1_000_000;
    _make_bar
      ~date:(Date.of_string "2024-08-27")
      ~open_:500.0 ~high:505.0 ~low:498.0 ~close:500.0 ~adjusted_close:125.0
      ~volume:1_000_000;
    (* Split day: raw close 125 (= 500 / 4); adjusted_close 125 (continuous). *)
    _make_bar
      ~date:(Date.of_string "2024-08-28")
      ~open_:125.0 ~high:127.0 ~low:124.0 ~close:125.0 ~adjusted_close:125.0
      ~volume:4_000_000;
    _make_bar
      ~date:(Date.of_string "2024-08-29")
      ~open_:125.0 ~high:126.0 ~low:124.0 ~close:125.0 ~adjusted_close:125.0
      ~volume:4_000_000;
  ]

(* Bars with no split between the last two days. Pure dividend / drift
   band: ratio stays within 5%. *)
let _flat_bars =
  [
    _make_bar
      ~date:(Date.of_string "2024-08-26")
      ~open_:100.0 ~high:101.0 ~low:99.5 ~close:100.0 ~adjusted_close:100.0
      ~volume:1_000_000;
    _make_bar
      ~date:(Date.of_string "2024-08-27")
      ~open_:100.0 ~high:101.0 ~low:99.5 ~close:100.5 ~adjusted_close:100.5
      ~volume:1_000_000;
  ]

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

(* Pin: on a non-split day the stop_state is unchanged. *)
let test_no_split_leaves_stop_state_untouched _ =
  let symbol = "AAPL" in
  let bar_reader = _bar_reader_of_one_symbol ~symbol _flat_bars in
  let pos =
    _make_holding_pos ~symbol ~entry_price:100.0
      ~entry_date:(Date.of_string "2024-08-26")
  in
  let positions = String.Map.singleton symbol pos in
  let initial_stop =
    Weinstein_stops.Initial { stop_level = 95.0; reference_level = 98.0 }
  in
  let stop_states = ref (String.Map.singleton symbol initial_stop) in
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:(Date.of_string "2024-08-27");
  assert_that
    (Map.find !stop_states symbol)
    (is_some_and (equal_to initial_stop))

(* Pin: on a 4:1 split day every absolute price in the stop_state divides
   by 4. The pre-split AAPL example: stop $440 → $110, reference $448 →
   $112. *)
let test_forward_4_to_1_scales_initial_stop _ =
  let symbol = "AAPL" in
  let bar_reader = _bar_reader_of_one_symbol ~symbol (_split_bars ~symbol) in
  let pos =
    _make_holding_pos ~symbol ~entry_price:500.0
      ~entry_date:(Date.of_string "2024-08-26")
  in
  let positions = String.Map.singleton symbol pos in
  let initial_stop =
    Weinstein_stops.Initial { stop_level = 440.0; reference_level = 448.0 }
  in
  let stop_states = ref (String.Map.singleton symbol initial_stop) in
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:(Date.of_string "2024-08-28");
  assert_that
    (Map.find !stop_states symbol)
    (is_some_and
       (equal_to
          (Weinstein_stops.Initial
             { stop_level = 110.0; reference_level = 112.0 })))

(* Pin: a Trailing-state stop scales the same way; correction_count is
   preserved. *)
let test_forward_4_to_1_scales_trailing_stop _ =
  let symbol = "AAPL" in
  let bar_reader = _bar_reader_of_one_symbol ~symbol (_split_bars ~symbol) in
  let pos =
    _make_holding_pos ~symbol ~entry_price:500.0
      ~entry_date:(Date.of_string "2024-08-26")
  in
  let positions = String.Map.singleton symbol pos in
  let trailing =
    Weinstein_stops.Trailing
      {
        stop_level = 440.0;
        last_correction_extreme = 460.0;
        last_trend_extreme = 520.0;
        ma_at_last_adjustment = 480.0;
        correction_count = 2;
        correction_observed_since_reset = true;
      }
  in
  let stop_states = ref (String.Map.singleton symbol trailing) in
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:(Date.of_string "2024-08-28");
  assert_that
    (Map.find !stop_states symbol)
    (is_some_and
       (equal_to
          (Weinstein_stops.Trailing
             {
               stop_level = 110.0;
               last_correction_extreme = 115.0;
               last_trend_extreme = 130.0;
               ma_at_last_adjustment = 120.0;
               correction_count = 2;
               correction_observed_since_reset = true;
             })))

(* Strategy-level regression. After [adjust] runs on a 4:1 split day, the
   post-split bar's low ($124) is comparable to the post-split stop
   ($110), and {!check_stop_hit} returns false — no spurious exit.

   This is the load-bearing scenario: pre-fix, the test would fail because
   the pre-split $440 stop would be compared against the $124 low and
   {!check_stop_hit} would return true. *)
let test_split_day_no_spurious_stop_hit _ =
  let symbol = "AAPL" in
  let bars = _split_bars ~symbol in
  let bar_reader = _bar_reader_of_one_symbol ~symbol bars in
  let pos =
    _make_holding_pos ~symbol ~entry_price:500.0
      ~entry_date:(Date.of_string "2024-08-26")
  in
  let positions = String.Map.singleton symbol pos in
  let stop_states =
    ref
      (String.Map.singleton symbol
         (Weinstein_stops.Initial
            { stop_level = 440.0; reference_level = 448.0 }))
  in
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:(Date.of_string "2024-08-28");
  let split_day_bar =
    List.nth_exn bars 2
    (* the split day: low 124 *)
  in
  let scaled = Map.find_exn !stop_states symbol in
  assert_that
    (Weinstein_stops.check_stop_hit ~state:scaled ~side:Trading_base.Types.Long
       ~bar:split_day_bar)
    (equal_to false)

(* Control case: same scenario, but the post-split bar drops below the
   {b adjusted} stop level. The state machine fires as expected — proving
   that [adjust] only neutralises the {e split-induced} phantom drop, not
   real adverse moves. *)
let test_real_adverse_move_after_split_still_triggers _ =
  let symbol = "AAPL" in
  let bars =
    [
      _make_bar
        ~date:(Date.of_string "2024-08-26")
        ~open_:498.0 ~high:502.0 ~low:495.0 ~close:500.0 ~adjusted_close:125.0
        ~volume:1_000_000;
      (* Split day. *)
      _make_bar
        ~date:(Date.of_string "2024-08-27")
        ~open_:125.0 ~high:127.0 ~low:124.0 ~close:125.0 ~adjusted_close:125.0
        ~volume:4_000_000;
      (* Post-split adverse move: low 100 < adjusted stop 110. *)
      _make_bar
        ~date:(Date.of_string "2024-08-28")
        ~open_:120.0 ~high:120.0 ~low:100.0 ~close:105.0 ~adjusted_close:105.0
        ~volume:4_000_000;
    ]
  in
  let bar_reader = _bar_reader_of_one_symbol ~symbol bars in
  let pos =
    _make_holding_pos ~symbol ~entry_price:500.0
      ~entry_date:(Date.of_string "2024-08-26")
  in
  let positions = String.Map.singleton symbol pos in
  let stop_states =
    ref
      (String.Map.singleton symbol
         (Weinstein_stops.Initial
            { stop_level = 440.0; reference_level = 448.0 }))
  in
  (* Run on the split day (bar index 1 = today). *)
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:(Date.of_string "2024-08-27");
  (* Now check the post-split adverse bar. *)
  let adverse_bar = List.nth_exn bars 2 in
  let scaled = Map.find_exn !stop_states symbol in
  assert_that
    (Weinstein_stops.check_stop_hit ~state:scaled ~side:Trading_base.Types.Long
       ~bar:adverse_bar)
    (equal_to true)

(* Pin: when the position has no entry in [stop_states], adjust is a
   no-op and [stop_states] stays empty. *)
let test_position_without_stop_state_is_noop _ =
  let symbol = "AAPL" in
  let bar_reader = _bar_reader_of_one_symbol ~symbol (_split_bars ~symbol) in
  let pos =
    _make_holding_pos ~symbol ~entry_price:500.0
      ~entry_date:(Date.of_string "2024-08-26")
  in
  let positions = String.Map.singleton symbol pos in
  let stop_states = ref String.Map.empty in
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:(Date.of_string "2024-08-28");
  assert_that (Map.is_empty !stop_states) (equal_to true)

(* Suite. *)

let () =
  run_test_tt_main
    ("stops_split_runner"
    >::: [
           "non-split day leaves stop_state untouched"
           >:: test_no_split_leaves_stop_state_untouched;
           "4:1 forward split scales Initial stop_state by 1/4"
           >:: test_forward_4_to_1_scales_initial_stop;
           "4:1 forward split scales Trailing stop_state by 1/4 \
            (correction_count preserved)"
           >:: test_forward_4_to_1_scales_trailing_stop;
           "split day: post-split bar low does NOT trip stop after adjust"
           >:: test_split_day_no_spurious_stop_hit;
           "real adverse move after split DOES trip the adjusted stop"
           >:: test_real_adverse_move_after_split_still_triggers;
           "position without stop_state entry is a no-op"
           >:: test_position_without_stop_state_is_noop;
         ])
