(* Warehouse corrupt-bar scanner: iterate every *.snap in a snapshot-warehouse
   directory and report MSZ-class one-day spike-revert bars (see
   [Audit_bars_detector] and [dev/notes/deep-remeasure-364-2026-07-09.md]).

   Usage:
     audit_bars.exe <warehouse-dir>
       [--spike-mult X] [--median-window K] [--revert-frac F] [--price-ceiling P]

   Prints one CSV row per hit
   (symbol,date,prev_close,spike_close,next_close,ratio) followed by a summary
   line. Exit code is always 0 — it is a report, not a gate. *)
open Core
module Detector = Audit_bars_detector
module Sc = Data_panel_snapshot.Snapshot_columnar
module Snap = Data_panel_snapshot.Snapshot
module Schema = Data_panel_snapshot.Snapshot_schema

(* Reconstruct the close series of one .snap file as detector bars. Missing
   close cells (nan) are kept: the detector's arithmetic naturally excludes
   them from spike matches. *)
let _bars_of_reader r =
  match Sc.read_all r with
  | Error e -> Error e
  | Ok rows ->
      Ok
        (Array.of_list_map rows ~f:(fun row ->
             {
               Detector.date = row.Snap.date;
               close =
                 Option.value (Snap.get row Schema.Close) ~default:Float.nan;
             }))

(* Scan one file; returns [(symbol, hits)] or an error. *)
let _scan_file ~params ~path =
  Sc.with_reader ~path ~f:(fun r ->
      match _bars_of_reader r with
      | Error e -> Error e
      | Ok bars -> Ok (Sc.symbol r, Detector.detect ~params bars))

let _print_hit symbol (h : Detector.hit) =
  printf "%s,%s,%.4f,%.4f,%.4f,%.2f\n" symbol (Date.to_string h.date)
    h.prev_close h.spike_close h.next_close h.ratio

let _snap_files dir =
  Sys_unix.readdir dir |> Array.to_list
  |> List.filter ~f:(fun f -> String.is_suffix f ~suffix:".snap")
  |> List.sort ~compare:String.compare
  |> List.map ~f:(fun f -> Filename.concat dir f)

(* Scan the whole directory, printing hits as they are found; returns
   [(hit_count, symbols_with_hits, scanned)]. *)
let _scan_dir ~params dir =
  let files = _snap_files dir in
  List.fold files ~init:(0, 0, 0) ~f:(fun (hits, syms, scanned) path ->
      match _scan_file ~params ~path with
      | Error e ->
          eprintf "WARN: skipping %s: %s\n" path (Status.show e);
          (hits, syms, scanned + 1)
      | Ok (symbol, file_hits) ->
          List.iter file_hits ~f:(_print_hit symbol);
          let n = List.length file_hits in
          (hits + n, (syms + if n > 0 then 1 else 0), scanned + 1))

let command =
  Command.basic
    ~summary:"Scan a snapshot warehouse for spike-revert corrupt bars"
    (let%map_open.Command dir = anon ("warehouse-dir" %: string)
     and spike_mult =
       flag "--spike-mult"
         (optional_with_default 5.0 float)
         ~doc:"X spike close / surrounding-median ratio threshold (default 5.0)"
     and median_window =
       flag "--median-window"
         (optional_with_default 5 int)
         ~doc:"K half-width of the surrounding median window (default 5)"
     and revert_frac =
       flag "--revert-frac"
         (optional_with_default 0.5 float)
         ~doc:"F next-close / spike-close revert threshold (default 0.5)"
     and price_ceiling =
       flag "--price-ceiling"
         (optional_with_default 5.0 float)
         ~doc:"P only flag when surrounding median close < P (default 5.0)"
     in
     fun () ->
       let params =
         { Detector.spike_mult; median_window; revert_frac; price_ceiling }
       in
       printf "symbol,date,prev_close,spike_close,next_close,ratio\n";
       let hits, syms, scanned = _scan_dir ~params dir in
       printf "%d hits across %d symbols (of %d scanned)\n" hits syms scanned)

let () = Command_unix.run command
