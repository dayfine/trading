open OUnit2
open Matchers
module L = Findings_registry_lib

let _parse s =
  L.parse
    ( Sexplib.Sexp.of_string ("(" ^ s ^ ")") |> function
      | Sexplib.Sexp.List l -> l
      | _ -> [] )

let _msg_containing needle msgs =
  List.exists (fun m -> L.contains ~haystack:m ~needle) msgs

let test_valid_rows_parse _ =
  let rows, errs =
    _parse
      {|((issue 7) (finding "f")
         (guard ((unit ("a.ml" "t")) (validator V2)))
         (status fixed))
        ((ref "r") (finding "g") (guard none) (reason "why") (status open))|}
  in
  assert_that
    (errs, List.map L.kind rows)
    (equal_to (([] : string list), [ "both"; "none" ]))

let test_none_needs_reason _ =
  let _, errs =
    _parse {|((issue 1) (finding "f") (guard none) (status open))|}
  in
  assert_that
    (_msg_containing "requires a non-empty reason" errs)
    (equal_to true)

let test_bad_status_and_unknown_key _ =
  let _, errs =
    _parse
      {|((issue 1) (finding "f") (guard none) (reason "r") (status nope))
        ((issue 2) (finding "f") (guard none) (reason "r") (status open) (extra 1))|}
  in
  assert_that
    ( _msg_containing "unknown status" errs,
      _msg_containing "unknown key extra" errs )
    (equal_to (true, true))

let test_validator_scan _ =
  let src =
    {|[ ("V1", Invariant, a); ("V12", Expectation, b); ("Vx", c, d) ]|}
  in
  assert_that
    (L.registered_validators src)
    (elements_are [ equal_to "V1"; equal_to "V12" ])

let test_check_rows _ =
  let rows, _ =
    _parse
      {|((issue 1) (finding "f") (guard ((unit ("a.ml" "present")) (unit ("a.ml" "absent"))
                                          (unit ("gone.ml" "x")) (validator V1) (validator V9)))
         (status fixed))|}
  in
  let read_file = function "a.ml" -> Some "let present = 1" | _ -> None in
  let errs = L.check_rows ~validators:[ "V1" ] ~read_file rows in
  assert_that errs (size_is 3)

let suite =
  "findings_registry_lib"
  >::: [
         "valid rows parse" >:: test_valid_rows_parse;
         "none needs reason" >:: test_none_needs_reason;
         "bad status and unknown key" >:: test_bad_status_and_unknown_key;
         "validator scan" >:: test_validator_scan;
         "check_rows finds each violation" >:: test_check_rows;
       ]

let () = run_test_tt_main suite
