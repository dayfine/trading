(* Ad-hoc snapshot inspector: dump one symbol's OHLC bars over a date range
   from a columnar .snap file.

   Usage: dump_snap <path-to-.snap> <from-date> <until-date>
     dates in YYYY-MM-DD; prints CSV. The trailing columns are the per-cell
     age-banded resistance histogram (band-major, one column per Res_hist cell).

   Histogram width is warehouse-version aware: a v4 (age-banded) warehouse
   carries [n_hist_cells] Res_hist columns; a v3 warehouse carries only the
   [n_hist_buckets] age-blind band-0 columns. The prior version iterated only
   [n_hist_buckets], so a v4 dump silently showed the youngest band alone and
   dropped the other three bands. Width is now detected per the same probe
   [resistance_sketch_reader.ml] uses.

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

(* Human-readable weekly-bar age range per histogram band, matching the schema's
   band boundaries [0-26w / 26-78w / 78-130w / 130-520w] (youngest first). *)
let band_labels = [| "0-26w"; "26-78w"; "78-130w"; "130-520w" |]

(* Band-major layout: cell [k] holds age band [k / n_hist_buckets] and price
   bucket [k mod n_hist_buckets]. E.g. [hist[b0-26w][k3]]. *)
let hist_cell_label k =
  let n = Schema.n_hist_buckets in
  Printf.sprintf "hist[b%s][k%d]" band_labels.(k / n) (k mod n)

(* Detect the histogram width from a sample row: probe the last v4 cell.
   [Snap.get] returns [None] when the field is absent from the row's schema (a
   v3 warehouse), so this mirrors the width detection in
   [resistance_sketch_reader.ml] -- v4 dumps [n_hist_cells], v3 dumps
   [n_hist_buckets]. *)
let hist_width row =
  match Snap.get row (Schema.Res_hist (Schema.n_hist_cells - 1)) with
  | Some _ -> Schema.n_hist_cells
  | None -> Schema.n_hist_buckets

let print_header ~width =
  let hist_headers =
    List.init width ~f:hist_cell_label |> String.concat ~sep:","
  in
  printf
    "date,open,high,low,close,adj_close,volume,res_bars_seen,res_max_520w,%s\n"
    hist_headers

let print_row ~width row =
  let hist_cells =
    List.init width ~f:(fun k ->
        Printf.sprintf "%.1f" (get row (Schema.Res_hist k)))
    |> String.concat ~sep:","
  in
  printf "%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.0f,%.0f,%.4f,%s\n"
    (Date.to_string row.Snap.date)
    (get row Schema.Open) (get row Schema.High) (get row Schema.Low)
    (get row Schema.Close)
    (get row Schema.Adjusted_close)
    (get row Schema.Volume)
    (get row Schema.Res_bars_seen)
    (get row Schema.Res_max_high_520w)
    hist_cells

let () =
  let argv = Sys.get_argv () in
  let path = argv.(1) in
  let from = Date.of_string argv.(2) in
  let until = Date.of_string argv.(3) in
  match Sc.with_reader ~path ~f:(fun r -> Sc.read_range r ~from ~until) with
  | Error e -> eprintf "ERROR: %s\n" (Status.show e)
  | Ok rows ->
      (* Width is uniform across a single .snap file; default to the v4 width
         when there are no rows to sample. *)
      let width =
        match rows with
        | first :: _ -> hist_width first
        | [] -> Schema.n_hist_cells
      in
      print_header ~width;
      List.iter rows ~f:(print_row ~width)
