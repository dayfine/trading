(** Round-trip tests for [Backtest_optimal.Optimal_run_artefacts.load].

    Pins the on-disk [trades.csv] contract that the loader consumes: the post-G2
    13-column layout (with a [side] column) emitted by [Backtest.Result_writer]
    AND the legacy 12-column layout still produced by pre-G2 runs. Both LONG
    (Buy→Sell) and SHORT (Sell→Buy) round-trip rows must parse with the correct
    entry-leg [side] tag.

    The {!_canonical_post_g2_header} literal mirrors the writer-side header in
    [Backtest.Result_writer._write_trades] verbatim. Schema drift on either side
    will fail one of the parser tests loudly. *)

open OUnit2
open Core
open Matchers
module RA = Backtest_optimal.Optimal_run_artefacts

(* --- Canonical CSV header literals ------------------------------------- *)

(** Mirrors [Backtest.Result_writer._write_trades]'s post-G2 header verbatim. A
    drift here means the writer's column list changed and the post-G2 parser
    fixtures below are stale — pin both sides against the same string. *)
let _canonical_post_g2_header =
  "symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger"

(** Mirrors the pre-G2 header (no [side] column). Kept around so the loader's
    legacy fallback branch stays exercised. *)
let _canonical_legacy_header =
  "symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger"

(* --- Fixture staging --------------------------------------------------- *)

let _date d = Date.of_string d
let _write_text path text = Out_channel.write_all path ~data:text

let _write_summary_sexp ~output_dir =
  let path = Filename.concat output_dir "summary.sexp" in
  _write_text path
    "((start_date 2024-01-05) (end_date 2024-04-30) (universe_size 1) (n_steps \
     5) (initial_cash 10000.00) (final_portfolio_value 10500.00) \
     (n_round_trips 2) (metrics ()))"

let _write_actual_sexp ~output_dir =
  let path = Filename.concat output_dir "actual.sexp" in
  _write_text path
    "((total_return_pct 5.00) (total_trades 2.00) (win_rate 100.00) \
     (sharpe_ratio 0.50) (max_drawdown_pct 1.00) (avg_holding_days 30.00) \
     (unrealized_pnl 0.00))"

let _write_trades_csv ~output_dir ~contents =
  _write_text (Filename.concat output_dir "trades.csv") contents

let _stage_run_dir ~prefix ~trades_csv =
  let output_dir = Core_unix.mkdtemp ("/tmp/" ^ prefix ^ "_") in
  _write_summary_sexp ~output_dir;
  _write_actual_sexp ~output_dir;
  _write_trades_csv ~output_dir ~contents:trades_csv;
  output_dir

(* --- Post-G2 round-trip tests ------------------------------------------ *)

(* A LONG round-trip emitted by Result_writer in the post-G2 layout: AAPL
   bought at 150, sold at 165, +15.00 pnl_$, +10.00%, with stop annotations. *)
let _long_row =
  "AAPL,LONG,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal"

(* A SHORT round-trip: TSLA sold short at 200, covered at 180, +20 pnl_$,
   +10.00%. The entry leg's side tag is SHORT — i.e. [Trading_base.Types.Sell]. *)
let _short_row =
  "TSLA,SHORT,2024-03-04,2024-04-08,35,200.00,180.00,5,100.00,10.00,210.00,185.00,stop_loss"

let test_load_post_g2_long_only_round_trip _ =
  let csv = _canonical_post_g2_header ^ "\n" ^ _long_row ^ "\n" in
  let output_dir =
    _stage_run_dir ~prefix:"opt_artefacts_long" ~trades_csv:csv
  in
  let inputs = RA.load ~output_dir in
  assert_that inputs.trades
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.symbol)
               (equal_to "AAPL");
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.side)
               (equal_to Trading_base.Types.Buy);
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) ->
                 t.quantity)
               (float_equal 10.0);
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) ->
                 t.pnl_dollars)
               (float_equal 150.00);
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) ->
                 t.pnl_percent)
               (float_equal 10.00);
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) ->
                 t.entry_date)
               (equal_to (_date "2024-01-15"));
           ];
       ])

let test_load_post_g2_short_only_round_trip _ =
  let csv = _canonical_post_g2_header ^ "\n" ^ _short_row ^ "\n" in
  let output_dir =
    _stage_run_dir ~prefix:"opt_artefacts_short" ~trades_csv:csv
  in
  let inputs = RA.load ~output_dir in
  (* SHORT row must round-trip with side = Sell — this is the new G2 contract. *)
  assert_that inputs.trades
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.symbol)
               (equal_to "TSLA");
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.side)
               (equal_to Trading_base.Types.Sell);
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) ->
                 t.entry_price)
               (float_equal 200.00);
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) ->
                 t.exit_price)
               (float_equal 180.00);
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) ->
                 t.pnl_dollars)
               (float_equal 100.00);
           ];
       ])

