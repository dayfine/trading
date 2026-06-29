(** CLI: build a single current-dated {b all-eligible} universe snapshot.

    Unlike [build_composition_universes_runner] (top-N by dollar-volume rank
    over an annual cadence), this emits {b every} eligible common-stock-like US
    listing at one date — no size cap — applying the live-universe spec gates
    (min-price, min-avg-dollar-volume, min-window-bars, REIT-exclude,
    preferred-exclude). Output is the standard {!Universe.Snapshot.t} the
    screener / scenario_runner consume.

    Usage:
    {v
      dune exec analysis/data/universe/bin/build_eligible_universe_runner.exe -- \
        -inventory-path /workspaces/trading-1/data/inventory.sexp \
        -csv-data-dir   /workspaces/trading-1/data \
        -date           2026-06-12 \
        -min-price      5.0 \
        -min-adv        1000000.0 \
        -output-path    /workspaces/trading-1/data/eligible-2026-06-12.sexp
    v}

    [-csv-data-dir] is both the cached-bars root and the directory holding
    [symbol_types.sexp] + [sectors.csv]. *)

open! Core

let _default_min_price = 5.0
let _default_min_adv = 1_000_000.0
let _default_max_staleness_trading_days = 0

(* Surface a freshness-gate exclusion so a silent universe-shrink is visible.
   A zero count prints nothing (no noise on a fully-fresh build). *)
let _print_staleness
    (report : Universe.Build_eligible_universe.staleness_report) =
  if report.excluded_count > 0 then
    Stdlib.Printf.printf
      "[eligible-universe] %d symbols excluded for staleness (sample: %s)\n"
      report.excluded_count
      (String.concat ~sep:" " report.sample)

let _print_result (result : Build_eligible_universe_runner_lib.result) =
  Stdlib.Printf.printf
    "build_eligible_universe_runner: wrote %d eligible symbols to %s\n"
    result.entry_count result.written_path;
  _print_staleness result.staleness_report

let _exit_with_error msg =
  Stdlib.Printf.fprintf Stdlib.stderr "build_eligible_universe_runner: %s\n" msg;
  Stdlib.flush Stdlib.stderr;
  Stdlib.exit 1

let _run ~inventory_path ~csv_data_dir ~date ~min_price ~min_avg_dollar_volume
    ~max_staleness_trading_days ~output_path =
  match
    Build_eligible_universe_runner_lib.run ~inventory_path ~csv_data_dir ~date
      ~min_price ~min_avg_dollar_volume ~max_staleness_trading_days ~output_path
  with
  | Ok result -> _print_result result
  | Error err -> _exit_with_error (Status.show err)

let command =
  Command.basic
    ~summary:
      "Build a single current-dated all-eligible universe snapshot (every \
       eligible common-stock-like listing, no size cap) from cached bars + \
       inventory."
    (let%map_open.Command inventory_path =
       flag "-inventory-path" (required string)
         ~doc:"PATH inventory.sexp from weinstein.data_source"
     and csv_data_dir =
       flag "-csv-data-dir" (required string)
         ~doc:
           "PATH cached-data root (bars + symbol_types.sexp + sectors.csv live \
            here)"
     and date =
       flag "-date" (required string) ~doc:"YYYY-MM-DD universe anchor date"
     and min_price =
       flag "-min-price"
         (optional_with_default _default_min_price float)
         ~doc:
           (Printf.sprintf "FLOAT min latest close (default: %.2f)"
              _default_min_price)
     and min_avg_dollar_volume =
       flag "-min-adv"
         (optional_with_default _default_min_adv float)
         ~doc:
           (Printf.sprintf
              "FLOAT min trailing avg dollar volume (default: %.0f)"
              _default_min_adv)
     and max_staleness_trading_days =
       flag "-max-staleness-trading-days"
         (optional_with_default _default_max_staleness_trading_days int)
         ~doc:
           (Printf.sprintf
              "INT keep symbols whose last bar is up to N trading days \
               (weekdays) before -date (default: %d = require a bar on/after \
               -date)"
              _default_max_staleness_trading_days)
     and output_path =
       flag "-output-path" (required string)
         ~doc:"PATH where to write the snapshot .sexp"
     in
     fun () ->
       let date = Date.of_string date in
       _run ~inventory_path ~csv_data_dir ~date ~min_price
         ~min_avg_dollar_volume ~max_staleness_trading_days ~output_path)

let () = Command_unix.run command
