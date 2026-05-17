(** Internal library for the [cross_validation_runner] executable.

    Owns the cache-CSV → [Cross_validation.report] → on-disk sexp + markdown
    pipeline. Split out from the executable so the orchestration can be
    unit-tested without writing real files to disk.

    The Shiller cache parser is shared with
    {!Build_synthetic_universes_runner_lib.parse_shiller_cache_csv} — both
    runners consume the canonical 6-column cache CSV produced by the
    [fetch_shiller_history] binary. *)

module CV = Universe.Cross_validation

type result = {
  report : CV.report;
  out_sexp_path : string;
  out_markdown_path : string;
}
[@@deriving show]
(** Summary returned by {!run}: the computed [report] together with the two
    output paths the runner wrote (echoed back for log-friendliness). *)

val run :
  composition_dir:string ->
  shiller_cache_body:string ->
  size:int ->
  start_year:int ->
  end_year:int ->
  out_sexp_path:string ->
  out_markdown_path:string ->
  result Status.status_or
(** [run ~composition_dir ~shiller_cache_body ~size ~start_year ~end_year
     ~out_sexp_path ~out_markdown_path] parses the Shiller cache CSV body,
    invokes {!Universe.Cross_validation.compute}, and writes the resulting
    report as sexp + markdown to the two supplied paths.

    Returns [Error _] if the Shiller cache fails to parse, the
    [Cross_validation.compute] call errors (e.g. zero usable cells), or either
    output write fails. Successful runs return the [report] in the [result] so
    the CLI can echo summary stats to stdout without a second sexp parse. *)
