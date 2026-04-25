open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Bar_panels = Data_panel.Bar_panels
module BA1 = Bigarray.Array1

let _make_idx universe =
  match Symbol_index.create ~universe with
  | Ok t -> t
  | Error err ->
      assert_failure (Printf.sprintf "create failed: %s" err.Status.message)

let _make_price ~date_str ~o ~h ~l ~c ~v () : Types.Daily_price.t =
  {
    date = Date.of_string date_str;
    open_price = o;
    high_price = h;
    low_price = l;
    close_price = c;
    volume = v;
    adjusted_close = c;
  }

let _make_calendar dates = Array.map dates ~f:Date.of_string

(* Build a small panel with two symbols across 5 days. AAPL trades all five
   days; MSFT skips day 2 (NaN). *)
let _build_test_panels () =
  let idx = _make_idx [ "AAPL"; "MSFT" ] in
  let calendar =
    _make_calendar
      [| "2024-01-02"; "2024-01-03"; "2024-01-04"; "2024-01-05"; "2024-01-08" |]
  in
  let panels = Ohlcv_panels.create idx ~n_days:5 in
  (* AAPL row 0: bars on every day. *)
  Ohlcv_panels.write_row panels ~symbol_index:0 ~day:0
    (_make_price ~date_str:"2024-01-02" ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.5
       ~v:1_000_000 ());
  Ohlcv_panels.write_row panels ~symbol_index:0 ~day:1
    (_make_price ~date_str:"2024-01-03" ~o:101.0 ~h:102.0 ~l:100.0 ~c:101.5
       ~v:1_100_000 ());
  Ohlcv_panels.write_row panels ~symbol_index:0 ~day:2
    (_make_price ~date_str:"2024-01-04" ~o:102.0 ~h:103.0 ~l:101.0 ~c:102.5
       ~v:1_200_000 ());
  Ohlcv_panels.write_row panels ~symbol_index:0 ~day:3
    (_make_price ~date_str:"2024-01-05" ~o:103.0 ~h:104.0 ~l:102.0 ~c:103.5
       ~v:1_300_000 ());
  Ohlcv_panels.write_row panels ~symbol_index:0 ~day:4
    (_make_price ~date_str:"2024-01-08" ~o:104.0 ~h:105.0 ~l:103.0 ~c:104.5
       ~v:1_400_000 ());
  (* MSFT row 1: bar on days 0, 1, 3, 4 (skip day 2). *)
  Ohlcv_panels.write_row panels ~symbol_index:1 ~day:0
    (_make_price ~date_str:"2024-01-02" ~o:200.0 ~h:201.0 ~l:199.0 ~c:200.5
       ~v:500_000 ());
  Ohlcv_panels.write_row panels ~symbol_index:1 ~day:1
    (_make_price ~date_str:"2024-01-03" ~o:201.0 ~h:202.0 ~l:200.0 ~c:201.5
       ~v:600_000 ());
  Ohlcv_panels.write_row panels ~symbol_index:1 ~day:3
    (_make_price ~date_str:"2024-01-05" ~o:203.0 ~h:204.0 ~l:202.0 ~c:203.5
       ~v:800_000 ());
  Ohlcv_panels.write_row panels ~symbol_index:1 ~day:4
    (_make_price ~date_str:"2024-01-08" ~o:204.0 ~h:205.0 ~l:203.0 ~c:204.5
       ~v:900_000 ());
  let bar_panels =
    match Bar_panels.create ~ohlcv:panels ~calendar with
    | Ok t -> t
    | Error err ->
        assert_failure
          (Printf.sprintf "Bar_panels.create failed: %s" err.Status.message)
  in
  bar_panels

let test_create_rejects_calendar_length_mismatch _ =
  let idx = _make_idx [ "AAPL" ] in
  let panels = Ohlcv_panels.create idx ~n_days:5 in
  let calendar = _make_calendar [| "2024-01-02"; "2024-01-03" |] in
  assert_that
    (Bar_panels.create ~ohlcv:panels ~calendar)
    (is_error_with Status.Invalid_argument)

let test_create_succeeds_when_lengths_match _ =
  let bar_panels = _build_test_panels () in
  assert_that bar_panels (field Bar_panels.n_days (equal_to 5))

let test_daily_bars_for_unknown_symbol _ =
  let bar_panels = _build_test_panels () in
  assert_that
    (Bar_panels.daily_bars_for bar_panels ~symbol:"UNKNOWN" ~as_of_day:4)
    is_empty

let test_daily_bars_for_full_history _ =
  let bar_panels = _build_test_panels () in
  let bars = Bar_panels.daily_bars_for bar_panels ~symbol:"AAPL" ~as_of_day:4 in
  assert_that bars
    (elements_are
       [
         field (fun b -> b.Types.Daily_price.close_price) (float_equal 100.5);
         field (fun b -> b.Types.Daily_price.close_price) (float_equal 101.5);
         field (fun b -> b.Types.Daily_price.close_price) (float_equal 102.5);
         field (fun b -> b.Types.Daily_price.close_price) (float_equal 103.5);
         field (fun b -> b.Types.Daily_price.close_price) (float_equal 104.5);
       ])

