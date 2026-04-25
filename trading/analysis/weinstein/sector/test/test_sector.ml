open OUnit2
open Core
open Matchers
open Sector
open Screener
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = Sector.default_config
let as_of = Date.of_string "2024-01-01"

let make_bar date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close *. 1.01;
    low_price = adjusted_close *. 0.99;
    close_price = adjusted_close;
    adjusted_close;
    volume = 10_000;
  }

let weekly_bars prices =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices ~f:(fun i p ->
      make_bar (Date.to_string (Date.add_days base (i * 7))) p)

let rising_bars ~n start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> start +. (Float.of_int i *. step)) |> weekly_bars

let make_stock_analysis ticker bars prior =
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker ~bars
    ~benchmark_bars:[] ~prior_stage:prior ~as_of_date:as_of

(* ------------------------------------------------------------------ *)
(* Strong sector: rising bars + bullish constituents                    *)
(* ------------------------------------------------------------------ *)

let test_strong_sector _ =
  let sector_bars = rising_bars ~n:40 50.0 120.0 in
  let bench = rising_bars ~n:40 80.0 100.0 in
  (* All constituents in Stage 2 transition *)
  let constituents =
    List.init 5 ~f:(fun i ->
        make_stock_analysis (Printf.sprintf "T%d" i)
          (rising_bars ~n:35 50.0 100.0)
          (Some (Stage1 { weeks_in_base = 8 })))
  in
  let result =
    analyze ~config:cfg ~sector_name:"Tech" ~sector_bars ~benchmark_bars:bench
      ~constituent_analyses:constituents ~prior_stage:None
  in
  assert_that result.rating (equal_to (Strong : sector_rating))

(* ------------------------------------------------------------------ *)
(* Weak sector: declining bars                                          *)
(* ------------------------------------------------------------------ *)

let test_weak_sector _ =
  let declining =
    List.init 40 ~f:(fun i -> 100.0 -. Float.of_int i) |> weekly_bars
  in
  let bench = rising_bars ~n:40 80.0 100.0 in
  (* All constituents declining *)
  let constituents =
    List.init 3 ~f:(fun i ->
        make_stock_analysis (Printf.sprintf "D%d" i)
          (List.init 35 ~f:(fun j -> 100.0 -. Float.of_int j) |> weekly_bars)
          (Some (Stage3 { weeks_topping = 6 })))
  in
  let result =
    analyze ~config:cfg ~sector_name:"Energy" ~sector_bars:declining
      ~benchmark_bars:bench ~constituent_analyses:constituents ~prior_stage:None
  in
  assert_that result.rating (equal_to (Weak : sector_rating))

(* ------------------------------------------------------------------ *)
(* sector_context_of conversion                                         *)
(* ------------------------------------------------------------------ *)

let test_sector_context_of _ =
  let sector_bars = rising_bars ~n:40 50.0 120.0 in
  let result =
    analyze ~config:cfg ~sector_name:"Healthcare" ~sector_bars
      ~benchmark_bars:[] ~constituent_analyses:[] ~prior_stage:None
  in
  let ctx = sector_context_of result in
  assert_that ctx.sector_name (equal_to "Healthcare");
  assert_that ctx.rating (equal_to (result.rating : sector_rating))

(* ------------------------------------------------------------------ *)
(* No constituents: uses stage + RS only                               *)
(* ------------------------------------------------------------------ *)

let test_no_constituents_uses_stage _ =
  (* Rising sector bars → Stage2 (score 1.0), no RS (neutral 0.5),
     no constituents (default pct 0.5).
     confidence = 1.0×0.40 + 0.5×0.35 + 0.5×0.25 = 0.70 ≥ strong_confidence=0.6
     → Strong. *)
  let sector_bars = rising_bars ~n:40 50.0 100.0 in
  let result =
    analyze ~config:cfg ~sector_name:"Misc" ~sector_bars ~benchmark_bars:[]
      ~constituent_analyses:[] ~prior_stage:None
  in
  assert_that result.constituent_count (equal_to 0);
  assert_that result.rating (equal_to (Strong : sector_rating))

(* ------------------------------------------------------------------ *)
(* Rationale list                                                       *)
(* ------------------------------------------------------------------ *)

