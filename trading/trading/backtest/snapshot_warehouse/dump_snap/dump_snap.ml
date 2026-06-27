(* Ad-hoc snapshot inspector: dump one symbol's OHLC bars over a date range
   from a v2 columnar .snap file.

   Usage: dump_snap <path-to-.snap> <from-date> <until-date>
     dates in YYYY-MM-DD; prints CSV (date,open,high,low,close,adj_close,volume).

   Built to confirm the ELCO unadjusted micro-cap artifact during the
   liquidity-realism forensic (2026-06-26): a delisted name trading ~2
   shares/day whose stale high-tick tripped a worst-case short cover fill. Kept
   as a dev tool so the liquidity work ships with the inspector that diagnosed
   it. *)
open Core
module Sc = Data_panel_snapshot.Snapshot_columnar
module Snap = Data_panel_snapshot.Snapshot
module Schema = Data_panel_snapshot.Snapshot_schema

let get row f = Option.value (Snap.get row f) ~default:Float.nan

let () =
  let argv = Sys.get_argv () in
  let path = argv.(1) in
  let from = Date.of_string argv.(2) in
  let until = Date.of_string argv.(3) in
  match Sc.with_reader ~path ~f:(fun r -> Sc.read_range r ~from ~until) with
  | Error e -> eprintf "ERROR: %s\n" (Status.show e)
  | Ok rows ->
      printf "date,open,high,low,close,adj_close,volume\n";
      List.iter rows ~f:(fun row ->
          printf "%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.0f\n"
            (Date.to_string row.Snap.date)
            (get row Schema.Open) (get row Schema.High) (get row Schema.Low)
            (get row Schema.Close)
            (get row Schema.Adjusted_close)
            (get row Schema.Volume))
