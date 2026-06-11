(** Orchestration for the [apply_composition_policy] CLI: load a universe
    snapshot + its symbol-type enrichment, run the composition policy, and write
    the filtered snapshot plus a drop report.

    Split from the executable so the load/apply/write flow is unit-testable
    without spawning a process. See
    [dev/plans/universe-composition-policy-2026-06-11.md] PR-C. *)

type result = {
  input_count : int;  (** Members in the input snapshot. *)
  kept_count : int;  (** Members in the filtered snapshot. *)
  report_text : string;  (** Rendered per-filter drop report. *)
}
[@@deriving show]

val run :
  snapshot_path:string ->
  symbol_types_path:string ->
  config:Universe.Composition_policy_types.config ->
  out_snapshot_path:string ->
  out_report_path:string ->
  result Status.status_or
(** [run ~snapshot_path ~symbol_types_path ~config ~out_snapshot_path
     ~out_report_path] loads the snapshot at [snapshot_path] and the enrichment
    index at [symbol_types_path], converts the snapshot to candidates, applies
    [config] via {!Composition_policy.apply}, writes the filtered snapshot to
    [out_snapshot_path] (same {!Snapshot.t} shape, members reduced to the kept
    set, [size] updated, weights left untouched), writes the rendered report to
    [out_report_path], and returns counts + the report text.

    Returns [Error] if either input fails to load or either output fails to
    write. The dollar-volume-dependent ADR floor is inert here (the snapshot
    carries no per-symbol volume — see
    {!Composition_policy_report.candidates_of_snapshot}). *)
