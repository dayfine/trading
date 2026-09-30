(** CLI for the post-run trade validator (v1, report-only).

    Parses a completed scenario run's artifacts + the bar store, runs the
    invariant / expectation checks ([Validator_checks.all_check_ids]), and
    writes [<out>.sexp] + [<out>.md]. Exit code is always 0 — the verdicts live
    in the report. *)

open Core
module Vt = Post_run_validator.Validator_types
module Vr = Post_run_validator.Validator_report
module Tw = Post_run_validator.Validator_twin_check

let _summary_line (r : Vt.check_result) =
  let sev =
    match r.severity with Vt.Invariant -> "INV" | Vt.Expectation -> "EXP"
  in
  let verdict =
    if r.passed then sprintf "%s %s PASS" r.id sev
    else sprintf "%s %s %d violations" r.id sev r.n_violations
  in
  match r.skip_reason with
  | Some reason when r.n_skipped > 0 ->
      sprintf "%s (%d skipped: %s)" verdict r.n_skipped reason
  | _ -> verdict

(* The issuer map is resolved independently of the bar store (issue #3045):
   [-share-classes], else [$TRADING_DATA_DIR], else [-data-dir]. *)
let _share_class_path ~explicit ~data_dir =
  Tw.resolve_share_class_path ~explicit
    ~trading_data_dir:(Sys.getenv "TRADING_DATA_DIR")
    ~data_dir

let _run ~run_dir ~data_dir ~share_classes ~config_path ~out =
  let config = Vt.load_config config_path in
  let share_class_path = _share_class_path ~explicit:share_classes ~data_dir in
  printf "share-class map (V6): %s\n" share_class_path;
  let report = Vr.run ~share_class_path ~run_dir ~data_dir ~config ~out () in
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
     and share_classes =
       flag "-share-classes" (optional string)
         ~doc:
           "PATH V6 issuer map (default: $TRADING_DATA_DIR/share_classes.sexp \
            if TRADING_DATA_DIR is set, else <data-dir>/share_classes.sexp)"
     and config_path =
       flag "-config" (optional string)
         ~doc:"PATH validator thresholds sexp (defaults when omitted)"
     and out =
       flag "-out" (required string)
         ~doc:"PREFIX report path prefix; writes <out>.sexp + <out>.md"
     in
     fun () -> _run ~run_dir ~data_dir ~share_classes ~config_path ~out)

let () = Command_unix.run command
