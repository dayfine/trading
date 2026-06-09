(** Walk-forward snapshot-mode parity gate.

    [walk_forward_runner.exe --snapshot-dir] threads a
    [Backtest.Bar_data_source.t] through {!Walk_forward.Walk_forward_executor}
    into every fold's {!Backtest.Runner.run_backtest}, so broad-universe (N >=
    1000) WF-CV can read OHLCV from a pre-built snapshot warehouse instead of
    building the whole universe's bars in-process from CSVs (the latter is
    superlinear and OOMs at N >= 1000). Snapshot is purely a faster bar backend:
    on the same input bars it must produce per-fold metrics identical to CSV
    mode.

    Two properties are pinned here:

    + {b End-to-end parity.} Build the same synthetic OHLCV stream into BOTH a
      CSV directory (pointed at via [TRADING_DATA_DIR]) and a snapshot
      directory, then run the same 2-fold walk-forward spec in CSV mode (no bar
      source) and snapshot mode ([Some (Snapshot {...})]). The two runs'
      [aggregate] and [fold_actuals] must be byte-identical (sexp round-trip
      preserves IEEE 754 bit patterns). The synthetic stream covers every symbol
      a default run reads — universe + index + SPDR ETFs + global indices, via
      {!Backtest.Runner.all_snapshot_symbols} — so neither mode degenerates on a
      missing macro column.

    + {b Flag-off backward-compat.} At the {!Walk_forward.Walk_forward_executor}
      seam, passing [?bar_data_source:None] explicitly is byte-identical to
      omitting it. Pins that adding the optional argument did not change the CSV
      default path. Exercised with a deterministic stub runner so it needs no
      backtest. *)

open OUnit2
open Core
open Matchers
module Executor = Walk_forward.Walk_forward_executor
module Spec = Walk_forward.Spec
module WS = Walk_forward.Window_spec
module WFR = Walk_forward.Walk_forward_runner
module Report = Walk_forward.Walk_forward_report
module Fold_gate = Walk_forward.Fold_gate
module Scenario = Scenario_lib.Scenario
module Bar_data_source = Backtest.Bar_data_source
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Pipeline = Snapshot_pipeline.Pipeline
module Daily_panels = Snapshot_runtime.Daily_panels

(* ---- Test tunables (named so the magic-number linter sees no surprises) ---- *)

let _baseline_label = "baseline"
let _universe_symbols = [ "AAPL"; "MSFT"; "JPM" ]
let _fixture_n_days = 420

(* ---- Date helpers ------------------------------------------------- *)

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d
let _fixture_start = _ymd 2020 1 2

(* ---- Synthetic OHLCV fixtures ------------------------------------- *)

(* Deterministic per-(symbol, day_index) bars: a gentle uptrend with a small
   per-symbol offset. Identical generation for both the CSV and snapshot writers
   so any drift is a backend mismatch, not a data mismatch. Volumes stay well
   under 2^53 so the float round-trip is exact. *)
let _make_bar ~symbol ~day_index : Types.Daily_price.t =
  let date = Date.add_days _fixture_start day_index in
  let base = 100.0 +. (Float.of_int (String.hash symbol mod 40) *. 0.25) in
  let drift = Float.of_int day_index *. 0.05 in
  let close = base +. drift in
  {
    date;
    open_price = close -. 0.10;
    high_price = close +. 0.20;
    low_price = close -. 0.30;
    close_price = close;
    volume = 1_000_000 + (day_index * 1000);
    adjusted_close = close;
    active_through = None;
  }

let _bars_for ~symbol =
  List.init _fixture_n_days ~f:(fun i -> _make_bar ~symbol ~day_index:i)

let _make_tmp_dir prefix = Filename_unix.temp_dir ~in_dir:"/tmp" prefix ""

(* CSV writer: emits the canonical 7-column schema [Csv_storage] reads, in the
   nested data_dir/<F>/<L>/<SYM>/data.csv layout the CSV [Market_data_adapter]
   expects. [%.17g] is round-trip-exact for IEEE 754 doubles so the CSV-read
   bars equal the snapshot-carried bars bit-for-bit. *)
