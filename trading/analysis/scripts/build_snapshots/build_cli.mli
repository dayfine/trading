(** Shared CLI params, default constants and the warehouse exceptions loader of
    the snapshot builders, extracted from {!Build_runner} (which re-exports
    them; see its [.mli] for the full contracts). *)

val default_survivor_tolerance_days : int
val default_exceptions_path : string
val survivor_tolerance_param : int Core.Command.Param.t

val tail_params :
  (Snapshot_pipeline.Series_tail.Config.t * string option) Core.Command.Param.t

val load_tail_exceptions :
  string option -> Snapshot_pipeline.Series_tail.Exceptions.t Status.status_or

val load_splice_exceptions :
  string option -> Snapshot_pipeline.Series_splice.Exceptions.t Status.status_or

val tail_exceptions_or_exit :
  string option -> Snapshot_pipeline.Series_tail.Exceptions.t

val splice_exceptions_or_exit :
  string option -> Snapshot_pipeline.Series_splice.Exceptions.t
