open Alcotest
open Status

let test_create () =
  let status = create Invalid_argument "test message" in
  check string "message" "test message" status.message;
  check bool "is_error" true (is_error status);
  check string "show" "{ Status.code = Status.Invalid_argument; message = \"test message\" }" (show status)

let test_to_string () =
  let status = create Invalid_argument "test message" in
  check string "to_string" "INVALID_ARGUMENT: test message" (to_string status)

let test_is_ok () =
  let ok_status = create Ok "success" in
  let error_status = create Invalid_argument "error" in
  check bool "ok is_ok" true (is_ok ok_status);
  check bool "error is_ok" false (is_ok error_status);
  check bool "eq" true (equal ok_status ok_status);
  check bool "neq" false (equal ok_status error_status)

let test_is_error () =
  let ok_status = create Ok "success" in
  let error_status = create Invalid_argument "error" in
  check bool "ok is_error" false (is_error ok_status);
  check bool "error is_error" true (is_error error_status)

let test_code_show () =
  let ok_status = create Ok "ok" in
  let invalid_status = create Invalid_argument "invalid" in
  check string "show Ok" "Status.Ok" (Status.show_code ok_status.code);
  check string "show Invalid_argument" "Status.Invalid_argument" (Status.show_code invalid_status.code)

let () =
  run "Status" [
    "create", [
      test_case "create" `Quick test_create;
    ];
    "to_string", [
      test_case "to_string" `Quick test_to_string;
    ];
    "is_ok", [
      test_case "is_ok" `Quick test_is_ok;
    ];
    "is_error", [
      test_case "is_error" `Quick test_is_error;
    ];
    "code_show", [
      test_case "code_show" `Quick test_code_show;
    ];
  ]
