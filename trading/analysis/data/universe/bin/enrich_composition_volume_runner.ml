(** CLI: volume-only enrichment of committed composition goldens.

    Loads every [*.sexp] under [--goldens-dir], recomputes [avg_dollar_volume]
    for each non-synthetic entry from the per-symbol bars under [--bars-root]
    (using the *same* trailing-window [avg (close * volume)] the composition
    builder used to rank — see
    {!Universe.Build_from_individuals.avg_dollar_volume_for_symbol}), and writes
    each snapshot back in place with *only* that field added. Symbol set,
    weights, sectors, order, synthetic flags, and all snapshot-level fields are
    preserved bit-for-bit, so no backtest reading these goldens re-pins. A
    per-file [composition_preserved] check guards the invariant; any file that
    would have drifted is left untouched and counted.

    Usage:
    {v
      dune exec analysis/data/universe/bin/enrich_composition_volume_runner.exe -- \
        --goldens-dir trading/test_data/goldens-custom-universe/composition/ \
        --bars-root /workspaces/trading-1/data
    v} *)

open! Core

let _default_goldens_dir =
  "trading/test_data/goldens-custom-universe/composition/"

let _exit_with_error msg =
  Stdlib.Printf.fprintf Stdlib.stderr "enrich_composition_volume_runner: %s\n"
    msg;
  Stdlib.flush Stdlib.stderr;
  Stdlib.exit 1

let _print_summary (result : Enrich_composition_volume_runner_lib.result) =
  let total =
    List.fold result.files ~init:(0, 0, 0)
      ~f:(fun
          (e, n, s) (f : Enrich_composition_volume_runner_lib.file_result) ->
        (e + f.result.enriched, n + f.result.no_volume, s + f.result.synthetic))
  in
  let enriched, no_volume, synthetic = total in
  Stdlib.Printf.printf
    "enrich_composition_volume_runner: files=%d enriched=%d no_volume=%d \
     synthetic=%d composition_changed=%d\n"
    (List.length result.files) enriched no_volume synthetic
    result.composition_changed

let _run ~goldens_dir ~bars_root =
  match Enrich_composition_volume_runner_lib.run ~goldens_dir ~bars_root with
  | Error err -> _exit_with_error (Status.show err)
  | Ok result ->
      _print_summary result;
      if result.composition_changed > 0 then
        _exit_with_error
          (Printf.sprintf
             "composition drifted in %d file(s) — enrichment aborted writing \
              them; investigate before retrying"
             result.composition_changed)

let command =
  Command.basic
    ~summary:
      "Inject avg_dollar_volume into committed composition goldens without \
       changing composition (symbols/weights/sectors/order preserved)."
    (let%map_open.Command goldens_dir =
       flag "--goldens-dir"
         (optional_with_default _default_goldens_dir string)
         ~doc:
           (Printf.sprintf "PATH composition goldens dir (default: %s)"
              _default_goldens_dir)
     and bars_root =
       flag "--bars-root" (required string)
         ~doc:"PATH root of cached bars (e.g. /workspaces/trading-1/data)"
     in
     fun () -> _run ~goldens_dir ~bars_root)

let () = Command_unix.run command
