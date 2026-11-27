(* Parity of the weekly report's per-stock analysis config with the backtest's
   (#3726): [Report_analysis_config.of_strategy_config] against
   [Weinstein_strategy.stock_analysis_config_for] on the same strategy config,
   at each knob's default and at a non-default value. *)

open Core
open OUnit2
open Matchers
module Report_config = Weinstein_snapshot_gen.Report_analysis_config

let _default_strategy () =
  Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"GSPCX"

(* [(report, backtest)] views of one field of the two builders' output. *)
let _both (config : Weinstein_strategy.config) ~f =
  ( f (Report_config.of_strategy_config config),
    f (Weinstein_strategy.stock_analysis_config_for ~config) )

let _same expected = pair (equal_to expected) (equal_to expected)

(* R1: at the strategy default none of the knobs this module threads moves the
   report off [Stock_analysis.default_config], so today's default picks are
   unchanged: no continuation detector, no resistance history floor, no RS
   [Positive_declining], the screen-time volume gate on, and the [Ma_cross]
   freshness basis. *)
let test_default_config_leaves_report_unchanged _ =
  let base = Stock_analysis.default_config in
  let built = Report_config.of_strategy_config (_default_strategy ()) in
  assert_that built
    (all_of
       [
         field (fun (c : Stock_analysis.config) -> c.continuation) is_none;
         field
           (fun (c : Stock_analysis.config) -> c.resistance.min_history_bars)
           (equal_to base.resistance.min_history_bars);
         field
           (fun (c : Stock_analysis.config) -> c.rs.enable_positive_declining)
           (equal_to base.rs.enable_positive_declining);
         field
           (fun (c : Stock_analysis.config) -> c.require_breakout_volume)
           (equal_to true);
         field
           (fun (c : Stock_analysis.config) -> c.entry_freshness_basis)
           (equal_to base.entry_freshness_basis);
       ])

(* EFFECTIVENESS-PIN: enable_continuation_buys -- weekly-report path: off by
   default (no detector on either path); armed with a non-default
   [continuation_config], both paths run the detector on that exact config.
   Red when the generator drops the copy (the report would read [None]). *)
let test_report_threads_continuation_like_backtest _ =
  let cfg = { Continuation.default_config with consolidation_weeks = 6 } in
  let armed =
    {
      (_default_strategy ()) with
      Weinstein_strategy.enable_continuation_buys = true;
      continuation_config = cfg;
    }
  in
  let sexp_of (c : Stock_analysis.config) =
    Option.map c.continuation ~f:Continuation.sexp_of_config
  in
  assert_that
    (_both (_default_strategy ()) ~f:sexp_of, _both armed ~f:sexp_of)
    (pair (_same None) (_same (Some (Continuation.sexp_of_config cfg))))

(* EFFECTIVENESS-PIN: resistance_min_history_bars -- weekly-report path: [0]
   (the floor disabled) by default on both paths; [120] reaches the report's
   [resistance.min_history_bars] exactly as it reaches the backtest's. *)
let test_report_threads_resistance_min_history_like_backtest _ =
  let armed =
    {
      (_default_strategy ()) with
      Weinstein_strategy.resistance_min_history_bars = 120;
    }
  in
  let floor (c : Stock_analysis.config) = c.resistance.min_history_bars in
  assert_that
    (_both (_default_strategy ()) ~f:floor, _both armed ~f:floor)
    (pair (_same 0) (_same 120))

(* EFFECTIVENESS-PIN: enable_rs_positive_declining -- weekly-report path: off
   by default on both paths; on in the strategy config, on in both. *)
let test_report_threads_rs_positive_declining_like_backtest _ =
  let armed =
    {
      (_default_strategy ()) with
      Weinstein_strategy.enable_rs_positive_declining = true;
    }
  in
  let flag (c : Stock_analysis.config) = c.rs.enable_positive_declining in
  assert_that
    (_both (_default_strategy ()) ~f:flag, _both armed ~f:flag)
    (pair (_same false) (_same true))

(* EFFECTIVENESS-PIN: entry_freshness_basis -- weekly-report path: [Ma_cross]
   by default on both paths; [Range_top_breakout] in the strategy config
   reaches both. *)
let test_report_threads_entry_freshness_basis_like_backtest _ =
  let armed =
    {
      (_default_strategy ()) with
      Weinstein_strategy.entry_freshness_basis =
        Entry_freshness.Range_top_breakout;
    }
  in
  let basis (c : Stock_analysis.config) = c.entry_freshness_basis in
  assert_that
    (_both (_default_strategy ()) ~f:basis, _both armed ~f:basis)
    (pair
       (_same Entry_freshness.Ma_cross)
       (_same Entry_freshness.Range_top_breakout))

(* The deliberate F5 divergence: with F5 armed the backtest waives the
   screen-time volume gate (its fill-week [Volume_eject_runner] checks volume
   instead), but the live report has no fill-week check, so it keeps the gate.
   Red if the generator copies the waiver alone. *)
let test_report_keeps_volume_gate_when_f5_armed _ =
  let f5 =
    {
      (_default_strategy ()) with
      Weinstein_strategy.volume_confirm_at_fill = true;
      sim_entry_trigger_at_suggested = true;
      enable_sim_entry_stoplimit = true;
    }
  in
  assert_that
    (_both f5 ~f:(fun (c : Stock_analysis.config) -> c.require_breakout_volume))
    (pair (equal_to true) (equal_to false))

let suite =
  "report_analysis_config"
  >::: [
         "default config leaves the report unchanged"
         >:: test_default_config_leaves_report_unchanged;
         "report threads continuation like the backtest"
         >:: test_report_threads_continuation_like_backtest;
         "report threads resistance min_history_bars like the backtest"
         >:: test_report_threads_resistance_min_history_like_backtest;
         "report threads RS positive_declining like the backtest"
         >:: test_report_threads_rs_positive_declining_like_backtest;
         "report threads entry_freshness_basis like the backtest"
         >:: test_report_threads_entry_freshness_basis_like_backtest;
         "report keeps the volume gate when F5 is armed"
         >:: test_report_keeps_volume_gate_when_f5_armed;
       ]

let () = run_test_tt_main suite
