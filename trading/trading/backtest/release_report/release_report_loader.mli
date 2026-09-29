(** On-disk artefact loading for [Release_report]: reads one scenario
    directory's [actual.sexp], [summary.sexp], optional RSS / wall-time files
    and the optional trade-audit / optimal-strategy / all-eligible artefacts. *)

val load_scenario_run : dir:string -> Release_report_types.scenario_run
(** Load one scenario directory. Raises [Failure] if [actual.sexp] or
    [summary.sexp] is missing; auxiliary artefacts degrade to [None]. *)
