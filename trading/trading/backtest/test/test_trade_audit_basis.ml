(** Unit tests for [Trade_audit_basis] — the price-basis selection the
    trade-audit report's on-demand bar reads run through.

    Coverage:
    - [window_closes] prefers the adjusted column when it is entirely finite
    - the fallback to raw is WHOLESALE, never per-bar: a single NaN anywhere in
      the adjusted column yields the raw column in full (the anti-mixing pin — a
      spliced window would reintroduce the cross-split discontinuity the module
      exists to remove)
    - non-finite means non-finite: infinities fall back too, not just NaN
    - empty in, empty out
    - [last_close] reads the window's newest cell, and answers [None] rather
      than reaching backwards past a non-finite one *)

open OUnit2
open Core
open Matchers
module TB = Trade_audit_basis

let _closes ~adjusted ~raw = Array.to_list (TB.window_closes ~adjusted ~raw)

(* -- window_closes: basis preference ------------------------------------- *)

let test_window_prefers_adjusted_when_all_finite _ =
  assert_that
    (_closes ~adjusted:[| 10.0; 11.0; 12.0 |] ~raw:[| 40.0; 44.0; 48.0 |])
    (elements_are [ float_equal 10.0; float_equal 11.0; float_equal 12.0 ])

let test_window_empty_in_empty_out _ =
  assert_that (_closes ~adjusted:[||] ~raw:[||]) is_empty

(* -- window_closes: the fallback is wholesale, never spliced ------------- *)

(* The load-bearing case. If the fallback were per-bar, the result would be
   [40.0; 11.0; 12.0] — an adjusted window with one raw close spliced in, i.e.
   exactly the fake discontinuity this module removes. It must be all-raw. *)
let test_nan_at_head_falls_back_to_whole_raw_window _ =
  assert_that
    (_closes ~adjusted:[| Float.nan; 11.0; 12.0 |] ~raw:[| 40.0; 44.0; 48.0 |])
    (elements_are [ float_equal 40.0; float_equal 44.0; float_equal 48.0 ])

let test_nan_in_middle_falls_back_to_whole_raw_window _ =
  assert_that
    (_closes ~adjusted:[| 10.0; Float.nan; 12.0 |] ~raw:[| 40.0; 44.0; 48.0 |])
    (elements_are [ float_equal 40.0; float_equal 44.0; float_equal 48.0 ])

let test_nan_at_tail_falls_back_to_whole_raw_window _ =
  assert_that
    (_closes ~adjusted:[| 10.0; 11.0; Float.nan |] ~raw:[| 40.0; 44.0; 48.0 |])
    (elements_are [ float_equal 40.0; float_equal 44.0; float_equal 48.0 ])

(* An infinity is as unusable as a NaN — the guard is [Float.is_finite], not a
   NaN test, so a corrupt cell that decoded to inf falls back as well. *)
let test_infinity_falls_back_to_raw _ =
  assert_that
    (_closes
       ~adjusted:[| 10.0; Float.infinity; 12.0 |]
       ~raw:[| 40.0; 44.0; 48.0 |])
    (elements_are [ float_equal 40.0; float_equal 44.0; float_equal 48.0 ])

(* -- last_close: the single-mark accessor over a selected window ---------- *)

let test_last_close_takes_the_newest_cell _ =
  assert_that
    (TB.last_close [| 10.0; 11.0; 12.0 |])
    (is_some_and (float_equal 12.0))

let test_last_close_empty_window_is_none _ =
  assert_that (TB.last_close [||]) is_none

(* The load-bearing case for the guard, and for the no-backwards-scan rule: the
   newest cell is NaN while older ones are finite. A NaN mark would poison a
   benchmark base by division and a utilization sum outright, so it must not
   surface; and answering with the finite 11.0 would substitute a stale bar's
   close for the date the caller actually asked about. Only [None] is honest. *)
let test_last_close_non_finite_newest_cell_is_none _ =
  assert_that (TB.last_close [| 10.0; 11.0; Float.nan |]) is_none

let test_last_close_infinite_newest_cell_is_none _ =
  assert_that (TB.last_close [| 10.0; 11.0; Float.infinity |]) is_none

(* The mirror direction: only the newest cell is consulted, so a non-finite
   cell earlier in the window is none of this function's business. *)
let test_last_close_tolerates_non_finite_earlier_cells _ =
  assert_that
    (TB.last_close [| Float.nan; 11.0; 12.0 |])
    (is_some_and (float_equal 12.0))

let suite =
  "trade_audit_basis"
  >::: [
         "window prefers adjusted when all finite"
         >:: test_window_prefers_adjusted_when_all_finite;
         "window empty in empty out" >:: test_window_empty_in_empty_out;
         "nan at head falls back to whole raw window"
         >:: test_nan_at_head_falls_back_to_whole_raw_window;
         "nan in middle falls back to whole raw window"
         >:: test_nan_in_middle_falls_back_to_whole_raw_window;
         "nan at tail falls back to whole raw window"
         >:: test_nan_at_tail_falls_back_to_whole_raw_window;
         "infinity falls back to raw" >:: test_infinity_falls_back_to_raw;
         "last_close takes the newest cell"
         >:: test_last_close_takes_the_newest_cell;
         "last_close empty window is none"
         >:: test_last_close_empty_window_is_none;
         "last_close non finite newest cell is none"
         >:: test_last_close_non_finite_newest_cell_is_none;
         "last_close infinite newest cell is none"
         >:: test_last_close_infinite_newest_cell_is_none;
         "last_close tolerates non finite earlier cells"
         >:: test_last_close_tolerates_non_finite_earlier_cells;
       ]

let () = run_test_tt_main suite
