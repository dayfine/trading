open Ta_ocaml.Ta

let print_result result =
  print_endline
    (match result with
    | Ok arr ->
        Printf.sprintf "Ok %s"
          (Array.to_list arr |> List.map string_of_float |> String.concat "; "
         |> Printf.sprintf "[|%s|]")
    | Error msg -> Printf.sprintf "Error %S" msg)

let%expect_test "Simplest SMA where period is equal to input data size" =
  let data = [| 10.0; 12.0; 11.0 |] in
  let period = 2 in
  let result = sma data period in
  print_result result;
  [%expect {|
    Ok [|11.0|]
  |}]

let%expect_test "SMA with valid data" =
  let data = [| 10.0; 12.0; 11.0; 13.0; 14.0; 13.0; 15.0; 16.0; 15.0; 17.0 |] in
  let period = 3 in
  let result = sma data period in
  print_endline
    (match result with
    | Ok arr ->
        Printf.sprintf "Ok %s"
          (Array.to_list arr |> List.map string_of_float |> String.concat "; "
         |> Printf.sprintf "[|%s|]")
    | Error msg -> Printf.sprintf "Error %S" msg);
  [%expect
    {|
    Ok [|11.0; 12.0; 12.67; 13.33; 14.0; 14.67; 15.33; 16.0|]
  |}]

(* Test error case: not enough data *)
let%expect_test "SMA with insufficient data" =
  let data = [| 10.0; 12.0 |] in
  (* Only 2 elements *)
  let period = 3 in
  (* Need 3 elements *)
  let result = sma data period in
  print_endline
    (match result with
    | Ok arr ->
        Printf.sprintf "Ok %s"
          (Array.to_list arr |> List.map string_of_float |> String.concat "; "
         |> Printf.sprintf "[|%s|]")
    | Error msg -> Printf.sprintf "Error %S" msg);
  [%expect {|
    Error "Not enough data: need at least 3 elements, got 2"
  |}]

(* Test Exponential Moving Average *)
let test_ema () =
  let data = [| 10.0; 12.0; 11.0; 13.0; 14.0; 13.0; 15.0; 16.0; 15.0; 17.0 |] in
  let period = 3 in
  Printf.printf "Testing EMA with input data: %s\n"
    (String.concat ", " (Array.to_list data |> List.map string_of_float));

  match ema data period with
  | Ok result ->
      Printf.printf "EMA output: %s\n"
        (String.concat ", " (Array.to_list result |> List.map string_of_float));
      Printf.printf "EMA test passed\n"
  | Error msg -> Printf.printf "EMA test failed with error: %s\n" msg

(* Test Relative Strength Index *)
let test_rsi () =
  let data = [| 10.0; 12.0; 11.0; 13.0; 14.0; 13.0; 15.0; 16.0; 15.0; 17.0 |] in
  let period = 3 in
  Printf.printf "Testing RSI with input data: %s\n"
    (String.concat ", " (Array.to_list data |> List.map string_of_float));

  match rsi data period with
  | Ok result ->
      Printf.printf "RSI output: %s\n"
        (String.concat ", " (Array.to_list result |> List.map string_of_float));
      Printf.printf "RSI test passed\n"
  | Error msg -> Printf.printf "RSI test failed with error: %s\n" msg

(* Run all tests *)
let () =
  Printf.printf "Running technical analysis tests...\n";
  test_ema ();
  test_rsi ();
  Printf.printf "All tests passed!\n"
