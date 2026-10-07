(** Issue #3173, strategy side: {!Weinstein_strategy.Stops_split_runner}'s
    detector (shared by the stop rescale and the resting-ticket cancel) honours
    the reader's {!Weinstein_strategy.Bar_reader.split_guard}, so a cash
    dividend the simulator does not treat as a split is not one to the strategy
    either. *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Stops_split_runner = Weinstein_strategy.Stops_split_runner
module CA = Corporate_actions

let _bar date ~close ~adjusted : Types.Daily_price.t =
  {
    date = Date.of_string date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = adjusted;
    volume = 1_000_000;
    active_through = None;
  }

(* TDG 2013-07-11: a $22.00 special on a 160.80 close. The vendor back-rolls
   the prior adjusted close to 138.80, so the detector reads 22/19. *)
let _tdg_bars =
  [
    _bar "2013-07-10" ~close:160.80 ~adjusted:138.80;
    _bar "2013-07-11" ~close:139.50 ~adjusted:139.50;
  ]

(* A real 4:1 split. *)
let _aapl_bars =
  [
    _bar "2020-08-28" ~close:499.23 ~adjusted:124.81;
    _bar "2020-08-31" ~close:129.04 ~adjusted:129.04;
  ]

let _guard ~dividends ~splits =
  Split_dividend_guard.create
    ~load_dividends:(fun _ -> Ok dividends)
    ~load_splits:(fun _ -> Ok splits)
    ()

let _tdg_dividend : CA.dividend =
  {
    ex_date = Date.of_string "2013-07-11";
    unadjusted_amount = Some 22.0;
    adjusted_amount = 22.0;
  }

let _detect ?guard ~symbol ~as_of bars =
  let reader = Bar_reader.of_in_memory_bars [ (symbol, bars) ] in
  let bar_reader =
    Option.value_map guard ~default:reader
      ~f:(Bar_reader.with_split_guard reader)
  in
  Stops_split_runner.detect_split ~bar_reader ~symbol
    ~as_of:(Date.of_string as_of)

(* No guard on the reader: today's behaviour, the dividend reads as 22/19. *)
let test_unguarded_reader_reports_dividend_as_split _ =
  assert_that
    (_detect ~symbol:"TDG" ~as_of:"2013-07-11" _tdg_bars)
    (is_some_and (float_equal (22.0 /. 19.0)))

let test_guarded_reader_drops_dividend_split _ =
  let guard = _guard ~dividends:[ _tdg_dividend ] ~splits:[] in
  assert_that
    (_detect ~guard ~symbol:"TDG" ~as_of:"2013-07-11" _tdg_bars)
    is_none

let test_guarded_reader_keeps_vendor_split _ =
  let guard =
    _guard ~dividends:[]
      ~splits:[ { CA.date = Date.of_string "2020-08-31"; factor = 4.0 } ]
  in
  assert_that
    (_detect ~guard ~symbol:"AAPL" ~as_of:"2020-08-31" _aapl_bars)
    (is_some_and (float_equal 4.0))

let suite =
  "stops_split_dividend_guard"
  >::: [
         "unguarded reader reports dividend as split"
         >:: test_unguarded_reader_reports_dividend_as_split;
         "guarded reader drops dividend split"
         >:: test_guarded_reader_drops_dividend_split;
         "guarded reader keeps vendor split"
         >:: test_guarded_reader_keeps_vendor_split;
       ]

let () = run_test_tt_main suite
