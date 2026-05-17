(** CLI: bulk-emit the decomposition-side custom-universe snapshots.

    Reads cached Shiller monthly + Kenneth French daily-5-industry CSVs,
    iterates over [(year, top_n)] for [year] in [[start_year..end_year]] and
    [top_n] in the supplied list, calls {!Universe.Build_from_index.build} once
    per pair, and writes each successful snapshot to
    [\{out_dir\}/top-\{top_n\}-\{year\}.sexp]. Errors from the builder are
    logged + counted but never crash the run.

    Usage:
    {v
      dune exec analysis/data/universe/bin/build_synthetic_universes_runner.exe -- \
        -shiller-cache PATH \
        -french-cache PATH \
        -out-dir trading/test_data/goldens-custom-universe/decomposition/ \
        -start-year 1927 -end-year 1997 \
        -top-n 500,1000,3000 \
        -rng-seed 42
    v} *)

open! Core

let _exit_with_error msg =
  Stdlib.Printf.fprintf Stdlib.stderr "build_synthetic_universes_runner: %s\n"
    msg;
  Stdlib.flush Stdlib.stderr;
  Stdlib.exit 1

let _parse_top_n_list raw : int list =
  let parts = String.split raw ~on:',' |> List.map ~f:String.strip in
  let parsed =
    List.map parts ~f:(fun s ->
        match Int.of_string s with
        | n when n > 0 -> Ok n
        | _ -> Error s
        | exception _ -> Error s)
  in
  match List.find parsed ~f:(function Ok _ -> false | Error _ -> true) with
  | Some (Error bad) ->
      _exit_with_error (Printf.sprintf "invalid -top-n %S" bad)
  | _ -> List.map parsed ~f:(function Ok n -> n | Error _ -> assert false)

let _read_file_or_exit ~label path =
  if not (Stdlib.Sys.file_exists path) then
    _exit_with_error (Printf.sprintf "%s file not found: %s" label path)
  else In_channel.read_all path

let _parse_shiller_or_exit body =
  match Build_synthetic_universes_runner_lib.parse_shiller_cache_csv body with
  | Ok obs -> obs
  | Error err ->
      _exit_with_error ("shiller cache parse failed: " ^ Status.show err)

let _parse_french_or_exit body =
  match Build_synthetic_universes_runner_lib.parse_french_cache_csv body with
  | Ok obs -> obs
  | Error err ->
      _exit_with_error ("french cache parse failed: " ^ Status.show err)

let _print_summary (result : Build_synthetic_universes_runner_lib.result) =
  Stdlib.Printf.printf
    "build_synthetic_universes_runner: written=%d skipped=%d\n" result.written
    result.skipped;
  if result.skipped > 0 then
    List.iter (List.rev result.skip_reasons) ~f:(fun (year, top_n, reason) ->
        Stdlib.Printf.printf "  skip year=%d top_n=%d: %s\n" year top_n reason)

let _run ~shiller_cache ~french_cache ~out_dir ~start_year ~end_year ~top_ns
    ~rng_seed =
  let shiller_body = _read_file_or_exit ~label:"shiller-cache" shiller_cache in
  let french_body = _read_file_or_exit ~label:"french-cache" french_cache in
  let shiller_obs = _parse_shiller_or_exit shiller_body in
  let french_obs = _parse_french_or_exit french_body in
  let result =
    Build_synthetic_universes_runner_lib.run ~shiller_obs ~french_obs ~out_dir
      ~start_year ~end_year ~top_ns ~rng_seed
  in
  _print_summary result

let _default_out_dir =
  "trading/test_data/goldens-custom-universe/decomposition/"

let _default_top_n_raw = "500,1000,3000"
let _default_start_year = 1927
let _default_end_year = 1997
let _default_rng_seed = 42

let command =
  Command.basic
    ~summary:
      "Bulk-emit decomposition-side synthetic-universe snapshots from cached \
       Shiller + Kenneth French CSVs."
    (let%map_open.Command shiller_cache =
       flag "-shiller-cache" (required string)
         ~doc:"PATH Shiller cache CSV (period,sp_price,dividend,...)"
     and french_cache =
       flag "-french-cache" (required string)
         ~doc:"PATH Kenneth French 5-industry daily cache CSV (block,date,...)"
     and out_dir =
       flag "-out-dir"
         (optional_with_default _default_out_dir string)
         ~doc:
           (Printf.sprintf "PATH output directory (default: %s)"
              _default_out_dir)
     and start_year =
       flag "-start-year"
         (optional_with_default _default_start_year int)
         ~doc:
           (Printf.sprintf "YEAR first reconstitution year (default: %d)"
              _default_start_year)
     and end_year =
       flag "-end-year"
         (optional_with_default _default_end_year int)
         ~doc:
           (Printf.sprintf "YEAR last reconstitution year (default: %d)"
              _default_end_year)
     and top_n_raw =
       flag "-top-n"
         (optional_with_default _default_top_n_raw string)
         ~doc:
           (Printf.sprintf "LIST comma-separated top-N sizes (default: %s)"
              _default_top_n_raw)
     and rng_seed =
       flag "-rng-seed"
         (optional_with_default _default_rng_seed int)
         ~doc:(Printf.sprintf "INT master seed (default: %d)" _default_rng_seed)
     in
     fun () ->
       let top_ns = _parse_top_n_list top_n_raw in
       _run ~shiller_cache ~french_cache ~out_dir ~start_year ~end_year ~top_ns
         ~rng_seed)

let () = Command_unix.run command
