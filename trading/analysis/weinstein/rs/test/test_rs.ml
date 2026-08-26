open OUnit2
open Core
open Matchers
open Rs
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config
let days_per_week = 7

let make_bar date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close;
    low_price = adjusted_close;
    close_price = adjusted_close;
    volume = 1000;
    adjusted_close;
    active_through = None;
  }

(** Build aligned weekly bars starting 2020-01-06 at the given prices. *)
let weekly_bars prices =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices ~f:(fun i p ->
      make_bar (Date.to_string (Date.add_days base (i * days_per_week))) p)

let const_bars ?(n = 60) price = List.init n ~f:(fun _ -> price) |> weekly_bars

(* ------------------------------------------------------------------ *)
(* Delegation to Relative_strength                                      *)
(* ------------------------------------------------------------------ *)

let test_insufficient_data_returns_none _ =
  let stock = const_bars ~n:40 100.0 in
  let bench = const_bars ~n:40 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    is_none

let test_exact_minimum_data _ =
  let stock = const_bars ~n:52 100.0 in
  let bench = const_bars ~n:52 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (field (fun r -> r.history) (size_is 1)))

let test_current_fields_populated _ =
  (* Verify result fields mirror the last point of the underlying RS history. *)
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.5)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun result ->
         let last = List.last_exn result.history in
         assert_that result.current_rs (float_equal last.rs_value);
         assert_that result.current_normalized (float_equal last.rs_normalized)))

(* ------------------------------------------------------------------ *)
(* Trend classification                                                 *)
(* ------------------------------------------------------------------ *)

let test_positive_rising_trend _ =
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun result ->
         match result.trend with
         | Positive_rising | Positive_flat | Bullish_crossover -> ()
         | other ->
             assert_failure
               (Printf.sprintf "Expected positive trend, got %s"
                  (show_rs_trend other))))

let test_negative_declining_trend _ =
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 0.2)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun result ->
         match result.trend with
         | Negative_declining | Negative_improving | Bearish_crossover -> ()
         | other ->
             assert_failure
               (Printf.sprintf "Expected negative trend, got %s"
                  (show_rs_trend other))))

let test_bullish_crossover _ =
  (* Underperforming for first half, outperforming for second half → crossover *)
  let n = 80 in
  let stock =
    List.init n ~f:(fun i ->
        if i < 60 then 50.0 else 100.0 +. (Float.of_int (i - 60) *. 5.0))
    |> weekly_bars
  in
  let bench = const_bars ~n 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun result ->
         match result.trend with
         | Bullish_crossover | Positive_rising | Positive_flat -> ()
         | other ->
             assert_failure
               (Printf.sprintf "Expected bullish crossover, got %s"
                  (show_rs_trend other))))

(* ------------------------------------------------------------------ *)
(* flat_threshold config                                                *)
(* ------------------------------------------------------------------ *)

