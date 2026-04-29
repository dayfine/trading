(** Smoke tests for [Backtest_optimal.Optimal_strategy_report].

    Pinpoints that the renderer:
    - emits all five sections (header, headline, divergence, missed,
      implications)
    - includes the scenario name and disclaimer
    - renders the headline comparison table with both variant columns
    - flags missed trades with their cascade-rejection reason when supplied
    - fires the right implications narrative branch given a return ratio

    Tests are substring-presence assertions on the rendered string — the
    renderer is pure, so a stable seeded fixture pins exact output. Remaining
    work (full per-Friday divergence pinning, exhaustive narrative coverage) is
    deferred per [dev/notes/optimal-strategy-pr4-followups.md]. *)

open Core
open OUnit2
open Matchers
module R = Backtest_optimal.Optimal_strategy_report
module OT = Backtest_optimal.Optimal_types

let _date d = Date.of_string d

let _has substring : string matcher =
  field (fun s -> String.is_substring s ~substring) (equal_to true)

(** Synthetic actual-run fixture: 3 winners, +18% total return on $10k. *)
let _make_actual ?(scenario_name = "test-2024") ?(round_trips = []) () :
    R.actual_run =
  {
    scenario_name;
    start_date = _date "2024-01-05";
    end_date = _date "2024-12-27";
    universe_size = 50;
    initial_cash = 10_000.0;
    final_portfolio_value = 11_800.0;
    round_trips;
    win_rate_pct = 33.3;
    sharpe_ratio = 0.85;
    max_drawdown_pct = 8.4;
    profit_factor = 1.7;
    cascade_rejections = [];
  }

let _make_actual_trade ~symbol ~entry_date ~exit_date ~pnl_dollars ~pnl_percent
    () : Trading_simulation.Metrics.trade_metrics =
  {
    symbol;
    entry_date;
    exit_date;
    days_held = Date.diff exit_date entry_date;
    entry_price = 100.0;
    exit_price = 100.0 +. (pnl_dollars /. 10.0);
    quantity = 10.0;
    pnl_dollars;
    pnl_percent;
  }

let _make_optimal_rt ~symbol ~entry_week ~exit_week ~pnl_dollars ~r_multiple
    ?(exit_trigger = OT.End_of_run) () : OT.optimal_round_trip =
  {
    symbol;
    side = Trading_base.Types.Long;
    entry_week;
    entry_price = 100.0;
    exit_week;
    exit_price = 100.0 +. (pnl_dollars /. 10.0);
    exit_trigger;
    shares = 10.0;
    initial_risk_dollars = 100.0;
    pnl_dollars;
    r_multiple;
    cascade_grade = Weinstein_types.B;
    passes_macro = true;
  }

let _make_summary ~total_return_pct ~variant : OT.optimal_summary =
  {
    total_round_trips = 5;
    winners = 3;
    losers = 2;
    total_return_pct;
    win_rate_pct = 0.6;
    avg_r_multiple = 1.2;
    profit_factor = 2.5;
    max_drawdown_pct = 0.05;
    variant;
  }

(* ------------------------------------------------------------------ *)
(* Section presence                                                    *)
(* ------------------------------------------------------------------ *)

let test_all_sections_present _ =
  let actual = _make_actual () in
  let constrained =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.30 ~variant:OT.Constrained;
    }
  in
  let relaxed_macro =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.45 ~variant:OT.Relaxed_macro;
    }
  in
  let md = R.render { actual; constrained; relaxed_macro } in
  assert_that md
    (all_of
       [
         _has "# Optimal-strategy counterfactual";
         _has "test-2024";
         _has "**Disclaimer.**";
         _has "## Headline comparison";
         _has "## Per-Friday divergence";
         _has "## Trades the actual missed";
         _has "## Implications";
       ])

(* ------------------------------------------------------------------ *)
(* Headline table cells                                                *)
(* ------------------------------------------------------------------ *)

let test_headline_includes_three_variants _ =
  let actual = _make_actual () in
  let constrained =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.30 ~variant:OT.Constrained;
    }
  in
  let relaxed_macro =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.45 ~variant:OT.Relaxed_macro;
    }
  in
  let md = R.render { actual; constrained; relaxed_macro } in
  (* +18.00% (actual) vs +30.00% (constrained) vs +45.00% (relaxed) *)
  assert_that md
    (all_of
       [
         _has "+18.00%";
         _has "+30.00%";
         _has "+45.00%";
         _has "Total return";
         _has "MaxDD";
         _has "Round-trips";
       ])

(* ------------------------------------------------------------------ *)
(* Missed trades + cascade-rejection reasons                            *)
(* ------------------------------------------------------------------ *)

