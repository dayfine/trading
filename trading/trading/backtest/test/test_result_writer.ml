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
    deterministically. *)

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

let _make_result ~round_trips ~force_liquidations : Backtest.Runner.result =
  let start_date = _date "2024-01-02" in
  let end_date = _date "2024-04-29" in
  {
    summary = _empty_summary ~start_date ~end_date;
    round_trips;
    steps = [];
    overrides = [];
    stop_infos = [];
    audit = [];
    cascade_summaries = [];
    force_liquidations;
  }

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
        _make_result ~round_trips:[ trade ] ~force_liquidations:[ event ]
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
        _make_result ~round_trips:[ trade ] ~force_liquidations:[ event ]
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
        _make_result ~round_trips:[ trade ] ~force_liquidations:[ event ]
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
       ]

let () = run_test_tt_main suite