(** The invariant [Screener_admission.rs_blocks_long] relies on:
    [Bullish_crossover] implies [current_normalized > 1.0].

    [_classify_trend] emits it only on the
    [(cur > 1.0, prev > 1.0) = (true, false)] arm, and [_result_of_history]
    reports that same float as [current_normalized] — so a crossing has already
    LANDED above the zero line by the time it is classified as one.

    That is why the long-side RS gate can be level-only without conflicting with
    book §4.4 rule 3 ("RS crossing from negative to positive territory -> A+
    bonus signal"): a level test never reaches rule 3's cohort. #2391 briefly
    carried a trend exemption built on the opposite assumption.

    {b Swept across the trend space, not one fixture.} A single
    genuine-crossover fixture cannot detect a classifier that starts emitting
    [Bullish_crossover] BELOW the line, because that fixture never reaches the
    offending branch — the check has to include cases that sit under 1.0. The
    sweep covers ALL THREE producers of a sub-1.0 trend value: the
    [(false, false)] arm, the [(false, true)] arm ([Bearish_crossover], whose
    crossing must fall within [trend_lookback] of the end or the classifier
    reports [Negative_declining] instead), and the [n < 2] fallback, reachable
    only when the history is a single element ([n = rs_ma_period]). An earlier
    version of this sentence said "both", under-counting by one arm. Each pair
    below is labelled so a failure names the shape that broke it.

    {b Non-vacuous only alongside {!test_bullish_crossover}}: a classifier that
    stopped emitting [Bullish_crossover] at all would pass this test through its
    catch-all. Do not delete that one. *)
let test_bullish_crossover_implies_positive_territory _ =
  let n = 80 in
  let rising_from_below =
    List.init n ~f:(fun i ->
        if i < 60 then 50.0 else 100.0 +. (Float.of_int (i - 60) *. 5.0))
    |> weekly_bars
  in
  (* Below the zero line throughout and improving — the shape that a broken
     classifier would most plausibly mislabel as a crossover. *)
  let below_and_improving =
    List.init n ~f:(fun i -> 40.0 +. (Float.of_int i *. 0.3)) |> weekly_bars
  in
  (* Below the line and deteriorating. *)
  let below_and_declining =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 0.2)) |> weekly_bars
  in
  let flat_bench = const_bars ~n 100.0 in
  let rising_bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  (* n = rs_ma_period leaves a ONE-element history, the only shape that reaches
     the [n < 2 -> Positive_flat] fallback (rs.ml:48) — the other producer of a
     sub-1.0 trend value, and the branch that fires in production today per
     #2380. Without it the sweep misses half the ways the invariant can break. *)
  let degenerate_n = 52 in
  let degenerate_stock =
    List.init degenerate_n ~f:(fun i -> 100.0 -. (Float.of_int i *. 0.5))
    |> weekly_bars
  in
  let degenerate_bench =
    List.init degenerate_n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0))
    |> weekly_bars
  in
  (* The THIRD producer of a sub-1.0 level: [(false, true) -> Bearish_crossover]
     has [cur > 1.0] false by construction. Stock outruns the benchmark early
     and gives it back, so RS crosses its own average downward. *)
  let fell_through_the_line =
    List.init n ~f:(fun i ->
        if i < n - 5 then 100.0 +. (Float.of_int i *. 3.0)
        else 325.0 -. (Float.of_int (i - (n - 5)) *. 45.0))
    |> weekly_bars
  in
  let cases =
    [
      (* Labels state the MEASURED normalized level, not the intent behind the
         price shape — an earlier version named two of these "below" when they
         in fact finish above the zero line, which would have made a failure
         report the wrong shape. *)
      ("crossed, now well above (2.23)", rising_from_below, flat_bench);
      ("just above the line (1.14)", below_and_improving, flat_bench);
      ("below the line, improving (0.82)", below_and_declining, rising_bench);
      ( "below the line, one-element history (0.60)",
        degenerate_stock,
        degenerate_bench );
      ("fell back through the line (0.58)", fell_through_the_line, flat_bench);
    ]
  in
  List.iter cases ~f:(fun (label, stock_bars, benchmark_bars) ->
      match analyze ~config:cfg ~stock_bars ~benchmark_bars with
      | Some ({ trend = Bullish_crossover; current_normalized; _ } : result)
        when Float.(current_normalized <= 1.0) ->
          assert_failure
            (Printf.sprintf
               "%s: Bullish_crossover at current_normalized = %.4f, which \
                breaks the invariant Screener_admission.rs_blocks_long depends \
                on (see its .mli)"
               label current_normalized)
      | _ -> ())

let test_flat_threshold_configurable _ =
  (* With a very tight threshold (1.0), even a tiny RS drop is NOT flat. *)
  let strict_cfg = { cfg with flat_threshold = 1.0 } in
  let n = 60 in
  let stock =
    List.init n ~f:(fun i ->
        if i < 55 then 100.0 +. (Float.of_int i *. 1.1)
        else 100.0 +. (Float.of_int i *. 0.9))
    |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. Float.of_int i) |> weekly_bars
  in
  assert_that
    (analyze ~config:strict_cfg ~stock_bars:stock ~benchmark_bars:bench)
    (not_ is_none)

