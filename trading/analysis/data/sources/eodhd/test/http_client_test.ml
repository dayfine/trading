open! Base
open Core

let%expect_test "make historical price API URL without dates" =
  let today = Date.create_exn ~y:2021 ~m:Month.Jan ~d:1 in
  let s =
    { symbol = "GOOG"; start_date = None; end_date = None }
    |> Eodhd.Http_client.to_uri ~testonly_today:(Some today)
    |> Uri.to_string
  in
  Stdio.print_endline s;
  [%expect
    {| https://eodhd.com/api/eod/GOOG?to=2021-01-01&fmt=csv&period=d&order=a |}]

let%expect_test "make historical price API URL with start date" =
  let today = Date.create_exn ~y:2023 ~m:Month.Jan ~d:1 in
  let start_date = Some (Date.create_exn ~y:2022 ~m:Month.Dec ~d:1) in
  let s =
    { symbol = "GOOG"; start_date; end_date = None }
    |> Eodhd.Http_client.to_uri ~testonly_today:(Some today)
    |> Uri.to_string
  in
  Stdio.print_endline s;
  [%expect
    {| https://eodhd.com/api/eod/GOOG?to=2023-01-01&from=2022-12-01&fmt=csv&period=d&order=a |}]

let%expect_test "make historical price API URL with end date" =
  let end_date = Some (Date.create_exn ~y:2022 ~m:Month.Dec ~d:1) in
  let s =
    { symbol = "GOOG"; start_date = None; end_date }
    |> Eodhd.Http_client.to_uri |> Uri.to_string
  in
  Stdio.print_endline s;
  [%expect
    {| https://eodhd.com/api/eod/GOOG?to=2022-12-01&fmt=csv&period=d&order=a |}]
