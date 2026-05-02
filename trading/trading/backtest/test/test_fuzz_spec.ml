(** Unit tests for {!Backtest.Fuzz_spec.parse}. The parser handles two value
    kinds (date / float) plus the [n] count; tests pin success cases for each
    kind, error paths for malformed input, and the variant-generation arithmetic
    (linear spacing, endpoints exact, n=1 returns just the centre). *)

open OUnit2
open Core
open Matchers
module Fuzz_spec = Backtest.Fuzz_spec

(* ---- date specs ---- *)

let test_date_spec_basic _ =
  let result = Fuzz_spec.parse "start_date=2019-05-01\xC2\xB15w:11" in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field (fun (t : Fuzz_spec.t) -> t.key_path) (equal_to "start_date");
            field (fun (t : Fuzz_spec.t) -> t.n) (equal_to 11);
            field (fun (t : Fuzz_spec.t) -> t.variants) (size_is 11);
          ]))

let test_date_spec_endpoints_exact _ =
  (* ±5w with n=11 → step = 70 days / 10 = 7 days; endpoints at 2019-05-01 ±
     35 days (2019-03-27 .. 2019-06-05). *)
  let result = Fuzz_spec.parse "start_date=2019-05-01\xC2\xB15w:11" in
  let variants =
    match result with
    | Ok t -> t.variants
    | Error _ -> assert_failure "parse failed"
  in
  let head = List.hd_exn variants in
  let tail = List.last_exn variants in
  assert_that head
    (all_of
       [
         field (fun (v : Fuzz_spec.variant) -> v.index) (equal_to 1);
         field
           (fun (v : Fuzz_spec.variant) -> v.value)
           (equal_to (Fuzz_spec.V_date (Date.of_string "2019-03-27")));
       ]);
  assert_that tail
    (all_of
       [
         field (fun (v : Fuzz_spec.variant) -> v.index) (equal_to 11);
         field
           (fun (v : Fuzz_spec.variant) -> v.value)
           (equal_to (Fuzz_spec.V_date (Date.of_string "2019-06-05")));
       ])

let test_date_spec_ascii_separator _ =
  (* The +/- ASCII fallback should parse equivalently to the unicode ±. *)
  let utf8 = Fuzz_spec.parse "start_date=2019-05-01\xC2\xB13d:3" in
  let ascii = Fuzz_spec.parse "start_date=2019-05-01+/-3d:3" in
  let dates_of r =
    match r with
    | Ok (t : Fuzz_spec.t) ->
        List.map t.variants ~f:(fun v ->
            match v.value with
            | V_date d -> d
            | V_float _ -> assert_failure "expected V_date")
    | Error _ -> assert_failure "parse failed"
  in
  assert_that (dates_of utf8) (equal_to (dates_of ascii))

let test_date_spec_days _ =
  let result = Fuzz_spec.parse "start_date=2020-01-15\xC2\xB12d:5" in
  let variants =
    match result with
    | Ok t -> t.variants
    | Error _ -> assert_failure "parse failed"
  in
  (* ±2d, n=5 → step = 4 days / 4 = 1 day → 13, 14, 15, 16, 17. *)
  let dates =
    List.map variants ~f:(fun v ->
        match v.value with
        | V_date d -> Date.to_string d
        | V_float _ -> "NOT-A-DATE")
  in
  assert_that dates
    (elements_are
       [
         equal_to "2020-01-13";
         equal_to "2020-01-14";
         equal_to "2020-01-15";
         equal_to "2020-01-16";
         equal_to "2020-01-17";
       ])

(* ---- numeric specs ---- *)

let test_numeric_spec_basic _ =
  let result =
    Fuzz_spec.parse "stops_config.initial_stop_buffer=1.05\xC2\xB10.02:11"
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (t : Fuzz_spec.t) -> t.key_path)
              (equal_to "stops_config.initial_stop_buffer");
            field (fun (t : Fuzz_spec.t) -> t.n) (equal_to 11);
            field (fun (t : Fuzz_spec.t) -> t.variants) (size_is 11);
          ]))

let test_numeric_spec_endpoints_exact _ =
  let result = Fuzz_spec.parse "x=1.05\xC2\xB10.02:11" in
  let variants =
    match result with
    | Ok t -> t.variants
    | Error _ -> assert_failure "parse failed"
  in
  let value_of v =
    match v.Fuzz_spec.value with
    | V_float f -> f
    | V_date _ -> assert_failure "expected V_float"
  in
  assert_that (value_of (List.hd_exn variants)) (float_equal 1.03);
  assert_that (value_of (List.last_exn variants)) (float_equal 1.07);
  (* Middle (index=6 of 11 → centre) should equal centre. *)
  assert_that (value_of (List.nth_exn variants 5)) (float_equal 1.05)

