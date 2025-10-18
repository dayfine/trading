open Core
open OUnit2

let assert_ok_with ~msg result ~f =
  match result with
  | Ok value -> f value
  | Error err -> assert_failure (msg ^ ": " ^ Status.show err)

let assert_error ~msg result =
  match result with Ok _ -> assert_failure msg | Error _ -> () (* Expected *)

let assert_ok ~msg result =
  match result with
  | Ok value -> value
  | Error err -> assert_failure (msg ^ ": " ^ Status.show err)

let assert_float_equal ?(epsilon = 1e-9) expected actual ~msg =
  let cmp a b = Float.(abs (a - b) < epsilon) in
  assert_equal expected actual ~cmp ~msg
