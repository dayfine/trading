(** Parity test for the two bar-source paths of {!Weekly_snapshot_generator}.

    Proves that the snapshot produced by feeding the generator a
    {b snapshot-warehouse-backed} bar reader ([Snapshot_warehouse_reader.build])
    is {b identical} to the one produced via the legacy {b in-memory CSV} bar
    reader ([Bar_reader.of_in_memory_bars]) for the same fixture universe +
    as-of date.

    The warehouse is built in-test from the same synthetic bars using the
    production warehouse libs the offline [build_snapshots] writer is built on —
    [Pipeline.build_for_symbol] for the per-day snapshot rows,
    [Snapshot_columnar.write] for each per-symbol [.snap] file, and
    [Snapshot_manifest.write] for the directory manifest. This mirrors the
    [build_snapshots] build path ([Build_runner.build]) row-for-row without
    depending on [analysis/scripts] — a [trading/trading/**] test must not
    import from there (architecture A2 import rule). The test still exercises
    the build -> read pipeline the production warehouse uses. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot
module Bar_reader = Weinstein_strategy.Bar_reader
module Generator = Weinstein_snapshot_gen.Weekly_snapshot_generator
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

module Snapshot_warehouse_reader =
  Weinstein_snapshot_gen.Snapshot_warehouse_reader

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)
let _index_symbol = "GSPCX"
let _as_of = Date.of_string "2022-09-16"
let _system_version = "parity-sha"

(* Same synthetic shapes the generator's own test uses: an AAPL 40-week-base
   breakout that screens Stage-2, plus a trending index. *)
let _syn_config : Synthetic_source.config =
  {
    start_date = Date.of_string "2022-01-01";
    symbols =
      [
        ( "AAPL",
          Breakout
            {
              base_price = 150.0;
              base_weeks = 40;
              weekly_gain_pct = 0.02;
              breakout_volume_mult = 3.0;
              base_volume = 50_000_000;
            } );
        ( _index_symbol,
          Trending
            {
              start_price = 4500.0;
              weekly_gain_pct = 0.005;
              volume = 1_000_000_000;
            } );
      ];
  }

let _ticker_sectors = [ ("AAPL", "Information Technology") ]

let _bars_for symbol : Types.Daily_price.t list =
  let ds = Synthetic_source.make _syn_config in
  let module DS = (val ds : Data_source.DATA_SOURCE) in
  let query : Data_source.bar_query =
    {
      symbol;
      period = Types.Cadence.Daily;
      start_date = Some _syn_config.start_date;
      end_date = None;
    }
  in
  match run_deferred (DS.get_bars ~query ()) with
  | Ok bars -> bars
  | Error e -> assert_failure ("get_bars failed: " ^ Status.show e)

let _config : Weinstein_strategy.config =
  let base =
    Weinstein_strategy.default_config
      ~universe:(List.map _ticker_sectors ~f:fst)
      ~index_symbol:_index_symbol
  in
  { base with sector_etfs = Weinstein_strategy.Macro_inputs.spdr_sector_etfs }

let _generate ~bar_reader =
  Generator.generate
    {
      config = _config;
      system_version = _system_version;
      as_of = _as_of;
      bar_reader;
      ticker_sectors = _ticker_sectors;
      held_positions = [];
    }

(* The same warmup the bin passes to [Snapshot_warehouse_reader.build]; the
   warehouse window is built to match so it holds every fixture bar. *)
let _warmup_days = 730

(* Write one symbol's [.snap] file via the production columnar writer and return
   its manifest entry. Mirrors [Build_runner._build_one_symbol]: build per-day
   rows with [Pipeline.build_for_symbol], then emit them with
   [Snapshot_columnar.write] — the same two steps the offline writer uses, minus
   the CSV-loading + checkpointing scaffolding that lives in [analysis/scripts].
   The manifest's checksum/mtime metadata is unused by the runtime reader, so
   placeholder values are fine; [active_through] tracks the bars' delisting
   marker as the production writer does. *)
let _write_snapshot ~output_dir ~schema ~symbol ~bars :
    Snapshot_manifest.file_metadata =
  let path = Filename.concat output_dir (symbol ^ ".snap") in
  let rows =
    match Pipeline.build_for_symbol ~symbol ~bars ~schema () with
    | Ok rows -> rows
    | Error e -> assert_failure ("build_for_symbol failed: " ^ Status.show e)
  in
  (match Snapshot_columnar.write ~path rows with
  | Ok () -> ()
  | Error e ->
      assert_failure ("Snapshot_columnar.write failed: " ^ Status.show e));
  let active_through =
    List.last bars
    |> Option.bind ~f:(fun (b : Types.Daily_price.t) -> b.active_through)
  in
  {
    Snapshot_manifest.symbol;
    path;
    byte_size = 0;
    payload_md5 = "";
    csv_mtime = 0.0;
    active_through;
  }

(* Build a snapshot warehouse from the fixture bars and return a reader over it.
   No CSV round-trip: the bars are written straight into per-symbol [.snap]
   files plus a directory manifest, then read back via the production
   [Snapshot_warehouse_reader]. *)
let _warehouse_bar_reader () =
  let warehouse_dir = Stdlib.Filename.temp_dir "weekly_snap_parity_wh" "" in
  let schema = Snapshot_schema.default in
  let symbols = _index_symbol :: List.map _ticker_sectors ~f:fst in
  let entries =
    List.map symbols ~f:(fun symbol ->
        _write_snapshot ~output_dir:warehouse_dir ~schema ~symbol
          ~bars:(_bars_for symbol))
  in
  let manifest_path = Filename.concat warehouse_dir "manifest.sexp" in
  (match
     Snapshot_manifest.write ~path:manifest_path
       (Snapshot_manifest.create ~schema ~entries)
   with
  | Ok () -> ()
  | Error e ->
      assert_failure ("Snapshot_manifest.write failed: " ^ Status.show e));
  Snapshot_warehouse_reader.build ~warehouse_dir ~as_of:_as_of
    ~warmup_days:_warmup_days ()

let _in_memory_bar_reader () =
  Bar_reader.of_in_memory_bars
    (List.map (_index_symbol :: List.map _ticker_sectors ~f:fst)
       ~f:(fun symbol -> (symbol, _bars_for symbol)))

(* The warehouse-backed snapshot equals the in-memory-CSV snapshot exactly. *)
let test_warehouse_matches_csv _ =
  let csv_snapshot = _generate ~bar_reader:(_in_memory_bar_reader ()) in
  let warehouse_snapshot = _generate ~bar_reader:(_warehouse_bar_reader ()) in
  assert_that warehouse_snapshot (equal_to (csv_snapshot : Weekly_snapshot.t))

(* Sanity guard: the parity fixture actually screens a candidate, so the
   equality above is over a non-degenerate snapshot (not two empty ones). *)
let test_fixture_screens_a_candidate _ =
  let csv_snapshot = _generate ~bar_reader:(_in_memory_bar_reader ()) in
  assert_that (csv_snapshot : Weekly_snapshot.t).long_candidates (size_is 1)

let suite =
  "snapshot_warehouse_parity"
  >::: [
         "warehouse-backed snapshot equals in-memory-CSV snapshot"
         >:: test_warehouse_matches_csv;
         "parity fixture screens a long candidate"
         >:: test_fixture_screens_a_candidate;
       ]

let () = run_test_tt_main suite