let _write_csv_dir ~data_dir bars_by_symbol =
  List.iter bars_by_symbol ~f:(fun (symbol, bars) ->
      let f = String.sub symbol ~pos:0 ~len:1 in
      let l = String.sub symbol ~pos:(String.length symbol - 1) ~len:1 in
      let dir = Filename.of_parts [ data_dir; f; l; symbol ] in
      Core_unix.mkdir_p dir;
      let path = Filename.concat dir "data.csv" in
      Out_channel.with_file path ~f:(fun oc ->
          Out_channel.output_string oc
            "date,open,high,low,close,adjusted_close,volume\n";
          List.iter bars ~f:(fun (b : Types.Daily_price.t) ->
              Out_channel.output_string oc
                (sprintf "%s,%.17g,%.17g,%.17g,%.17g,%.17g,%d\n"
                   (Date.to_string b.date) b.open_price b.high_price b.low_price
                   b.close_price b.adjusted_close b.volume))))

(* Snapshot writer: one [.snap] per symbol via the Phase B pipeline + Phase A
   file format, plus the directory manifest (returned for the test to hand to
   [Bar_data_source.Snapshot]). *)
let _write_snapshot_dir ~snapshot_dir bars_by_symbol =
  let schema = Snapshot_schema.default in
  let entries =
    List.map bars_by_symbol ~f:(fun (symbol, bars) ->
        let rows =
          match Pipeline.build_for_symbol ~symbol ~bars ~schema () with
          | Ok r -> r
          | Error err ->
              assert_failure ("Pipeline.build_for_symbol: " ^ Status.show err)
        in
        let path = Filename.concat snapshot_dir (symbol ^ ".snap") in
        (match Snapshot_format.write ~path rows with
        | Ok () -> ()
        | Error err ->
            assert_failure ("Snapshot_format.write: " ^ Status.show err));
        let stat = Core_unix.stat path in
        ({
           symbol;
           path;
           byte_size = Int64.to_int_exn stat.st_size;
           payload_md5 = "ignored";
           csv_mtime = stat.st_mtime;
           active_through = None;
         }
          : Snapshot_manifest.file_metadata))
  in
  Snapshot_manifest.create ~schema ~entries

(* Build BOTH a CSV directory and a snapshot directory from the same synthetic
   bar stream, covering every symbol a default Weinstein run reads (universe +
   index + ETFs + global indices). Returns [(data_dir, snapshot_dir, manifest)].
*)
let _setup_dual_fixtures () =
  let symbols =
    Backtest.Runner.all_snapshot_symbols ~universe:_universe_symbols
  in
  let data_dir = _make_tmp_dir "wf_parity_csv_" in
  let snapshot_dir = _make_tmp_dir "wf_parity_snap_" in
  let bars_by_symbol =
    List.map symbols ~f:(fun s -> (s, _bars_for ~symbol:s))
  in
  _write_csv_dir ~data_dir bars_by_symbol;
  let manifest = _write_snapshot_dir ~snapshot_dir bars_by_symbol in
  (data_dir, snapshot_dir, manifest)

(* ---- Universe file + scenario ------------------------------------- *)

(* Write a [Pinned] universe sexp under the fixtures root and return the path
   relative to that root (what [Scenario.universe_path] holds). Each symbol maps
   to its own sector so [to_sector_map_override] yields exactly these keys as the
   backtest universe (bypassing [Sector_map.load]). *)
let _write_universe ~fixtures_root : string =
  let rel = Filename.of_parts [ "universes"; "wf-parity.sexp" ] in
  let abs = Filename.concat fixtures_root rel in
  Core_unix.mkdir_p (Filename.dirname abs);
  let entries =
    List.map _universe_symbols ~f:(fun s ->
        sprintf "((symbol %s) (sector %s))" s s)
    |> String.concat ~sep:" "
  in
  Out_channel.write_all abs ~data:(sprintf "(Pinned (%s))" entries);
  rel

let _wide_expected : Scenario.expected =
  {
    total_return_pct = { min_f = -100.0; max_f = 1000.0 };
    total_trades = { min_f = 0.0; max_f = 10000.0 };
    win_rate = { min_f = 0.0; max_f = 100.0 };
    sharpe_ratio = { min_f = -5.0; max_f = 5.0 };
    max_drawdown_pct = { min_f = 0.0; max_f = 100.0 };
    avg_holding_days = { min_f = 0.0; max_f = 1000.0 };
    open_positions_value = None;
    unrealized_pnl = None;
    sortino_ratio_annualized = None;
    calmar_ratio = None;
    ulcer_index = None;
    wall_seconds = None;
  }

