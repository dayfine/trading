open OUnit2
open Core
open Matchers
open Types

(* ------------------------------------------------------------------ *)
(* Fixture builders                                                     *)
(* ------------------------------------------------------------------ *)

(* Build a Daily_price.t with the fields the detector reads pinned and
   the others set to plausible defaults. Only [close_price] and
   [adjusted_close] matter for detection; OHLV are filled to keep the
   record well-formed. *)
let make_bar ~date ~close_price ~adjusted_close : Daily_price.t =
  {
    date = Date.of_string date;
    open_price = close_price;
    high_price = close_price;
    low_price = close_price;
    close_price;
    adjusted_close;
    volume = 100_000;
  }

let detect prev curr = Split_detector.detect_split ~prev ~curr ()

(* ------------------------------------------------------------------ *)
(* AAPL 2020-08-31 4:1 forward split                                    *)
(* ------------------------------------------------------------------ *)

(* On 2020-08-28 (last day pre-split) AAPL closed at $499.23 raw, with
   adjusted_close $124.81 (back-rolled by all post-Aug-2020 actions —
   primarily the 4:1 itself, plus a few small dividends). On 2020-08-31
   (split day) it closed at $129.04 both raw and adjusted (the back-roll
   factor flipped to ~1.0 after the split). The detector should recover
   factor = 4.0. *)
let test_aapl_4_to_1_forward_split _ =
  let prev =
    make_bar ~date:"2020-08-28" ~close_price:499.23 ~adjusted_close:124.81
  in
  let curr =
    make_bar ~date:"2020-08-31" ~close_price:129.04 ~adjusted_close:129.04
  in
  assert_that (detect prev curr) (is_some_and (float_equal 4.0))

(* ------------------------------------------------------------------ *)
(* TSLA 2020-08-31 5:1 forward split                                    *)
(* ------------------------------------------------------------------ *)

(* TSLA's 5:1 on the same date. We use a stylised pair where the raw
   price falls by exactly 5x and adjusted_close is continuous, so the
   detector recovers factor = 5.0 cleanly. (Real EODHD bars have the
   same shape modulo ε from intraday move and dividend back-roll — that
   ε is well within rational_snap_tolerance.) *)
let test_tsla_5_to_1_forward_split _ =
  let prev =
    make_bar ~date:"2020-08-28" ~close_price:2213.40 ~adjusted_close:442.68
  in
  let curr =
    make_bar ~date:"2020-08-31" ~close_price:442.68 ~adjusted_close:442.68
  in
  assert_that (detect prev curr) (is_some_and (float_equal 5.0))

(* ------------------------------------------------------------------ *)
(* 1:5 reverse split                                                    *)
(* ------------------------------------------------------------------ *)

(* Reverse split: 5 old shares → 1 new share. Raw price goes UP by 5x;
   adjusted_close stays continuous. Factor = new/old = 1/5 = 0.2. *)
let test_reverse_split_1_to_5 _ =
  let prev =
    make_bar ~date:"2024-01-02" ~close_price:10.00 ~adjusted_close:50.00
  in
  let curr =
    make_bar ~date:"2024-01-03" ~close_price:50.00 ~adjusted_close:50.00
  in
  assert_that (detect prev curr) (is_some_and (float_equal 0.2))

(* ------------------------------------------------------------------ *)
(* 3:2 forward split (boundary)                                         *)
(* ------------------------------------------------------------------ *)

(* 3:2 means 2 old shares → 3 new shares. Raw price falls by factor 2/3.
   Detected factor is new/old = 3/2 = 1.5. This is the smallest factor
   the threshold (5% deviation from 1.0) accepts as a split. *)
let test_boundary_3_to_2_split _ =
  let prev =
    make_bar ~date:"2023-06-01" ~close_price:300.00 ~adjusted_close:200.00
  in
  let curr =
    make_bar ~date:"2023-06-02" ~close_price:200.00 ~adjusted_close:200.00
  in
  assert_that (detect prev curr) (is_some_and (float_equal 1.5))

(* ------------------------------------------------------------------ *)
(* Pure-dividend day (NOT a split)                                      *)
(* ------------------------------------------------------------------ *)

(* A $0.50 dividend on a $100 stock on the day after ex-div: raw moves
   from 100.00 → 100.50 (price recovery), adjusted from 99.40 → 100.50
   (the back-roll factor absorbed the dividend pre-event). The implied
   "factor" is ~1.006 — well below the 5% threshold, so no split. *)
let test_dividend_day_not_a_split _ =
  let prev =
    make_bar ~date:"2023-04-15" ~close_price:100.00 ~adjusted_close:99.40
  in
  let curr =
    make_bar ~date:"2023-04-16" ~close_price:100.50 ~adjusted_close:100.50
  in
  assert_that (detect prev curr) is_none

(* ------------------------------------------------------------------ *)
(* Quiet day with no corporate action                                   *)
(* ------------------------------------------------------------------ *)

(* On a no-corporate-action day the back-roll factor is constant: raw
   and adjusted move by the same percentage. split_factor ≈ 1.0 → None. *)
let test_quiet_day_no_corporate_action _ =
  let prev =
    make_bar ~date:"2023-07-10" ~close_price:150.00 ~adjusted_close:148.50
  in
  let curr =
    make_bar ~date:"2023-07-11" ~close_price:151.50 ~adjusted_close:149.985
  in
  assert_that (detect prev curr) is_none

(* ------------------------------------------------------------------ *)
(* Special-dividend-style large drift that does NOT snap to a small     *)
(* rational (filtered out by max_denominator)                           *)
(* ------------------------------------------------------------------ *)

(* A large adjustment with no rational interpretation in [N/M, M ≤ 20]
   is rejected. Here we engineer split_factor = 1.07 (above 5% threshold
   but ≈ 15/14 = 1.0714 lies just outside the 1e-3 snap tolerance — and
   lower-denom rationals like 11/10 = 1.1 are even further off). *)
let test_unsnappable_drift_not_a_split _ =
  let prev =
    make_bar ~date:"2023-05-01" ~close_price:100.00 ~adjusted_close:100.00
  in
  let curr =
    make_bar ~date:"2023-05-02" ~close_price:100.00 ~adjusted_close:107.00
  in
  assert_that (detect prev curr) is_none

(* ------------------------------------------------------------------ *)
(* Test suite registration                                              *)
(* ------------------------------------------------------------------ *)

let suite =
  "split_detector"
  >::: [
         "aapl 4:1 forward split" >:: test_aapl_4_to_1_forward_split;
         "tsla 5:1 forward split" >:: test_tsla_5_to_1_forward_split;
         "1:5 reverse split" >:: test_reverse_split_1_to_5;
         "boundary 3:2 forward split" >:: test_boundary_3_to_2_split;
         "dividend day not a split" >:: test_dividend_day_not_a_split;
         "quiet day no corporate action" >:: test_quiet_day_no_corporate_action;
         "unsnappable drift not a split" >:: test_unsnappable_drift_not_a_split;
       ]

let () = run_test_tt_main suite
