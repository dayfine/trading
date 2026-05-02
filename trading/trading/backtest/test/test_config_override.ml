(** Unit tests for {!Backtest.Config_override.parse} and helpers. Pins the
    contract that key-path strings compile to the same partial-config sexp the
    runner already deep-merges. Errors are surfaced via [Status.status_or] so
    callers can route them like any other invalid-argument failure. *)

open OUnit2
open Core
open Matchers
module Override = Backtest.Config_override

let test_simple_top_level_field _ =
  let result = Override.parse "initial_stop_buffer=1.05" in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (o : Override.t) -> o.key_path)
              (elements_are [ equal_to "initial_stop_buffer" ]);
            field
              (fun (o : Override.t) -> o.value)
              (equal_to (Sexp.Atom "1.05"));
          ]))

let test_nested_field_two_levels _ =
  let result = Override.parse "stops_config.initial_stop_buffer=1.08" in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (o : Override.t) -> o.key_path)
              (elements_are
                 [ equal_to "stops_config"; equal_to "initial_stop_buffer" ]);
            field
              (fun (o : Override.t) -> o.value)
              (equal_to (Sexp.Atom "1.08"));
          ]))

let test_nested_field_three_levels _ =
  let result =
    Override.parse "portfolio_config.position_sizing.target_risk=0.02"
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Override.t) -> o.key_path)
          (elements_are
             [
               equal_to "portfolio_config";
               equal_to "position_sizing";
               equal_to "target_risk";
             ])))

let test_boolean_value _ =
  let result = Override.parse "skip_ad_breadth=true" in
  assert_that result
    (is_ok_and_holds
       (field (fun (o : Override.t) -> o.value) (equal_to (Sexp.Atom "true"))))

let test_int_value _ =
  let result = Override.parse "stage_config.ma_period=40" in
  assert_that result
    (is_ok_and_holds
       (field (fun (o : Override.t) -> o.value) (equal_to (Sexp.Atom "40"))))

let test_paren_value_is_sexp_list _ =
  (* When the right-hand side is a parenthesised sexp, it parses as Sexp.List
     rather than an atom — useful for expressing list-valued or variant-tagged
     fields, though the more typical path for those is a full --override sexp. *)
  let result = Override.parse "indices=((primary GSPC.INDX))" in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Override.t) -> o.value)
          (equal_to
             (Sexp.List
                [ Sexp.List [ Sexp.Atom "primary"; Sexp.Atom "GSPC.INDX" ] ]))))

let test_to_sexp_top_level _ =
  let parsed =
    match Override.parse "initial_stop_buffer=1.05" with
    | Ok t -> t
    | Error err -> assert_failure ("parse failed: " ^ Status.show err)
  in
  assert_that (Override.to_sexp parsed)
    (equal_to
       (Sexp.List
          [ Sexp.List [ Sexp.Atom "initial_stop_buffer"; Sexp.Atom "1.05" ] ]))

let test_to_sexp_nested _ =
  let parsed =
    match Override.parse "stops_config.initial_stop_buffer=1.08" with
    | Ok t -> t
    | Error err -> assert_failure ("parse failed: " ^ Status.show err)
  in
  assert_that (Override.to_sexp parsed)
    (equal_to
       (Sexp.List
          [
            Sexp.List
              [
                Sexp.Atom "stops_config";
                Sexp.List
                  [
                    Sexp.List
                      [ Sexp.Atom "initial_stop_buffer"; Sexp.Atom "1.08" ];
                  ];
              ];
          ]))

let test_to_sexp_three_levels _ =
  let parsed =
    match Override.parse "a.b.c=42" with
    | Ok t -> t
    | Error err -> assert_failure ("parse failed: " ^ Status.show err)
  in
  assert_that (Override.to_sexp parsed)
    (equal_to
       (Sexp.List
          [
            Sexp.List
              [
                Sexp.Atom "a";
                Sexp.List
                  [
                    Sexp.List
                      [
                        Sexp.Atom "b";
                        Sexp.List
                          [ Sexp.List [ Sexp.Atom "c"; Sexp.Atom "42" ] ];
                      ];
                  ];
              ];
          ]))

