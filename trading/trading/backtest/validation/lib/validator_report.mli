(** Report rendering + end-to-end run orchestration. *)

open Validator_types

val render_md : report -> string
(** Render [report] as the human [.md]: one line per check plus up to 10
    specimen rows under each violated check. *)

val run :
  run_dir:string ->
  data_dir:string ->
  config:check_config ->
  out:string ->
  report
(** Parse [run_dir]'s artifacts, load bars from [data_dir], run {!validate}, and
    write [<out>.sexp] + [<out>.md]. Returns the report. Read-only w.r.t. the
    run; exit code semantics are the caller's (v1 is report-only). *)
