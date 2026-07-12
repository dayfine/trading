open Core
open Validator_types

let _severity_label = function
  | Invariant -> "INVARIANT"
  | Expectation -> "EXPECTATION"

let _verdict (r : check_result) =
  if r.passed then "PASS" else sprintf "%d violations" r.n_violations

let _base_line (r : check_result) =
  let head =
    sprintf "%s %s %s" r.id (_severity_label r.severity) (_verdict r)
  in
  if r.n_skipped > 0 then sprintf "%s (%d skipped)" head r.n_skipped else head

let _specimen_line (s : specimen) =
  sprintf "    %s %s %s" s.symbol s.entry_date s.detail

let _check_line (r : check_result) =
  let rows = List.map r.specimens ~f:_specimen_line in
  String.concat ~sep:"\n" (_base_line r :: rows)

let _failing_invariants report =
  List.count report.checks ~f:(fun c ->
      (not c.passed) && equal_severity c.severity Invariant)

let render_md report =
  let header =
    sprintf "# Post-run validation report\n\nInvariant checks failing: %d\n\n"
      (_failing_invariants report)
  in
  let body = List.map report.checks ~f:_check_line |> String.concat ~sep:"\n" in
  header ^ body ^ "\n"

let _infer_run_end trades =
  List.map trades ~f:(fun (t : trade_row) -> t.exit_date)
  |> List.max_elt ~compare:Date.compare
  |> Option.value ~default:far_future

let _maybe_audit path =
  if Sys_unix.file_exists_exn path then
    Validator_artifacts.load_audit_lookup path
  else fun _ -> None

let _maybe_open path =
  if Sys_unix.file_exists_exn path then
    Validator_artifacts.parse_open_positions_csv path
  else []

let run ~run_dir ~data_dir ~config ~out =
  let trades = Validator_artifacts.parse_trades_csv (run_dir ^ "/trades.csv") in
  let open_positions = _maybe_open (run_dir ^ "/open_positions.csv") in
  let audit = _maybe_audit (run_dir ^ "/trade_audit.sexp") in
  let run_end = _infer_run_end trades in
  let bars = Validator_artifacts.load_bars ~data_dir ~run_end in
  let inputs = { trades; open_positions; audit; bars; run_end; config } in
  let report = Validator_checks.validate inputs in
  Sexp.save_hum (out ^ ".sexp") (sexp_of_report report);
  Out_channel.write_all (out ^ ".md") ~data:(render_md report);
  report
