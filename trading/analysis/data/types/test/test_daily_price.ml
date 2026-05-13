open OUnit2
open Core
open Matchers
open Types

let _sample_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19

(* The [make] helper defaults [active_through] to [None] — appropriate for
   any data source that does not carry a delisting marker. *)
let test_make_defaults_active_through_to_none _ =
  let bar =
    Daily_price.make ~date:_sample_date ~open_price:100.0 ~high_price:105.0
      ~low_price:98.0 ~close_price:103.0 ~adjusted_close:103.0 ~volume:1000 ()
  in
  assert_that bar.active_through is_none

(* The helper threads through an explicit [active_through] when supplied. *)
let test_make_threads_active_through _ =
  let delisted_on = Date.create_exn ~y:2024 ~m:Month.May ~d:15 in
  let bar =
    Daily_price.make ~date:_sample_date ~open_price:100.0 ~high_price:105.0
      ~low_price:98.0 ~close_price:103.0 ~adjusted_close:103.0 ~volume:1000
      ~active_through:delisted_on ()
  in
  assert_that bar.active_through (is_some_and (equal_to delisted_on))

(* Equality respects [active_through]: bars that differ only in their
   delisting marker are not considered equal. This guards against an
   eager refactor that drops the field from the derived equality. *)
let test_equality_respects_active_through _ =
  let base =
    Daily_price.make ~date:_sample_date ~open_price:100.0 ~high_price:105.0
      ~low_price:98.0 ~close_price:103.0 ~adjusted_close:103.0 ~volume:1000 ()
  in
  let with_marker =
    Daily_price.make ~date:_sample_date ~open_price:100.0 ~high_price:105.0
      ~low_price:98.0 ~close_price:103.0 ~adjusted_close:103.0 ~volume:1000
      ~active_through:_sample_date ()
  in
  assert_that (Daily_price.equal base with_marker) (equal_to false)

(* Two bars sharing identical OHLCV + [active_through] are equal. *)
let test_equality_holds_for_identical_records _ =
  let bar1 =
    Daily_price.make ~date:_sample_date ~open_price:100.0 ~high_price:105.0
      ~low_price:98.0 ~close_price:103.0 ~adjusted_close:103.0 ~volume:1000
      ~active_through:_sample_date ()
  in
  let bar2 =
    Daily_price.make ~date:_sample_date ~open_price:100.0 ~high_price:105.0
      ~low_price:98.0 ~close_price:103.0 ~adjusted_close:103.0 ~volume:1000
      ~active_through:_sample_date ()
  in
  assert_that (Daily_price.equal bar1 bar2) (equal_to true)

let suite =
  "Daily_price tests"
  >::: [
         "test_make_defaults_active_through_to_none"
         >:: test_make_defaults_active_through_to_none;
         "test_make_threads_active_through" >:: test_make_threads_active_through;
         "test_equality_respects_active_through"
         >:: test_equality_respects_active_through;
         "test_equality_holds_for_identical_records"
         >:: test_equality_holds_for_identical_records;
       ]

let () = run_test_tt_main suite
