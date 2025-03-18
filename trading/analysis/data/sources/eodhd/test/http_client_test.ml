open! Base
open CalendarLib

let%expect_test "make historical price API URL without dates" =
  let today = Date.lmake ~year:2021 ~month:1 ~day:1 () in
  let s =
    { symbol = "GOOG"; start_date = None; end_date = None }
    |> Eodhd.Http_client.to_uri ~testonly_today:(Some today)
    |> Uri.to_string
  in
  Stdio.print_endline s;
  [%expect
    {| https://eodhd.com/api/eod/GOOG?to=2021-01-31&fmt=csv&period=d&order=a |}]

let%expect_test "make historical price API URL with start date" =
  let today = Date.lmake ~year:2023 ~month:1 ~day:1 () in
  let start_date = Some (Date.lmake ~year:2022 ~month:12 ~day:1 ()) in
  let s =
    { symbol = "GOOG"; start_date; end_date = None }
    |> Eodhd.Http_client.to_uri ~testonly_today:(Some today)
    |> Uri.to_string
  in
  Stdio.print_endline s;
  [%expect
    {| https://eodhd.com/api/eod/GOOG?to=2023-01-31&from=2022-12-31&fmt=csv&period=d&order=a |}]

let%expect_test "make historical price API URL with end date" =
  let end_date = Some (Date.lmake ~year:2022 ~month:12 ~day:1 ()) in
  let s =
    { symbol = "GOOG"; start_date = None; end_date }
    |> Eodhd.Http_client.to_uri |> Uri.to_string
  in
  Stdio.print_endline s;
  [%expect
    {| https://eodhd.com/api/eod/GOOG?to=2022-12-31&fmt=csv&period=d&order=a |}]
