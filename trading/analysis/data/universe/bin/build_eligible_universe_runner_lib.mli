(** Runner core for [build_eligible_universe_runner.exe]: build a single
    current-dated all-eligible universe snapshot and write it to disk.

    Separated from the CLI shell so the [run] logic is unit-testable without
    argument parsing. *)

open Core

type result = {
  written_path : string;
  entry_count : int;
  staleness_report : Universe.Build_eligible_universe.staleness_report;
}
[@@deriving show, eq]
(** Outcome of a successful run: where the snapshot was written, how many
    eligible symbols it contains, and the freshness-gate
    {!Universe.Build_eligible_universe.staleness_report} (count + sample of
    symbols dropped specifically for stale data). *)

val run :
  inventory_path:string ->
  csv_data_dir:string ->
  date:Date.t ->
  min_price:float ->
  min_avg_dollar_volume:float ->
  max_staleness_trading_days:int ->
  output_path:string ->
  result Status.status_or
(** [run ~inventory_path ~csv_data_dir ~date ~min_price ~min_avg_dollar_volume
     ~max_staleness_trading_days ~output_path] builds the eligible universe at
    [date] from the inventory + cached bars under [csv_data_dir], applying the
    live-universe spec gates (REIT-exclude, preferred-exclude, the supplied
    [min_price] / [min_avg_dollar_volume]) and the freshness tolerance
    [max_staleness_trading_days] (0 = require a bar on / after [date]), and
    writes the resulting {!Universe.Snapshot.t} to [output_path].

    [csv_data_dir] is both the bars root and the directory holding
    [symbol_types.sexp] and [sectors.csv] (the standard cached-data layout).

    Returns [Error] when the build or the on-disk write fails (propagating the
    {!Universe.Build_eligible_universe.build} status), else
    [Ok { written_path; entry_count; staleness_report }]. *)
