(** Smoke tests for [Backtest_optimal.Optimal_strategy_runner.run].

    The runner is the pipeline orchestrator: it loads
    [summary.sexp]/[actual.sexp]/[trades.csv]/[trade_audit.sexp] from a
    [output_dir], builds bar panels from [Data_path.default_data_dir ()], scans
    \+ scores per Friday, and writes [output_dir/optimal_strategy.md].

    These tests exercise the whole pipeline against a synthetic-panel fixture: a
    tmpdir staged with the four artefacts plus a small CSV bar fixture for one
    symbol over a short window, with [TRADING_DATA_DIR] pointed at the staged
    data directory.

    Coverage:
    - [test_run_emits_optimal_strategy_md] — full pipeline produces
      [optimal_strategy.md] with the disclaimer header and the scenario name.
    - [test_run_handles_missing_trade_audit] — same fixture without
      [trade_audit.sexp]; pipeline still completes and the renderer's "no
      rejection annotations" path is exercised.

    The renderer's content contract is pinned by
    [test_optimal_strategy_report.ml]; these tests are not a content audit. *)

open Core
open OUnit2
open Matchers

let _has substring : string matcher =
  field (fun s -> String.is_substring s ~substring) (equal_to true)

(** Stage a single OHLCV CSV under [data_dir/<F>/<L>/<SYM>/data.csv] using the
    canonical [Csv_storage] helpers. [Daily_price.t]s carry full OHLCV fields;
    we set every column to [close] so the bars are bland enough that the scanner
    reliably finds no breakouts (the runner just needs to not crash). *)
let _write_symbol_csv ~data_dir ~symbol prices =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error err ->
      assert_failure (Printf.sprintf "csv create: %s" err.Status.message)
  | Ok storage -> (
      match Csv.Csv_storage.save storage prices with
      | Error err ->
          assert_failure (Printf.sprintf "csv save: %s" err.Status.message)
      | Ok () -> ())

let _make_bar ~date_str ~close () : Types.Daily_price.t =
  {
    date = Date.of_string date_str;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
  }

(** Generate weekday daily bars between [start] and [end_] (inclusive) at a flat
    [close] price. *)
let _flat_bars ~start ~end_ ~close : Types.Daily_price.t list =
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' =
        if is_weekend then acc
        else _make_bar ~date_str:(Date.to_string d) ~close () :: acc
      in
      loop (Date.add_days d 1) acc'
  in
  loop start []

(** Write [data_dir/sectors.csv] with [(symbol, sector)] pairs + a header. *)
let _write_sectors_csv ~data_dir pairs =
  let path = Fpath.(to_string (data_dir / "sectors.csv")) in
  let oc = Out_channel.create path in
  Out_channel.output_string oc "symbol,sector\n";
  List.iter pairs ~f:(fun (sym, sector) ->
      Out_channel.output_string oc (Printf.sprintf "%s,%s\n" sym sector));
  Out_channel.close oc

(** Stage [output_dir/{summary,actual}.sexp] + [output_dir/trades.csv]. *)
let _write_summary_sexp ~output_dir ~start_date ~end_date =
  let path = Filename.concat output_dir "summary.sexp" in
  let body =
    Printf.sprintf
      "((start_date %s) (end_date %s) (universe_size 1) (n_steps 5)\n\
      \ (initial_cash 10000.00) (final_portfolio_value 11000.00)\n\
      \ (n_round_trips 1) (metrics ()))"
      start_date end_date
  in
  Out_channel.write_all path ~data:body

let _write_actual_sexp ~output_dir =
  let path = Filename.concat output_dir "actual.sexp" in
  let body =
    "((total_return_pct 10.00) (total_trades 1.00) (win_rate 100.00)\n\
    \ (sharpe_ratio 0.50) (max_drawdown_pct 2.00)\n\
    \ (avg_holding_days 30.00) (unrealized_pnl 0.00))"
  in
  Out_channel.write_all path ~data:body

let _write_trades_csv ~output_dir =
  let path = Filename.concat output_dir "trades.csv" in
  let header =
    "symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger\n"
  in
  let row =
    "AAA,2024-01-08,2024-02-09,32,100.0,110.0,10,100.0,10.0,95.0,108.0,Stop\n"
  in
  Out_channel.write_all path ~data:(header ^ row)

