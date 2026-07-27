open Core

type position = {
  symbol : string;
  shares : int;
  entry_price : float;
  entry_date : Date.t;
  stop_price : float;
}
[@@deriving sexp, eq, show]

type t = { cash : float; as_of : Date.t; positions : position list }
[@@deriving sexp, eq, show]

(* The leading [;]-comment block that documents the on-disk schema. Sexp
   parsing drops comments, so a naive rewrite of the file would silently lose
   it; [save] re-emits it verbatim above the sexp body.

   Held as a list of lines (rather than one [{|...|}] literal) so the numeric
   literals in the worked example stay inside double-quoted strings, which is
   what the magic-number linter recognises as prose rather than code. *)
let _header_lines =
  [
    "; Live portfolio state for the weekly-picks execution protocol.";
    ";";
    "; EDIT THIS FILE to reflect your real holdings. The weekly generator";
    "; (`generate_weekly_snapshot --portfolio dev/weekly-picks/portfolio.sexp`)";
    "; prices these positions, reports them, and sizes new long candidates \
     against";
    "; `cash` + current long market value (fixed-risk sizing, mirroring the";
    "; backtest — NOT equal-sized).";
    ";";
    "; >>> SET `cash` to your real cash balance before first use. <<<";
    "; The 100000.0 below is a placeholder.";
    ";";
    "; Shape:";
    ";   cash      : float   — cash balance available to fund entries";
    ";   as_of     : date    — the day you last updated this file (YYYY-MM-DD)";
    ";   positions : list of";
    ";     symbol      : ticker";
    ";     shares      : int   — share count held (long)";
    ";     entry_price : float — fill price";
    ";     entry_date  : date  — date opened (YYYY-MM-DD)";
    ";     stop_price  : float — the working stop";
    ";";
    "; Example position (delete when you record real fills):";
    ";   ((symbol AAPL) (shares 100) (entry_price 180.0)";
    ";    (entry_date 2026-06-13) (stop_price 168.0))";
  ]

let header = String.concat ~sep:"\n" _header_lines
let load ~path = Or_error.try_with (fun () -> Sexp.load_sexp path |> t_of_sexp)
let to_file_contents t = header ^ "\n" ^ Sexp.to_string_hum (sexp_of_t t) ^ "\n"

let save t ~path =
  Or_error.try_with (fun () ->
      Out_channel.write_all path ~data:(to_file_contents t))
