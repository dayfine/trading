open Ta_ocaml.Ta

let print_result result =
  print_endline
    (match result with
    | Ok arr ->
        Printf.sprintf "Ok %s"
          (Array.to_list arr |> List.map string_of_float |> String.concat "; "
         |> Printf.sprintf "[|%s|]")
    | Error msg -> Printf.sprintf "Error %S" msg)

let%expect_test "Simplest SMA" =
  let data = [| 10.0; 12.0 |] in
  let period = 2 in
  let result = sma data period in
  print_result result;
  [%expect {| Ok [|11.|] |}]

let%expect_test "SMA with valid data" =
  let data = [| 10.0; 12.0; 11.0; 13.0; 14.0; 13.0; 15.0; 16.0; 15.0; 17.0 |] in
  let period = 3 in
  let result = sma data period in
  print_result result;
  [%expect {| Ok [|11.; 12.; 12.67; 13.33; 14.; 14.67; 15.33; 16.|] |}]

let%expect_test "SMA with insufficient data" =
  let data = [| 10.0; 12.0 |] in
  let period = 3 in
  let result = sma data period in
  print_result result;
  [%expect {|
    Error "Not enough data: need at least 3 elements, got 2"
  |}]

let%expect_test "EMA with valid data" =
  let data = [| 10.0; 12.0; 11.0; 13.0; 14.0; 13.0; 15.0; 16.0; 15.0; 17.0 |] in
  let period = 3 in
  let result = ema data period in
  print_result result;
  [%expect {| Ok [|11.; 12.; 13.; 13.; 14.; 15.; 15.; 16.|] |}]

let%expect_test "RSI with valid data" =
  let data = [| 10.0; 12.0; 11.0; 13.0; 14.0; 13.0; 15.0; 16.0; 15.0; 17.0 |] in
  let period = 3 in
  let result = rsi data period in
  print_result result;
  [%expect {| Ok [|80.; 84.62; 62.86; 79.03; 84.19; 61.49; 78.71|] |}]
