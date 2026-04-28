(** Trade-audit report CLI — render a markdown audit of a single scenario.

    Usage:
    {v trade_audit_report --scenario-dir <dir> [--out <path>] v}

    [--scenario-dir] points at a directory of the shape produced by
    {!Backtest.Result_writer.write}:

    {v
      <dir>/trades.csv          — round-trip P&L (required)
      <dir>/trade_audit.sexp    — Trade_audit.audit_record list (optional)
      <dir>/summary.sexp        — period + universe size (optional)
    v}

    Reads those files via {!Trade_audit_report.load}, renders to markdown via
    {!Trade_audit_report.to_markdown}, and writes to [--out] (when given) or
    prints to stdout (when omitted). The exe never reads from a network or
    invokes the backtest runner — it only reformats already-on- disk artefacts.
*)

open Core

type _cli_args = { scenario_dir : string; out : string option }

let _usage () =
  eprintf "Usage: trade_audit_report --scenario-dir <dir> [--out <path>]\n";
  Stdlib.exit 1

let _parse_flags args =
  let rec loop args scenario_dir out =
    match args with
    | [] ->
        let scenario_dir =
          match scenario_dir with Some v -> v | None -> _usage ()
        in
        { scenario_dir; out }
    | "--scenario-dir" :: v :: rest -> loop rest (Some v) out
    | "--out" :: v :: rest -> loop rest scenario_dir (Some v)
    | _ -> _usage ()
  in
  loop args None None

let _parse_args () =
  let argv = Sys.get_argv () in
  _parse_flags (List.tl_exn (Array.to_list argv))

let _emit ~out md =
  match out with
  | None -> print_string md
  | Some path ->
      Out_channel.with_file path ~f:(fun oc -> Out_channel.output_string oc md)

let () =
  let { scenario_dir; out } = _parse_args () in
  let report = Trade_audit_report.load ~scenario_dir in
  let md = Trade_audit_report.to_markdown report in
  _emit ~out md
