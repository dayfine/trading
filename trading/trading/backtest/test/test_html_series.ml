(** Direct unit tests for [Trade_audit_html.Html_series]: the downsample
    last-row guarantee, the [extra_of] empty default, and the per-trade weekly
    [series] window / WMA30 / index / stop pass-through contracts. *)

open OUnit2
open Core
open Matchers
module HS = Trade_audit_html.Html_series
module Src = Trade_audit_html.Html_sources

let _date = Date.of_string

(* downsample ------------------------------------------------------------- *)

let test_downsample_keeps_last_row _ =
  assert_that
    (HS.downsample ~every:5 [ 0; 1; 2; 3; 4; 5; 6 ])
    (elements_are [ equal_to 0; equal_to 5; equal_to 6 ])

let test_downsample_no_duplicate_when_last_aligned _ =
  assert_that
    (HS.downsample ~every:5 [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10 ])
    (elements_are [ equal_to 0; equal_to 5; equal_to 10 ])

(* extra_of --------------------------------------------------------------- *)

let _present : Src.trade_extra =
  { qty = 7.0; stop_kind = "gap_down"; entry_stop = Some 9.0; exit_stop = None }

let _extras =
  Map.of_alist_exn
    (module String)
    [ (Src.key "AAA" "2020-06-01" "2020-09-07", _present) ]

let test_extra_of_missing_key_defaults_empty _ =
  assert_that
    (HS.extra_of _extras ~sym:"ZZZ" ~entry:(_date "2020-06-01")
       ~exit_:(_date "2020-09-07"))
    (all_of
       [
         field (fun (e : Src.trade_extra) -> e.qty) (float_equal 0.0);
         field (fun (e : Src.trade_extra) -> e.stop_kind) (equal_to "");
         field (fun (e : Src.trade_extra) -> e.entry_stop) is_none;
         field (fun (e : Src.trade_extra) -> e.exit_stop) is_none;
       ])

let test_extra_of_present_key_returns_entry _ =
  assert_that
    (HS.extra_of _extras ~sym:"AAA" ~entry:(_date "2020-06-01")
       ~exit_:(_date "2020-09-07"))
    (equal_to _present)

(* series ----------------------------------------------------------------- *)

let _start = _date "2018-01-01"

(* Stub: [total] weekly bars from [_start], close at index [i] = [i + 1]. *)
let _stub total ~symbol:_ ~n:_ ~as_of:_ =
  Array.init total ~f:(fun i ->
      (Date.add_days _start (7 * i), Float.of_int (i + 1)))

let _extra : Src.trade_extra =
  { qty = 1.0; stop_kind = ""; entry_stop = Some 90.0; exit_stop = Some 120.0 }

(* Entry is global bar 126, exit 140; visible window starts at 126 - 52 = 74. *)
let _series total =
  HS.series ~weekly_series:(_stub total) ~extra:_extra ~sym:"AAA"
    ~entry:(_date "2020-06-01") ~exit_:(_date "2020-09-07")

let test_series_window_indices_and_stops _ =
  assert_that (_series 200)
    (is_some_and
       (all_of
          [
            field
              (fun (s : Trade_audit_html.Html_data.trade_series) ->
                List.hd_exn s.dates)
              (equal_to (_date "2019-06-03"));
            field
              (fun (s : Trade_audit_html.Html_data.trade_series) -> s.entry_idx)
              (equal_to 52);
            field
              (fun (s : Trade_audit_html.Html_data.trade_series) -> s.exit_idx)
              (equal_to 66);
            field
              (fun (s : Trade_audit_html.Html_data.trade_series) ->
                s.entry_stop)
              (is_some_and (float_equal 90.0));
            field
              (fun (s : Trade_audit_html.Html_data.trade_series) -> s.exit_stop)
              (is_some_and (float_equal 120.0));
          ]))

(* Global bar 100 (visible index 26): weights 30..1 over closes 101, 100, ...
   = sum_{m=1..30} m * (71 + m) / 465 = 42470 / 465. *)
let test_series_wma30_hand_computed_and_no_nan _ =
  assert_that (_series 200)
    (is_some_and
       (all_of
          [
            field
              (fun (s : Trade_audit_html.Html_data.trade_series) ->
                List.nth_exn s.wma30 26)
              (float_equal (42470.0 /. 465.0));
            field
              (fun (s : Trade_audit_html.Html_data.trade_series) ->
                List.count s.wma30 ~f:Float.is_nan)
              (equal_to 0);
          ]))

let test_series_none_at_or_below_wma_window _ = assert_that (_series 30) is_none

let test_series_some_just_above_wma_window _ =
  assert_that (_series 31)
    (is_some_and
       (field
          (fun (s : Trade_audit_html.Html_data.trade_series) -> s.dates)
          (size_is 31)))

let suite =
  "Trade_audit_html.Html_series"
  >::: [
         "downsample keeps last row" >:: test_downsample_keeps_last_row;
         "downsample no duplicate when aligned"
         >:: test_downsample_no_duplicate_when_last_aligned;
         "extra_of missing key defaults empty"
         >:: test_extra_of_missing_key_defaults_empty;
         "extra_of present key returns entry"
         >:: test_extra_of_present_key_returns_entry;
         "series window, indices, stops"
         >:: test_series_window_indices_and_stops;
         "series wma30 hand computed, no nan"
         >:: test_series_wma30_hand_computed_and_no_nan;
         "series none at or below wma window"
         >:: test_series_none_at_or_below_wma_window;
         "series some just above wma window"
         >:: test_series_some_just_above_wma_window;
       ]

let () = run_test_tt_main suite