let test_daily_bars_for_truncated _ =
  let bar_panels = _build_test_panels () in
  let bars = Bar_panels.daily_bars_for bar_panels ~symbol:"AAPL" ~as_of_day:1 in
  (* Only days 0 and 1 should be visible. *)
  assert_that bars
    (elements_are
       [
         all_of
           [
             field
               (fun b -> b.Types.Daily_price.date)
               (equal_to (Date.of_string "2024-01-02"));
             field
               (fun b -> b.Types.Daily_price.close_price)
               (float_equal 100.5);
             field
               (fun b -> b.Types.Daily_price.adjusted_close)
               (float_equal 100.5);
           ];
         all_of
           [
             field
               (fun b -> b.Types.Daily_price.date)
               (equal_to (Date.of_string "2024-01-03"));
             field
               (fun b -> b.Types.Daily_price.close_price)
               (float_equal 101.5);
             field (fun b -> b.Types.Daily_price.volume) (equal_to 1_100_000);
           ];
       ])

let test_daily_bars_for_skips_nan_cells _ =
  let bar_panels = _build_test_panels () in
  let bars = Bar_panels.daily_bars_for bar_panels ~symbol:"MSFT" ~as_of_day:4 in
  (* MSFT skipped day 2 — should not appear in the list. *)
  assert_that bars
    (all_of
       [
         size_is 4;
         field
           (fun b ->
             List.map b ~f:(fun b -> b.Types.Daily_price.date)
             |> List.map ~f:Date.to_string)
           (equal_to [ "2024-01-02"; "2024-01-03"; "2024-01-05"; "2024-01-08" ]);
       ])

let test_daily_bars_for_as_of_out_of_range _ =
  let bar_panels = _build_test_panels () in
  assert_raises (Invalid_argument "Bar_panels: as_of_day 5 out of range [0, 5)")
    (fun () -> Bar_panels.daily_bars_for bar_panels ~symbol:"AAPL" ~as_of_day:5);
  assert_raises
    (Invalid_argument "Bar_panels: as_of_day -1 out of range [0, 5)") (fun () ->
      Bar_panels.daily_bars_for bar_panels ~symbol:"AAPL" ~as_of_day:(-1))

let test_weekly_bars_for_aggregates _ =
  let bar_panels = _build_test_panels () in
  (* The 5-day fixture spans Tue 1/2 → Mon 1/8, so daily_to_weekly produces:
     - week ending Friday 1/5 (covers Tue 1/2 - Fri 1/5)
     - week ending Monday 1/8 alone (partial week, include_partial_week=true) *)
  let weekly =
    Bar_panels.weekly_bars_for bar_panels ~symbol:"AAPL" ~n:10 ~as_of_day:4
  in
  assert_that weekly (size_is 2)

let test_weekly_bars_for_truncates_to_n _ =
  let bar_panels = _build_test_panels () in
  let weekly =
    Bar_panels.weekly_bars_for bar_panels ~symbol:"AAPL" ~n:1 ~as_of_day:4
  in
  assert_that weekly (size_is 1)

let test_weekly_bars_for_unknown _ =
  let bar_panels = _build_test_panels () in
  assert_that
    (Bar_panels.weekly_bars_for bar_panels ~symbol:"UNKNOWN" ~n:10 ~as_of_day:4)
    is_empty

let test_low_window_zero_copy_slice _ =
  let bar_panels = _build_test_panels () in
  let slice =
    Bar_panels.low_window bar_panels ~symbol:"AAPL" ~as_of_day:4 ~len:3
  in
  match slice with
  | None -> assert_failure "expected Some"
  | Some s ->
      assert_that
        [ BA1.get s 0; BA1.get s 1; BA1.get s 2 ]
        (elements_are
           [ float_equal 101.0; float_equal 102.0; float_equal 103.0 ])

let test_low_window_returns_none_when_window_underflows _ =
  let bar_panels = _build_test_panels () in
  assert_that
    (Bar_panels.low_window bar_panels ~symbol:"AAPL" ~as_of_day:1 ~len:5)
    is_none

let test_low_window_unknown_symbol _ =
  let bar_panels = _build_test_panels () in
  assert_that
    (Bar_panels.low_window bar_panels ~symbol:"UNKNOWN" ~as_of_day:4 ~len:3)
    is_none

let test_low_window_zero_len _ =
  let bar_panels = _build_test_panels () in
  assert_that
    (Bar_panels.low_window bar_panels ~symbol:"AAPL" ~as_of_day:4 ~len:0)
    is_none

let suite =
  "Bar_panels"
  >::: [
         "create rejects calendar length mismatch"
         >:: test_create_rejects_calendar_length_mismatch;
         "create succeeds when lengths match"
         >:: test_create_succeeds_when_lengths_match;
         "daily_bars_for unknown symbol" >:: test_daily_bars_for_unknown_symbol;
         "daily_bars_for full history" >:: test_daily_bars_for_full_history;
         "daily_bars_for truncated" >:: test_daily_bars_for_truncated;
         "daily_bars_for skips NaN cells"
         >:: test_daily_bars_for_skips_nan_cells;
         "daily_bars_for as_of out of range"
         >:: test_daily_bars_for_as_of_out_of_range;
         "weekly_bars_for aggregates" >:: test_weekly_bars_for_aggregates;
         "weekly_bars_for truncates to n"
         >:: test_weekly_bars_for_truncates_to_n;
         "weekly_bars_for unknown" >:: test_weekly_bars_for_unknown;
         "low_window zero-copy slice" >:: test_low_window_zero_copy_slice;
         "low_window returns None when window underflows"
         >:: test_low_window_returns_none_when_window_underflows;
         "low_window unknown symbol" >:: test_low_window_unknown_symbol;
         "low_window zero len" >:: test_low_window_zero_len;
       ]

let () = run_test_tt_main suite
