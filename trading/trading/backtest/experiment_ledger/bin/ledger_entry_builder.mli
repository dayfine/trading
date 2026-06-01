(** Pure mapping from a walk-forward aggregate to an {!Experiment_ledger.entry}.

    Hoisted out of [write_ledger_entry.ml] so the entry-construction path is
    unit -testable without invoking the process or touching disk. The CLI is a
    thin flag-parsing wrapper around {!build_entry}.

    The aggregate ({!Walk_forward.Walk_forward_types.aggregate}) carries each
    variant's label plus its cross-fold metric means, but NOT its config-hash
    (the hash is a function of the variant's override blob, which the aggregate
    does not record). The caller therefore supplies a [config_hash_for] lookup —
    typically built from the same [Variant_matrix] spec that produced the run
    (see {!hash_map_of_variants}) — so the recorded hashes line up with the
    ledger's dedup key. *)

open Core

type metadata = {
  date : string;
  slug : string;
  hypothesis : string;
  base_scenario : string;
  window_id : string;
  baseline_label : string;
  verdict : Experiment_ledger.verdict;
  notes : string;
}
(** The scalar (non-variant) entry fields the CLI collects from flags. Bundled
    so {!build_entry} keeps a small, stable signature as fields are added. *)

val hash_map_of_variants :
  (string * Sexp.t list) list -> (string, string) Hashtbl.t
(** [hash_map_of_variants pairs] maps each [(label, overrides)] to
    [label -> Experiment_ledger.config_hash overrides]. Built once from a
    [Spec.load]ed walk-forward spec's [variants] so per-variant hashes match the
    ledger's dedup key. Raises [Failure] (via [config_hash]) if any override
    blob fails to resolve against the canonical default config. *)

val build_entry :
  metadata:metadata ->
  config_hash_for:(string -> string) ->
  Walk_forward.Walk_forward_types.aggregate ->
  Experiment_ledger.entry
(** [build_entry ~metadata ~config_hash_for aggregate] maps each variant in
    [aggregate.stability] to an {!Experiment_ledger.variant_record}:

    - [label] = the variant's [variant_label];
    - [config_hash] = [config_hash_for label], or [""] when [config_hash_for]
      has no mapping for the label (e.g. no spec was supplied);
    - [aggregate] = [Some] of the four cross-fold metric means
      ([sharpe_ratio.mean], [calmar_ratio.mean], [total_return_pct.mean],
      [max_drawdown_pct.mean]) when all four are finite, else [None] — a
      degenerate fixture with NaN means records [None] rather than fabricating a
      value, per {!Experiment_ledger.variant_record}'s documented contract.

    The variant order is preserved from [aggregate.stability]. *)
