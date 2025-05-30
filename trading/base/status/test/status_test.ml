open Alcotest
open Status

let test_create () =
  let status = { code = Invalid_argument; message = "test message" } in
  check string "message" "test message" status.message;
  check bool "is_error" true (is_error status);
  check string "show"
    "{ Status.code = Status.Invalid_argument; message = \"test message\" }"
    (show status)

let test_is_ok () =
  let ok_status = { code = Ok; message = "success" } in
  let error_status = { code = Invalid_argument; message = "error" } in
  check bool "ok is_ok" true (is_ok ok_status);
  check bool "error is_ok" false (is_ok error_status);
  check bool "eq" true (equal ok_status ok_status);
  check bool "neq" false (equal ok_status error_status)

let test_is_error () =
  let ok_status = { code = Ok; message = "success" } in
  let error_status = { code = Invalid_argument; message = "error" } in
  check bool "ok is_error" false (is_error ok_status);
  check bool "error is_error" true (is_error error_status)

let test_code_show () =
  let ok_status = { code = Ok; message = "ok" } in
  let invalid_status = { code = Invalid_argument; message = "invalid" } in
  check string "show Ok" "Status.Ok" (Status.show_code ok_status.code);
  check string "show Invalid_argument" "Status.Invalid_argument"
    (Status.show_code invalid_status.code)

let () =
  run "Status"
    [
      ("create", [ test_case "create" `Quick test_create ]);
      ("is_ok", [ test_case "is_ok" `Quick test_is_ok ]);
      ("is_error", [ test_case "is_error" `Quick test_is_error ]);
      ("code_show", [ test_case "code_show" `Quick test_code_show ]);
    ]
