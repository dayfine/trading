(** CLI: fetch + parse + persist the Shiller monthly S&P composite series.

    Usage:
    {v
      dune exec analysis/data/sources/shiller/bin/fetch_shiller_history.exe -- \
        -out dev/data/shiller/shiller-monthly-YYYYMMDD.csv
    v}

    Behaviour:
    - HTTP-GETs the canonical mirror URI ({!Shiller.Shiller_client.source_uri})
      via system [curl] ({!Shiller_curl_fetch.fetch}).
    - Parses the body through {!Shiller.Shiller_client.parse} (so any upstream
      schema drift fails loudly here, before the data is persisted).
    - Writes the parsed series as a stable CSV under the operator-supplied
      output path: 6 columns ([period,sp_price,dividend,earnings,cpi,long_rate])
      with sentinel-derived [None] options emitted as empty cells.

    The output CSV is purely derived from the parsed series — round-tripping
    through the parser strips the four redundant computed columns (Real Price /
    Real Dividend / Real Earnings / PE10) which downstream code can re-derive
    deterministically.

    Cache layout (caller-controlled): the priorities doc requests
    [dev/data/shiller/shiller-monthly-YYYYMMDD.csv]; the CLI does not enforce
    this — the [-out] flag accepts any path so operators can stage to [/tmp/]
    for probes. *)

open! Core
open Async
module Client = Shiller.Shiller_client

let _option_float_to_csv = function None -> "" | Some f -> Float.to_string f

let _row_to_csv (o : Client.monthly_observation) : string =
  Printf.sprintf "%s,%s,%s,%s,%s,%s" (Date.to_string o.period)
    (Float.to_string o.sp_price)
    (_option_float_to_csv o.dividend)
    (_option_float_to_csv o.earnings)
    (_option_float_to_csv o.cpi)
    (_option_float_to_csv o.long_rate)

let _output_header = "period,sp_price,dividend,earnings,cpi,long_rate"

let _write_series ~out_path (series : Client.series) : unit =
  let lines = _output_header :: List.map series.observations ~f:_row_to_csv in
  Out_channel.write_lines out_path lines

(* The Or_error error path here is operator-facing: we want a clean exit-1
   with the underlying message on the stderr, not a stack trace. *)
let _exit_with_error msg =
  eprintf "fetch_shiller_history: %s\n" msg;
  Stdlib.exit 1

let _print_summary ~out_path (series : Client.series) : unit =
  let n = List.length series.observations in
  let first_date, last_date =
    match (List.hd series.observations, List.last series.observations) with
    | Some a, Some b -> (Date.to_string a.period, Date.to_string b.period)
    | _ -> ("(empty)", "(empty)")
  in
  printf
    "fetch_shiller_history: wrote %d observations to %s (first %s, last %s)\n" n
    out_path first_date last_date

let _handle_body ~out_path body : unit =
  match Client.parse body with
  | Error status -> _exit_with_error ("parse failed: " ^ Status.show status)
  | Ok series ->
      _write_series ~out_path series;
      _print_summary ~out_path series

let _run ~out_path : unit Deferred.t =
  Shiller_curl_fetch.fetch Client.source_uri >>| function
  | Error err -> _exit_with_error ("fetch failed: " ^ Error.to_string_hum err)
  | Ok body -> _handle_body ~out_path body

let command =
  Command.async
    ~summary:
      "Fetch the Shiller monthly S&P composite series from the \
       datasets/s-and-p-500 mirror and write a canonical CSV."
    (let%map_open.Command out_path =
       flag "-out" (required string)
         ~doc:"PATH output CSV path (will be overwritten)"
     in
     fun () -> _run ~out_path)

let () = Command_unix.run command
