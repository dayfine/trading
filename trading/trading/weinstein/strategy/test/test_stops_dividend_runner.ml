(** Issue #3174, strategy side: {!Weinstein_strategy.Stops_dividend_runner}
    reduces a held long's stop level by the cash dividend on its ex-date, so the
    dividend drop no longer reads as a stop hit. Fixtures are AD- and
    BKE-shaped: the real stop, open and low of the two specimens. *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Runner = Weinstein_strategy.Stops_dividend_runner
module Position = Trading_strategy.Position
module CA = Corporate_actions

let _bar date ~open_ ~low ~close : Types.Daily_price.t =
  {
    date = Date.of_string date;
    open_price = open_;
    high_price = Float.max open_ close;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* AD 2025-08-20: a $23.00 special. Stop 67.46, open 51.26, low 50.69. *)
let _ad_bars =
  [
    _bar "2025-08-19" ~open_:74.0 ~low:73.5 ~close:74.2;
    _bar "2025-08-20" ~open_:51.26 ~low:50.69 ~close:51.5;
    _bar "2025-08-21" ~open_:51.5 ~low:51.0 ~close:52.0;
  ]

(* BKE 2021-12-17: a $6.00 special. Stop 45.76, open 40.58, low 40.01. *)
let _bke_bars =
  [
    _bar "2021-12-16" ~open_:47.0 ~low:46.5 ~close:46.8;
    _bar "2021-12-17" ~open_:40.58 ~low:40.01 ~close:40.9;
  ]

let _dividend ex_date amount : CA.dividend =
  {
    ex_date = Date.of_string ex_date;
    unadjusted_amount = Some amount;
    adjusted_amount = amount;
  }

let _holding ?(side = Trading_base.Types.Long) ~symbol ~entry_date () =
  let trans kind =
    Position.{ position_id = symbol; date = Date.of_string entry_date; kind }
  in
  let unwrap = function Ok p -> p | Error _ -> failwith "pos setup" in
  let p =
    Position.create_entering
      (trans
         (Position.CreateEntering
            {
              symbol;
              side;
              target_quantity = 100.0;
              entry_price = 60.0;
              reasoning = Position.ManualDecision { description = "fixture" };
            }))
    |> unwrap
  in
  let p =
    Position.apply_transition p
      (trans
         (Position.EntryFill { filled_quantity = 100.0; fill_price = 60.0 }))
    |> unwrap
  in
  Position.apply_transition p
    (trans
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

let _trailing stop_level : Weinstein_stops.stop_state =
  Trailing
    {
      stop_level;
      last_correction_extreme = 60.0;
      last_trend_extreme = 80.0;
      ma_at_last_adjustment = 65.0;
      correction_count = 2;
      correction_observed_since_reset = false;
    }

(* Run one tick for a single position and return the stop state after it. *)
let _run ?dividends ?(side = Trading_base.Types.Long)
    ?(entry_date = "2025-01-02") ~symbol ~bars ~stop ~as_of () =
  let reader = Bar_reader.of_in_memory_bars [ (symbol, bars) ] in
  let bar_reader =
    Option.value_map dividends ~default:reader ~f:(fun divs ->
        Bar_reader.with_ex_dividend_stops reader
          (Ex_dividend_stop.create ~load:(fun _ -> Ok divs)))
  in
  let positions =
    String.Map.singleton symbol (_holding ~side ~symbol ~entry_date ())
  in
  let stop_states = ref (String.Map.singleton symbol stop) in
  Runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:(Date.of_string as_of);
  Map.find_exn !stop_states symbol

let _hit ?(side = Trading_base.Types.Long) ~bars ~as_of state =
  let bar =
    List.find_exn bars ~f:(fun (b : Types.Daily_price.t) ->
        Date.equal b.date (Date.of_string as_of))
  in
  Weinstein_stops.check_stop_hit ~state ~side ~bar ()

let _ad_dividend = [ _dividend "2025-08-20" 23.0 ]

(* Flag off (no reducer on the reader): today's behaviour, the stop stays at
   67.46 and the ex-date bar trips it. *)
let test_no_reducer_ad_stopped_on_dividend_drop _ =
  let state =
    _run ~symbol:"AD" ~bars:_ad_bars ~stop:(_trailing 67.46) ~as_of:"2025-08-20"
      ()
  in
  assert_that
    (state, _hit ~bars:_ad_bars ~as_of:"2025-08-20" state)
    (all_of
       [
         field
           (fun (s, _) -> Weinstein_stops.get_stop_level s)
           (float_equal 67.46);
         field (fun (_, hit) -> hit) (equal_to true);
       ])

let test_ad_stop_reduced_not_hit _ =
  let state =
    _run ~dividends:_ad_dividend ~symbol:"AD" ~bars:_ad_bars
      ~stop:(_trailing 67.46) ~as_of:"2025-08-20" ()
  in
  assert_that
    (state, _hit ~bars:_ad_bars ~as_of:"2025-08-20" state)
    (all_of
       [
         field (fun (s, _) -> s) (equal_to (_trailing 44.46));
         field (fun (_, hit) -> hit) (equal_to false);
       ])

let test_bke_stop_reduced_not_hit _ =
  let state =
    _run
      ~dividends:[ _dividend "2021-12-17" 6.0 ]
      ~entry_date:"2021-06-01" ~symbol:"BKE" ~bars:_bke_bars
      ~stop:(_trailing 45.76) ~as_of:"2021-12-17" ()
  in
  assert_that
    (state, _hit ~bars:_bke_bars ~as_of:"2021-12-17" state)
    (all_of
       [
         field
           (fun (s, _) -> Weinstein_stops.get_stop_level s)
           (float_equal 39.76);
         field (fun (_, hit) -> hit) (equal_to false);
       ])

(* The day after the ex-date: the dividend is outside the window, the stop is
   not reduced a second time. *)
let test_day_after_ex_date_unchanged _ =
  assert_that
    (_run ~dividends:_ad_dividend ~symbol:"AD" ~bars:_ad_bars
       ~stop:(_trailing 44.46) ~as_of:"2025-08-21" ())
    (equal_to (_trailing 44.46))

(* A short's protective stop is a buy stop, which FINRA 5330 leaves alone. *)
let test_short_unchanged _ =
  assert_that
    (_run ~dividends:_ad_dividend ~side:Trading_base.Types.Short ~symbol:"AD"
       ~bars:_ad_bars ~stop:(_trailing 80.0) ~as_of:"2025-08-20" ())
    (equal_to (_trailing 80.0))

(* Entered on the ex-date: its stop was set on ex-dividend prices already. *)
(* #3193 review: a tick with no bar for the symbol (08-21 here: a halt or a
   vendor gap) must not reuse the 08-19..08-20 window and reduce the stop a
   second time. *)
let test_no_bar_tick_does_not_reduce_again _ =
  assert_that
    (_run ~dividends:_ad_dividend ~symbol:"AD" ~bars:(List.take _ad_bars 2)
       ~stop:(_trailing 44.46) ~as_of:"2025-08-21" ())
    (equal_to (_trailing 44.46))

(* An ex-date with no bar of its own (08-20 missing) is applied on the next
   bar's tick, whose window starts at the bar before (08-19). *)
let test_ex_date_without_bar_applied_next_bar _ =
  let bars = [ List.nth_exn _ad_bars 0; List.nth_exn _ad_bars 2 ] in
  assert_that
    (_run ~dividends:_ad_dividend ~symbol:"AD" ~bars ~stop:(_trailing 67.46)
       ~as_of:"2025-08-21" ())
    (equal_to (_trailing 44.46))

let test_entry_on_ex_date_unchanged _ =
  assert_that
    (_run ~dividends:_ad_dividend ~entry_date:"2025-08-20" ~symbol:"AD"
       ~bars:_ad_bars ~stop:(_trailing 45.0) ~as_of:"2025-08-20" ())
    (equal_to (_trailing 45.0))

let test_with_stop_level_initial _ =
  assert_that
    (Runner.with_stop_level
       (Initial { stop_level = 50.0; reference_level = 52.0 })
       40.0)
    (equal_to
       (Weinstein_stops.Initial { stop_level = 40.0; reference_level = 52.0 }))

let test_with_stop_level_tightened _ =
  assert_that
    (Runner.with_stop_level
       (Tightened
          {
            stop_level = 50.0;
            last_correction_extreme = 48.0;
            reason = "r";
            swing_peak = Some 60.0;
          })
       40.0)
    (equal_to
       (Weinstein_stops.Tightened
          {
            stop_level = 40.0;
            last_correction_extreme = 48.0;
            reason = "r";
            swing_peak = Some 60.0;
          }))

let suite =
  "stops_dividend_runner"
  >::: [
         "no reducer: AD stopped on dividend drop"
         >:: test_no_reducer_ad_stopped_on_dividend_drop;
         "AD stop reduced, not hit" >:: test_ad_stop_reduced_not_hit;
         "BKE stop reduced, not hit" >:: test_bke_stop_reduced_not_hit;
         "day after ex-date unchanged" >:: test_day_after_ex_date_unchanged;
         "short unchanged" >:: test_short_unchanged;
         "entry on ex-date unchanged" >:: test_entry_on_ex_date_unchanged;
         "no-bar tick does not reduce again"
         >:: test_no_bar_tick_does_not_reduce_again;
         "ex-date without a bar applied on the next bar"
         >:: test_ex_date_without_bar_applied_next_bar;
         "with_stop_level initial" >:: test_with_stop_level_initial;
         "with_stop_level tightened" >:: test_with_stop_level_tightened;
       ]

let () = run_test_tt_main suite