let test_missed_trades_with_reason _ =
  let actual_trade =
    _make_actual_trade ~symbol:"AAPL" ~entry_date:(_date "2024-02-02")
      ~exit_date:(_date "2024-03-01") ~pnl_dollars:200.0 ~pnl_percent:20.0 ()
  in
  let actual =
    _make_actual ~round_trips:[ actual_trade ]
      ~scenario_name:"test-missed-reason" ()
    |> fun a ->
    { a with cascade_rejections = [ ("MSFT", "below grade threshold") ] }
  in
  let constrained_rts =
    [
      _make_optimal_rt ~symbol:"MSFT" ~entry_week:(_date "2024-02-02")
        ~exit_week:(_date "2024-03-29") ~pnl_dollars:500.0 ~r_multiple:5.0 ();
    ]
  in
  let constrained =
    {
      R.round_trips = constrained_rts;
      summary = _make_summary ~total_return_pct:0.30 ~variant:OT.Constrained;
    }
  in
  let relaxed_macro =
    {
      R.round_trips = constrained_rts;
      summary = _make_summary ~total_return_pct:0.45 ~variant:OT.Relaxed_macro;
    }
  in
  let md = R.render { actual; constrained; relaxed_macro } in
  assert_that md
    (all_of
       [
         _has "MSFT";
         _has "below grade threshold";
         _has "## Trades the actual missed";
       ])

(* ------------------------------------------------------------------ *)
(* Implications narrative — three branches                              *)
(* ------------------------------------------------------------------ *)

let test_implications_high_ratio _ =
  (* actual = +18.00%, constrained = +60.00% → ratio ~3.33× → "significantly
     mis-scoring" branch. *)
  let actual = _make_actual () in
  let constrained =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.60 ~variant:OT.Constrained;
    }
  in
  let relaxed_macro =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.80 ~variant:OT.Relaxed_macro;
    }
  in
  let md = R.render { actual; constrained; relaxed_macro } in
  assert_that md (_has "significantly mis-scoring")

let test_implications_low_ratio _ =
  (* actual = +18.00%, constrained = +20.00% → ratio ~1.11× → "near-optimal"
     branch. *)
  let actual = _make_actual () in
  let constrained =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.20 ~variant:OT.Constrained;
    }
  in
  let relaxed_macro =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.25 ~variant:OT.Relaxed_macro;
    }
  in
  let md = R.render { actual; constrained; relaxed_macro } in
  assert_that md (_has "near-optimal")

let test_implications_degenerate _ =
  (* actual return non-positive → degenerate branch. *)
  let actual =
    {
      (_make_actual ()) with
      final_portfolio_value = 9_000.0 (* loss → -10% return *);
    }
  in
  let constrained =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.30 ~variant:OT.Constrained;
    }
  in
  let relaxed_macro =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.45 ~variant:OT.Relaxed_macro;
    }
  in
  let md = R.render { actual; constrained; relaxed_macro } in
  assert_that md (_has "non-positive")

(* ------------------------------------------------------------------ *)
(* Determinism                                                         *)
(* ------------------------------------------------------------------ *)

let test_render_is_deterministic _ =
  let mk () =
    {
      R.actual = _make_actual ();
      constrained =
        {
          R.round_trips = [];
          summary = _make_summary ~total_return_pct:0.30 ~variant:OT.Constrained;
        };
      relaxed_macro =
        {
          R.round_trips = [];
          summary =
            _make_summary ~total_return_pct:0.45 ~variant:OT.Relaxed_macro;
        };
    }
  in
  let md1 = R.render (mk ()) in
  let md2 = R.render (mk ()) in
  assert_that md1 (equal_to md2)

(* ------------------------------------------------------------------ *)
(* Trailing newline                                                    *)
(* ------------------------------------------------------------------ *)

let test_ends_with_newline _ =
  let actual = _make_actual () in
  let constrained =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.30 ~variant:OT.Constrained;
    }
  in
  let relaxed_macro =
    {
      R.round_trips = [];
      summary = _make_summary ~total_return_pct:0.45 ~variant:OT.Relaxed_macro;
    }
  in
  let md = R.render { actual; constrained; relaxed_macro } in
  assert_that md
    (field
       (fun s -> Char.equal (String.get s (String.length s - 1)) '\n')
       (equal_to true))

let suite =
  "Optimal_strategy_report"
  >::: [
         "all five sections present" >:: test_all_sections_present;
         "headline shows three variant columns"
         >:: test_headline_includes_three_variants;
         "missed trades flag cascade-rejection reason"
         >:: test_missed_trades_with_reason;
         "implications: high ratio fires mis-scoring branch"
         >:: test_implications_high_ratio;
         "implications: low ratio fires near-optimal branch"
         >:: test_implications_low_ratio;
         "implications: degenerate (non-positive actual)"
         >:: test_implications_degenerate;
         "render is deterministic" >:: test_render_is_deterministic;
         "output ends with single newline" >:: test_ends_with_newline;
       ]

let () = run_test_tt_main suite
