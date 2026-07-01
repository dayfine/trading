(** [decision_audit] — per-screen faithfulness audit of a backtest's entries.

    Reads a [trade_audit.sexp] (produced by {!Backtest.Result_writer.write}
    alongside [trades.csv]), groups the entry decisions by weekly screen date,
    and for each screen compares the {b funded} entries against the
    {b cash-rejected near-misses} on the captured decision-time features (score,
    grade, stage, weeks_advancing, rs_value, volume_ratio, sector).

    This is a read-only faithfulness lens — it changes no strategy behaviour and
    grades no picks by outcome. It answers: at each screen, do the funded names
    differ from the near-misses on any signal we capture? If none, the tie is
    uninformative and selection is faithful; if one does and we are not funding
    on it, that is a candidate lever. See
    [dev/plans/per-screen-decision-audit-2026-06-30.md].

    Usage:
    {[
      decision_audit --audit <trade_audit.sexp> [--out report.md]
    ]}

    [--audit] is required. [--out], when given, writes the markdown there;
    otherwise it goes to stdout. *)

open Core
module TA = Backtest.Trade_audit
module DA = Decision_audit

let _usage () =
  eprintf "Usage: decision_audit --audit <trade_audit.sexp> [--out report.md]\n";
  Stdlib.exit 1

type _parse_acc = {
  mutable audit_path : string option;
  mutable out_path : string option;
}

let _parse_flag args =
  let acc = { audit_path = None; out_path = None } in
  let rec loop = function
    | [] -> acc
    | "--audit" :: p :: rest ->
        acc.audit_path <- Some p;
        loop rest
    | "--out" :: p :: rest ->
        acc.out_path <- Some p;
        loop rest
    | _ -> _usage ()
  in
  loop args

(** Load the audit records from [path]. Accepts both the combined
    {!TA.audit_blob} envelope and the bare {!TA.audit_records} list, matching
    the loader in [decision_grading_bin]. *)
let _load_audit_records ~path : TA.audit_record list =
  let sexp = Sexp.load_sexp path in
  try (TA.audit_blob_of_sexp sexp).audit_records
  with _ -> TA.audit_records_of_sexp sexp

let () =
  let acc = _parse_flag (List.tl_exn (Array.to_list (Sys.get_argv ()))) in
  let audit_path =
    Option.value_or_thunk acc.audit_path ~default:(fun () ->
        eprintf "--audit is required\n";
        _usage ())
  in
  let records = _load_audit_records ~path:audit_path in
  let screens = DA.Screen_record.of_audit_records records in
  eprintf "decision_audit: %d entries across %d screens from %s\n%!"
    (List.length records) (List.length screens) audit_path;
  let markdown = DA.Report.to_markdown screens in
  match acc.out_path with
  | Some path ->
      Out_channel.write_all path ~data:markdown;
      eprintf "decision_audit: wrote %s\n%!" path
  | None -> print_string markdown
