open OUnit2
open Matchers

(* Re-declare the type to get exhaustive matcher generation.
   If the production type adds/removes a field, this declaration
   fails to compile — that's the exhaustiveness guarantee. *)
type snapshot = Portfolio_risk.portfolio_snapshot = {
  total_value : float;
  cash : float;
  cash_pct : float;
  long_exposure : float;
  long_exposure_pct : float;
  short_exposure : float;
  short_exposure_pct : float;
  position_count : int;
  sector_counts : (string * int) list;
}
[@@deriving test_matcher]

(* A simple record defined locally for basic testing. *)
type point = { x : float; y : float } [@@deriving test_matcher]

let _make_snapshot () : Portfolio_risk.portfolio_snapshot =
  {
    total_value = 100_000.0;
    cash = 50_000.0;
    cash_pct = 0.5;
    long_exposure = 40_000.0;
    long_exposure_pct = 0.4;
    short_exposure = 10_000.0;
    short_exposure_pct = 0.1;
    position_count = 5;
    sector_counts = [ ("Tech", 3); ("Finance", 2) ];
  }

let test_point_matcher_all_fields _ =
  let p = { x = 1.0; y = 2.0 } in
  assert_that p (match_point ~x:(float_equal 1.0) ~y:(float_equal 2.0) ())

let test_point_matcher_partial _ =
  let p = { x = 1.0; y = 2.0 } in
  (* Only check x, ignore y *)
  assert_that p (match_point ~x:(float_equal 1.0) ())

let test_point_matcher_ignore_all _ =
  let p = { x = 1.0; y = 2.0 } in
  (* All fields ignored — just verifies the function exists *)
  assert_that p (match_point ())

let test_snapshot_matcher _ =
  let s = _make_snapshot () in
  assert_that s
    (match_snapshot ~total_value:(float_equal 100_000.0)
       ~cash:(float_equal 50_000.0) ~cash_pct:(float_equal 0.5)
       ~position_count:(equal_to 5) ())

let test_snapshot_matcher_all_fields _ =
  let s = _make_snapshot () in
  assert_that s
    (match_snapshot ~total_value:(float_equal 100_000.0)
       ~cash:(float_equal 50_000.0) ~cash_pct:(float_equal 0.5)
       ~long_exposure:(float_equal 40_000.0)
       ~long_exposure_pct:(float_equal 0.4)
       ~short_exposure:(float_equal 10_000.0)
       ~short_exposure_pct:(float_equal 0.1) ~position_count:(equal_to 5)
       ~sector_counts:
         (elements_are
            [
              pair (equal_to "Tech") (equal_to 3);
              pair (equal_to "Finance") (equal_to 2);
            ])
       ())

let test_snapshot_matcher_failure _ =
  let s = _make_snapshot () in
  let failed =
    try
      match_snapshot ~total_value:(float_equal 999.0) () s;
      false
    with _ -> true
  in
  assert_bool "Expected matcher to fail" failed

let suite =
  "ppx_test_matcher"
  >::: [
         "point matcher all fields" >:: test_point_matcher_all_fields;
         "point matcher partial" >:: test_point_matcher_partial;
         "point matcher ignore all" >:: test_point_matcher_ignore_all;
         "snapshot matcher partial" >:: test_snapshot_matcher;
         "snapshot matcher all fields" >:: test_snapshot_matcher_all_fields;
         "snapshot matcher failure" >:: test_snapshot_matcher_failure;
       ]

let () = run_test_tt_main suite
