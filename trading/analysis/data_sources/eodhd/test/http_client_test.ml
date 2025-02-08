open! Base

let%expect_test "trivial" =
  let s =
    Eodhd.Http_client.Params.make ~symbol:"GOOG"
    |> Eodhd.Http_client.Params.to_uri |> Uri.to_string
    |> Uri.pct_decode
  in
  Stdio.print_endline s;
  [%expect {| https://https://eodhd.com/api/eod//GOOG?fmt=csv&period=d&order=a |}]