(* ------------------------------------------------------------------ *)
(* Positive_declining (issue #2556)                                     *)
(*                                                                      *)
(* A compact classifier config — a 3-bar zero-line MA and a 1-entry     *)
(* trend lookback — so each fixture is 8 hand-checkable bars against a  *)
(* flat 100 benchmark, and the two compared history entries are the     *)
(* last two. Under the shipped 52/4 config the same shapes would need   *)
(* ~56 bars and the arithmetic would not be readable.                   *)
(* ------------------------------------------------------------------ *)

let _compact = { cfg with rs_ma_period = 3; trend_lookback = 1 }
let _flat_bench n = const_bars ~n 100.0

let _classify ?(config = _compact) prices =
  let stock = weekly_bars prices in
  analyze ~config ~stock_bars:stock
    ~benchmark_bars:(_flat_bench (List.length prices))
  |> Option.map ~f:(fun (r : result) -> r.trend)

(** Positive RS that is rolling over: prices compound at 10%/week for seven
    bars, then the eighth rises only 2%. Geometric growth against a flat
    benchmark holds normalized RS CONSTANT (each bar's raw value and its own
    trailing average grow by the same factor), so the kink — not the level, and
    not the price direction, which is still up — is what moves the
    classification.

    Normalized RS goes 1.0967 -> 1.0447, a 4.74% drop, with both points above
    1.0. That lands strictly inside the default [flat_threshold = 0.98] band's
    declining side. *)
let _positive_declining_prices =
  let geometric i = 100.0 *. (1.1 ** Float.of_int i) in
  List.init 8 ~f:(fun i -> if i < 7 then geometric i else geometric 6 *. 1.02)

(** Armed, the rolling-over fixture is [Positive_declining]. *)
let test_positive_declining_when_armed _ =
  assert_that
    (_classify
       ~config:{ _compact with enable_positive_declining = true }
       _positive_declining_prices)
    (is_some_and (equal_to Positive_declining))

(** R1: the SAME fixture with the flag off is [Positive_flat] — the state this
    cohort has always been reported as. This is the bit-identity half of the
    default-off contract, asserted on the one input that can tell the two
    branches apart. *)
let test_positive_declining_folds_to_flat_when_off _ =
  assert_that
    (_classify _positive_declining_prices)
    (is_some_and (equal_to Positive_flat))

(** [flat_threshold] becomes OBSERVABLE once the state is armed — before this
    change both sides of that comparison returned [Positive_flat], so the knob
    could not affect any output. The measured 4.74% drop straddles the two
    thresholds: at 0.98 it is declining, at 0.95 it is still flat. Asserted as a
    pair so a failure names which side moved. *)
let test_flat_threshold_is_observable_when_armed _ =
  let at threshold =
    _classify
      ~config:
        {
          _compact with
          enable_positive_declining = true;
          flat_threshold = threshold;
        }
      _positive_declining_prices
  in
  assert_that
    (at 0.98, at 0.95)
    (equal_to (Some Positive_declining, Some Positive_flat))

(** Arming the flag must not disturb any OTHER classification. One fixture per
    remaining constructor plus the [n < 2] degenerate fallback, all run with the
    flag ON: only the positive-zone sub-threshold arm may change, so every one
    of these must land exactly where it did before.

    Note the geometric case: constant-ratio growth is [Positive_flat], not
    [Positive_rising] — normalized RS is flat because the price and its own
    trailing average grow together. *)
let test_arming_leaves_other_classifications_unchanged _ =
  let armed = { _compact with enable_positive_declining = true } in
  let at prices = _classify ~config:armed prices in
  assert_that
    [
      at [ 100.0; 102.0; 106.0; 112.0; 122.0; 140.0; 175.0; 240.0 ];
      at [ 100.0; 100.0; 100.0; 100.0; 100.0; 100.0; 99.0; 140.0 ];
      at [ 100.0; 100.0; 100.0; 100.0; 100.0; 120.0; 140.0; 100.0 ];
      at [ 100.0; 95.0; 90.0; 85.0; 80.0; 75.0; 70.0; 65.0 ];
      at [ 100.0; 90.0; 81.0; 73.0; 66.0; 60.0; 58.0; 57.0 ];
      at [ 100.0; 110.0; 121.0 ];
    ]
    (elements_are
       [
         is_some_and (equal_to Positive_rising);
         is_some_and (equal_to Bullish_crossover);
         is_some_and (equal_to Bearish_crossover);
         is_some_and (equal_to Negative_declining);
         is_some_and (equal_to Negative_improving);
         is_some_and (equal_to Positive_flat);
       ])

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs_same_output _ =
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.5)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  let r1 =
    Option.value_exn
      (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
  in
  let r2 =
    Option.value_exn
      (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
  in
  assert_that r1.current_rs (float_equal r2.current_rs);
  assert_that r1.current_normalized (float_equal r2.current_normalized);
  assert_that r1.trend (equal_to (r2.trend : rs_trend))

(** Stock falls 20% while benchmark rises 10% over 60 weeks. Unambiguous
    underperformance — RS must be [Negative_declining]. *)
let test_stock_falling_benchmark_rising _ =
  let n = 60 in
  let benchmark =
    List.init n ~f:(fun i ->
        100.0 *. (1.0 +. (Float.of_int i *. 0.10 /. Float.of_int (n - 1))))
    |> weekly_bars
  in
  let stock =
    List.init n ~f:(fun i ->
        100.0 *. (1.0 -. (Float.of_int i *. 0.20 /. Float.of_int (n - 1))))
    |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:benchmark)
    (is_some_and (field (fun r -> r.trend) (equal_to Negative_declining)))

(* ------------------------------------------------------------------ *)
(* Parity: analyze (bar-list) vs analyze_with_callbacks                *)
(*                                                                      *)
(* Builds [get_stock_close] / [get_benchmark_close] / [get_date]       *)
(* callbacks externally over the same date-aligned series the wrapper  *)
(* would compute internally, then asserts that the two entry points    *)
(* produce bit-identical [result] records. Each scenario hits a        *)
(* different RS regime (positive, negative, near-zero, crossover) plus *)
(* the insufficient-data early-return.                                 *)
(* ------------------------------------------------------------------ *)

(** Build a [get_*] closure over a precomputed array, indexed in chronological
    order (oldest at index 0, newest at the end). [week_offset:0] returns the
    newest entry; offsets past the array's depth return [None]. Mirrors the
    indexing rules the wrapper uses internally. *)
let make_indexed (arr : 'a array) ~week_offset : 'a option =
  let n = Array.length arr in
  let idx = n - 1 - week_offset in
  if idx < 0 || idx >= n then None else Some arr.(idx)

(** Date.t Map of benchmark adjusted_close values, keyed on bar date. *)
let bench_map_of_bars (benchmark_bars : Daily_price.t list) =
  List.fold benchmark_bars ~init:Date.Map.empty ~f:(fun m b ->
      Map.set m ~key:b.Daily_price.date ~data:b.Daily_price.adjusted_close)

(** Build aligned (date, stock_close, bench_close) triples from the same join
    the wrapper uses, oldest first. *)
let aligned_triples ~stock_bars ~benchmark_bars =
  let bench_map = bench_map_of_bars benchmark_bars in
  List.filter_map stock_bars ~f:(fun bar ->
      Map.find bench_map bar.Daily_price.date
      |> Option.map ~f:(fun bench_close ->
          (bar.Daily_price.date, bar.Daily_price.adjusted_close, bench_close)))

(** Bit-identity matcher for [Rs.result]. Float fields use [equal_to] with
    [Poly.equal] (structural equality) so any drift — even a single ULP — fails
    the test. The [history] list is compared element-wise on every field. *)
let raw_rs_is_bit_identical (expected : raw_rs) : raw_rs matcher =
  all_of
    [
      field
        (fun (r : raw_rs) -> r.Relative_strength.date)
        (equal_to expected.Relative_strength.date);
      field
        (fun (r : raw_rs) -> r.Relative_strength.rs_value)
        (equal_to (expected.Relative_strength.rs_value : float));
      field
        (fun (r : raw_rs) -> r.Relative_strength.rs_normalized)
        (equal_to (expected.Relative_strength.rs_normalized : float));
    ]

let result_is_bit_identical (expected : Rs.result) : Rs.result matcher =
  all_of
    [
      field
        (fun (r : Rs.result) -> r.current_rs)
        (equal_to (expected.current_rs : float));
      field
        (fun (r : Rs.result) -> r.current_normalized)
        (equal_to (expected.current_normalized : float));
      field (fun (r : Rs.result) -> r.trend) (equal_to expected.trend);
      field
        (fun (r : Rs.result) -> r.history)
        (elements_are (List.map expected.history ~f:raw_rs_is_bit_identical));
    ]

(** Run both [Rs.analyze] and [Rs.analyze_with_callbacks] over the same input
    and assert the results match bit-for-bit. *)
let assert_parity ?(config = cfg) ~stock_bars ~benchmark_bars () =
  let aligned = aligned_triples ~stock_bars ~benchmark_bars |> Array.of_list in
  let stock_arr = Array.map aligned ~f:(fun (_, sc, _) -> sc) in
  let bench_arr = Array.map aligned ~f:(fun (_, _, bc) -> bc) in
  let date_arr = Array.map aligned ~f:(fun (d, _, _) -> d) in
  let from_bars = analyze ~config ~stock_bars ~benchmark_bars in
  let from_callbacks =
    analyze_with_callbacks ~config ~get_stock_close:(make_indexed stock_arr)
      ~get_benchmark_close:(make_indexed bench_arr)
      ~get_date:(make_indexed date_arr)
  in
  match (from_bars, from_callbacks) with
  | None, None -> ()
  | Some bars_result, Some cb_result ->
      assert_that cb_result (result_is_bit_identical bars_result)
  | None, Some _ ->
      assert_failure "bar-list returned None but callbacks returned Some"
  | Some _, None ->
      assert_failure "bar-list returned Some but callbacks returned None"

(** Positive RS: stock outperforms benchmark consistently across 100 weeks. *)
let test_parity_positive_rs _ =
  let n = 100 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Negative RS: stock underperforms benchmark across 100 weeks. *)
let test_parity_negative_rs _ =
  let n = 100 in
  let stock =
    List.init n ~f:(fun i ->
        100.0 *. (1.0 -. (Float.of_int i *. 0.30 /. Float.of_int (n - 1))))
    |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i ->
        100.0 *. (1.0 +. (Float.of_int i *. 0.20 /. Float.of_int (n - 1))))
    |> weekly_bars
  in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Near-zero RS movement: stock and benchmark move identically. *)
