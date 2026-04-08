(** Tests for Synthetic_source — deterministic bar generation. *)

open Core
open OUnit2
open Matchers

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)
let start_date = Date.of_string "2024-01-02"

let make_query ?start_date ?end_date symbol : Data_source.bar_query =
  { symbol; period = Types.Cadence.Daily; start_date; end_date }

(* ------------------------------------------------------------------ *)
(* Trending: bar count and price progression                           *)
(* ------------------------------------------------------------------ *)

let test_trending_generates_bars _ =
  let cfg =
    {
      Synthetic_source.start_date;
      symbols =
        [
          ( "AAPL",
            Synthetic_source.Trending
              { start_price = 100.0; weekly_gain_pct = 0.01; volume = 1000 } );
        ];
    }
  in
  let (module Src) = Synthetic_source.make cfg in
  let bars =
    run_deferred (Src.get_bars ~query:(make_query "AAPL") ()) |> function
    | Ok b -> b
    | Error e -> failwith (Status.show e)
  in
  (* We get up to max_bars weekday bars — verify we get many bars *)
  assert_that (List.length bars) (gt (module Int_ord) 50);
  (* First bar should be at start_date *)
  assert_that (List.hd_exn bars)
    (field (fun b -> b.Types.Daily_price.date) (equal_to start_date))

let test_trending_prices_increase _ =
  let cfg =
    {
      Synthetic_source.start_date;
      symbols =
        [
          ( "AAPL",
            Synthetic_source.Trending
              { start_price = 100.0; weekly_gain_pct = 0.01; volume = 1000 } );
        ];
    }
  in
  let (module Src) = Synthetic_source.make cfg in
  let end_date = Date.add_days start_date 30 in
  let bars =
    run_deferred (Src.get_bars ~query:(make_query ~end_date "AAPL") ())
    |> function
    | Ok b -> b
    | Error e -> failwith (Status.show e)
  in
  let first = List.hd_exn bars in
  let last = List.last_exn bars in
  assert_that last.Types.Daily_price.close_price
    (gt (module Float_ord) first.Types.Daily_price.close_price)

(* ------------------------------------------------------------------ *)
(* Basing: price oscillates around base_price                          *)
(* ------------------------------------------------------------------ *)

let test_basing_stays_near_base _ =
  let base = 50.0 in
  let noise = 0.02 in
  let cfg =
    {
      Synthetic_source.start_date;
      symbols =
        [
          ( "XYZ",
            Synthetic_source.Basing
              { base_price = base; noise_pct = noise; volume = 500 } );
        ];
    }
  in
  let (module Src) = Synthetic_source.make cfg in
  let end_date = Date.add_days start_date 60 in
  let bars =
    run_deferred (Src.get_bars ~query:(make_query ~end_date "XYZ") ())
    |> function
    | Ok b -> b
    | Error e -> failwith (Status.show e)
  in
  (* All close prices should be within ±noise_pct of base *)
  let tolerance = base *. noise *. 1.01 in
  List.iter bars ~f:(fun b ->
      let diff = Float.abs (b.Types.Daily_price.close_price -. base) in
      assert_that diff (le (module Float_ord) tolerance))

(* ------------------------------------------------------------------ *)
(* Breakout: basing phase then uptrend                                 *)
(* ------------------------------------------------------------------ *)

let test_breakout_has_basing_then_trend _ =
  let base = 80.0 in
  let base_weeks = 4 in
  let cfg =
    {
      Synthetic_source.start_date;
      symbols =
        [
          ( "BRK",
            Synthetic_source.Breakout
              {
                base_price = base;
                base_weeks;
                weekly_gain_pct = 0.02;
                breakout_volume_mult = 2.5;
                base_volume = 1000;
              } );
        ];
    }
  in
  let (module Src) = Synthetic_source.make cfg in
  let end_date = Date.add_days start_date ((base_weeks * 7) + 30) in
  let bars =
    run_deferred (Src.get_bars ~query:(make_query ~end_date "BRK") ())
    |> function
    | Ok b -> b
    | Error e -> failwith (Status.show e)
  in
  (* Total bars: base_days (~20) + trending days *)
  assert_that (List.length bars) (gt (module Int_ord) (base_weeks * 5));
  (* Price at the end should be above base (uptrend after breakout) *)
  let last_price = (List.last_exn bars).Types.Daily_price.close_price in
  assert_that last_price (gt (module Float_ord) (base *. 1.04))