let test_parse_to_sexp_round_trip _ =
  (* parse_to_sexp = parse |> to_sexp — pin that the convenience function
     lines up with the two-step path. *)
  let result = Override.parse_to_sexp "stops_config.initial_stop_buffer=1.05" in
  assert_that result
    (is_ok_and_holds
       (equal_to
          (Sexp.List
             [
               Sexp.List
                 [
                   Sexp.Atom "stops_config";
                   Sexp.List
                     [
                       Sexp.List
                         [ Sexp.Atom "initial_stop_buffer"; Sexp.Atom "1.05" ];
                     ];
                 ];
             ])))

let test_missing_equals_is_error _ =
  let result = Override.parse "stops_config.initial_stop_buffer" in
  assert_that result is_error

let test_empty_key_is_error _ =
  let result = Override.parse "=1.05" in
  assert_that result is_error

let test_empty_value_is_error _ =
  let result = Override.parse "initial_stop_buffer=" in
  assert_that result is_error

let test_leading_dot_is_error _ =
  let result = Override.parse ".initial_stop_buffer=1.05" in
  assert_that result is_error

let test_trailing_dot_is_error _ =
  let result = Override.parse "stops_config.=1.05" in
  assert_that result is_error

let test_double_dot_is_error _ =
  let result = Override.parse "stops_config..initial_stop_buffer=1.05" in
  assert_that result is_error

let test_value_unparseable_sexp_is_error _ =
  (* An unbalanced paren makes the right-hand side fail to parse as a sexp. *)
  let result = Override.parse "indices=((primary GSPC.INDX)" in
  assert_that result is_error

let test_is_key_path_form_recognises_dotted_form _ =
  assert_that
    (Override.is_key_path_form "stops_config.initial_stop_buffer=1.05")
    (equal_to true)

let test_is_key_path_form_recognises_top_level _ =
  assert_that
    (Override.is_key_path_form "initial_stop_buffer=1.05")
    (equal_to true)

let test_is_key_path_form_rejects_raw_sexp _ =
  (* Pre-existing CLI form: full sexp blob. is_key_path_form must return false
     so the caller can dispatch to the legacy sexp-parser fallback. *)
  assert_that
    (Override.is_key_path_form "((initial_stop_buffer 1.08))")
    (equal_to false)

let test_is_key_path_form_rejects_no_equals _ =
  assert_that
    (Override.is_key_path_form "((initial_stop_buffer 1.08))")
    (equal_to false)

let suite =
  "Backtest.Config_override"
  >::: [
         "simple top-level field" >:: test_simple_top_level_field;
         "nested field, two levels" >:: test_nested_field_two_levels;
         "nested field, three levels" >:: test_nested_field_three_levels;
         "boolean value" >:: test_boolean_value;
         "int value" >:: test_int_value;
         "paren value parses as sexp list" >:: test_paren_value_is_sexp_list;
         "to_sexp: top-level" >:: test_to_sexp_top_level;
         "to_sexp: nested" >:: test_to_sexp_nested;
         "to_sexp: three levels" >:: test_to_sexp_three_levels;
         "parse_to_sexp round-trip" >:: test_parse_to_sexp_round_trip;
         "missing '=' is error" >:: test_missing_equals_is_error;
         "empty key is error" >:: test_empty_key_is_error;
         "empty value is error" >:: test_empty_value_is_error;
         "leading dot is error" >:: test_leading_dot_is_error;
         "trailing dot is error" >:: test_trailing_dot_is_error;
         "double dot is error" >:: test_double_dot_is_error;
         "unparseable sexp value is error"
         >:: test_value_unparseable_sexp_is_error;
         "is_key_path_form: dotted form"
         >:: test_is_key_path_form_recognises_dotted_form;
         "is_key_path_form: top-level"
         >:: test_is_key_path_form_recognises_top_level;
         "is_key_path_form rejects raw sexp"
         >:: test_is_key_path_form_rejects_raw_sexp;
         "is_key_path_form rejects no '='"
         >:: test_is_key_path_form_rejects_no_equals;
       ]

let () = run_test_tt_main suite
