(** Loads a symbol's full weekly OHLCV history for the blind-judge harness,
    preferring the snapshot warehouse's [.snap] daily columns and falling back
    to the CSV store. Both paths converge on
    {!Time_period.Conversion.daily_to_weekly} for the daily -> weekly fold, so
    the aggregation semantics (open = first trading day of the week, high = week
    max, low = week min, close = last trading day, volume = week sum) are
    exactly the ones the rest of the codebase already relies on
    ({!Snapshot_pipeline.Weekly_sidetable_builder}, [Bar_reader]) -- this module
    does not invent a second aggregation. *)

(** Which store actually served the bars. Operator-facing metadata only -- never
    surfaced to the judge (see {!Table_format.render}, which has no parameter
    for it). Exists so a cohort run can confirm every case in a comparison was
    built from the same store; a cohort silently mixing warehouse and CSV bars
    for different symbols is a comparability failure the harness cannot afford
    (different history depth, potentially a different price basis). *)
type source =
  | Warehouse  (** Served from [<warehouse_dir>/<symbol>.snap]. *)
  | Csv
      (** Served from the CSV store, either as the only source configured or as
          the warehouse fallback. *)

val load_daily :
  symbol:string ->
  warehouse_dir:string option ->
  csv_data_dir:string option ->
  (Types.Daily_price.t list * source) Status.status_or
(** [load_daily ~symbol ~warehouse_dir ~csv_data_dir] returns [symbol]'s full
    daily bar history (chronologically ascending, oldest first) paired with
    which store served it.

    - [warehouse_dir = Some dir]: reads [<dir>/<symbol>.snap] via
      {!Data_panel_snapshot.Snapshot_columnar} and reconstitutes raw OHLCV +
      [Adjusted_close] from the snap's columns (same field mapping as
      {!Sidetable_migrator}'s [_bar_of_row]). Returns [Warehouse] on success.
    - Falls back to [csv_data_dir = Some dir] (the {!Csv.Csv_storage} layout,
      returns [Csv]) when [warehouse_dir] is [None], or the [.snap] file is
      absent, or reading it errors.
    - [Error Not_found] when neither source yields data for [symbol] (both
      [None], or both present but empty/unreadable). *)

val load_weekly :
  symbol:string ->
  warehouse_dir:string option ->
  csv_data_dir:string option ->
  (Types.Daily_price.t list * source) Status.status_or
(** [load_weekly] is {!load_daily} folded through
    {!Time_period.Conversion.daily_to_weekly} [~include_partial_week:true] --
    the full weekly series, chronologically ascending, oldest first, trailing
    entry possibly a partial (in-progress) week -- paired with the same
    {!source} {!load_daily} returned.

    @raise Invalid_argument
      if the daily bars from either source are not sorted chronologically
      ({!Time_period.Conversion.daily_to_weekly}'s own precondition) -- this
      surfaces as a raised exception rather than a {!Status.status_or} error,
      since [load_daily] does not itself validate ordering. *)