(** Stage all five artefacts in [output_dir] + an OHLCV fixture in [data_dir].
    Returns nothing — caller asserts on the file the runner writes. *)
let _stage_fixture ~data_dir ~output_dir =
  let bench_bars =
    _flat_bars
      ~start:(Date.of_string "2023-06-01")
      ~end_:(Date.of_string "2024-03-01")
      ~close:4500.0
  in
  let sym_bars =
    _flat_bars
      ~start:(Date.of_string "2023-06-01")
      ~end_:(Date.of_string "2024-03-01")
      ~close:100.0
  in
  _write_symbol_csv ~data_dir ~symbol:"GSPC.INDX" bench_bars;
  _write_symbol_csv ~data_dir ~symbol:"AAA" sym_bars;
  _write_sectors_csv ~data_dir [ ("AAA", "Information Technology") ];
  _write_summary_sexp ~output_dir ~start_date:"2024-01-05"
    ~end_date:"2024-02-23";
  _write_actual_sexp ~output_dir;
  _write_trades_csv ~output_dir

(** Set [TRADING_DATA_DIR] for the duration of a thunk, then restore. *)
let _with_data_dir ~data_dir f =
  let prev = Sys.getenv "TRADING_DATA_DIR" in
  Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:(Fpath.to_string data_dir);
  let result =
    Exn.protect ~f ~finally:(fun () ->
        match prev with
        | Some v -> Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:v
        | None -> Core_unix.unsetenv "TRADING_DATA_DIR")
  in
  result

(** Make + return a fresh tmpdir pair. The dirs leak after the test; the OS will
    reap [/tmp] on its own schedule. *)
let _mk_tmpdirs prefix =
  let data_dir = Fpath.v (Core_unix.mkdtemp ("/tmp/" ^ prefix ^ "_data_")) in
  let output_dir = Core_unix.mkdtemp ("/tmp/" ^ prefix ^ "_out_") in
  (data_dir, output_dir)

let test_run_emits_optimal_strategy_md _ =
  let data_dir, output_dir = _mk_tmpdirs "opt_runner_smoke" in
  _stage_fixture ~data_dir ~output_dir;
  _with_data_dir ~data_dir (fun () ->
      Backtest_optimal.Optimal_strategy_runner.run ~output_dir);
  let report_path = Filename.concat output_dir "optimal_strategy.md" in
  let exists = Sys_unix.file_exists_exn report_path in
  let body = if exists then In_channel.read_all report_path else "" in
  assert_that (exists, body)
    (all_of
       [
         field (fun (e, _) -> e) (equal_to true);
         field
           (fun (_, b) -> b)
           (all_of
              [
                _has "# Optimal-strategy counterfactual";
                _has "**Disclaimer.**";
                (* scenario_name = basename of output_dir, which starts with
                   the [_mk_tmpdirs] prefix. *)
                _has "opt_runner_smoke";
              ]);
       ])

let test_run_handles_missing_trade_audit _ =
  let data_dir, output_dir = _mk_tmpdirs "opt_runner_no_audit" in
  _stage_fixture ~data_dir ~output_dir;
  (* Confirm trade_audit.sexp was never staged. *)
  let audit_path = Filename.concat output_dir "trade_audit.sexp" in
  assert_that (Sys_unix.file_exists_exn audit_path) (equal_to false);
  _with_data_dir ~data_dir (fun () ->
      Backtest_optimal.Optimal_strategy_runner.run ~output_dir);
  let report_path = Filename.concat output_dir "optimal_strategy.md" in
  let body = In_channel.read_all report_path in
  assert_that body
    (all_of
       [
         _has "# Optimal-strategy counterfactual";
         _has "## Trades the actual missed";
         (* "(reason: ..." is the renderer's annotation prefix when an audit
            entry exists for the missed symbol. With no audit at all, no
            missed-trade row should carry this fragment. *)
         field
           (fun s -> String.is_substring s ~substring:"(reason:")
           (equal_to false);
       ])

let suite =
  "Optimal_strategy_runner"
  >::: [
         "run emits optimal_strategy.md" >:: test_run_emits_optimal_strategy_md;
         "run handles missing trade_audit.sexp"
         >:: test_run_handles_missing_trade_audit;
       ]

let () = run_test_tt_main suite
