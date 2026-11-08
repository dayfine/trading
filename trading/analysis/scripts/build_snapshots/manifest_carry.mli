(** Carry-forward of untouched pre-run manifest entries (#2669), extracted from
    {!Build_runner}. *)

val carried_entries :
  existing:Snapshot_pipeline.Snapshot_manifest.t option ->
  schema:Data_panel_snapshot.Snapshot_schema.t ->
  excluded:Core.Set.M(Core.String).t ->
  output_dir:string ->
  Snapshot_pipeline.Snapshot_manifest.file_metadata list ->
  Snapshot_pipeline.Snapshot_manifest.file_metadata list
(** Pre-run manifest entries for symbols this run did not produce. Dropped: a
    symbol this run produced (its fresh entry wins), one whose [.snap] is gone
    from [output_dir] (resolved by
    [Snapshot_pipeline.Snapshot_manifest.resolve_path], so a warehouse copied
    from where it was built still carries its entries, #3535), and one in
    [excluded] (a twin leg the rename-twin pass dropped, #2730). Entries from a
    different schema are never carried. *)

val log_carry_forward :
  Snapshot_pipeline.Snapshot_manifest.file_metadata list -> unit
(** Warn when the carry set is non-empty (the run's universe was not a superset
    of the warehouse). *)
