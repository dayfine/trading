(** Report rendering + end-to-end run orchestration. *)

open Validator_types

val quality_flag_line : report -> string option
(** [Some "QUALITY-FLAG: <n> fallback exits (V16)"] when V16 found any round
    trip closed by a fallback safety net, else [None].

    Zero is the target — a clean run prints nothing at all, so the line's mere
    presence in a log is the signal. See {!Validator_fallback_check} for why
    each such row is a worklist item rather than a strategy result, and note it
    counts V16 only: V17's stale-entry findings are a different defect class and
    are read off the report body. *)

val render_md : report -> string
(** Render [report] as the human [.md]: one line per check plus up to 10
    specimen rows under each violated check, with {!quality_flag_line} — when
    there is one — between the header and the check lines. *)

val run :
  run_dir:string ->
  data_dir:string ->
  config:check_config ->
  out:string ->
  report
(** Parse [run_dir]'s artifacts, load bars from [data_dir], run {!validate}, and
    write [<out>.sexp] + [<out>.md]. Also prints {!quality_flag_line} to stderr
    when non-empty, so a fallback exit is visible in the run log without opening
    the report. Returns the report. Read-only w.r.t. the run; exit code
    semantics are the caller's (v1 is report-only). *)
