(** End-to-end pinning of {!Backtest.Result_writer.write}'s [trades.csv]
    [exit_trigger] override (PR #695, qc-behavioral B2).

    The backtest layer produces [trades.csv] rows whose [exit_trigger] column is
    the standard {!Backtest.Stop_log.exit_trigger} label by default
    (["stop_loss"], ["take_profit"], etc.) but overridden to
    ["force_liquidation_position"] / ["force_liquidation_portfolio"] when the
    same [(symbol, exit_date)] tuple appears in [result.force_liquidations]. The
    literal label strings live only in [result_writer.ml] and were previously
    not asserted by any test — these tests pin them end-to-end so a refactor
    that drifts the strings or breaks the substitution rule fails
    deterministically.

    Also pins the reconciler-producer artefacts ([open_positions.csv],
    [splits.csv], [final_prices.csv]) — see
    [~/Projects/trading-reconciler/PHASE_1_SPEC.md]. The reconciler validates
    these files on header match and exits 2 on drift, so tests pin both the
    header and the row format strictly. *)

open Core
open OUnit2
open Matchers
module FL = Portfolio_risk.Force_liquidation

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _date = Date.of_string

let _make_trade ?(symbol = "AAPL") ?(side = Trading_base.Types.Buy)
    ?(entry_date = _date "2024-01-02") ?(exit_date = _date "2024-04-29")
    ?(entry_price = 100.0) ?(exit_price = 40.0) ?(quantity = 100.0) () :
    Trading_simulation.Metrics.trade_metrics =
  let days_held = Date.diff exit_date entry_date in
  {
    symbol;
    side;
    entry_date;
    exit_date;
    days_held;
    entry_price;
    exit_price;
    quantity;
    pnl_dollars = (exit_price -. entry_price) *. quantity;
    pnl_percent = (exit_price -. entry_price) /. entry_price *. 100.0;
  }

(** Build a force-liquidation event matching a trade by [(symbol, exit_date)].
    The runner-side path always feeds [event.date = exit_date] for the close leg
    of the round-trip, so the [(symbol, date)] join key in
    [_build_force_liq_index] hits this row. *)
let _make_event ~symbol ~exit_date ~reason : FL.event =
  {
    symbol;
    position_id = symbol ^ "-1";
    date = exit_date;
    side = Trading_base.Types.Long;
    entry_price = 100.0;
    current_price = 40.0;
    quantity = 100.0;
    cost_basis = 10_000.0;
    unrealized_pnl = -6_000.0;
    unrealized_pnl_pct = -0.6;
    reason;
  }

let _empty_summary ~start_date ~end_date : Backtest.Summary.t =
  {
    start_date;
    end_date;
    universe_size = 1;
    n_steps = 1;
    initial_cash = 100_000.0;
    final_portfolio_value = 100_000.0;
    n_round_trips = 1;
    metrics = Trading_simulation_types.Metric_types.empty;
  }

let _make_result ?(steps = []) ?(final_prices = []) ~round_trips
    ~force_liquidations () : Backtest.Runner.result =
  let start_date = _date "2024-01-02" in
  let end_date = _date "2024-04-29" in
  {
    summary = _empty_summary ~start_date ~end_date;
    round_trips;
    steps;
    overrides = [];
    stop_infos = [];
    audit = [];
    cascade_summaries = [];
    force_liquidations;
    final_prices;
  }

(** Build a [Trading_portfolio.Types.portfolio_position] with a single lot. The
    [quantity] sign carries the side: positive for longs, negative for shorts.
    [cost_basis] is the {e total} cost (entry_price × quantity), preserving the
    invariant {!Trading_portfolio.Calculations.avg_cost_of_position} relies on.
*)
let _make_position ~symbol ~quantity ~entry_price ~entry_date :
    Trading_portfolio.Types.portfolio_position =
  let cost_basis = entry_price *. Float.abs quantity in
  {
    symbol;
    accounting_method = Trading_portfolio.Types.AverageCost;
    lots =
      [
        {
          lot_id = symbol ^ "-1";
          quantity;
          cost_basis;
          acquisition_date = entry_date;
        };
      ];
  }

let _make_portfolio ~positions : Trading_portfolio.Portfolio.t =
  {
    initial_cash = 100_000.0;
    trade_history = [];
    current_cash = 50_000.0;
    positions;
    accounting_method = Trading_portfolio.Types.AverageCost;
    unrealized_pnl_per_position = [];
  }

(** Build a [step_result] with the supplied portfolio + splits_applied. The
    [date] is the step's date; [trades] / [orders_submitted] are empty because
    the reconciler artefacts under test consume only [portfolio] (open
    positions) and [splits_applied] (split events). *)
let _make_step ~date ~portfolio ?(splits_applied = []) () :
    Trading_simulation_types.Simulator_types.step_result =
  {
    date;
    portfolio;
    portfolio_value = portfolio.Trading_portfolio.Portfolio.current_cash;
    trades = [];
    orders_submitted = [];
    splits_applied;
  }

(** Read a header-and-rows CSV back as [(header_columns, row_columns_list)].
    Each row is split on [,]. Mirrors [_read_trades_csv] but generalized so the
    new tests can read any of the three new CSVs through one helper. *)
let _read_csv ~path =
  match In_channel.read_lines path with
  | header :: rows ->
      let header_cols = String.split header ~on:',' in
      let rows_cols = List.map rows ~f:(fun r -> String.split r ~on:',') in
      (header_cols, rows_cols)
  | [] -> assert_failure ("CSV missing or empty: " ^ path)

(** Read [trades.csv] back into [(header, rows)] where [rows] are split on the
    first comma so callers can index into specific columns by header position
    without re-parsing CSV. *)
let _read_trades_csv ~output_dir =
  let path = output_dir ^ "/trades.csv" in
  match In_channel.read_lines path with
  | header :: rows ->
      let header_cols = String.split header ~on:',' in
      let rows_cols = List.map rows ~f:(fun r -> String.split r ~on:',') in
      (header_cols, rows_cols)
  | [] -> assert_failure ("trades.csv missing or empty: " ^ path)

(** Index of the [exit_trigger] column. Hard-pinning the column position here
    would mask drift; we look it up from the header instead. *)
let _exit_trigger_idx header =
  match
    List.findi header ~f:(fun _ name -> String.equal name "exit_trigger")
  with
  | Some (i, _) -> i
  | None -> assert_failure "exit_trigger column not present in trades.csv"

(* ------------------------------------------------------------------ *)
(* B2.1 — Per_position event labels exit_trigger                       *)
(* ------------------------------------------------------------------ *)

let test_per_position_force_liq_overrides_exit_trigger _ =
  let dir = Core_unix.mkdtemp "/tmp/result_writer_per_pos_" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () ->
      let exit_date = _date "2024-04-29" in
      let trade = _make_trade ~symbol:"AAPL" ~exit_date () in
      let event =
        _make_event ~symbol:"AAPL" ~exit_date ~reason:FL.Per_position
      in
      let result =
        _make_result ~round_trips:[ trade ] ~force_liquidations:[ event ] ()
      in
      Backtest.Result_writer.write ~output_dir:dir result;
      let header, rows = _read_trades_csv ~output_dir:dir in
      let idx = _exit_trigger_idx header in
      assert_that rows
        (elements_are
           [
             field
               (fun cols -> List.nth_exn cols idx)
               (equal_to "force_liquidation_position");
           ]))