let test_rationale_not_empty _ =
  let sector_bars = rising_bars ~n:40 50.0 100.0 in
  let result =
    analyze ~config:cfg ~sector_name:"X" ~sector_bars ~benchmark_bars:[]
      ~constituent_analyses:[] ~prior_stage:None
  in
  assert_that result.rationale (not_ is_empty)

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let sector_bars = rising_bars ~n:40 50.0 100.0 in
  let bench = rising_bars ~n:40 80.0 100.0 in
  let r1 =
    analyze ~config:cfg ~sector_name:"Tech" ~sector_bars ~benchmark_bars:bench
      ~constituent_analyses:[] ~prior_stage:None
  in
  let r2 =
    analyze ~config:cfg ~sector_name:"Tech" ~sector_bars ~benchmark_bars:bench
      ~constituent_analyses:[] ~prior_stage:None
  in
  assert_that r1.rating (equal_to (r2.rating : sector_rating));
  assert_that r1.bullish_constituent_pct
    (float_equal r2.bullish_constituent_pct)

(* ------------------------------------------------------------------ *)
(* Parity: analyze (bar-list) vs analyze_with_callbacks                *)
(*                                                                      *)
(* Builds the {!callbacks} record externally over the same bars the   *)
(* wrapper would compute internally, then asserts that the two entry   *)
(* points produce bit-identical [result] records. Each scenario hits   *)
(* a different regime: high-confidence Stage2 + strong RS,             *)
(* low-confidence Stage4, mixed-stage constituents, insufficient bars. *)
(* ------------------------------------------------------------------ *)

(** Bit-identity matcher for {!Stage.result}. Float fields use [equal_to]
    (Poly.equal — structural equality) so any drift fails. *)
let stage_result_is_bit_identical (expected : Stage.result) :
    Stage.result matcher =
  all_of
    [
      field (fun (r : Stage.result) -> r.stage) (equal_to expected.stage);
      field
        (fun (r : Stage.result) -> r.ma_value)
        (equal_to (expected.ma_value : float));
      field
        (fun (r : Stage.result) -> r.ma_direction)
        (equal_to expected.ma_direction);
      field
        (fun (r : Stage.result) -> r.ma_slope_pct)
        (equal_to (expected.ma_slope_pct : float));
      field
        (fun (r : Stage.result) -> r.transition)
        (equal_to expected.transition);
      field
        (fun (r : Stage.result) -> r.above_ma_count)
        (equal_to expected.above_ma_count);
    ]

(** Bit-identity matcher for {!Sector.result}. The constituent count, breadth,
    rating, name, rationale, RS option, and Stage sub-result are all checked
    field-by-field — any drift in the delegated [Stage.classify_with_callbacks]
    or [Rs.analyze_with_callbacks] paths will surface as a Stage / RS field
    mismatch. *)
let result_is_bit_identical (expected : Sector.result) : Sector.result matcher
    =
  all_of
    [
      field
        (fun (r : Sector.result) -> r.sector_name)
        (equal_to expected.sector_name);
      field
        (fun (r : Sector.result) -> r.stage)
        (stage_result_is_bit_identical expected.stage);
      field
        (fun (r : Sector.result) -> r.rs)
        (equal_to (expected.rs : Rs.result option));
      field
        (fun (r : Sector.result) -> r.rating)
        (equal_to (expected.rating : sector_rating));
      field
        (fun (r : Sector.result) -> r.constituent_count)
        (equal_to expected.constituent_count);
      field
        (fun (r : Sector.result) -> r.bullish_constituent_pct)
        (equal_to (expected.bullish_constituent_pct : float));
      field
        (fun (r : Sector.result) -> r.rationale)
        (equal_to expected.rationale);
    ]

(** Run both [analyze] and [analyze_with_callbacks] over the same input and
    assert their results are bit-equal. The callback bundle is built externally
    via {!Sector.callbacks_from_bars} (the same constructor the wrapper uses
    internally, but we exercise it through the public API). *)
