open Core
module Snapshot_validator = Weinstein_snapshot.Snapshot_validator

type outcome = { report : string; exit_code : int } [@@deriving sexp, eq, show]

let _delim = "==================== snapshot-validator ===================="

let _is_error (f : Snapshot_validator.finding) =
  match f.level with Snapshot_validator.Error -> true | Warning -> false

(* One-line verdict appended after the finding block, so a human reading stderr
   knows whether the run failed and how to change that. *)
let _verdict ~strict =
  if strict then
    "snapshot-validator: -validate-strict set — failing the run (exit 1).\n"
  else
    "snapshot-validator: warn-first (exit 0). Re-run with -validate-strict to \
     fail on findings.\n"

let _summary_line findings =
  let total = List.length findings in
  let errors = List.count findings ~f:_is_error in
  Printf.sprintf "%d finding(s): %d error(s), %d warning(s)\n" total errors
    (total - errors)

let _findings_report ~strict findings =
  String.concat
    [
      _delim;
      "\n";
      _summary_line findings;
      Snapshot_validator.to_report findings;
      _delim;
      "\n";
      _verdict ~strict;
    ]

let evaluate ~strict findings =
  match findings with
  | [] -> { report = "snapshot-validator: OK — no findings.\n"; exit_code = 0 }
  | _ ->
      {
        report = _findings_report ~strict findings;
        exit_code = (if strict then 1 else 0);
      }
