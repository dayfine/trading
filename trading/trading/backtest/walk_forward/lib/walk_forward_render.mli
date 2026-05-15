(** Pure markdown renderer for a {!Walk_forward_types.aggregate} + the raw
    per-(fold, variant) measurements that produced it.

    Split out of {!Walk_forward_report} only to keep that module under the
    repo's file-length limit; the public entry point is
    {!Walk_forward_report.render} which delegates to this module. *)

val to_markdown :
  gate:Fold_gate.t ->
  fold_actuals:Walk_forward_types.fold_actual list ->
  Walk_forward_types.aggregate ->
  string
(** [to_markdown ~gate ~fold_actuals agg] returns the four-section markdown
    report: per-fold metrics, stability, cross-fold sensitivity, go/no-go
    verdict. Deterministic — same inputs produce byte-identical output. *)