let test_numeric_spec_n_equals_one _ =
  let result = Fuzz_spec.parse "x=2.5\xC2\xB10.5:1" in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (t : Fuzz_spec.t) -> t.variants)
          (elements_are
             [
               all_of
                 [
                   field
                     (fun (v : Fuzz_spec.variant) -> v.value)
                     (equal_to (Fuzz_spec.V_float 2.5));
                   field (fun (v : Fuzz_spec.variant) -> v.index) (equal_to 1);
                 ];
             ])))

(* ---- error paths ---- *)

let test_missing_equals _ =
  let result = Fuzz_spec.parse "start_date 2019-05-01" in
  assert_that result is_error

let test_missing_separator _ =
  let result = Fuzz_spec.parse "x=1.05" in
  assert_that result is_error

let test_missing_n _ =
  let result = Fuzz_spec.parse "x=1.05\xC2\xB10.02" in
  assert_that result is_error

let test_zero_n _ =
  let result = Fuzz_spec.parse "x=1.05\xC2\xB10.02:0" in
  assert_that result is_error

let test_negative_delta _ =
  let result = Fuzz_spec.parse "x=1.05\xC2\xB1-0.02:5" in
  assert_that result is_error

let test_invalid_date_unit _ =
  let result = Fuzz_spec.parse "start_date=2019-05-01\xC2\xB15y:5" in
  assert_that result is_error

let test_invalid_key_path _ =
  let result = Fuzz_spec.parse "bad-key=1.0\xC2\xB10.1:3" in
  assert_that result is_error

let test_empty_key _ =
  let result = Fuzz_spec.parse "=1.0\xC2\xB10.1:3" in
  assert_that result is_error

(* ---- subdir naming ---- *)

let test_subdir_zero_padded _ =
  assert_that (Fuzz_spec.subdir_name ~n:11 ~index:3) (equal_to "var-03");
  assert_that (Fuzz_spec.subdir_name ~n:11 ~index:11) (equal_to "var-11");
  assert_that (Fuzz_spec.subdir_name ~n:100 ~index:7) (equal_to "var-007");
  assert_that (Fuzz_spec.subdir_name ~n:9 ~index:3) (equal_to "var-3")

(* ---- variant labels ---- *)

let test_date_label_is_iso_date _ =
  let result = Fuzz_spec.parse "start_date=2019-05-01\xC2\xB10d:1" in
  match result with
  | Ok t ->
      let v = List.hd_exn t.variants in
      assert_that v.label (equal_to "2019-05-01")
  | Error _ -> assert_failure "parse failed"

let test_float_label_three_decimals _ =
  let result = Fuzz_spec.parse "x=1.05\xC2\xB10.02:11" in
  match result with
  | Ok t ->
      let labels = List.map t.variants ~f:(fun v -> v.label) in
      assert_that (List.hd_exn labels) (equal_to "1.030");
      assert_that (List.last_exn labels) (equal_to "1.070")
  | Error _ -> assert_failure "parse failed"

let suite =
  "Backtest.Fuzz_spec"
  >::: [
         "date spec basic" >:: test_date_spec_basic;
         "date spec endpoints exact" >:: test_date_spec_endpoints_exact;
         "date spec ASCII separator" >:: test_date_spec_ascii_separator;
         "date spec days unit" >:: test_date_spec_days;
         "numeric spec basic" >:: test_numeric_spec_basic;
         "numeric spec endpoints exact" >:: test_numeric_spec_endpoints_exact;
         "numeric spec n=1" >:: test_numeric_spec_n_equals_one;
         "missing equals" >:: test_missing_equals;
         "missing ± separator" >:: test_missing_separator;
         "missing :n" >:: test_missing_n;
         "n=0 is error" >:: test_zero_n;
         "negative delta is error" >:: test_negative_delta;
         "invalid date unit (y)" >:: test_invalid_date_unit;
         "invalid key path" >:: test_invalid_key_path;
         "empty key" >:: test_empty_key;
         "subdir_name zero-padded" >:: test_subdir_zero_padded;
         "date label is ISO date" >:: test_date_label_is_iso_date;
         "float label is 3 decimals" >:: test_float_label_three_decimals;
       ]

let () = run_test_tt_main suite
