(** CLI: cross-validate Shiller monthly S&P composite against EODHD's SP500
    index adjusted-close.

    Usage:
    {v
      dune exec analysis/data/sources/shiller/bin/shiller_validator.exe -- \
        -shiller-csv  dev/data/shiller/shiller-monthly-YYYYMMDD.csv \
        -eodhd-cache-dir data \
        [-index-symbol GSPC.INDX] \
        [-threshold 0.005] \
        [-top-n 10] \
        [-out dev/data/shiller/validation_report.md]
    v}

    Behaviour:
    - Reads the Shiller derived CSV (output of [fetch_shiller_history.exe]).
    - Loads the EODHD index from the cache via {!Csv_storage}.
    - Resamples daily → monthly (last bar per calendar month).
    - Computes drift per period.
    - Writes a Markdown report.

    Failure modes:
    - Shiller CSV missing / unparseable → exit 1 with stderr message.
    - EODHD index missing from cache → graceful exit 0 with a "no overlap"
      report (per the task spec: "report that as a gap and exit gracefully").
    - Any other unexpected error → exit 1. *)

open! Core
module Core_ = Shiller_validator_core

let _default_threshold = 0.005
let _default_top_n = 10
let _default_index_symbol = "GSPC.INDX"
let _default_out = "dev/data/shiller/validation_report.md"

let _read_file_or_exit path =
  match Sys_unix.file_exists path with
  | `No | `Unknown ->
      eprintf "shiller_validator: shiller-csv not found: %s\n" path;
      Stdlib.exit 1
  | `Yes -> In_channel.read_all path

let _load_shiller_or_exit path =
  let body = _read_file_or_exit path in
  match Core_.parse_shiller_derived_csv body with
  | Ok obs -> obs
  | Error status ->
      eprintf "shiller_validator: failed to parse Shiller CSV %s: %s\n" path
        (Status.show status);
      Stdlib.exit 1

(* Load EODHD bars via the canonical Csv_storage layer. Returns [None] if
   the index symbol is not present in the cache; that case maps to a
   "no-overlap" report rather than an exit-1 (per the task spec). *)
let _load_eodhd_or_none ~data_dir ~symbol : Types.Daily_price.t list option =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error _ -> None
  | Ok store -> (
      match Csv.Csv_storage.get store () with
      | Ok bars -> Some bars
      | Error status ->
          let msg = Status.show status in
          if String.is_substring msg ~substring:"not found" then None
          else (
            eprintf "shiller_validator: failed to read EODHD cache %s: %s\n"
              symbol msg;
            Stdlib.exit 1))

let _empty_report ~threshold =
  let stats : Core_.stats =
    {
      n_compared = 0;
      n_flagged = 0;
      mean_abs_rel_diff = 0.0;
      stdev_abs_rel_diff = 0.0;
      max_abs_rel_diff = 0.0;
    }
  in
  {
    Core_.threshold;
    overlap_first = None;
    overlap_last = None;
    stats;
    rows = [];
    top_drift = [];
  }

let _ensure_parent_dir path =
  let parent = Filename.dirname path in
  match Core_unix.mkdir_p parent with _ -> ()

let _write_report ~out (report : Core_.report) =
  _ensure_parent_dir out;
  Out_channel.write_all out ~data:(Core_.format_markdown_report report)

let _print_summary ~out (r : Core_.report) =
  printf "shiller_validator: wrote %s\n" out;
  printf "  overlap: %s → %s\n"
    (Option.value_map r.overlap_first ~default:"n/a" ~f:Date.to_string)
    (Option.value_map r.overlap_last ~default:"n/a" ~f:Date.to_string);
  printf "  months compared: %d\n" r.stats.n_compared;
  printf "  months flagged (|rel_diff| > %.4f): %d\n" r.threshold
    r.stats.n_flagged;
  printf "  mean |rel_diff|: %.4f%%\n" (r.stats.mean_abs_rel_diff *. 100.0);
  printf "  max  |rel_diff|: %.4f%%\n" (r.stats.max_abs_rel_diff *. 100.0)

let _run ~shiller_csv ~eodhd_cache_dir ~index_symbol ~threshold ~top_n ~out =
  let shiller = _load_shiller_or_exit shiller_csv in
  let data_dir = Fpath.v eodhd_cache_dir in
  let report =
    match _load_eodhd_or_none ~data_dir ~symbol:index_symbol with
    | None ->
        eprintf
          "shiller_validator: EODHD cache has no %s under %s — emitting \
           no-overlap report.\n"
          index_symbol eodhd_cache_dir;
        _empty_report ~threshold
    | Some bars ->
        let eodhd_monthly = Core_.resample_daily_to_monthly bars in
        Core_.build_report ~shiller ~eodhd_monthly ~threshold ~top_n
  in
  _write_report ~out report;
  _print_summary ~out report

let command =
  Command.basic
    ~summary:
      "Cross-validate Shiller monthly S&P composite against EODHD's SP500 \
       index adjusted-close; emits a Markdown drift report."
    (let%map_open.Command shiller_csv =
       flag "-shiller-csv" (required string)
         ~doc:"PATH derived Shiller CSV (output of fetch_shiller_history.exe)"
     and eodhd_cache_dir =
       flag "-eodhd-cache-dir" (required string)
         ~doc:"DIR root of the EODHD CSV cache (e.g. ./data)"
     and index_symbol =
       flag "-index-symbol"
         (optional_with_default _default_index_symbol string)
         ~doc:
           (Printf.sprintf "SYM EODHD index ticker (default %s)"
              _default_index_symbol)
     and threshold =
       flag "-threshold"
         (optional_with_default _default_threshold float)
         ~doc:
           (Printf.sprintf "FLOAT |rel_diff| flag cutoff (default %.4f = 0.5%%)"
              _default_threshold)
     and top_n =
       flag "-top-n"
         (optional_with_default _default_top_n int)
         ~doc:
           (Printf.sprintf "N top-N drift months in the report (default %d)"
              _default_top_n)
     and out =
       flag "-out"
         (optional_with_default _default_out string)
         ~doc:
           (Printf.sprintf "PATH output Markdown report path (default %s)"
              _default_out)
     in
     fun () ->
       _run ~shiller_csv ~eodhd_cache_dir ~index_symbol ~threshold ~top_n ~out)

let () = Command_unix.run command
