(** See [panel_close_prices.mli]. *)

open Core
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Read one symbol's close on [date]. Returns [None] when the symbol is not
   present in the snapshot, the read errors, or the close is NaN. *)
let _read_close ~daily_panels ~close_col ~date symbol =
  match Daily_panels.read_today daily_panels ~symbol ~date with
  | Error _ -> None
  | Ok snap ->
      let v = snap.values.(close_col) in
      if Float.is_nan v then None else Some (symbol, v)

(** Close prices on [end_date] for every universe symbol, read from the snapshot
    via [Daily_panels.read_today]. Missing / NaN entries are dropped; the runner
    filters to held symbols when populating [Runner.result.final_prices]. *)
let final ~daily_panels ~symbols ~end_date =
  let schema = Daily_panels.schema daily_panels in
  match Snapshot_schema.index_of schema Snapshot_schema.Close with
  | None -> []
  | Some close_col ->
      List.filter_map symbols
        ~f:(_read_close ~daily_panels ~close_col ~date:end_date)