let test_parity_near_zero_rs _ =
  let n = 80 in
  let stock = const_bars ~n 100.0 in
  let bench = const_bars ~n 100.0 in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Bullish crossover: stock underperforms then outperforms. *)
let test_parity_crossover _ =
  let n = 80 in
  let stock =
    List.init n ~f:(fun i ->
        if i < 60 then 50.0 else 100.0 +. (Float.of_int (i - 60) *. 5.0))
    |> weekly_bars
  in
  let bench = const_bars ~n 100.0 in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Insufficient data: fewer aligned bars than [rs_ma_period]. Both paths take
    the [None] early-return. *)
let test_parity_insufficient_data _ =
  let stock = const_bars ~n:30 100.0 in
  let bench = const_bars ~n:30 100.0 in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Exact-minimum data: aligned bars equal [rs_ma_period]. Edge of the
    [n < rs_ma_period] guard. *)
let test_parity_exact_minimum_data _ =
  let n = 52 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 0.5)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 0.4)) |> weekly_bars
  in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

let suite =
  "rs_tests"
  >::: [
         "insufficient_data_returns_none"
         >:: test_insufficient_data_returns_none;
         "exact_minimum_data" >:: test_exact_minimum_data;
         "current_fields_populated" >:: test_current_fields_populated;
         "positive_rising_trend" >:: test_positive_rising_trend;
         "negative_declining_trend" >:: test_negative_declining_trend;
         "stock_falling_benchmark_rising"
         >:: test_stock_falling_benchmark_rising;
         "bullish_crossover" >:: test_bullish_crossover;
         "bullish_crossover_implies_positive_territory"
         >:: test_bullish_crossover_implies_positive_territory;
         "flat_threshold_configurable" >:: test_flat_threshold_configurable;
         "positive_declining_when_armed" >:: test_positive_declining_when_armed;
         "positive_declining_folds_to_flat_when_off"
         >:: test_positive_declining_folds_to_flat_when_off;
         "flat_threshold_is_observable_when_armed"
         >:: test_flat_threshold_is_observable_when_armed;
         "arming_leaves_other_classifications_unchanged"
         >:: test_arming_leaves_other_classifications_unchanged;
         "pure_same_inputs_same_output" >:: test_pure_same_inputs_same_output;
         "parity_positive_rs" >:: test_parity_positive_rs;
         "parity_negative_rs" >:: test_parity_negative_rs;
         "parity_near_zero_rs" >:: test_parity_near_zero_rs;
         "parity_crossover" >:: test_parity_crossover;
         "parity_insufficient_data" >:: test_parity_insufficient_data;
         "parity_exact_minimum_data" >:: test_parity_exact_minimum_data;
       ]

let () = run_test_tt_main suite
