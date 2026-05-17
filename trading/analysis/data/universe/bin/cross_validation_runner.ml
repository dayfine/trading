(** CLI: cross-validate the composition path's annual aggregate-return against
    Shiller's S&P composite total return for the matching window.

    Usage:
    {v
      dune exec analysis/data/universe/bin/cross_validation_runner.exe -- \
        -composition-dir trading/test_data/goldens-custom-universe/composition/ \
        -shiller-cache dev/data/shiller/shiller_history.csv \
        -size 500 \
        -start-year 1998 -end-year 2025 \
        -out-sexp trading/test_data/cross-validation-composition-vs-shiller.sexp \
        -out-markdown dev/sweep/cross-validation-composition-vs-shiller.md
    v}

    Errors are written to stderr and the process exits non-zero. Successful runs
    print the summary statistics (mean / median / max-abs drift, worst year,
    cell count) to stdout. *)

open! Core
module Runner = Cross_validation_runner_lib

let _exit_with_error msg =
  Stdlib.Printf.fprintf Stdlib.stderr "cross_validation_runner: %s\n" msg;
  Stdlib.flush Stdlib.stderr;
  Stdlib.exit 1

let _read_file_or_exit ~label path =
  if not (Stdlib.Sys.file_exists path) then
    _exit_with_error (Printf.sprintf "%s file not found: %s" label path)
  else In_channel.read_all path

let _print_summary (result : Runner.result) =
  let r = result.report in
  Stdlib.Printf.printf
    "cross_validation_runner: cells=%d mean_drift=%+.4f median_drift=%+.4f \
     max_abs_drift=%.4f worst_year=%d\n"
    (List.length r.cells) r.mean_drift r.median_drift r.max_abs_drift
    r.worst_year;
  Stdlib.Printf.printf "  wrote sexp: %s\n" result.out_sexp_path;
  Stdlib.Printf.printf "  wrote markdown: %s\n" result.out_markdown_path

let _run ~composition_dir ~shiller_cache ~size ~start_year ~end_year
    ~out_sexp_path ~out_markdown_path =
  let shiller_body = _read_file_or_exit ~label:"shiller-cache" shiller_cache in
  match
    Runner.run ~composition_dir ~shiller_cache_body:shiller_body ~size
      ~start_year ~end_year ~out_sexp_path ~out_markdown_path
  with
  | Ok result -> _print_summary result
  | Error err -> _exit_with_error (Status.show err)

let _default_composition_dir =
  "trading/test_data/goldens-custom-universe/composition/"

let _default_size = 500
let _default_start_year = 1998
let _default_end_year = 2025

let command =
  Command.basic
    ~summary:
      "Compute year-by-year drift between composition aggregate-return goldens \
       and Shiller's S&P composite total return for the matching window."
    (let%map_open.Command composition_dir =
       flag "-composition-dir"
         (optional_with_default _default_composition_dir string)
         ~doc:
           (Printf.sprintf "PATH composition goldens directory (default: %s)"
              _default_composition_dir)
     and shiller_cache =
       flag "-shiller-cache" (required string)
         ~doc:"PATH Shiller cache CSV (period,sp_price,dividend,...)"
     and size =
       flag "-size"
         (optional_with_default _default_size int)
         ~doc:(Printf.sprintf "INT top-N size (default: %d)" _default_size)
     and start_year =
       flag "-start-year"
         (optional_with_default _default_start_year int)
         ~doc:
           (Printf.sprintf "YEAR first cross-val year (default: %d)"
              _default_start_year)
     and end_year =
       flag "-end-year"
         (optional_with_default _default_end_year int)
         ~doc:
           (Printf.sprintf "YEAR last cross-val year (default: %d)"
              _default_end_year)
     and out_sexp_path =
       flag "-out-sexp" (required string) ~doc:"PATH output sexp report path"
     and out_markdown_path =
       flag "-out-markdown" (required string)
         ~doc:"PATH output markdown report path"
     in
     fun () ->
       _run ~composition_dir ~shiller_cache ~size ~start_year ~end_year
         ~out_sexp_path ~out_markdown_path)

let () = Command_unix.run command
