open OUnit2
open Status

let test_create _ =
  let status = { code = Invalid_argument; message = "test message" } in
  assert_equal "test message" status.message;
  assert_bool "is_error" (is_error status);
  assert_equal
    "{ Status.code = Status.Invalid_argument; message = \"test message\" }"
    (show status)

let test_is_ok _ =
  let ok_status = { code = Ok; message = "success" } in
  let error_status = { code = Invalid_argument; message = "error" } in
  assert_bool "ok is_ok" (is_ok ok_status);
  assert_bool "error is_ok" (not (is_ok error_status));
  assert_bool "eq" (equal ok_status ok_status);
  assert_bool "neq" (not (equal ok_status error_status))

let test_is_error _ =
  let ok_status = { code = Ok; message = "success" } in
  let error_status = { code = Invalid_argument; message = "error" } in
  assert_bool "ok is_error" (not (is_error ok_status));
  assert_bool "error is_error" (is_error error_status)

let test_code_show _ =
  let ok_status = { code = Ok; message = "ok" } in
  let invalid_status = { code = Invalid_argument; message = "invalid" } in
  assert_equal "Status.Ok" (Status.show_code ok_status.code);
  assert_equal "Status.Invalid_argument" (Status.show_code invalid_status.code)

let suite =
  "Status"
  >::: [
         "create" >:: test_create;
         "is_ok" >:: test_is_ok;
         "is_error" >:: test_is_error;
         "code_show" >:: test_code_show;
       ]

let () = run_test_tt_main suite
