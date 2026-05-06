(** Tests for {!Weinstein_strategy.Bar_reader} — the closure-shaped bar source.

    Phase F.3.a-1 added two pieces of behaviour to cover here:

    - {!Bar_reader.empty} no longer allocates a {!Bar_panels.t}; every read
      returns the empty list / empty view directly.
    - {!Bar_reader.of_in_memory_bars} materialises a tmp snapshot dir from
      [(symbol, bars)] pairs and produces a snapshot-backed reader.

    The empty-reader test is a smoke check (the panel-free implementation has no
    observable difference from the panel-backed one was, but we still want a
    test that pins the empty contract for future refactors).

    The of_in_memory_bars tests pin the round-trip: feed in synthetic OHLCV
    history for a symbol, read it back via [daily_bars_for], and assert the
    reconstructed close-prices match. We also pin the unknown-symbol fallback so
    consumers can rely on "missing → empty list" without a NotFound. *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Macro_inputs = Weinstein_strategy.Macro_inputs
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* ------------------------------------------------------------------ *)
(* Synthetic OHLCV builders                                            *)
(* ------------------------------------------------------------------ *)

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* Build [n] consecutive weekday bars starting at [start]. The date walks
   one day at a time, skipping Sat/Sun so the calendar approximates a real
   trading week. Prices walk [+step] per bar from [start_price]. *)
let _is_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

let _weekdays_starting ~start ~n =
  let rec loop acc d remaining =
    if remaining = 0 then List.rev acc
    else if _is_weekday d then
      loop (d :: acc) (Date.add_days d 1) (remaining - 1)
    else loop acc (Date.add_days d 1) remaining
  in
  loop [] start n

let _make_bar ~date ~price : Types.Daily_price.t =
  {
    date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
  }

let _make_bars ~start ~n ~start_price ~step =
  let dates = _weekdays_starting ~start ~n in
  List.mapi dates ~f:(fun i d ->
      _make_bar ~date:d ~price:(start_price +. (Float.of_int i *. step)))

(* ------------------------------------------------------------------ *)
(* empty: closures return empty without allocating a panel              *)
(* ------------------------------------------------------------------ *)

let test_empty_daily_bars_returns_empty _ =
  let r = Bar_reader.empty () in
  let date = _ymd 2024 1 2 in
  assert_that
    (Bar_reader.daily_bars_for r ~symbol:"AAPL" ~as_of:date)
    (size_is 0)

let test_empty_weekly_view_has_zero_n _ =
  let r = Bar_reader.empty () in
  let date = _ymd 2024 1 2 in
  assert_that
    (Bar_reader.weekly_view_for r ~symbol:"AAPL" ~n:30 ~as_of:date)
    (field
       (fun (v : Snapshot_runtime.Snapshot_bar_views.weekly_view) -> v.n)
       (equal_to 0))

let test_empty_daily_view_has_zero_n_days _ =
  let r = Bar_reader.empty () in
  let date = _ymd 2024 1 2 in
  assert_that
    (Bar_reader.daily_view_for r ~symbol:"AAPL" ~as_of:date ~lookback:50)
    (field
       (fun (v : Snapshot_runtime.Snapshot_bar_views.daily_view) -> v.n_days)
       (equal_to 0))

(* ------------------------------------------------------------------ *)
(* of_in_memory_bars: round-trip through tmp snapshot dir               *)
(* ------------------------------------------------------------------ *)

let test_of_in_memory_bars_round_trip _ =
  let start =
    _ymd 2024 1 2
    (* Tuesday *)
  in
  let n = 60 in
  let bars = _make_bars ~start ~n ~start_price:100.0 ~step:0.5 in
  let r = Bar_reader.of_in_memory_bars [ ("AAPL", bars) ] in
  let last_bar = List.last_exn bars in
  let read_back =
    Bar_reader.daily_bars_for r ~symbol:"AAPL" ~as_of:last_bar.date
  in
  (* The snapshot reader returns bars up to and including [as_of] in
     chronological order. Compare close_price of the last few entries to
     the synthetic series. *)
  let expected_closes =
    List.map bars ~f:(fun b -> b.Types.Daily_price.close_price)
  in
  let got_closes =
    List.map read_back ~f:(fun b -> b.Types.Daily_price.close_price)
  in
  assert_that got_closes
    (elements_are (List.map expected_closes ~f:(fun c -> float_equal c)))

