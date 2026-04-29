(** Unit tests for {!Backtest.Macro_trend_writer}. Pin the projection from
    [cascade_summary] (date + macro_trend only), the ascending-by-date sort,
    sexp round-trip stability, and the on-disk artefact format including the
    empty-list case. *)

open OUnit2
open Core
open Matchers
module MTW = Backtest.Macro_trend_writer
module TA = Backtest.Trade_audit

let _date s = Date.of_string s

(* Cascade-summary builder copied from test_trade_audit.ml — defaults model a
   typical Bullish-macro Friday. Only [date] + [macro_trend] feed
   [Macro_trend_writer]; the other fields are filler so the projection is
   exercised against a realistic input. *)
let _make_cascade ?(date = _date "2024-01-19")
    ?(macro_trend = Weinstein_types.Bullish) () : TA.cascade_summary =
  {
    date;
    total_stocks = 20;
    candidates_after_held = 18;
    macro_trend;
    long_macro_admitted = 18;
    long_breakout_admitted = 5;
    long_sector_admitted = 5;
    long_grade_admitted = 3;
    long_top_n_admitted = 3;
    short_macro_admitted = 18;
    short_breakdown_admitted = 0;
    short_sector_admitted = 0;
    short_rs_hard_gate_admitted = 0;
    short_grade_admitted = 0;
    short_top_n_admitted = 0;
    entered = 1;
  }

(* of_cascade_summaries projection ---------------------------------------- *)

let test_empty_input_yields_empty_list _ =
  assert_that (MTW.of_cascade_summaries []) (size_is 0)

let test_three_fridays_in_date_order _ =
  let summaries =
    [
      _make_cascade ~date:(_date "2024-01-19")
        ~macro_trend:Weinstein_types.Bullish ();
      _make_cascade ~date:(_date "2024-01-26")
        ~macro_trend:Weinstein_types.Neutral ();
      _make_cascade ~date:(_date "2024-02-02")
        ~macro_trend:Weinstein_types.Bearish ();
    ]
  in
  assert_that
    (MTW.of_cascade_summaries summaries)
    (elements_are
       [
         all_of
           [
             field
               (fun (e : MTW.per_friday) -> Date.to_string e.date)
               (equal_to "2024-01-19");
             field
               (fun (e : MTW.per_friday) -> e.trend)
               (equal_to Weinstein_types.Bullish);
           ];
         all_of
           [
             field
               (fun (e : MTW.per_friday) -> Date.to_string e.date)
               (equal_to "2024-01-26");
             field
               (fun (e : MTW.per_friday) -> e.trend)
               (equal_to Weinstein_types.Neutral);
           ];
         all_of
           [
             field
               (fun (e : MTW.per_friday) -> Date.to_string e.date)
               (equal_to "2024-02-02");
             field
               (fun (e : MTW.per_friday) -> e.trend)
               (equal_to Weinstein_types.Bearish);
           ];
       ])

let test_unsorted_input_is_sorted_ascending_by_date _ =
  (* Cascades arrive in arbitrary order — the projection must still emit
     ascending dates. *)
  let summaries =
    [
      _make_cascade ~date:(_date "2024-03-15")
        ~macro_trend:Weinstein_types.Bullish ();
      _make_cascade ~date:(_date "2024-01-19")
        ~macro_trend:Weinstein_types.Bearish ();
      _make_cascade ~date:(_date "2024-02-09")
        ~macro_trend:Weinstein_types.Neutral ();
    ]
  in
  assert_that
    (MTW.of_cascade_summaries summaries
    |> List.map ~f:(fun (e : MTW.per_friday) -> Date.to_string e.date))
    (elements_are
       [ equal_to "2024-01-19"; equal_to "2024-02-09"; equal_to "2024-03-15" ])

(* Sexp round-trip --------------------------------------------------------- *)

let test_sexp_round_trip _ =
  let original : MTW.t =
    [
      { date = _date "2024-01-19"; trend = Weinstein_types.Bullish };
      { date = _date "2024-01-26"; trend = Weinstein_types.Bearish };
    ]
  in
  let parsed = MTW.t_of_sexp (MTW.sexp_of_t original) in
  assert_that parsed (elements_are (List.map original ~f:equal_to))

(* On-disk artefact -------------------------------------------------------- *)

let test_write_creates_file_and_round_trips _ =
  let dir = Core_unix.mkdtemp "/tmp/macro_trend_writer_test_" in
  let summaries =
    [
      _make_cascade ~date:(_date "2024-02-02")
        ~macro_trend:Weinstein_types.Bearish ();
      _make_cascade ~date:(_date "2024-01-19")
        ~macro_trend:Weinstein_types.Bullish ();
    ]
  in
  MTW.write ~output_dir:dir summaries;
  let path = dir ^ "/macro_trend.sexp" in
  let parsed = MTW.t_of_sexp (Sexp.load_sexp path) in
  assert_that parsed
    (elements_are
       [
         all_of
           [
             field
               (fun (e : MTW.per_friday) -> Date.to_string e.date)
               (equal_to "2024-01-19");
             field
               (fun (e : MTW.per_friday) -> e.trend)
               (equal_to Weinstein_types.Bullish);
           ];
         all_of
           [
             field
               (fun (e : MTW.per_friday) -> Date.to_string e.date)
               (equal_to "2024-02-02");
             field
               (fun (e : MTW.per_friday) -> e.trend)
               (equal_to Weinstein_types.Bearish);
           ];
       ])

let test_write_empty_list_creates_file _ =
  (* Empty input still writes the artefact — the file's presence is the
     contract for downstream consumers, distinct from [trade_audit.sexp]'s
     "absent on empty" rule. *)
  let dir = Core_unix.mkdtemp "/tmp/macro_trend_writer_test_empty_" in
  MTW.write ~output_dir:dir [];
  let path = dir ^ "/macro_trend.sexp" in
  assert_that (Stdlib.Sys.file_exists path) (equal_to true);
  let parsed = MTW.t_of_sexp (Sexp.load_sexp path) in
  assert_that parsed (size_is 0)

let suite =
  "macro_trend_writer"
  >::: [
         "empty_input_yields_empty_list" >:: test_empty_input_yields_empty_list;
         "three_fridays_in_date_order" >:: test_three_fridays_in_date_order;
         "unsorted_input_is_sorted_ascending_by_date"
         >:: test_unsorted_input_is_sorted_ascending_by_date;
         "sexp_round_trip" >:: test_sexp_round_trip;
         "write_creates_file_and_round_trips"
         >:: test_write_creates_file_and_round_trips;
         "write_empty_list_creates_file" >:: test_write_empty_list_creates_file;
       ]

let () = run_test_tt_main suite