(* ------------------------------------------------------------------ *)
(* B2.2 — Portfolio_floor event labels exit_trigger                    *)
(* ------------------------------------------------------------------ *)

let test_portfolio_floor_force_liq_overrides_exit_trigger _ =
  let dir = Core_unix.mkdtemp "/tmp/result_writer_floor_" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () ->
      let exit_date = _date "2024-04-29" in
      let trade = _make_trade ~symbol:"TSLA" ~exit_date () in
      let event =
        _make_event ~symbol:"TSLA" ~exit_date ~reason:FL.Portfolio_floor
      in
      let result =
        _make_result ~round_trips:[ trade ] ~force_liquidations:[ event ] ()
      in
      Backtest.Result_writer.write ~output_dir:dir result;
      let header, rows = _read_trades_csv ~output_dir:dir in
      let idx = _exit_trigger_idx header in
      assert_that rows
        (elements_are
           [
             field
               (fun cols -> List.nth_exn cols idx)
               (equal_to "force_liquidation_portfolio");
           ]))

(* ------------------------------------------------------------------ *)
(* B2.3 — Non-matching event does NOT override exit_trigger            *)
(* ------------------------------------------------------------------ *)

(** The override is keyed on [(symbol, exit_date)]. A force-liquidation event
    with a non-matching symbol or date must NOT override the row — pin the join
    precision so a refactor that broadens the key doesn't silently relabel
    unrelated trades. *)
