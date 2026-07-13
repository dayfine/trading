(** CLI for the post-run trade validator (v1, report-only).

    Parses a completed scenario run's artifacts + the bar store, runs the 11
    invariant / expectation checks, and writes [<out>.sexp] + [<out>.md]. Exit
    code is always 0 — the verdicts live in the report. *)

open Core
module Vt = Post_run_validator.Validator_types
module Vr = Post_run_validator.Validator_report

let _summary_line (r : Vt.check_result) =
  let sev =
    match r.severity with Vt.Invariant -> "INV" | Vt.Expectation -> "EXP"
  in
  if r.passed then sprintf "%s %s PASS" r.id sev
  else sprintf "%s %s %d violations" r.id sev r.n_violations

let _run ~run_dir ~data_dir ~config_path ~out =
  let config = Vt.load_config config_path in
  let report = Vr.run ~run_dir ~data_dir ~config ~out in
  List.iter report.checks ~f:(fun r -> printf "%s\n" (_summary_line r));
  printf "audit join: %d/%d rows matched\n" report.audit_join.matched
    report.audit_join.total;
  printf "wrote %s.sexp + %s.md\n" out out

let command =
  Command.basic ~summary:"Post-run trade validator (report-only)"
    (let%map_open.Command run_dir =
       flag "-run-dir" (required string)
         ~doc:"DIR scenario output dir (trades.csv, trade_audit.sexp, ...)"
     and data_dir =
       flag "-data-dir" (required string) ~doc:"DIR per-symbol CSV bar store"
     and config_path =
       flag "-config" (optional string)
         ~doc:"PATH validator thresholds sexp (defaults when omitted)"
     and out =
       flag "-out" (required string)
         ~doc:"PREFIX report path prefix; writes <out>.sexp + <out>.md"
     in
     fun () -> _run ~run_dir ~data_dir ~config_path ~out)

let () = Command_unix.run command
