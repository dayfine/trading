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

let test_combine_status_list_all_ok _ =
  let status_list = [ Result.Ok (); Result.Ok (); Result.Ok () ] in
  match combine_status_list status_list with
  | Result.Ok () -> ()
  | Result.Error _ -> assert_failure "Expected Ok when all statuses are Ok"

let test_combine_status_list_single_error _ =
  let status_list =
    [
      Result.Ok ();
      Result.Error (invalid_argument_error "first error");
      Result.Ok ();
    ]
  in
  match combine_status_list status_list with
  | Result.Ok () -> assert_failure "Expected Error when one status is Error"
  | Result.Error status ->
      assert_equal Invalid_argument status.code;
      assert_equal "first error" status.message

let test_combine_status_list_multiple_errors _ =
  let status_list =
    [
      Result.Error (invalid_argument_error "first error");
      Result.Ok ();
      Result.Error (internal_error "second error");
    ]
  in
  match combine_status_list status_list with
  | Result.Ok () ->
      assert_failure "Expected Error when multiple statuses are Error"
  | Result.Error status ->
      assert_equal Invalid_argument status.code;
      assert_equal "first error; second error" status.message

let test_combine_status_list_empty _ =
  let status_list = [] in
  match combine_status_list status_list with
  | Result.Ok () -> ()
  | Result.Error _ -> assert_failure "Expected Ok for empty list"

let suite =
  "Status"
  >::: [
         "create" >:: test_create;
         "is_ok" >:: test_is_ok;
         "is_error" >:: test_is_error;
         "code_show" >:: test_code_show;
         "combine_status_list_all_ok" >:: test_combine_status_list_all_ok;
         "combine_status_list_single_error"
         >:: test_combine_status_list_single_error;
         "combine_status_list_multiple_errors"
         >:: test_combine_status_list_multiple_errors;
         "combine_status_list_empty" >:: test_combine_status_list_empty;
       ]

let () = run_test_tt_main suite