let test_non_matching_event_does_not_override _ =
  let dir = Core_unix.mkdtemp "/tmp/result_writer_no_match_" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () ->
      let trade =
        _make_trade ~symbol:"AAPL" ~exit_date:(_date "2024-04-29") ()
      in
      (* Same symbol, different exit_date — no join hit. *)
      let event =
        _make_event ~symbol:"AAPL" ~exit_date:(_date "2024-05-15")
          ~reason:FL.Per_position
      in
      let result =
        _make_result ~round_trips:[ trade ] ~force_liquidations:[ event ] ()
      in
      Backtest.Result_writer.write ~output_dir:dir result;
      let header, rows = _read_trades_csv ~output_dir:dir in
      let idx = _exit_trigger_idx header in
      (* No matching event + no stop_info → blank exit_trigger. The point
         is just that it is NOT one of the force-liquidation labels. *)
      assert_that rows
        (elements_are
           [
             field
               (fun cols ->
                 String.is_prefix (List.nth_exn cols idx)
                   ~prefix:"force_liquidation")
               (equal_to false);
           ]))

(* ------------------------------------------------------------------ *)
(* Reconciler-producer artefacts                                        *)
(*                                                                      *)
(* PHASE_1_SPEC.md §3 + §4 + §3.3 schemas pinned end-to-end. The        *)
(* downstream reconciler validates files on header match and exits 2 on *)
(* any drift, so these tests assert both the header text and the row    *)
(* shape exactly.                                                       *)
(* ------------------------------------------------------------------ *)

(** Run [Result_writer.write] inside a temp directory, then pass the directory
    path to [k]. The directory is removed even on test failure. *)
let _with_writer_output ~result ~prefix k =
  let dir = Core_unix.mkdtemp prefix in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () ->
      Backtest.Result_writer.write ~output_dir:dir result;
      k dir)

(* ------------------------------------------------------------------ *)
(* open_positions.csv                                                   *)
(* ------------------------------------------------------------------ *)

(** Per PHASE_1_SPEC §3, the file has columns
    [symbol,side,entry_date,entry_price,quantity] with one row per Holding
    position at run end, [side] is uppercase (LONG / SHORT), [entry_date] is
    [YYYY-MM-DD], and [quantity] is the entry-leg (positive) quantity. *)
