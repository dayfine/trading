(** Runner-level test for [decision_grading_bin.exe].

    Builds a tiny scenario directory ([trades.csv] + [trade_audit.sexp] +
    [summary.sexp]) and a snapshot warehouse of synthetic bars, runs the real
    executable as a subprocess and pins the markdown it writes. This pins what
    no library test can: the [per_trade_row] -> [_grade_row] wiring, the
    audit-record -> MFE triple mapping, the [trades.csv] exit-reason join and
    the [--horizons] / [--grade-horizon] flags.

    Fixture: three round-trips that all exit on 2020-03-06 at 100.0.
    - [AAA] long, +20% realized, exit reason [stop_loss], audit MFE 0.40.
    - [BBB] short (side comes from its audit entry, not trades.csv), -10%
      realized, exit reason [laggard_rotation], no audit exit decision.
    - [CCC] long, 0% realized, empty exit trigger (reported as [unlabeled]).

    Post-exit daily closes (calendar days after the exit, [d]): AAA rises
    0.5/day for 28 days then falls 1/day (so 4 weeks out it is up, 13 weeks out
    down); BBB is flat for a week then rises 0.25/day; CCC rises 0.5/day. *)

open OUnit2
open Core
open Matchers
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Pipeline = Snapshot_pipeline.Pipeline

let _exe = "../bin/decision_grading_bin.exe"
let _exit_date = Date.create_exn ~y:2020 ~m:Month.Mar ~d:6
let _first_day = Date.create_exn ~y:2019 ~m:Month.Oct ~d:1
let _n_days = 520

(* Close on [date]: flat 100 up to the exit, then [after] of the days since. *)
let _close ~after date =
  let d = Date.diff date _exit_date in
  if d <= 0 then 100.0 else after (Float.of_int d)

let _hump d =
  if Float.( <= ) d 28.0 then 100.0 +. (0.5 *. d) else 114.0 -. (d -. 28.0)

let _jump d = if Float.( <= ) d 7.0 then 100.0 else 100.0 +. (0.25 *. d)

let _bars ~after =
  List.init _n_days ~f:(fun i ->
      let date = Date.add_days _first_day i in
      let c = _close ~after date in
      {
        Types.Daily_price.date;
        open_price = c;
        high_price = c;
        low_price = c;
        close_price = c;
        volume = 1_000_000;
        adjusted_close = c;
        active_through = None;
      })

(* Unwrap a setup Result, failing the test with [what] and the status. *)
let _ok_exn ~what = function
  | Ok v -> v
  | Error err -> assert_failure (what ^ ": " ^ Status.show err)