let _make_base ~universe_path : Scenario.t =
  {
    name = "wf-parity-base";
    description = "synthetic dual-fixture base scenario";
    period = { start_date = _fixture_start; end_date = _ymd 2021 1 1 };
    universe_path;
    config_overrides = [];
    strategy = Backtest.Strategy_choice.default;
    slippage_bps = None;
    cost_model = None;
    expected = _wide_expected;
  }

(* Two adjacent test folds inside the fixture window. [Explicit] folds keep the
   test independent of the rolling generator's arithmetic. The single
   [baseline] variant runs each fold once — exactly what we compare across
   backends. *)
let _make_spec : Spec.t =
  let folds : WS.explicit_fold list =
    [
      {
        name = "fold-000";
        train_period = None;
        test_period = { start_date = _ymd 2020 4 1; end_date = _ymd 2020 8 1 };
      };
      {
        name = "fold-001";
        train_period = None;
        test_period = { start_date = _ymd 2020 8 1; end_date = _ymd 2020 12 1 };
      };
    ]
  in
  {
    base_scenario = "wf-parity-base";
    window_spec = WS.Explicit folds;
    variants = [ { WFR.label = _baseline_label; overrides = [] } ];
    baseline_label = _baseline_label;
    gate = { metric = Fold_gate.Sharpe; m = 1; n = 2; worst_delta = 1.0 };
  }

(* ---- §1 End-to-end snapshot/CSV parity ---------------------------- *)

let _run_mode ~fixtures_root ~base ?bar_data_source () : Executor.result =
  Executor.execute_spec ~base ~spec:_make_spec ~fixtures_root ~parallel:1
    ?bar_data_source ()

(* CSV mode reads bars from [TRADING_DATA_DIR]. Point it at [data_dir] for the
   duration of [f], then restore the prior value so OUnit's end-of-test
   environment-stability guard does not flag the mutation. *)
let _with_data_dir data_dir ~f =
  let key = "TRADING_DATA_DIR" in
  let prior = Sys.getenv key in
  Core_unix.putenv ~key ~data:data_dir;
  Exn.protect ~f ~finally:(fun () ->
      match prior with
      | Some v -> Core_unix.putenv ~key ~data:v
      | None -> Core_unix.unsetenv key)

let test_snapshot_csv_aggregate_parity _ =
  let data_dir, snapshot_dir, manifest = _setup_dual_fixtures () in
  let fixtures_root = _make_tmp_dir "wf_parity_fixtures_" in
  let universe_path = _write_universe ~fixtures_root in
  let base = _make_base ~universe_path in
  let csv_sexp, snap_sexp =
    _with_data_dir data_dir ~f:(fun () ->
        let csv_result = _run_mode ~fixtures_root ~base () in
        let snap_result =
          _run_mode ~fixtures_root ~base
            ~bar_data_source:
              (Bar_data_source.Snapshot { snapshot_dir; manifest })
            ()
        in
        let to_sexp (r : Executor.result) =
          ( Report.sexp_of_aggregate r.aggregate,
            Sexp.List (List.map r.fold_actuals ~f:Report.sexp_of_fold_actual) )
        in
        (to_sexp csv_result, to_sexp snap_result))
  in
  (* Aggregate AND fold_actuals must be byte-identical: snapshot is just a
     faster bar backend over the same series. *)
  assert_that (snd snap_sexp) (equal_to (snd csv_sexp));
  assert_that (fst snap_sexp) (equal_to (fst csv_sexp))

(* ---- §2 Flag-off backward-compat (executor seam, no backtest) ----- *)

(** Deterministic stub: maps a scenario name to a fixed [fold_actual] so the
    flag-off comparison runs in milliseconds without a real backtest. The stub
    ignores [?bar_data_source] entirely (production wiring captures it; the stub
    seam does not), which is exactly the contract we pin: at this seam, omitting
    vs. explicitly passing [None] must be identical. *)
let _stub_runner (s : Scenario.t) : Report.fold_actual =
  let f = Float.of_int (String.hash s.name mod 1000) in
  {
    fold_name = "";
    variant_label = "";
    total_return_pct = f;
    sharpe_ratio = f /. 100.0;
    max_drawdown_pct = (f /. 10.0) +. 1.0;
    calmar_ratio = (f /. 50.0) +. 0.1;
    cagr_pct = (f /. 2.0) +. 0.5;
    avg_holding_days = (f /. 5.0) +. 7.0;
  }