let test_open_positions_csv_header_and_rows _ =
  let long_pos =
    _make_position ~symbol:"AAPL" ~quantity:100.0 ~entry_price:189.50
      ~entry_date:(_date "2024-11-15")
  in
  let short_pos =
    _make_position ~symbol:"TSLA" ~quantity:(-50.0) ~entry_price:420.00
      ~entry_date:(_date "2025-02-04")
  in
  let portfolio = _make_portfolio ~positions:[ long_pos; short_pos ] in
  let step = _make_step ~date:(_date "2024-04-29") ~portfolio () in
  let result =
    _make_result ~round_trips:[] ~force_liquidations:[] ~steps:[ step ] ()
  in
  _with_writer_output ~result ~prefix:"/tmp/result_writer_open_pos_" (fun dir ->
      let header, rows = _read_csv ~path:(dir ^ "/open_positions.csv") in
      assert_that header
        (elements_are
           [
             equal_to "symbol";
             equal_to "side";
             equal_to "entry_date";
             equal_to "entry_price";
             equal_to "quantity";
           ]);
      assert_that rows
        (elements_are
           [
             elements_are
               [
                 equal_to "AAPL";
                 equal_to "LONG";
                 equal_to "2024-11-15";
                 equal_to "189.50";
                 equal_to "100";
               ];
             elements_are
               [
                 equal_to "TSLA";
                 equal_to "SHORT";
                 equal_to "2025-02-04";
                 equal_to "420.00";
                 equal_to "50";
               ];
           ]))

(** Empty case: no open positions → header-only file. The reconciler still
    accepts this (an empty input means zero open positions to verify). *)
let test_open_positions_csv_empty_writes_header_only _ =
  let portfolio = _make_portfolio ~positions:[] in
  let step = _make_step ~date:(_date "2024-04-29") ~portfolio () in
  let result =
    _make_result ~round_trips:[] ~force_liquidations:[] ~steps:[ step ] ()
  in
  _with_writer_output ~result ~prefix:"/tmp/result_writer_open_pos_empty_"
    (fun dir ->
      let header, rows = _read_csv ~path:(dir ^ "/open_positions.csv") in
      assert_that header
        (elements_are
           [
             equal_to "symbol";
             equal_to "side";
             equal_to "entry_date";
             equal_to "entry_price";
             equal_to "quantity";
           ]);
      assert_that rows (elements_are []))

(* ------------------------------------------------------------------ *)
(* final_prices.csv                                                     *)
(* ------------------------------------------------------------------ *)

(** Per PHASE_1_SPEC §3.3, the file has columns [symbol,price] with one row per
    symbol present in [open_positions.csv]. The runner threads [final_prices] as
    an alist; [Result_writer] filters to held symbols. *)
let test_final_prices_csv_header_and_rows _ =
  let long_pos =
    _make_position ~symbol:"AAPL" ~quantity:100.0 ~entry_price:189.50
      ~entry_date:(_date "2024-11-15")
  in
  let short_pos =
    _make_position ~symbol:"TSLA" ~quantity:(-50.0) ~entry_price:420.00
      ~entry_date:(_date "2025-02-04")
  in
  let portfolio = _make_portfolio ~positions:[ long_pos; short_pos ] in
  let step = _make_step ~date:(_date "2024-04-29") ~portfolio () in
  (* Include extra symbols not held — they must be dropped. *)
  let final_prices = [ ("AAPL", 182.45); ("TSLA", 395.10); ("NVDA", 800.00) ] in
  let result =
    _make_result ~round_trips:[] ~force_liquidations:[] ~steps:[ step ]
      ~final_prices ()
  in
  _with_writer_output ~result ~prefix:"/tmp/result_writer_final_prices_"
    (fun dir ->
      let header, rows = _read_csv ~path:(dir ^ "/final_prices.csv") in
      assert_that header (elements_are [ equal_to "symbol"; equal_to "price" ]);
      assert_that rows
        (elements_are
           [
             elements_are [ equal_to "AAPL"; equal_to "182.45" ];
             elements_are [ equal_to "TSLA"; equal_to "395.10" ];
           ]))

(** Empty case: no open positions → header-only file regardless of how many
    [final_prices] entries the runner supplied. *)
