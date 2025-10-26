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
  let printer = Float.to_string in
  assert_equal expected actual ~cmp ~printer ~msg

let assert_some_with ~msg option ~f =
  match option with Some value -> f value | None -> assert_failure msg

let assert_some ~msg option =
  match option with Some value -> value | None -> assert_failure msg

let assert_none ~msg option =
  match option with Some _ -> assert_failure msg | None -> () (* Expected *)