let _write_warehouse ~snapshot_dir symbols =
  let schema = Snapshot_schema.default in
  let entries =
    List.map symbols ~f:(fun (symbol, after) ->
        let rows =
          _ok_exn ~what:"build_for_symbol"
            (Pipeline.build_for_symbol ~symbol ~bars:(_bars ~after) ~schema ())
        in
        let path = Filename.concat snapshot_dir (symbol ^ ".snap") in
        _ok_exn ~what:"Snapshot_format.write" (Snapshot_format.write ~path rows);
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
  _ok_exn ~what:"Snapshot_manifest.write"
    (Snapshot_manifest.write
       ~path:(Filename.concat snapshot_dir "manifest.sexp")
       (Snapshot_manifest.create ~schema ~entries))

let _trades_csv =
  "symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger\n\
   AAA,LONG,2020-01-03,2020-03-06,63,83.33,100.0,10,166.7,20.0,70.0,90.0,stop_loss\n\
   BBB,SHORT,2020-01-03,2020-03-06,63,90.0,100.0,10,-100.0,-10.0,95.0,95.0,laggard_rotation\n\
   CCC,LONG,2020-01-03,2020-03-06,63,100.0,100.0,10,0.0,0.0,90.0,90.0,\n"

(* AAA's audit decision is the Friday before its 2020-01-03 fill; MFE 0.40. *)
(* One audit record per symbol; [exit_] is the pre-rendered option sexp. The
   audit entry_date is the Friday decision date before the 2020-01-03 fill. *)
let _audit_record ~symbol ~side ~exit_ =
  sprintf
    "((entry ((symbol %s) (entry_date 2019-12-27) (position_id %s-1) \
     (macro_trend Bullish) (macro_confidence 0.75) (macro_indicators ()) \
     (stage (Stage2 (weeks_advancing 1) (late false))) (ma_direction Rising) \
     (ma_slope_pct 0.01) (rs_trend ()) (rs_value ()) (volume_quality ()) \
     (volume_ratio ()) (resistance_quality ()) (support_quality ()) \
     (sector_name Tech) (sector_rating Strong) (cascade_score 75) \
     (cascade_grade A) (cascade_score_components ()) (cascade_rationale ()) \
     (side %s) (suggested_entry 83.0) (screener_proxy_stop 70.0) \
     (installed_stop 70.0) (stop_floor_kind Buffer_fallback) (risk_pct 0.08) \
     (initial_position_value 1000.0) (initial_risk_dollars 80.0) \
     (alternatives_considered ()))) (exit_ %s))"
    symbol symbol side exit_

(* AAA closed with in-trade MFE 0.40; BBB (a short) has no exit decision. *)
let _aaa_exit =
  "(((symbol AAA) (exit_date 2020-03-06) (position_id AAA-1) (exit_trigger \
   (Stop_loss (stop_price 90.0) (actual_price 90.0))) (macro_trend_at_exit \
   Bullish) (macro_confidence_at_exit 0.7) (stage_at_exit (Stage2 \
   (weeks_advancing 4) (late false))) (rs_trend_at_exit ()) \
   (distance_from_ma_pct 0.1) (max_favorable_excursion_pct 0.4) \
   (max_adverse_excursion_pct -0.05) (weeks_macro_was_bearish 0) \
   (weeks_stage_left_2 0)))"

let _trade_audit =
  sprintf "((audit_records (%s %s)) (cascade_summaries ()))"
    (_audit_record ~symbol:"AAA" ~side:"Long" ~exit_:_aaa_exit)
    (_audit_record ~symbol:"BBB" ~side:"Short" ~exit_:"()")

let _summary =
  "((start_date 2020-01-01) (end_date 2020-12-31) (universe_size 3))"

let _write_scenario dir =
  Out_channel.write_all (Filename.concat dir "trades.csv") ~data:_trades_csv;
  Out_channel.write_all
    (Filename.concat dir "trade_audit.sexp")
    ~data:_trade_audit;
  Out_channel.write_all (Filename.concat dir "summary.sexp") ~data:_summary

let _run_report () =
  let root = Filename_unix.temp_dir "dg_bin" "" in
  let scenario_dir = Filename.concat root "scn" in
  let snapshot_dir = Filename.concat root "snap" in
  Core_unix.mkdir scenario_dir;
  Core_unix.mkdir snapshot_dir;
  _write_scenario scenario_dir;
  _write_warehouse ~snapshot_dir
    [
      ("AAA", fun d -> _hump d);
      ("BBB", fun d -> _jump d);
      ("CCC", fun d -> 100.0 +. (0.5 *. d));
    ];
  let out = Filename.concat root "report.md" in
  let log = Filename.concat root "stderr.log" in
  let cmd =
    sprintf
      "%s --scenario-dir %s --snapshot-dir %s --horizons 4,13 --grade-horizon \
       13 --out %s 2>%s"
      _exe scenario_dir snapshot_dir out log
  in
  let rc = Stdlib.Sys.command cmd in
  (* On failure the report is absent: surface stderr instead. *)
  (rc, In_channel.read_all (if Sys_unix.file_exists_exn out then out else log))

let _expected =
  {|# Decision-grading report — scn

Period: 2020-01-01 .. 2020-12-31 | round-trips graded: 3 | grade horizon: 13w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 1 | -10.0% | -22.8% | 0% | 100% | +22.8% | n/a |
| stop_loss | 1 | +20.0% | -49.0% | 0% | 100% | +49.0% | 0.50 |
| unlabeled | 1 | +0.0% | +45.5% | 100% | 0% | -45.5% | n/a |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 1 | -22.8% | +0.0% | -22.8% | -22.8% | 100% |
| stop_loss | 1 | -49.0% | +14.0% | -49.0% | -49.0% | 100% |
| unlabeled | 1 | +0.0% | +45.5% | +45.5% | +45.5% | 0% |
|}

let test_report _ =
  let rc, markdown = _run_report () in
  assert_that (rc, markdown) (equal_to (0, _expected))

let suite = "decision_grading_bin" >::: [ "report" >:: test_report ]
let () = run_test_tt_main suite
