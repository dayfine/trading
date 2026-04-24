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
(* seed                                                                 *)
(* ------------------------------------------------------------------ *)

let test_seed_empty_history_ingests_bars _ =
  let t = Bar_history.create () in
  let bars =
    [
      make_bar "2024-01-08" 180.0;
      make_bar "2024-01-09" 181.0;
      make_bar "2024-01-10" 182.0;
    ]
  in
  Bar_history.seed t ~symbol:"AAPL" ~bars;
  let daily = Bar_history.daily_bars_for t ~symbol:"AAPL" in
  assert_that daily (size_is 3)

let test_seed_skips_older_than_last_bar _ =
  let t = Bar_history.create () in
  (* Seed with Jan 15. *)
  Bar_history.seed t ~symbol:"AAPL" ~bars:[ make_bar "2024-01-15" 185.0 ];
  (* Second seed with earlier + equal-date bars is ignored. *)
  Bar_history.seed t ~symbol:"AAPL"
    ~bars:[ make_bar "2024-01-08" 180.0; make_bar "2024-01-15" 190.0 ];
  let daily = Bar_history.daily_bars_for t ~symbol:"AAPL" in
  assert_that daily
    (elements_are
       [ field (fun b -> b.Types.Daily_price.close_price) (float_equal 185.0) ])

let test_seed_appends_strictly_later_bars _ =
  let t = Bar_history.create () in
  Bar_history.seed t ~symbol:"AAPL" ~bars:[ make_bar "2024-01-08" 180.0 ];
  Bar_history.seed t ~symbol:"AAPL"
    ~bars:
      [
        make_bar "2024-01-08" 999.0 (* ignored: equal date *);
        make_bar "2024-01-09" 181.0 (* kept *);
        make_bar "2024-01-10" 182.0 (* kept *);
      ];
  let daily = Bar_history.daily_bars_for t ~symbol:"AAPL" in
  assert_that daily
    (elements_are
       [
         field (fun b -> b.Types.Daily_price.close_price) (float_equal 180.0);
         field (fun b -> b.Types.Daily_price.close_price) (float_equal 181.0);
         field (fun b -> b.Types.Daily_price.close_price) (float_equal 182.0);
       ])

let test_seed_idempotent _ =
  let t = Bar_history.create () in
  let bars = [ make_bar "2024-01-08" 180.0; make_bar "2024-01-09" 181.0 ] in
  Bar_history.seed t ~symbol:"AAPL" ~bars;
  Bar_history.seed t ~symbol:"AAPL" ~bars;
  Bar_history.seed t ~symbol:"AAPL" ~bars;
  let daily = Bar_history.daily_bars_for t ~symbol:"AAPL" in
  assert_that daily (size_is 2)

let test_seed_is_per_symbol _ =
  let t = Bar_history.create () in
  Bar_history.seed t ~symbol:"AAPL" ~bars:[ make_bar "2024-01-08" 180.0 ];
  Bar_history.seed t ~symbol:"MSFT"
    ~bars:[ make_bar "2024-01-08" 400.0; make_bar "2024-01-09" 401.0 ];
  assert_that (Bar_history.daily_bars_for t ~symbol:"AAPL") (size_is 1);
  assert_that (Bar_history.daily_bars_for t ~symbol:"MSFT") (size_is 2);
  assert_that (Bar_history.daily_bars_for t ~symbol:"GOOG") is_empty

let test_seed_then_accumulate_continues_cleanly _ =
  (* Contract: after seed, accumulate still appends only bars strictly later
     than the seeded tail's last date. Simulates the Tiered path's usage: seed
     from loader on Full promote, then the simulator calls accumulate on
     subsequent days. *)
  let t = Bar_history.create () in
  Bar_history.seed t ~symbol:"AAPL"
    ~bars:[ make_bar "2024-01-08" 180.0; make_bar "2024-01-09" 181.0 ];
  let later = make_bar "2024-01-10" 182.0 in
  Bar_history.accumulate t
    ~get_price:(single_symbol_get_price ~symbol:"AAPL" ~bar:later)
    ~symbols:[ "AAPL" ];
  let daily = Bar_history.daily_bars_for t ~symbol:"AAPL" in
  assert_that daily (size_is 3);
  (* And an accumulate of an older bar still gets rejected. *)
  let older = make_bar "2024-01-05" 179.0 in
  Bar_history.accumulate t
    ~get_price:(single_symbol_get_price ~symbol:"AAPL" ~bar:older)
    ~symbols:[ "AAPL" ];
  assert_that (Bar_history.daily_bars_for t ~symbol:"AAPL") (size_is 3)

(* ------------------------------------------------------------------ *)
(* trim_before                                                          *)
(* ------------------------------------------------------------------ *)

let test_trim_before_empty_buffer_is_noop _ =
  let t = Bar_history.create () in
  Bar_history.trim_before t
    ~as_of:(Date.of_string "2024-06-01")
    ~max_lookback_days:30;
  assert_that (Bar_history.daily_bars_for t ~symbol:"AAPL") is_empty