(* ------------------------------------------------------------------ *)
(* Declining: prices fall                                              *)
(* ------------------------------------------------------------------ *)

let test_declining_prices_fall _ =
  let cfg =
    {
      Synthetic_source.start_date;
      symbols =
        [
          ( "FALL",
            Synthetic_source.Declining
              { start_price = 200.0; weekly_loss_pct = 0.02; volume = 800 } );
        ];
    }
  in
  let (module Src) = Synthetic_source.make cfg in
  let end_date = Date.add_days start_date 30 in
  let bars =
    run_deferred (Src.get_bars ~query:(make_query ~end_date "FALL") ())
    |> function
    | Ok b -> b
    | Error e -> failwith (Status.show e)
  in
  let first = List.hd_exn bars in
  let last = List.last_exn bars in
  assert_that last.Types.Daily_price.close_price
    (lt (module Float_ord) first.Types.Daily_price.close_price)

(* ------------------------------------------------------------------ *)
(* Unknown symbol returns error                                         *)
(* ------------------------------------------------------------------ *)

let test_unknown_symbol_returns_error _ =
  let cfg =
    {
      Synthetic_source.start_date;
      symbols =
        [
          ( "AAPL",
            Synthetic_source.Trending
              { start_price = 100.0; weekly_gain_pct = 0.01; volume = 1000 } );
        ];
    }
  in
  let (module Src) = Synthetic_source.make cfg in
  let result = run_deferred (Src.get_bars ~query:(make_query "UNKNOWN") ()) in
  assert_that result is_error

(* ------------------------------------------------------------------ *)
(* get_universe returns configured symbols                              *)
(* ------------------------------------------------------------------ *)

let test_get_universe_returns_symbols _ =
  let cfg =
    {
      Synthetic_source.start_date;
      symbols =
        [
          ( "AAPL",
            Synthetic_source.Trending
              { start_price = 100.0; weekly_gain_pct = 0.01; volume = 1000 } );
          ( "XYZ",
            Synthetic_source.Basing
              { base_price = 50.0; noise_pct = 0.02; volume = 500 } );
        ];
    }
  in
  let (module Src) = Synthetic_source.make cfg in
  let instruments =
    run_deferred (Src.get_universe ()) |> function
    | Ok i -> i
    | Error e -> failwith (Status.show e)
  in
  assert_that instruments (size_is 2);
  let symbols =
    List.map instruments ~f:(fun i -> i.Types.Instrument_info.symbol)
    |> List.sort ~compare:String.compare
  in
  assert_that symbols (elements_are [ equal_to "AAPL"; equal_to "XYZ" ])

(* ------------------------------------------------------------------ *)
(* end_date filtering                                                   *)
(* ------------------------------------------------------------------ *)

let test_end_date_filters_bars _ =
  let cfg =
    {
      Synthetic_source.start_date;
      symbols =
        [
          ( "AAPL",
            Synthetic_source.Trending
              { start_price = 100.0; weekly_gain_pct = 0.01; volume = 1000 } );
        ];
    }
  in
  let (module Src) = Synthetic_source.make cfg in
  let end_date = Date.add_days start_date 9 in
  let bars =
    run_deferred (Src.get_bars ~query:(make_query ~end_date "AAPL") ())
    |> function
    | Ok b -> b
    | Error e -> failwith (Status.show e)
  in
  (* 10 days (2024-01-02 to 2024-01-11) = 8 weekdays *)
  assert_that (List.length bars) (gt (module Int_ord) 4);
  List.iter bars ~f:(fun b ->
      let d = b.Types.Daily_price.date in
      assert_bool
        (Printf.sprintf "bar date %s > end_date %s" (Date.to_string d)
           (Date.to_string end_date))
        Date.(d <= end_date))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "synthetic_source"
  >::: [
         "trending_generates_bars" >:: test_trending_generates_bars;
         "trending_prices_increase" >:: test_trending_prices_increase;
         "basing_stays_near_base" >:: test_basing_stays_near_base;
         "breakout_has_basing_then_trend"
         >:: test_breakout_has_basing_then_trend;
         "declining_prices_fall" >:: test_declining_prices_fall;
         "unknown_symbol_returns_error" >:: test_unknown_symbol_returns_error;
         "get_universe_returns_symbols" >:: test_get_universe_returns_symbols;
         "end_date_filters_bars" >:: test_end_date_filters_bars;
       ]

let () = run_test_tt_main suite