let _stub_aggregate ?bar_data_source () : Sexp.t =
  let base = _make_base ~universe_path:"unused-by-stub" in
  let result =
    Executor.execute_spec ~base ~spec:_make_spec
      ~fixtures_root:"/tmp/unused-by-stub" ~parallel:1 ?bar_data_source
      ~run_one:_stub_runner ()
  in
  Report.sexp_of_aggregate result.aggregate

let test_flag_off_is_byte_identical_to_none _ =
  let omitted = _stub_aggregate () in
  let explicit_none = _stub_aggregate ?bar_data_source:None () in
  assert_that explicit_none (equal_to omitted)

(* ---- §3 Shared-panel cache reuse across folds ---------------------- *)

(* Sector-map override for the fixture universe so [run_backtest] trades over
   exactly these symbols (one sector each) without touching [data/sectors.csv].
   Mirrors what [Universe_file.to_sector_map_override] produces from the Pinned
   universe written by [_write_universe]. *)
let _fixture_sector_map () =
  let tbl = Hashtbl.create (module String) in
  List.iter _universe_symbols ~f:(fun s -> Hashtbl.set tbl ~key:s ~data:s);
  tbl

(* Run one fold's backtest in snapshot mode through a caller-owned shared cache.
   The two adjacent test folds match [_make_spec]'s windows. *)
let _run_fold_shared ~snapshot_dir ~manifest ~panels ~start ~end_ =
  let _ : Backtest.Runner.result =
    Backtest.Runner.run_backtest ~start_date:start ~end_date:end_
      ~sector_map_override:(_fixture_sector_map ())
      ~bar_data_source:(Bar_data_source.Snapshot { snapshot_dir; manifest })
      ~shared_panels:panels ()
  in
  ()

(* The load-bearing regression for the [~shared_panels] cache-reuse contract:
   two backtests over the SAME shared [Daily_panels.t], in one process, must
   decode each symbol only ONCE — the second backtest reads what the first
   decoded. This is the in-process half of the broad-universe fix: the executor
   forks each fold (so a fold's transient heap + the N=3000 GC-residue die with
   the child), and within whichever process reads through a shared handle,
   [Panel_runner.run] must NOT close the caller-owned cache, so a second read
   reuses the first's decode instead of re-decoding.

   Three exact invariants, each its own value + assert:
   - The first backtest decodes a real working set: misses > 0 after fold-0.
   - The second backtest adds ZERO new misses for symbols fold-0 already decoded
     — a strictly-smaller delta than a full re-decode. The pre-fix path (each
     backtest creates + CLOSES its own cache) would re-decode the whole set, so
     the delta would equal the first backtest's misses.
   - [evictions = 0] throughout, so the small fixture's working set never falls
     out of the LRU (which would manufacture spurious re-decodes). *)
let test_shared_panels_reused_across_backtests _ =
  let _data_dir, snapshot_dir, manifest = _setup_dual_fixtures () in
  let panels =
    match
      Bar_data_source.build_shared_panels
        (Bar_data_source.Snapshot { snapshot_dir; manifest })
    with
    | Ok (Some p) -> p
    | Ok None -> assert_failure "expected Some panels for Snapshot source"
    | Error err ->
        assert_failure ("build_shared_panels failed: " ^ Status.show err)
  in
  let run start end_ =
    _run_fold_shared ~snapshot_dir ~manifest ~panels ~start ~end_
  in
  run (_ymd 2020 4 1) (_ymd 2020 8 1);
  let misses_after_first = (Daily_panels.cache_stats panels).misses in
  run (_ymd 2020 8 1) (_ymd 2020 12 1);
  let stats = Daily_panels.cache_stats panels in
  Daily_panels.close panels;
  let second_run_miss_delta = stats.misses - misses_after_first in
  assert_that misses_after_first (gt (module Int_ord) 0);
  assert_that second_run_miss_delta (lt (module Int_ord) misses_after_first);
  assert_that stats.evictions (equal_to 0)

let suite =
  "Walk_forward_snapshot_parity"
  >::: [
         "test_snapshot_csv_aggregate_parity"
         >:: test_snapshot_csv_aggregate_parity;
         "test_flag_off_is_byte_identical_to_none"
         >:: test_flag_off_is_byte_identical_to_none;
         "test_shared_panels_reused_across_backtests"
         >:: test_shared_panels_reused_across_backtests;
       ]

let () = run_test_tt_main suite
