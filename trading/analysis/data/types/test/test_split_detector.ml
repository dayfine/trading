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
    active_through = None;
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
(* Issue #3104: ADR dividends > 5% read as splits                       *)
(* ------------------------------------------------------------------ *)

(* The rule #3104 adds, switched on: a 10% minimum band plus a raw-gap
   confirmation (the raw close must carry at least half of the factor's
   log-magnitude). dev/notes/split-detector-dividend-misfire-2026-10-03.md
   has the bar-store counts behind both values. *)
let detect_strict prev curr =
  Split_detector.detect_split ~dividend_threshold:0.10
    ~raw_confirm_min_share:0.5 ~prev ~curr ()

let detect_raw_confirm_only prev curr =
  Split_detector.detect_split ~raw_confirm_min_share:0.5 ~prev ~curr ()

(* FUJIY 2020-09-25 -> 2020-09-28, verbatim from the bar store: the raw close
   ROSE 2.0% while adjusted_close jumped 8.0%, so factor = 1.0590, which the
   default detector snaps to 18/17. An ex-dividend date, not a split. *)
let fujiy_prev =
  make_bar ~date:"2020-09-25" ~close_price:48.8071 ~adjusted_close:5.0548

let fujiy_curr =
  make_bar ~date:"2020-09-28" ~close_price:49.7991 ~adjusted_close:5.4616

(* DHLGY 2025-05-05 -> 2025-05-06, verbatim: raw close -3.7%, adjusted +1.2%,
   factor 1.0505 -> 21/20 under the default detector. DHL's post-AGM ~5%
   dividend. The raw drop is consistent with the factor, so only the band
   (not the raw-gap check) can reject it. *)
let dhlgy_prev =
  make_bar ~date:"2025-05-05" ~close_price:43.59 ~adjusted_close:19.9388

let dhlgy_curr =
  make_bar ~date:"2025-05-06" ~close_price:41.97 ~adjusted_close:20.168

(* The default behaviour is the defect. Pinned so the default stays unchanged
   until a flip is decided with a paired golden run. *)
let test_default_reads_adr_dividends_as_splits _ =
  assert_that
    [ detect fujiy_prev fujiy_curr; detect dhlgy_prev dhlgy_curr ]
    (elements_are
       [
         is_some_and (float_equal ~epsilon:1e-9 (18.0 /. 17.0));
         is_some_and (float_equal ~epsilon:1e-9 (21.0 /. 20.0));
       ])

let test_strict_rejects_adr_dividends _ =
  assert_that
    [ detect_strict fujiy_prev fujiy_curr; detect_strict dhlgy_prev dhlgy_curr ]
    (elements_are [ is_none; is_none ])

(* The raw-gap check alone rejects FUJIY (raw moved the wrong way) but not
   DHLGY (raw fell by ~3/4 of the factor), which is why the band is part of
   the rule. *)
let test_raw_confirm_alone_rejects_fujiy_not_dhlgy _ =
  assert_that
    [
      detect_raw_confirm_only fujiy_prev fujiy_curr;
      detect_raw_confirm_only dhlgy_prev dhlgy_curr;
    ]
    (elements_are
       [ is_none; is_some_and (float_equal ~epsilon:1e-9 (21.0 /. 20.0)) ])

(* Real splits with a same-day economic move, so the raw-gap check is
   exercised away from the textbook share of exactly 1.0. Each case is
   (prev, curr, expected factor):
   - 3:2 with the stock -4% on the day (adjusted 100 -> 96, raw 150 -> 96);
   - 2:1 with -7% (adjusted 24.32 -> 22.6176, raw 48.64 -> 22.6176);
   - 1:10 reverse with +5% (adjusted 10.00 -> 10.50, raw 1.00 -> 10.50). *)
let real_split_cases =
  [
    ( make_bar ~date:"2023-06-01" ~close_price:150.0 ~adjusted_close:100.0,
      make_bar ~date:"2023-06-02" ~close_price:96.0 ~adjusted_close:96.0,
      1.5 );
    ( make_bar ~date:"2026-03-27" ~close_price:48.64 ~adjusted_close:24.32,
      make_bar ~date:"2026-03-30" ~close_price:22.6176 ~adjusted_close:22.6176,
      2.0 );
    ( make_bar ~date:"2024-01-02" ~close_price:1.00 ~adjusted_close:10.00,
      make_bar ~date:"2024-01-03" ~close_price:10.50 ~adjusted_close:10.50,
      0.1 );
  ]

let _detect_all detector =
  List.map real_split_cases ~f:(fun (prev, curr, _) -> detector prev curr)

let _expected_factors =
  List.map real_split_cases ~f:(fun (_, _, factor) ->
      is_some_and (float_equal ~epsilon:1e-9 factor))

let test_real_splits_detected_rule_on_and_off _ =
  assert_that
    [ _detect_all detect; _detect_all detect_strict ]
    (elements_are
       [ elements_are _expected_factors; elements_are _expected_factors ])

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
         "default reads adr dividends as splits"
         >:: test_default_reads_adr_dividends_as_splits;
         "strict rule rejects adr dividends (fujiy, dhlgy)"
         >:: test_strict_rejects_adr_dividends;
         "raw confirm alone rejects fujiy not dhlgy"
         >:: test_raw_confirm_alone_rejects_fujiy_not_dhlgy;
         "real 3:2, 2:1, 1:10 detected rule on and off"
         >:: test_real_splits_detected_rule_on_and_off;
       ]

let () = run_test_tt_main suite
