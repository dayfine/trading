(** End-of-run close prices read from the snapshot (split out of
    [Panel_runner]). *)

open Core

val final :
  daily_panels:Snapshot_runtime.Daily_panels.t ->
  symbols:string list ->
  end_date:Date.t ->
  (string * float) list
(** Close prices on [end_date] for every symbol in [symbols], read via
    [Daily_panels.read_today]. Missing symbols, read errors and NaN closes are
    dropped; the runner filters to held symbols when populating
    [Runner.result.final_prices]. *)