let test_of_in_memory_bars_unknown_symbol_returns_empty _ =
  let start = _ymd 2024 1 2 in
  let bars = _make_bars ~start ~n:10 ~start_price:100.0 ~step:0.5 in
  let r = Bar_reader.of_in_memory_bars [ ("AAPL", bars) ] in
  let last_bar = List.last_exn bars in
  assert_that
    (Bar_reader.daily_bars_for r ~symbol:"NOPE" ~as_of:last_bar.date)
    (size_is 0)

let test_of_in_memory_bars_multi_symbol _ =
  let start = _ymd 2024 1 2 in
  let n = 20 in
  let aapl_bars = _make_bars ~start ~n ~start_price:100.0 ~step:0.5 in
  let msft_bars = _make_bars ~start ~n ~start_price:200.0 ~step:1.0 in
  let r =
    Bar_reader.of_in_memory_bars [ ("AAPL", aapl_bars); ("MSFT", msft_bars) ]
  in
  let last_aapl = List.last_exn aapl_bars in
  let last_msft = List.last_exn msft_bars in
  (* Per-symbol reads must isolate; AAPL's close is NOT MSFT's close. *)
  let aapl_last_close =
    Bar_reader.daily_bars_for r ~symbol:"AAPL" ~as_of:last_aapl.date
    |> List.last_exn
    |> fun (b : Types.Daily_price.t) -> b.close_price
  in
  let msft_last_close =
    Bar_reader.daily_bars_for r ~symbol:"MSFT" ~as_of:last_msft.date
    |> List.last_exn
    |> fun (b : Types.Daily_price.t) -> b.close_price
  in
  assert_that
    (aapl_last_close, msft_last_close)
    (all_of
       [
         field fst (float_equal last_aapl.close_price);
         field snd (float_equal last_msft.close_price);
       ])

(* ------------------------------------------------------------------ *)
(* Sentinel-cb guard tests (CP4 — pin docstring claims on              *)
(* [Bar_reader.snapshot_callbacks] for non-snapshot constructors)       *)
(* ------------------------------------------------------------------ *)

(* Pins guard G1: the sentinel cb on [Bar_reader.empty ()] returns
   [Error NotFound] from every read. *)
let test_empty_reader_snapshot_callbacks_yields_not_found _ =
  let cb = Bar_reader.snapshot_callbacks (Bar_reader.empty ()) in
  let result =
    cb.read_field_history ~symbol:"ANY" ~from:(_ymd 2024 1 1)
      ~until:(_ymd 2024 1 31) ~field:Snapshot_schema.Close
  in
  assert_that result
    (matching ~msg:"Expected Error NotFound"
       (function Error s -> Some s | Ok _ -> None)
       (field (fun s -> s.Status.code) (equal_to Status.NotFound)))

(* Pins guard G2: routing the sentinel-cb through
   [Macro_inputs.build_global_index_views_of_snapshot_views] yields the
   empty list (NotFound → [] cascades to "no resident bars → drop"). *)
let test_empty_reader_routed_through_macro_inputs_yields_empty _ =
  let cb = Bar_reader.snapshot_callbacks (Bar_reader.empty ()) in
  let result =
    Macro_inputs.build_global_index_views_of_snapshot_views ~lookback_bars:52
      ~global_index_symbols:[ ("FOO.INDX", "Foo") ]
      ~cb ~as_of:(_ymd 2024 1 31)
  in
  assert_that result (size_is 0)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "bar_reader"
  >::: [
         "empty_daily_bars_returns_empty"
         >:: test_empty_daily_bars_returns_empty;
         "empty_weekly_view_has_zero_n" >:: test_empty_weekly_view_has_zero_n;
         "empty_daily_view_has_zero_n_days"
         >:: test_empty_daily_view_has_zero_n_days;
         "of_in_memory_bars_round_trip" >:: test_of_in_memory_bars_round_trip;
         "of_in_memory_bars_unknown_symbol_returns_empty"
         >:: test_of_in_memory_bars_unknown_symbol_returns_empty;
         "of_in_memory_bars_multi_symbol"
         >:: test_of_in_memory_bars_multi_symbol;
         "empty_reader_snapshot_callbacks_yields_not_found"
         >:: test_empty_reader_snapshot_callbacks_yields_not_found;
         "empty_reader_routed_through_macro_inputs_yields_empty"
         >:: test_empty_reader_routed_through_macro_inputs_yields_empty;
       ]

let () = run_test_tt_main suite
