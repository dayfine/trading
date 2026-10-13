open Core
open OUnit2
open Matchers
open Universe
module SC = Symbol_class

let _cls = SC.classify ?extra_non_usd:None

let test_warrants _ =
  assert_that
    (List.map [ "AIG-WS"; "C-WS-A"; "BAC-WS-A"; "acel-ws" ] ~f:_cls)
    (elements_are
       [
         equal_to (Some SC.Warrant);
         equal_to (Some SC.Warrant);
         equal_to (Some SC.Warrant);
         equal_to (Some SC.Warrant);
       ])

let test_units _ =
  assert_that
    (List.map [ "LHC-UN"; "AAC-UN"; "aaqc-un" ] ~f:_cls)
    (elements_are
       [
         equal_to (Some SC.Unit);
         equal_to (Some SC.Unit);
         equal_to (Some SC.Unit);
       ])

let test_non_usd_specimens _ =
  assert_that
    (List.map [ "HSBA"; "SBER"; "CELSIA"; "CTRA_old"; "hsba" ] ~f:_cls)
    (each (equal_to (Some SC.Non_usd_listing)))

let test_extra_non_usd_extends_seed _ =
  assert_that
    (SC.classify ~extra_non_usd:[ "ISF-CL" ] "ISF-CL", SC.classify "ISF-CL")
    (equal_to (Some SC.Non_usd_listing, (None : SC.t option)))

(* Ordinary symbols, share classes, bare tickers named like suffixes, and
   [_old] renames of USD names are not classed. *)
let test_ordinary_symbols_unclassed _ =
  assert_that
    (List.map
       [
         "AAPL"; "AMZN"; "BRK-B"; "GOOGL"; "UN"; "WS"; "COMP_old"; "UNP"; "LDG";
       ]
       ~f:_cls)
    (each (equal_to (None : SC.t option)))

(* A symbol matching both a suffix and the non-USD set reports the suffix
   class. *)
let test_precedence_suffix_over_set _ =
  assert_that
    (SC.classify ~extra_non_usd:[ "X-WS" ] "X-WS")
    (equal_to (Some SC.Warrant))

let test_precedence_warrant_unit_non_usd _ =
  assert_that
    ( SC.classify "X-WS-UN",
      SC.classify ~extra_non_usd:[ "Y-UN" ] "Y-UN",
      SC.classify "HSBA" )
    (equal_to (Some SC.Warrant, Some SC.Unit, Some SC.Non_usd_listing))

let suite =
  "symbol_class"
  >::: [
         "test_warrants" >:: test_warrants;
         "test_units" >:: test_units;
         "test_non_usd_specimens" >:: test_non_usd_specimens;
         "test_extra_non_usd_extends_seed" >:: test_extra_non_usd_extends_seed;
         "test_ordinary_symbols_unclassed" >:: test_ordinary_symbols_unclassed;
         "test_precedence_suffix_over_set" >:: test_precedence_suffix_over_set;
         "test_precedence_warrant_unit_non_usd"
         >:: test_precedence_warrant_unit_non_usd;
       ]

let () = run_test_tt_main suite
