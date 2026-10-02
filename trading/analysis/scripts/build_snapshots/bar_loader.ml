(* CSV bar loading + windowing for the snapshot build, extracted from
   [symbol_builder.ml]. *)

open Core

let csv_mtime ~data_dir ~symbol =
  let dir = Csv.Csv_storage.symbol_data_dir ~data_dir symbol in
  let csv_path = Fpath.add_seg dir "data.csv" |> Fpath.to_string in
  if Stdlib.Sys.file_exists csv_path then
    Some (Core_unix.stat csv_path).st_mtime
  else None

let load_bars ~data_dir ~symbol =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error err ->
      Error
        (Status.invalid_argument_error
           (Printf.sprintf "create %s: %s" symbol (Status.show err)))
  | Ok storage -> Csv.Csv_storage.get storage ()

(* Window a symbol's loaded bars to the inclusive [start_date, end_date] range
   before the snapshot pipeline sees them. Mirrors [Csv_snapshot_builder]'s
   windowing so a snapshot-mode warehouse stays cache-friendly (see
   {!Bar_window} for the perf rationale + warmup caveat). When both bounds are
   [None] the bars pass through unchanged. *)
let _window_bars ~start_date ~end_date bars =
  Bar_window.filter ?start:start_date ?end_:end_date bars

let load_windowed_bars ~data_dir ~start_date ~end_date ~symbol =
  match load_bars ~data_dir ~symbol with
  | Error _ as err -> err
  | Ok bars -> Ok (_window_bars ~start_date ~end_date bars)

(* Deep-history slice [[start_date - sketch_deep_days, start_date)] that feeds
   ONLY the resistance sketch (resistance-v2 §D4). Empty when [start_date] is
   [None] (full-history build already carries all bars in the window). The
   inclusive [end_ = start - 1 day] keeps the slice strictly before the window,
   so it never overlaps [_window_bars ~start_date]. *)
let _deep_bars ~sketch_deep_days ~start_date bars =
  match start_date with
  | None -> []
  | Some start ->
      let deep_start = Date.add_days start (-sketch_deep_days) in
      let deep_end = Date.add_days start (-1) in
      Bar_window.filter ~start:deep_start ~end_:deep_end bars

(* Load a symbol once, split into (deep_bars, window_bars): rows are emitted for
   [window_bars] only, while [deep_bars] widen the sketch's weekly prefix. *)
let load_split_bars ~data_dir ~start_date ~end_date ~sketch_deep_days ~symbol =
  match load_bars ~data_dir ~symbol with
  | Error e -> Error e
  | Ok bars ->
      Ok
        ( _deep_bars ~sketch_deep_days ~start_date bars,
          _window_bars ~start_date ~end_date bars )
