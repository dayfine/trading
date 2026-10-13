(* Issue #3109: the detector fires on adjusted-series steps the raw close does
   not confirm. Two shapes:
   - adjusted-only steps with no raw gap (AABA 2000-02-14, KKD 2001-06-15),
     rejected by [raw_confirm_min_share];
   - frozen-adjusted days (adjusted close bit-identical, raw close moved
     5-25 %), rejected by the frozen-adjusted check that rides on the same
     parameter.
   With the parameter omitted every shape still reads as a split, so the
   default path is unchanged until the default flip is decided. *)

open OUnit2
open Core
open Matchers
open Types

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

(* The recommended rule from dev/notes/split-detector-dividend-misfire-2026-10-03.md. *)
let detect_strict prev curr =
  Split_detector.detect_split ~dividend_threshold:0.10
    ~raw_confirm_min_share:0.5 ~prev ~curr ()

let detect_raw_confirm_only prev curr =
  Split_detector.detect_split ~raw_confirm_min_share:0.5 ~prev ~curr ()

(* AABA-shaped: the adjusted close doubles (the back-roll steps by the 2:1)
   while the raw close moves +1 %. Factor 2.0; the raw gap carries a negative
   share of it. *)
let aaba_prev =
  make_bar ~date:"2000-02-11" ~close_price:400.0 ~adjusted_close:200.0

let aaba_curr =
  make_bar ~date:"2000-02-14" ~close_price:404.0 ~adjusted_close:404.0

(* KKD-shaped: the adjusted close halves while the raw close moves -1 %.
   Factor 0.5 (a phantom 1:2 reverse split). *)
let kkd_prev =
  make_bar ~date:"2001-06-14" ~close_price:70.0 ~adjusted_close:70.0

let kkd_curr =
  make_bar ~date:"2001-06-15" ~close_price:69.3 ~adjusted_close:34.65

(* Frozen adjusted close, raw -6.7 %: snaps to 15/14 (0.05-0.10 band). *)
let frozen_small_prev =
  make_bar ~date:"2010-05-03" ~close_price:30.0 ~adjusted_close:20.0

let frozen_small_curr =
  make_bar ~date:"2010-05-04" ~close_price:28.0 ~adjusted_close:20.0

(* Frozen adjusted close, raw -16.7 %: snaps to 6/5 (0.10-0.25 band), past
   the strict rule's 0.10 dividend band. *)
let frozen_mid_prev =
  make_bar ~date:"2011-08-01" ~close_price:60.0 ~adjusted_close:40.0

let frozen_mid_curr =
  make_bar ~date:"2011-08-02" ~close_price:50.0 ~adjusted_close:40.0

(* Real splits on a flat adjusted close: 2:1 (raw 100 -> 50) and 1:5 reverse
   (raw 2 -> 10), adjusted close unchanged on the day. *)
let frozen_2_for_1_prev =
  make_bar ~date:"2015-03-02" ~close_price:100.0 ~adjusted_close:50.0

let frozen_2_for_1_curr =
  make_bar ~date:"2015-03-03" ~close_price:50.0 ~adjusted_close:50.0

let frozen_reverse_prev =
  make_bar ~date:"2016-04-04" ~close_price:2.0 ~adjusted_close:10.0

let frozen_reverse_curr =
  make_bar ~date:"2016-04-05" ~close_price:10.0 ~adjusted_close:10.0

let _all detector =
  [
    detector aaba_prev aaba_curr;
    detector kkd_prev kkd_curr;
    detector frozen_small_prev frozen_small_curr;
    detector frozen_mid_prev frozen_mid_curr;
  ]

let _factor f = is_some_and (float_equal ~epsilon:1e-9 f)

(* Pinned defect: the default reads every misaligned shape as a split. *)
let test_default_reads_misalignments_as_splits _ =
  assert_that (_all detect)
    (elements_are
       [ _factor 2.0; _factor 0.5; _factor (15.0 /. 14.0); _factor 1.2 ])

let test_strict_rejects_misalignments _ =
  assert_that (_all detect_strict)
    (elements_are [ is_none; is_none; is_none; is_none ])

(* Without the 0.10 band, the frozen check alone still drops the 15/14. *)
let test_raw_confirm_only_rejects_frozen_small_band _ =
  assert_that
    (_all detect_raw_confirm_only)
    (elements_are [ is_none; is_none; is_none; is_none ])

let test_real_splits_on_frozen_adjusted_kept _ =
  assert_that
    [
      detect_strict frozen_2_for_1_prev frozen_2_for_1_curr;
      detect_strict frozen_reverse_prev frozen_reverse_curr;
    ]
    (elements_are [ _factor 2.0; _factor 0.2 ])

(* The deviation floor is a live knob when the raw check is on, and ignored
   when it is off. *)
let test_frozen_min_deviation_gated_by_raw_confirm _ =
  let detect_floor ?raw_confirm_min_share prev curr =
    Split_detector.detect_split ?raw_confirm_min_share
      ~frozen_adjusted_min_deviation:1.5 ~prev ~curr ()
  in
  assert_that
    [
      detect_floor ~raw_confirm_min_share:0.5 frozen_2_for_1_prev
        frozen_2_for_1_curr;
      detect_floor frozen_2_for_1_prev frozen_2_for_1_curr;
      detect_floor frozen_small_prev frozen_small_curr;
    ]
    (elements_are [ is_none; _factor 2.0; _factor (15.0 /. 14.0) ])

let suite =
  "split_detector_misalignment"
  >::: [
         "default reads aaba, kkd, frozen days as splits"
         >:: test_default_reads_misalignments_as_splits;
         "strict rule rejects aaba, kkd, frozen days"
         >:: test_strict_rejects_misalignments;
         "raw confirm only rejects frozen 15/14"
         >:: test_raw_confirm_only_rejects_frozen_small_band;
         "real 2:1 and 1:5 on frozen adjusted close kept"
         >:: test_real_splits_on_frozen_adjusted_kept;
         "frozen min deviation gated by raw confirm"
         >:: test_frozen_min_deviation_gated_by_raw_confirm;
       ]

let () = run_test_tt_main suite