let test_trim_before_then_accumulate_appends_new_bar _ =
  (* Seed buffer with bars spanning Jan-Jun, trim to last 30 days as of Jun 1,
     then accumulate a Jun 5 bar. Final buffer holds bars >= May 2 plus Jun 5. *)
  let t = Bar_history.create () in
  let dates =
    [
      "2024-01-08";
      "2024-02-08";
      "2024-04-08";
      "2024-05-08";
      "2024-05-25";
      "2024-06-01";
    ]
  in
  let bars = List.map dates ~f:(fun d -> make_bar d 100.0) in
  Bar_history.seed t ~symbol:"AAPL" ~bars;
  Bar_history.trim_before t
    ~as_of:(Date.of_string "2024-06-01")
    ~max_lookback_days:30;
  (* Cutoff = May 2; keep bars >= May 2: May 8, May 25, Jun 1. *)
  let later = make_bar "2024-06-05" 105.0 in
  Bar_history.accumulate t
    ~get_price:(single_symbol_get_price ~symbol:"AAPL" ~bar:later)
    ~symbols:[ "AAPL" ];
  let daily = Bar_history.daily_bars_for t ~symbol:"AAPL" in
  assert_that daily
    (elements_are
       [
         field
           (fun b -> b.Types.Daily_price.date)
           (equal_to (Date.of_string "2024-05-08"));
         field
           (fun b -> b.Types.Daily_price.date)
           (equal_to (Date.of_string "2024-05-25"));
         field
           (fun b -> b.Types.Daily_price.date)
           (equal_to (Date.of_string "2024-06-01"));
         field
           (fun b -> b.Types.Daily_price.date)
           (equal_to (Date.of_string "2024-06-05"));
       ])

let test_trim_before_is_idempotent _ =
  (* Two calls with the same as_of / max_lookback_days produce the same buffer
     state as a single call. *)
  let t_once = Bar_history.create () in
  let t_twice = Bar_history.create () in
  let bars =
    [
      make_bar "2024-01-08" 100.0;
      make_bar "2024-03-08" 105.0;
      make_bar "2024-05-25" 110.0;
      make_bar "2024-06-01" 115.0;
    ]
  in
  Bar_history.seed t_once ~symbol:"AAPL" ~bars;
  Bar_history.seed t_twice ~symbol:"AAPL" ~bars;
  let as_of = Date.of_string "2024-06-01" in
  Bar_history.trim_before t_once ~as_of ~max_lookback_days:30;
  Bar_history.trim_before t_twice ~as_of ~max_lookback_days:30;
  Bar_history.trim_before t_twice ~as_of ~max_lookback_days:30;
  assert_that
    (Bar_history.daily_bars_for t_twice ~symbol:"AAPL")
    (equal_to (Bar_history.daily_bars_for t_once ~symbol:"AAPL"))

let test_trim_before_with_as_of_before_oldest_bar_is_noop _ =
  (* If the cutoff lies before every held bar, nothing drops. *)
  let t = Bar_history.create () in
  let bars = [ make_bar "2024-05-01" 100.0; make_bar "2024-05-15" 105.0 ] in
  Bar_history.seed t ~symbol:"AAPL" ~bars;
  Bar_history.trim_before t
    ~as_of:(Date.of_string "2024-04-01")
    ~max_lookback_days:7;
  let daily = Bar_history.daily_bars_for t ~symbol:"AAPL" in
  assert_that daily (size_is 2)

let test_trim_before_zero_lookback_keeps_only_as_of_bar _ =
  (* max_lookback_days = 0 → cutoff = as_of, so bars strictly older than as_of
     drop and only as_of (or later) remain. *)
  let t = Bar_history.create () in
  let bars =
    [
      make_bar "2024-05-01" 100.0;
      make_bar "2024-05-15" 105.0;
      make_bar "2024-06-01" 110.0;
    ]
  in
  Bar_history.seed t ~symbol:"AAPL" ~bars;
  Bar_history.trim_before t
    ~as_of:(Date.of_string "2024-06-01")
    ~max_lookback_days:0;
  assert_that
    (Bar_history.daily_bars_for t ~symbol:"AAPL")
    (elements_are
       [
         field
           (fun b -> b.Types.Daily_price.date)
           (equal_to (Date.of_string "2024-06-01"));
       ])

let test_trim_before_negative_lookback_raises _ =
  let t = Bar_history.create () in
  Bar_history.seed t ~symbol:"AAPL" ~bars:[ make_bar "2024-05-01" 100.0 ];
  assert_raises
    (Invalid_argument
       "Bar_history.trim_before: max_lookback_days must be >= 0, got -1")
    (fun () ->
      Bar_history.trim_before t
        ~as_of:(Date.of_string "2024-06-01")
        ~max_lookback_days:(-1))

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
           "seed empty history ingests bars"
           >:: test_seed_empty_history_ingests_bars;
           "seed skips bars older or equal to last-bar date"
           >:: test_seed_skips_older_than_last_bar;
           "seed appends strictly later bars"
           >:: test_seed_appends_strictly_later_bars;
           "seed is idempotent when called with same bars"
           >:: test_seed_idempotent;
           "seed is per-symbol" >:: test_seed_is_per_symbol;
           "seed then accumulate continues cleanly"
           >:: test_seed_then_accumulate_continues_cleanly;
           "trim_before on empty buffer is no-op"
           >:: test_trim_before_empty_buffer_is_noop;
           "trim_before then accumulate appends new bar"
           >:: test_trim_before_then_accumulate_appends_new_bar;
           "trim_before is idempotent" >:: test_trim_before_is_idempotent;
           "trim_before with as_of before oldest bar is no-op"
           >:: test_trim_before_with_as_of_before_oldest_bar_is_noop;
           "trim_before with max_lookback_days = 0 keeps only as_of bar"
           >:: test_trim_before_zero_lookback_keeps_only_as_of_bar;
           "trim_before with negative lookback raises Invalid_argument"
           >:: test_trim_before_negative_lookback_raises;
         ])
