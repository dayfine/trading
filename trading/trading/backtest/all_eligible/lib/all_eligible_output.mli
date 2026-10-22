(** Output writers shared by the runner and grade-sweep pipeline. *)

open Core

val format_summary_md :
  scenario_name:string ->
  start_date:Date.t ->
  end_date:Date.t ->
  result:All_eligible.result ->
  string
(** [format_summary_md ~scenario_name ~start_date ~end_date ~result] renders
    [result.aggregate] as a Markdown report. Includes the scenario header, the
    aggregate metrics table, and a bucket-histogram table. Pure function;
    exposed for direct unit testing. *)

val write_trades_csv : path:string -> All_eligible.result -> unit
(** [write_trades_csv ~path result] writes one CSV row per [result.trades]
    entry, with a header row matching the {!All_eligible.trade_record} field
    set. Overwrites any existing file at [path]. *)
