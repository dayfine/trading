(** #3664: the virgin test and the overhead-supply grade on one price basis,
    driven through the record's own path. Weekly bars go into a snapshot
    ({!Bar_reader.of_in_memory_bars}) and into an adjusted-basis side-table (the
    warehouse builder, {!Weekly_sidetable_builder.of_bars}); {!Panel_callbacks}
    reads the sketch anchored at [Adjusted_close], as an adjusted-basis
    warehouse run does; {!Stock_analysis.analyze_with_callbacks} computes both
    verdicts. No [Stock_analysis.t] or sketch is built by hand.

    The fixture's raw 10-year high is 150 (100 to 109 weeks back). Its base top,
    the raw breakout, is 100, and the as-of week closes at 98. A 2-for-1 split
    AFTER the as-of date halves every stored adjusted price, so the sketch's
    520-week high reads 75 and its anchor 49. [Legacy_mixed] compares the raw
    100 with 75 and calls the name virgin (the record's defect, pinned as the
    unchanged default). [One_basis] reads the breakout as 100 * 49 / 98 = 50,
    which is not virgin, as it is not on the raw tape (100 < 150). *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Panel_callbacks = Weinstein_strategy.Panel_callbacks
module Weekly_sidetable_reader = Weinstein_strategy.Weekly_sidetable_reader
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder

let _symbol = "SPLITS"
let _first_friday = Date.of_string "2015-01-02"
let _n_weeks = 110

(* Raw (high, low, close) by offset back from the as-of week (0 = newest). Ten
   weeks at the 10-year high, a decline, a base whose top (100, 30 weeks back)
   is the breakout, then a recent advance that stays under it. *)
let _raw_at off =
  if off >= 100 then (150.0, 140.0, 145.0)
  else if off >= 52 then (90.0, 80.0, 85.0)
  else if off = 30 then (100.0, 88.0, 94.0)
  else if off >= 8 then (96.0, 88.0, 94.0)
  else if off > 0 then (98.0, 92.0, 96.0)
  else (98.0, 92.0, 98.0)

(* One bar per week, each on a Friday, stored the way the bar store keeps a
   name whose split lands after the as-of date: raw OHLC as traded,
   [adjusted_close] the raw close times [factor]. *)
let _bars ~factor =
  List.init _n_weeks ~f:(fun i ->
      let high, low, close = _raw_at (_n_weeks - 1 - i) in
      Types.Daily_price.make
        ~date:(Date.add_days _first_friday (7 * i))
        ~open_price:close ~high_price:high ~low_price:low ~close_price:close
        ~volume:1_000_000 ~adjusted_close:(close *. factor) ())

(* Both resistance-v2 features armed (the record's defaults), on [basis]. *)
let _config ~basis =
  {
    Stock_analysis.default_config with
    overhead_supply = Some Resistance_supply.default_config;
    virgin_crossing_readmission = true;
    virgin_supply_basis = basis;
  }

let _analyze ~basis ~factor =
  let bars = _bars ~factor in
  let as_of = (List.last_exn bars).date in
  let config = _config ~basis in
  let reader = Bar_reader.of_in_memory_bars [ (_symbol, bars) ] in
  let stock =
    Bar_reader.weekly_view_for reader ~symbol:_symbol ~n:_n_weeks ~as_of
  in
  let callbacks =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views
      ~snapshot_cb:(Bar_reader.snapshot_callbacks reader)
      ~stock_symbol:_symbol
      ~weekly_sidetable:(Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars)
      ~sketch_warehouse:true ~sidetable_basis:Weekly_sidetable_reader.Adjusted
      ~config ~stock ~benchmark:stock ()
  in
  Stock_analysis.analyze_with_callbacks ~config ~ticker:_symbol ~callbacks
    ~prior_stage:None ~as_of_date:as_of

let _legacy = Stock_analysis_supply.Legacy_mixed
let _one_basis = Stock_analysis_supply.One_basis

(* The fixture is what it claims: raw breakout 100 and raw as-of close 98, both
   under the raw 10-year high of 150, with the adjusted close at half. *)
let _is_later_split_fixture =
  all_of
    [
      field
        (fun (a : Stock_analysis.t) -> a.breakout_price)
        (is_some_and (float_equal 100.0));
      field
        (fun (a : Stock_analysis.t) -> a.current_raw_close)
        (is_some_and (float_equal 98.0));
      field
        (fun (a : Stock_analysis.t) -> a.current_close)
        (is_some_and (float_equal 49.0));
    ]

(* The virgin test. Legacy: the raw breakout clears the adjusted 520-week high,
   so the name is re-admitted as virgin (unchanged default). One basis: it is
   not virgin, and the sketch is not clear of supply (the ten weeks at the old
   high sit in the 78-130w band), so re-admission is off. Red when the virgin
   test reads the raw breakout under [One_basis]. *)
let test_virgin_later_split_not_virgin_on_one_basis _ =
  assert_that
    (_analyze ~basis:_legacy ~factor:0.5, _analyze ~basis:_one_basis ~factor:0.5)
    (all_of
       [
         field (fun (legacy, _) -> legacy) _is_later_split_fixture;
         field (fun (_, one) -> one) _is_later_split_fixture;
         field
           (fun ((legacy : Stock_analysis.t), _) -> legacy.virgin_readmission)
           (equal_to true);
         field
           (fun (_, (one : Stock_analysis.t)) -> one.virgin_readmission)
           (equal_to false);
       ])

(* The supply grade. Legacy: [Virgin_territory] with score 0, from the same
   mixed comparison. One basis: the ten weeks at the old high (one histogram
   bucket, count 10 >= the heavy threshold 8) sit above the breakout, so the
   grade is [Heavy_resistance] with a positive score. Red when the grade reads
   the raw breakout under [One_basis]. *)
let test_supply_grade_later_split_not_virgin_on_one_basis _ =
  let supply basis = (_analyze ~basis ~factor:0.5).supply in
  assert_that
    (supply _legacy, supply _one_basis)
    (all_of
       [
         field
           (fun (legacy, _) -> legacy)
           (is_some_and
              (all_of
                 [
                   field
                     (fun (r : Resistance_supply.result) -> r.quality)
                     (equal_to Weinstein_types.Virgin_territory);
                   field
                     (fun (r : Resistance_supply.result) -> r.score)
                     (float_equal 0.0);
                 ]));
         field
           (fun (_, one) -> one)
           (is_some_and
              (all_of
                 [
                   field
                     (fun (r : Resistance_supply.result) -> r.quality)
                     (equal_to Weinstein_types.Heavy_resistance);
                   field
                     (fun (r : Resistance_supply.result) -> r.score)
                     (gt (module Float_ord) 0.0);
                 ]));
       ])

(* Control: the same tape with no corporate action after the as-of date. The
   bases already agree, so both settings give the same grade and the same
   (not virgin) verdict: [One_basis] moves only the mixed cases. *)
let test_split_free_one_basis_matches_legacy _ =
  let verdicts basis =
    let a = _analyze ~basis ~factor:1.0 in
    (a.virgin_readmission, a.supply)
  in
  assert_that (verdicts _one_basis)
    (all_of
       [
         field (fun (virgin, _) -> virgin) (equal_to false);
         equal_to (verdicts _legacy);
       ])

let suite =
  "virgin_supply_basis"
  >::: [
         "test_virgin_later_split_not_virgin_on_one_basis"
         >:: test_virgin_later_split_not_virgin_on_one_basis;
         "test_supply_grade_later_split_not_virgin_on_one_basis"
         >:: test_supply_grade_later_split_not_virgin_on_one_basis;
         "test_split_free_one_basis_matches_legacy"
         >:: test_split_free_one_basis_matches_legacy;
       ]

let () = run_test_tt_main suite
