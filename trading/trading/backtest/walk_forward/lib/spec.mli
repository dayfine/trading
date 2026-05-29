(** On-disk spec consumed by [bin/walk_forward_runner.exe]. Hoisted out of the
    binary into the library so test fixtures can be parsed and validated without
    invoking the backtest itself (the binary's surface is otherwise not
    addressable from unit tests). *)

type t = {
  base_scenario : string;
      (** Path (relative to fixtures-root) to a base scenario sexp file. *)
  window_spec : Window_spec.t;
  variants : Walk_forward_runner.variant list;
  baseline_label : string;
  gate : Fold_gate.t;
}
[@@deriving sexp]
(** Top-level spec the binary reads via [Sexp.load_sexp] + [t_of_sexp].

    The underlying record allows extra sexp fields
    ([\@\@sexp.allow_extra_fields]) so spec files may carry metadata that the
    runner does not consume directly (e.g. a [holdout_folds] block used by the
    Bayesian tuner to mark folds excluded from BO scoring — the walk-forward
    runner itself ignores the list). *)

val load : string -> t
(** [load path] parses the spec sexp at [path] and returns the resolved {!t}.

    The on-disk sexp may declare an optional [axes] block (a
    {!Variant_matrix.t}) instead of, or in addition to, hand-written [variants]:

    - If [axes] is present, [t.variants] = the explicit [variants] (if any, kept
      first) followed by the auto-included baseline cell (empty-override,
      labelled [baseline_label]) followed by the expanded matrix
      ({!Variant_matrix.expand}). Expansion validates every generated override
      against the canonical default config, so a typo'd axis key raises
      [Failure] here, at load time.
    - If [axes] is absent, [t.variants] = the hand-written [variants] verbatim —
      100% backward-compatible with pre-matrix spec files.

    Variants are de-duplicated by [label]; a collision (whether between two
    explicit variants, the baseline, or two matrix cells) raises [Failure].

    Raises [Failure] / sexp parse errors per the underlying functions. *)
