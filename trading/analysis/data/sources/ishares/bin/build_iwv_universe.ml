(** [build_iwv_universe.exe] CLI entry point.

    Reads the iShares IWV holdings CSV cache produced by
    [fetch_iwv_history.exe], pipes the parsed snapshots through
    {!Ishares.Ishares_membership_replay.replay}, and writes a point-in-time
    universe sexp matching the existing [broad-3000-2010-01-01.sexp] shape.

    See [build_iwv_universe_lib.mli] and [dev/plans/iwv-scraper-2026-05-16.md]
    §PR-D for the planning contract. *)

open Core
module Lib = Build_iwv_universe_lib

let _default_cache_dir = "../dev/data/ishares/iwv"
let _default_threshold_misses = 3
let _default_start_str = "2006-09-29"
let _today () = Date.today ~zone:Time_float.Zone.utc

let _print_summary (outcome : Lib.outcome) =
  printf
    "Wrote universe: %d members | %d snapshots replayed | %d tenures removed.\n"
    outcome.member_count outcome.snapshot_count outcome.removed_count

let _run ~cache_dir ~output ~from_str ~until_str ~as_of_str
    ~threshold_consecutive_misses =
  let from = Date.of_string from_str in
  let until = Date.of_string until_str in
  let as_of =
    match as_of_str with Some s -> Date.of_string s | None -> until
  in
  match
    Lib.run ~cache_dir ~output ~from ~until ~as_of ~threshold_consecutive_misses
      ()
  with
  | Error err ->
      eprintf "Error: %s\n" (Status.show err);
      Stdlib.exit 1
  | Ok outcome -> _print_summary outcome

let command =
  Command.basic
    ~summary:
      "Build a point-in-time Russell 3000 universe sexp from the iShares IWV \
       holdings CSV cache."
    ~readme:(fun () ->
      "Reads <cache-dir>/YYYY-MM-DD.csv files in [--start..--end], pipes the\n\
       parsed snapshots through Ishares_membership_replay.replay, and writes\n\
       a (Pinned ...) universe sexp for [--as-of] (defaults to --end). The\n\
       output sexp shape matches\n\
      \  \
       trading/test_data/backtest_scenarios/universes/broad-3000-2010-01-01.sexp\n\
       so existing consumers (Universe_file.load + scenario runners) work\n\
       unchanged.\n\n\
       Sentinel marker files (.sentinel) in the cache are ignored. Cached\n\
       bodies that contain the iShares no-data template are also skipped at\n\
       parse time. See dev/plans/iwv-scraper-2026-05-16.md §PR-D.")
    (let%map_open.Command cache_dir =
       flag "cache-root"
         (optional_with_default _default_cache_dir string)
         ~doc:"PATH local IWV CSV cache (default: ../dev/data/ishares/iwv)"
     and output =
       flag "output" (required string)
         ~doc:"PATH where to write the universe sexp"
     and from_str =
       flag "start"
         (optional_with_default _default_start_str string)
         ~doc:"YYYY-MM-DD inclusive window start (default: 2006-09-29)"
     and until_str =
       flag "end" (optional string)
         ~doc:"YYYY-MM-DD inclusive window end (default: today UTC)"
     and as_of_str =
       flag "as-of" (optional string)
         ~doc:"YYYY-MM-DD point-in-time membership snapshot (default: --end)"
     and threshold_consecutive_misses =
       flag "threshold-misses"
         (optional_with_default _default_threshold_misses int)
         ~doc:"N consecutive missing snapshots to close a tenure (default: 3)"
     in
     fun () ->
       let until_str =
         match until_str with Some s -> s | None -> Date.to_string (_today ())
       in
       _run ~cache_dir ~output ~from_str ~until_str ~as_of_str
         ~threshold_consecutive_misses)

let () = Command_unix.run command
