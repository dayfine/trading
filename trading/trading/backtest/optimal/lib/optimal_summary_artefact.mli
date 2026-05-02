(** Structured artefact written alongside [optimal_strategy.md] so downstream
    consumers (e.g. {!Release_report}) can read the headline counterfactual
    metrics without parsing markdown.

    The on-disk shape is a record carrying the [Constrained], [Score_picked],
    and [Relaxed_macro] variants of {!Optimal_types.optimal_summary}; every
    field on the markdown headline table is recoverable from this sexp. The
    {!Optimal_strategy_runner} writes one to [<output_dir>/optimal_summary.sexp]
    on every run.

    Pure data — no I/O beyond the {!write} helper. The sexp shape is fixed by
    the [@@deriving sexp] derivation; downstream readers should mirror the
    record locally with [@@sexp.allow_extra_fields] to stay forward-compatible
    with future field additions. *)

type t = {
  constrained : Optimal_types.optimal_summary;
      (** Macro-gated, ordered by realised R-multiple (descending) — the
          outcome-foresight ceiling against the actual run. *)
  score_picked : Optimal_types.optimal_summary;
      (** Macro-gated, ordered by pre-trade [cascade_score] (descending) — the
          honest cascade-ranking comparison. The [Strategy actual] →
          [Score_picked] gap is closeable cascade-ranking error; [Score_picked]
          → [Constrained] is the (uncloseable) outcome-foresight bonus. *)
  relaxed_macro : Optimal_types.optimal_summary;
      (** Macro gate dropped, ordered by realised R-multiple — the unconstrained
          upper bound. *)
}
[@@deriving sexp]
(** The three-variant artefact emitted alongside [optimal_strategy.md]. *)

val write : output_dir:string -> t -> unit
(** [write ~output_dir t] writes [t] to [<output_dir>/optimal_summary.sexp] in
    sexp-of-record form. Logs a one-line stderr message on completion. *)
