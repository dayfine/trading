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
    - [last_close] reads the newest close of the selected window, falls back
      alongside it, and returns [None] rather than [Some nan] on an empty window
      or a non-finite mark *)

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

(* -- last_close ---------------------------------------------------------- *)

let test_last_close_reads_newest_adjusted _ =
  assert_that
    (TB.last_close ~adjusted:[| 10.0; 11.0; 12.0 |] ~raw:[| 40.0; 44.0; 48.0 |])
    (is_some_and (float_equal 12.0))

let test_last_close_falls_back_with_its_window _ =
  (* The NaN is not the newest cell, yet the mark still comes off raw: the mark
     must sit on the same basis as the window it was selected from, or a
     benchmark curve built from successive marks mixes bases across dates. *)
  assert_that
    (TB.last_close
       ~adjusted:[| Float.nan; 11.0; 12.0 |]
       ~raw:[| 40.0; 44.0; 48.0 |])
    (is_some_and (float_equal 48.0))

let test_last_close_none_on_empty_window _ =
  assert_that (TB.last_close ~adjusted:[||] ~raw:[||]) is_none

(* Belt-and-braces: a well-formed daily view never has a NaN raw close (the
   view drops those bars), so this state is unreachable in production — but if
   it ever arises the mark is dropped rather than handed on as [Some nan],
   which would silently poison the benchmark and utilization series. *)
let test_last_close_none_rather_than_some_nan _ =
  assert_that
    (TB.last_close ~adjusted:[| 10.0; Float.nan |] ~raw:[| 40.0; Float.nan |])
    is_none

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
         "last close reads newest adjusted"
         >:: test_last_close_reads_newest_adjusted;
         "last close falls back with its window"
         >:: test_last_close_falls_back_with_its_window;
         "last close none on empty window"
         >:: test_last_close_none_on_empty_window;
         "last close none rather than some nan"
         >:: test_last_close_none_rather_than_some_nan;
       ]

let () = run_test_tt_main suite