let test_final_prices_csv_empty_writes_header_only _ =
  let portfolio = _make_portfolio ~positions:[] in
  let step = _make_step ~date:(_date "2024-04-29") ~portfolio () in
  let result =
    _make_result ~round_trips:[] ~force_liquidations:[] ~steps:[ step ]
      ~final_prices:[ ("AAPL", 100.0) ]
      ()
  in
  _with_writer_output ~result ~prefix:"/tmp/result_writer_final_prices_empty_"
    (fun dir ->
      let header, rows = _read_csv ~path:(dir ^ "/final_prices.csv") in
      assert_that header (elements_are [ equal_to "symbol"; equal_to "price" ]);
      assert_that rows (elements_are []))

(* ------------------------------------------------------------------ *)
(* splits.csv                                                           *)
(* ------------------------------------------------------------------ *)

(** Per PHASE_1_SPEC §4, the file has columns [symbol,date,factor]. Splits are
    pulled from [step_result.splits_applied] across all steps — deduplicated on
    [(symbol, date)] in case the simulator emits the same event on multiple
    holding positions of the same symbol. *)
let test_splits_csv_header_and_rows _ =
  let portfolio = _make_portfolio ~positions:[] in
  let split_aapl : Trading_portfolio.Split_event.t =
    { symbol = "AAPL"; date = _date "2020-08-31"; factor = 4.0 }
  in
  let split_ge : Trading_portfolio.Split_event.t =
    { symbol = "GE"; date = _date "2021-08-02"; factor = 0.125 }
  in
  let step1 =
    _make_step ~date:(_date "2020-08-31") ~portfolio
      ~splits_applied:[ split_aapl ] ()
  in
  let step2 =
    _make_step ~date:(_date "2021-08-02") ~portfolio
      ~splits_applied:[ split_ge ] ()
  in
  let result =
    _make_result ~round_trips:[] ~force_liquidations:[] ~steps:[ step1; step2 ]
      ()
  in
  _with_writer_output ~result ~prefix:"/tmp/result_writer_splits_" (fun dir ->
      let header, rows = _read_csv ~path:(dir ^ "/splits.csv") in
      assert_that header
        (elements_are [ equal_to "symbol"; equal_to "date"; equal_to "factor" ]);
      assert_that rows
        (elements_are
           [
             elements_are
               [ equal_to "AAPL"; equal_to "2020-08-31"; equal_to "4.0" ];
             elements_are
               [ equal_to "GE"; equal_to "2021-08-02"; equal_to "0.125" ];
           ]))

(** Empty case: no splits across steps → header-only file. *)
let test_splits_csv_empty_writes_header_only _ =
  let portfolio = _make_portfolio ~positions:[] in
  let step = _make_step ~date:(_date "2024-04-29") ~portfolio () in
  let result =
    _make_result ~round_trips:[] ~force_liquidations:[] ~steps:[ step ] ()
  in
  _with_writer_output ~result ~prefix:"/tmp/result_writer_splits_empty_"
    (fun dir ->
      let header, rows = _read_csv ~path:(dir ^ "/splits.csv") in
      assert_that header
        (elements_are [ equal_to "symbol"; equal_to "date"; equal_to "factor" ]);
      assert_that rows (elements_are []))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "result_writer"
  >::: [
         "per_position force-liq overrides exit_trigger"
         >:: test_per_position_force_liq_overrides_exit_trigger;
         "portfolio_floor force-liq overrides exit_trigger"
         >:: test_portfolio_floor_force_liq_overrides_exit_trigger;
         "non-matching event does not override exit_trigger"
         >:: test_non_matching_event_does_not_override;
         "open_positions.csv header and rows"
         >:: test_open_positions_csv_header_and_rows;
         "open_positions.csv empty writes header only"
         >:: test_open_positions_csv_empty_writes_header_only;
         "final_prices.csv header and rows"
         >:: test_final_prices_csv_header_and_rows;
         "final_prices.csv empty writes header only"
         >:: test_final_prices_csv_empty_writes_header_only;
         "splits.csv header and rows" >:: test_splits_csv_header_and_rows;
         "splits.csv empty writes header only"
         >:: test_splits_csv_empty_writes_header_only;
       ]

let () = run_test_tt_main suite
