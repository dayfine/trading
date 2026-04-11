open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date price =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1000;
  }

(** Build a [get_price] function that returns a fixed bar for one symbol and
    [None] for everything else. *)
let single_symbol_get_price ~symbol ~bar other =
  if String.equal other symbol then Some bar else None

(** Build a [get_price] that returns different bars per symbol. *)
let multi_symbol_get_price bars_by_symbol other =
  List.Assoc.find bars_by_symbol other ~equal:String.equal

(* ------------------------------------------------------------------ *)
(* create                                                               *)
(* ------------------------------------------------------------------ *)

let test_create_is_empty _ =
  let t = Bar_history.create () in
  assert_that (Bar_history.weekly_bars_for t ~symbol:"AAPL" ~n:10) is_empty

(* ------------------------------------------------------------------ *)
(* accumulate                                                           *)
(* ------------------------------------------------------------------ *)

let test_accumulate_adds_first_bar _ =
  let t = Bar_history.create () in
  let bar = make_bar "2024-01-08" 180.0 in
  Bar_history.accumulate t
    ~get_price:(single_symbol_get_price ~symbol:"AAPL" ~bar)
    ~symbols:[ "AAPL" ];
  (* include_partial_week:true means one daily bar becomes one weekly bar *)
  assert_that (Bar_history.weekly_bars_for t ~symbol:"AAPL" ~n:10) (size_is 1)

let test_accumulate_is_idempotent_same_date _ =
  let t = Bar_history.create () in
  let bar = make_bar "2024-01-08" 180.0 in
  let get_price = single_symbol_get_price ~symbol:"AAPL" ~bar in
  Bar_history.accumulate t ~get_price ~symbols:[ "AAPL" ];
  Bar_history.accumulate t ~get_price ~symbols:[ "AAPL" ];
  Bar_history.accumulate t ~get_price ~symbols:[ "AAPL" ];
  (* Three identical accumulate calls should still produce one weekly bar *)
  assert_that (Bar_history.weekly_bars_for t ~symbol:"AAPL" ~n:10) (size_is 1)

let test_accumulate_rejects_older_bar _ =
  let t = Bar_history.create () in
  let newer = make_bar "2024-01-15" 185.0 in
  let older = make_bar "2024-01-08" 180.0 in
  Bar_history.accumulate t
    ~get_price:(single_symbol_get_price ~symbol:"AAPL" ~bar:newer)
    ~symbols:[ "AAPL" ];
  Bar_history.accumulate t
    ~get_price:(single_symbol_get_price ~symbol:"AAPL" ~bar:older)
    ~symbols:[ "AAPL" ];
  (* The older bar is ignored — last known bar stays at Jan 15 *)
  let weekly = Bar_history.weekly_bars_for t ~symbol:"AAPL" ~n:10 in
  assert_that weekly (size_is 1);
  assert_that (List.last_exn weekly).Types.Daily_price.date
    (equal_to (Date.of_string "2024-01-15"))

let test_accumulate_handles_multiple_symbols _ =
  let t = Bar_history.create () in
  let bars =
    [
      ("AAPL", make_bar "2024-01-08" 180.0);
      ("MSFT", make_bar "2024-01-08" 400.0);
    ]
  in
  Bar_history.accumulate t
    ~get_price:(multi_symbol_get_price bars)
    ~symbols:[ "AAPL"; "MSFT"; "GOOG" ];
  assert_that (Bar_history.weekly_bars_for t ~symbol:"AAPL" ~n:10) (size_is 1);
  assert_that (Bar_history.weekly_bars_for t ~symbol:"MSFT" ~n:10) (size_is 1);
  (* GOOG was requested but get_price returned None — no history *)
  assert_that (Bar_history.weekly_bars_for t ~symbol:"GOOG" ~n:10) is_empty

(* ------------------------------------------------------------------ *)
(* weekly_bars_for                                                      *)
(* ------------------------------------------------------------------ *)

let test_weekly_bars_for_unknown_symbol _ =
  let t = Bar_history.create () in
  assert_that (Bar_history.weekly_bars_for t ~symbol:"UNKNOWN" ~n:10) is_empty

let test_weekly_bars_for_respects_n _ =
  let t = Bar_history.create () in
  (* Accumulate 20 weekdays ~4 weeks. Each weekday gets accumulated once via
     repeated get_price + accumulate calls. *)
  let dates =
    [
      "2024-01-01";
      "2024-01-02";
      "2024-01-03";
      "2024-01-04";
      "2024-01-05";
      "2024-01-08";
      "2024-01-09";
      "2024-01-10";
      "2024-01-11";
      "2024-01-12";
      "2024-01-15";
      "2024-01-16";
      "2024-01-17";
      "2024-01-18";
      "2024-01-19";
      "2024-01-22";
      "2024-01-23";
      "2024-01-24";
      "2024-01-25";
      "2024-01-26";
    ]
  in
  List.iter dates ~f:(fun date ->
      let bar = make_bar date 100.0 in
      Bar_history.accumulate t
        ~get_price:(single_symbol_get_price ~symbol:"AAPL" ~bar)
        ~symbols:[ "AAPL" ]);
  (* 4 full weeks of Mon-Fri → 4 weekly bars *)
  let all = Bar_history.weekly_bars_for t ~symbol:"AAPL" ~n:100 in
  assert_that all (size_is 4);
  (* Asking for 2 returns the most recent 2 *)
  let recent = Bar_history.weekly_bars_for t ~symbol:"AAPL" ~n:2 in
  assert_that recent (size_is 2);
  (* The most recent 2 should be the last two calendar weeks *)
  assert_that (List.last_exn recent).Types.Daily_price.date
    (equal_to (Date.of_string "2024-01-26"))

let test_weekly_bars_for_returns_all_if_fewer_than_n _ =
  let t = Bar_history.create () in
  let bar = make_bar "2024-01-08" 180.0 in
  Bar_history.accumulate t
    ~get_price:(single_symbol_get_price ~symbol:"AAPL" ~bar)
    ~symbols:[ "AAPL" ];
  (* Asking for 100 weeks when only 1 exists returns 1 *)
  assert_that (Bar_history.weekly_bars_for t ~symbol:"AAPL" ~n:100) (size_is 1)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("bar_history"
    >::: [
           "create is empty" >:: test_create_is_empty;
           "accumulate adds first bar" >:: test_accumulate_adds_first_bar;
           "accumulate is idempotent for same date"
           >:: test_accumulate_is_idempotent_same_date;
           "accumulate rejects older bar" >:: test_accumulate_rejects_older_bar;
           "accumulate handles multiple symbols"
           >:: test_accumulate_handles_multiple_symbols;
           "weekly_bars_for unknown symbol returns empty"
           >:: test_weekly_bars_for_unknown_symbol;
           "weekly_bars_for respects n" >:: test_weekly_bars_for_respects_n;
           "weekly_bars_for returns all if fewer than n"
           >:: test_weekly_bars_for_returns_all_if_fewer_than_n;
         ])
