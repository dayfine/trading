open OUnit2
open Core
open Matchers
module CA = Corporate_actions

let _d = Date.of_string

let _div ?(unadjusted = None) ex_date amount : CA.dividend =
  {
    ex_date = _d ex_date;
    unadjusted_amount = Option.first_some unadjusted (Some amount);
    adjusted_amount = amount;
  }

let _no_amount ex_date : CA.dividend =
  { ex_date = _d ex_date; unadjusted_amount = None; adjusted_amount = 1.0 }

(* AD 2025-08-20: a $23.00 special. Stop 67.46, open 51.26, low 50.69. *)
let _ad_special = _div "2025-08-20" 23.0

(* BKE 2021-12-17: a $6.00 special. Stop 45.76, open 40.58, low 40.01. *)
let _bke_special = _div "2021-12-17" 6.0

let test_ad_stop_reduced_below_low _ =
  assert_that
    (Ex_dividend_stop.reduce_for_dividends ~dividends:[ _ad_special ]
       ~after:(_d "2025-08-19") ~through:(_d "2025-08-20") 67.46)
    (all_of [ float_equal 44.46; lt (module Float_ord) 50.69 ])

let test_bke_stop_reduced_below_low _ =
  assert_that
    (Ex_dividend_stop.reduce_for_dividends ~dividends:[ _bke_special ]
       ~after:(_d "2021-12-16") ~through:(_d "2021-12-17") 45.76)
    (all_of [ float_equal 39.76; lt (module Float_ord) 40.01 ])

(* FINRA rounds the reduced price down to the next lower cent. *)
let test_rounds_down_to_cent _ =
  assert_that
    (Ex_dividend_stop.reduce_stop_level ~stop_level:50.0 ~amount:0.125)
    (float_equal 49.87)

let test_below_one_cent_not_adjusted _ =
  assert_that
    (Ex_dividend_stop.reduce_stop_level ~stop_level:50.0 ~amount:0.009)
    (float_equal 50.0)

let test_never_below_zero _ =
  assert_that
    (Ex_dividend_stop.reduce_stop_level ~stop_level:5.0 ~amount:9.0)
    (float_equal 0.0)

(* The window is (after, through]: an ex-date on [after] was already applied
   by the previous tick; one after [through] belongs to a later tick. *)
let test_window_is_half_open _ =
  let dividends =
    [ _div "2025-08-19" 1.0; _div "2025-08-20" 2.0; _div "2025-08-21" 4.0 ]
  in
  assert_that
    (Ex_dividend_stop.reduce_for_dividends ~dividends ~after:(_d "2025-08-19")
       ~through:(_d "2025-08-20") 60.0)
    (float_equal 58.0)

(* A skipped weekend: Friday's and Monday's ex-dates both land on Monday's
   tick, each reduced in turn. *)
let test_two_ex_dates_in_window _ =
  let dividends = [ _div "2025-08-25" 1.0; _div "2025-08-23" 2.0 ] in
  assert_that
    (Ex_dividend_stop.reduce_for_dividends ~dividends ~after:(_d "2025-08-22")
       ~through:(_d "2025-08-25") 60.0)
    (float_equal 57.0)

let test_no_unadjusted_amount_skipped _ =
  assert_that
    (Ex_dividend_stop.reduce_for_dividends
       ~dividends:[ _no_amount "2025-08-20" ]
       ~after:(_d "2025-08-19") ~through:(_d "2025-08-20") 60.0)
    (float_equal 60.0)

let _counting_loader ~calls result symbol =
  Hashtbl.incr calls symbol;
  result

let test_adjust_reads_once_and_counts _ =
  let calls = String.Table.create () in
  let t =
    Ex_dividend_stop.create
      ~load:
        (_counting_loader ~calls
           (Ok [ _ad_special; _no_amount "2025-09-20"; _div "2025-10-20" 0.005 ]))
  in
  let first =
    Ex_dividend_stop.adjust t ~symbol:"AD" ~after:(_d "2025-08-19")
      ~through:(_d "2025-08-20") 67.46
  in
  let (_ : float) =
    Ex_dividend_stop.adjust t ~symbol:"AD" ~after:(_d "2025-09-19")
      ~through:(_d "2025-10-20") 44.46
  in
  assert_that
    (first, Ex_dividend_stop.counts t, Hashtbl.find calls "AD")
    (all_of
       [
         field (fun (s, _, _) -> s) (float_equal 44.46);
         field
           (fun (_, c, _) -> c)
           (equal_to
              ({ reduced = 1; skipped_no_amount = 1; no_files = 0 }
                : Ex_dividend_stop.counts));
         field (fun (_, _, n) -> n) (is_some_and (equal_to 1));
       ])

let test_missing_file_keeps_stop_and_counts _ =
  let calls = String.Table.create () in
  let t =
    Ex_dividend_stop.create
      ~load:(_counting_loader ~calls (Error (Status.not_found_error "none")))
  in
  let adjust () =
    Ex_dividend_stop.adjust t ~symbol:"X" ~after:(_d "2025-08-19")
      ~through:(_d "2025-08-20") 67.46
  in
  let first = adjust () in
  let (_ : float) = adjust () in
  assert_that
    (first, Ex_dividend_stop.counts t, Hashtbl.find calls "X")
    (all_of
       [
         field (fun (s, _, _) -> s) (float_equal 67.46);
         field
           (fun (_, c, _) -> c)
           (equal_to
              ({ reduced = 0; skipped_no_amount = 0; no_files = 1 }
                : Ex_dividend_stop.counts));
         field (fun (_, _, n) -> n) (is_some_and (equal_to 1));
       ])

let suite =
  "ex_dividend_stop"
  >::: [
         "AD stop reduced below low" >:: test_ad_stop_reduced_below_low;
         "BKE stop reduced below low" >:: test_bke_stop_reduced_below_low;
         "rounds down to cent" >:: test_rounds_down_to_cent;
         "below one cent not adjusted" >:: test_below_one_cent_not_adjusted;
         "never below zero" >:: test_never_below_zero;
         "window is half open" >:: test_window_is_half_open;
         "two ex-dates in window" >:: test_two_ex_dates_in_window;
         "no unadjusted amount skipped" >:: test_no_unadjusted_amount_skipped;
         "adjust reads once and counts" >:: test_adjust_reads_once_and_counts;
         "missing file keeps stop and counts"
         >:: test_missing_file_keeps_stop_and_counts;
       ]

let () = run_test_tt_main suite
