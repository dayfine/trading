(** Parity test for the two bar-source paths of {!Weekly_snapshot_generator}.

    Proves that the snapshot produced by feeding the generator a
    {b snapshot-warehouse-backed} bar reader ([Snapshot_warehouse_reader.build])
    is {b identical} to the one produced via the legacy {b in-memory CSV} bar
    reader ([Bar_reader.of_in_memory_bars]) for the same fixture universe +
    as-of date.

    The warehouse is built end-to-end with the real [build_snapshots] build path
    ([Build_runner.build]) over the same synthetic bars written to a temp CSV
    store, so the test also exercises the build -> read pipeline the production
    warehouse will use. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot
module Bar_reader = Weinstein_strategy.Bar_reader
module Generator = Weinstein_snapshot_gen.Weekly_snapshot_generator

module Snapshot_warehouse_reader =
  Weinstein_snapshot_gen.Snapshot_warehouse_reader

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)
let _index_symbol = "GSPCX"
let _as_of = Date.of_string "2022-10-07"
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

(* Write [bars] for [symbol] into the [Csv_storage] layout under [data_dir]. *)
let _write_csv ~data_dir ~symbol ~bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> assert_failure ("Csv_storage.create failed: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage bars with
      | Ok () -> ()
      | Error e -> assert_failure ("Csv_storage.save failed: " ^ Status.show e))

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

(* Build a snapshot warehouse from the CSV store and return a reader over it. *)
let _warehouse_bar_reader ~csv_data_dir =
  let warehouse_dir = Stdlib.Filename.temp_dir "weekly_snap_parity_wh" "" in
  let symbols = _index_symbol :: List.map _ticker_sectors ~f:fst in
  Build_runner.build ~symbols ~csv_data_dir ~output_dir:warehouse_dir
    ~benchmark_symbol:None
    ~start_date:(Some (Date.add_days _as_of (-_warmup_days)))
    ~end_date:(Some _as_of) ~incremental:false
    ~progress_every:Build_runner.default_progress_every ();
  Snapshot_warehouse_reader.build ~warehouse_dir ~as_of:_as_of
    ~warmup_days:_warmup_days ()

(* The fixture's bars written once to a shared temp CSV store, then read two
   ways. *)
let _csv_data_dir =
  lazy
    (let dir = Stdlib.Filename.temp_dir "weekly_snap_parity_csv" "" in
     List.iter (_index_symbol :: List.map _ticker_sectors ~f:fst)
       ~f:(fun symbol ->
         _write_csv ~data_dir:dir ~symbol ~bars:(_bars_for symbol));
     dir)

let _in_memory_bar_reader () =
  Bar_reader.of_in_memory_bars
    (List.map (_index_symbol :: List.map _ticker_sectors ~f:fst)
       ~f:(fun symbol -> (symbol, _bars_for symbol)))

(* The warehouse-backed snapshot equals the in-memory-CSV snapshot exactly. *)
let test_warehouse_matches_csv _ =
  let csv_data_dir = Lazy.force _csv_data_dir in
  let csv_snapshot = _generate ~bar_reader:(_in_memory_bar_reader ()) in
  let warehouse_snapshot =
    _generate ~bar_reader:(_warehouse_bar_reader ~csv_data_dir)
  in
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