let test_load_post_g2_mixed_long_and_short _ =
  let csv =
    _canonical_post_g2_header ^ "\n" ^ _long_row ^ "\n" ^ _short_row ^ "\n"
  in
  let output_dir =
    _stage_run_dir ~prefix:"opt_artefacts_mixed" ~trades_csv:csv
  in
  let inputs = RA.load ~output_dir in
  assert_that inputs.trades
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.symbol)
               (equal_to "AAPL");
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.side)
               (equal_to Trading_base.Types.Buy);
           ];
         all_of
           [
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.symbol)
               (equal_to "TSLA");
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.side)
               (equal_to Trading_base.Types.Sell);
           ];
       ])

(* --- Legacy (pre-G2) regression --------------------------------------- *)

let test_load_legacy_12_col_defaults_to_buy _ =
  (* Pre-G2 trades.csv files have no [side] column. The loader must keep parsing
     them, defaulting [side] to [Buy] preserving the historical long-only
     semantics. *)
  let legacy_row =
    "AAPL,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal"
  in
  let csv = _canonical_legacy_header ^ "\n" ^ legacy_row ^ "\n" in
  let output_dir =
    _stage_run_dir ~prefix:"opt_artefacts_legacy" ~trades_csv:csv
  in
  let inputs = RA.load ~output_dir in
  assert_that inputs.trades
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.symbol)
               (equal_to "AAPL");
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) -> t.side)
               (equal_to Trading_base.Types.Buy);
             field
               (fun (t : Trading_simulation.Metrics.trade_metrics) ->
                 t.pnl_dollars)
               (float_equal 150.00);
           ];
       ])

(* --- position_id column (follow-up to PR #2317) ------------------------

   [trades.csv] carries a trailing [position_id] column. Dropping it here forced
   every downstream consumer of [RA.load] back onto a date-proximity join, which
   misattributes audit / stop records on re-traded symbols. The loader resolves
   the cell by header name (not by a fixed index) so appending further trailing
   columns cannot shift what it reads. *)

(** The full header a current [Result_writer] emits — the 13 base columns plus
    the 8 trailing per-trade-context columns. [position_id] is cell 19. *)
let _canonical_full_header =
  _canonical_post_g2_header
  ^ ",entry_stage,entry_volume_ratio,stop_initial_distance_pct,stop_trigger_kind,days_to_first_stop_trigger,screener_score_at_entry,position_id,stop_fill_distance_pct"

let _full_row ~position_id =
  "AAPL,LONG,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal,Stage2,2.4000,0.0800,intraday,36,75,"
  ^ position_id ^ ",0.0650"

let _load_only_trade_position_id ~prefix ~csv =
  let output_dir = _stage_run_dir ~prefix ~trades_csv:csv in
  let inputs = RA.load ~output_dir in
  List.hd inputs.trades
  |> Option.bind ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
      t.position_id)

let test_load_reads_populated_position_id _ =
  assert_that
    (_load_only_trade_position_id ~prefix:"opt_artefacts_pid"
       ~csv:
         (_canonical_full_header ^ "\n"
         ^ _full_row ~position_id:"AAPL-wein-7"
         ^ "\n"))
    (is_some_and (equal_to "AAPL-wein-7"))

let test_load_empty_position_id_cell_reads_none _ =
  (* The empty cell is the canonical missing-data sentinel the writer emits for
     [None]; it must not surface as [Some ""]. *)
  assert_that
    (_load_only_trade_position_id ~prefix:"opt_artefacts_pid_empty"
       ~csv:(_canonical_full_header ^ "\n" ^ _full_row ~position_id:"" ^ "\n"))
    is_none

let test_load_position_id_none_when_row_predates_column _ =
  (* Header advertises the column, but this row stops at the 13 base cells (a
     run written before the trailing context block existed). *)
  assert_that
    (_load_only_trade_position_id ~prefix:"opt_artefacts_pid_short"
       ~csv:(_canonical_full_header ^ "\n" ^ _long_row ^ "\n"))
    is_none

let test_load_legacy_row_has_no_position_id _ =
  (* The legacy layout has no such column at all. *)
  assert_that
    (_load_only_trade_position_id ~prefix:"opt_artefacts_pid_legacy"
       ~csv:
         (_canonical_legacy_header
        ^ "\n\
           AAPL,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal\n"
         ))
    is_none

let suite =
  "Optimal_run_artefacts"
  >::: [
         "load reads populated position_id"
         >:: test_load_reads_populated_position_id;
         "load empty position_id cell reads none"
         >:: test_load_empty_position_id_cell_reads_none;
         "load position_id none when row predates column"
         >:: test_load_position_id_none_when_row_predates_column;
         "load legacy row has no position_id"
         >:: test_load_legacy_row_has_no_position_id;
         "load post-G2 LONG round-trip"
         >:: test_load_post_g2_long_only_round_trip;
         "load post-G2 SHORT round-trip"
         >:: test_load_post_g2_short_only_round_trip;
         "load post-G2 mixed LONG and SHORT"
         >:: test_load_post_g2_mixed_long_and_short;
         "load legacy 12-col defaults to Buy"
         >:: test_load_legacy_12_col_defaults_to_buy;
       ]

let () = run_test_tt_main suite