let assert_parity ~sector_name ~sector_bars ~benchmark_bars
    ?(constituent_analyses = []) ?(prior_stage = None) () =
  let callbacks =
    Sector.callbacks_from_bars ~config:cfg ~sector_bars ~benchmark_bars
  in
  let from_bars =
    analyze ~config:cfg ~sector_name ~sector_bars ~benchmark_bars
      ~constituent_analyses ~prior_stage
  in
  let from_callbacks =
    analyze_with_callbacks ~config:cfg ~sector_name ~callbacks
      ~constituent_analyses ~prior_stage
  in
  assert_that from_callbacks (result_is_bit_identical from_bars)

(** High-confidence Stage 2 sector with strong RS vs benchmark and a full slate
    of bullish constituents. Exercises the [Strong] rating branch through the
    callback path. *)
let test_parity_strong_stage2_strong_rs _ =
  let sector_bars = rising_bars ~n:60 50.0 150.0 in
  let bench = rising_bars ~n:60 80.0 100.0 in
  let constituents =
    List.init 5 ~f:(fun i ->
        make_stock_analysis (Printf.sprintf "T%d" i)
          (rising_bars ~n:40 50.0 100.0)
          (Some (Stage1 { weeks_in_base = 8 })))
  in
  assert_parity ~sector_name:"Tech" ~sector_bars ~benchmark_bars:bench
    ~constituent_analyses:constituents ()

(** Low-confidence Stage 4 sector: declining series + declining constituents,
    benchmark rising. Exercises the [Weak] rating branch through the callback
    path. *)
let test_parity_weak_stage4 _ =
  let sector_bars =
    List.init 60 ~f:(fun i -> 150.0 -. Float.of_int i) |> weekly_bars
  in
  let bench = rising_bars ~n:60 80.0 100.0 in
  let constituents =
    List.init 3 ~f:(fun i ->
        make_stock_analysis (Printf.sprintf "D%d" i)
          (List.init 40 ~f:(fun j -> 100.0 -. Float.of_int j) |> weekly_bars)
          (Some (Stage3 { weeks_topping = 6 })))
  in
  assert_parity ~sector_name:"Energy" ~sector_bars ~benchmark_bars:bench
    ~constituent_analyses:constituents ()

(** Mixed-stage constituents: half rising (Stage 2), half declining (Stage 4).
    Tests that [bullish_constituent_pct] and the resulting rating land
    bit-identically through both paths. *)
let test_parity_mixed_constituents _ =
  let sector_bars = rising_bars ~n:60 50.0 100.0 in
  let bench = rising_bars ~n:60 80.0 100.0 in
  let bullish =
    List.init 3 ~f:(fun i ->
        make_stock_analysis (Printf.sprintf "B%d" i)
          (rising_bars ~n:40 50.0 100.0)
          None)
  in
  let bearish =
    List.init 3 ~f:(fun i ->
        make_stock_analysis (Printf.sprintf "X%d" i)
          (List.init 40 ~f:(fun j -> 100.0 -. Float.of_int j) |> weekly_bars)
          None)
  in
  assert_parity ~sector_name:"Mixed" ~sector_bars ~benchmark_bars:bench
    ~constituent_analyses:(bullish @ bearish) ()

(** Insufficient bars: fewer than [stage_config.ma_period] bars and fewer than
    [rs_config.rs_ma_period] aligned bars → Stage1 default + RS = None. *)
let test_parity_insufficient_bars _ =
  let sector_bars = List.init 5 ~f:(Fn.const 50.0) |> weekly_bars in
  assert_parity ~sector_name:"Tiny" ~sector_bars ~benchmark_bars:[] ()

let suite =
  "sector_tests"
  >::: [
         "test_strong_sector" >:: test_strong_sector;
         "test_weak_sector" >:: test_weak_sector;
         "test_sector_context_of" >:: test_sector_context_of;
         "test_no_constituents_uses_stage" >:: test_no_constituents_uses_stage;
         "test_rationale_not_empty" >:: test_rationale_not_empty;
         "test_pure_same_inputs" >:: test_pure_same_inputs;
         "test_parity_strong_stage2_strong_rs"
         >:: test_parity_strong_stage2_strong_rs;
         "test_parity_weak_stage4" >:: test_parity_weak_stage4;
         "test_parity_mixed_constituents" >:: test_parity_mixed_constituents;
         "test_parity_insufficient_bars" >:: test_parity_insufficient_bars;
       ]

let () = run_test_tt_main suite
