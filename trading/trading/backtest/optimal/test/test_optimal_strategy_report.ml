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

(* ------------------------------------------------------------------ *)
(* Per-Friday divergence — pin specific cells                           *)
(* ------------------------------------------------------------------ *)

(** Two-Friday fixture. Each Friday has different actual vs counterfactual picks
    (symbol sets differ), so both Fridays appear in the divergence section.
    Pins:
    - the section's ### date headers for both Fridays
    - actual rows render as "SYM (N sh)" with share counts
    - optimal rows render as "SYM (N sh, R=±X.XX)" with share counts +
      R-multiples to two decimals *)
let test_divergence_pins_specific_cells _ =
  let friday1 = _date "2024-02-02" in
  let friday2 = _date "2024-03-01" in
  (* Actual: 2 round-trips, one per Friday. *)
  let actual_aapl =
    _make_actual_trade ~symbol:"AAPL" ~entry_date:friday1
      ~exit_date:(_date "2024-03-08") ~pnl_dollars:200.0 ~pnl_percent:20.0 ()
  in
  let actual_googl =
    _make_actual_trade ~symbol:"GOOGL" ~entry_date:friday2
      ~exit_date:(_date "2024-04-05") ~pnl_dollars:150.0 ~pnl_percent:15.0 ()
  in
  let actual =
    _make_actual ~scenario_name:"divergence-pin"
      ~round_trips:[ actual_aapl; actual_googl ]
      ()
  in
  (* Constrained counterfactual: 4 round-trips across the same two Fridays.
     Friday1 picks {MSFT, NVDA} (both differ from AAPL); Friday2 picks
     {AMZN, META} (both differ from GOOGL). *)
  let constrained_rts =
    [
      _make_optimal_rt ~symbol:"MSFT" ~entry_week:friday1
        ~exit_week:(_date "2024-03-29") ~pnl_dollars:500.0 ~r_multiple:5.0 ();
      _make_optimal_rt ~symbol:"NVDA" ~entry_week:friday1
        ~exit_week:(_date "2024-03-22") ~pnl_dollars:300.0 ~r_multiple:3.5 ();
      _make_optimal_rt ~symbol:"AMZN" ~entry_week:friday2
        ~exit_week:(_date "2024-04-26") ~pnl_dollars:400.0 ~r_multiple:4.0 ();
      _make_optimal_rt ~symbol:"META" ~entry_week:friday2
        ~exit_week:(_date "2024-04-19") ~pnl_dollars:250.0 ~r_multiple:2.5 ();
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
         (* Both Friday section headers present. *)
         _has "### 2024-02-02";
         _has "### 2024-03-01";
         (* Actual picks render with share counts (quantity = 10.0 from
            _make_actual_trade). *)
         _has "AAPL (10 sh)";
         _has "GOOGL (10 sh)";
         (* Optimal picks render with share counts + R-multiples to 2 dp.
            shares = 10.0 from _make_optimal_rt; R= per fixture above. *)
         _has "MSFT (10 sh, R=+5.00)";
         _has "NVDA (10 sh, R=+3.50)";
         _has "AMZN (10 sh, R=+4.00)";
         _has "META (10 sh, R=+2.50)";
       ])

(* ------------------------------------------------------------------ *)
(* Missed-trade ranking — descending by realized P&L                    *)
(* ------------------------------------------------------------------ *)

(** Index of the first occurrence of [needle] in [haystack]. Helper for
    asserting relative order of substrings in the rendered markdown. *)
let _index_of haystack needle = String.substr_index_exn haystack ~pattern:needle

(** Three missed-trade candidates with distinct P&L (all symbols absent from the
    actual run). The renderer's {!Optimal_strategy_report.mli} documents that
    "trades the actual missed" are "ranked by realized P&L"; the impl sorts by
    [pnl_dollars] descending. We pin that ordering by extracting each symbol's
    position in the rendered output and asserting BIG appears before MID before
    SML. *)
let test_missed_trades_ordered_by_pnl_descending _ =
  (* Actual has one round-trip in a totally different symbol, so all three
     counterfactual symbols qualify as "missed". *)
  let actual_trade =
    _make_actual_trade ~symbol:"ZZZ" ~entry_date:(_date "2024-02-02")
      ~exit_date:(_date "2024-03-01") ~pnl_dollars:50.0 ~pnl_percent:5.0 ()
  in
  let actual =
    _make_actual ~scenario_name:"missed-ranking" ~round_trips:[ actual_trade ]
      ()
  in
  (* Symbols are deliberately spelled to make alphabetical ordering disagree
     with the expected P&L ordering, so the test fails loudly if the renderer
     sorts alphabetically. *)
  let constrained_rts =
    [
      (* Alphabetical-first but middle P&L. *)
      _make_optimal_rt ~symbol:"AAA" ~entry_week:(_date "2024-02-02")
        ~exit_week:(_date "2024-03-01") ~pnl_dollars:300.0 ~r_multiple:3.0 ();
      (* Alphabetical-last but largest P&L (must render first). *)
      _make_optimal_rt ~symbol:"ZBIG" ~entry_week:(_date "2024-02-09")
        ~exit_week:(_date "2024-03-08") ~pnl_dollars:1_000.0 ~r_multiple:10.0 ();
      (* Alphabetical-middle but smallest P&L (must render last). *)
      _make_optimal_rt ~symbol:"MSML" ~entry_week:(_date "2024-02-16")
        ~exit_week:(_date "2024-03-15") ~pnl_dollars:50.0 ~r_multiple:0.5 ();
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
  (* Restrict the search to the missed-trades section so we don't pick up
     symbol mentions from the divergence section (which lists them by
     entry-week, not by P&L). *)
  let missed_section =
    let start_idx =
      String.substr_index_exn md ~pattern:"## Trades the actual missed"
    in
    let end_idx =
      String.substr_index_exn md ~pos:start_idx ~pattern:"## Implications"
    in
    String.sub md ~pos:start_idx ~len:(end_idx - start_idx)
  in
  let pos_big = _index_of missed_section "ZBIG" in
  let pos_mid = _index_of missed_section "AAA" in
  let pos_sml = _index_of missed_section "MSML" in
  assert_that pos_big (lt (module Int_ord) pos_mid);
  assert_that pos_mid (lt (module Int_ord) pos_sml)

(* ------------------------------------------------------------------ *)
(* Empty divergence — sentinel renders when symbol sets match           *)
(* ------------------------------------------------------------------ *)

(** When the actual and constrained sets contain the same symbols on every
    Friday, [_picks_diverge] returns false everywhere and the divergence section
    emits a single sentinel line ("_No Fridays where actual and
    constrained-counterfactual picks differed._"). Pins that contract; also
    asserts the per-Friday detail rows are absent. *)
let test_empty_divergence_renders_sentinel _ =
  let friday = _date "2024-02-02" in
  let symbol = "AAPL" in
  let actual_trade =
    _make_actual_trade ~symbol ~entry_date:friday
      ~exit_date:(_date "2024-03-01") ~pnl_dollars:200.0 ~pnl_percent:20.0 ()
  in
  let actual =
    _make_actual ~scenario_name:"no-divergence" ~round_trips:[ actual_trade ] ()
  in
  let constrained_rts =
    [
      _make_optimal_rt ~symbol ~entry_week:friday
        ~exit_week:(_date "2024-03-01") ~pnl_dollars:200.0 ~r_multiple:2.0 ();
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
         _has "## Per-Friday divergence";
         _has
           "_No Fridays where actual and constrained-counterfactual picks \
            differed._";
         (* No per-Friday detail subsection should render. *)
         field
           (fun s -> String.is_substring s ~substring:"### 2024-02-02")
           (equal_to false);
       ])

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
         "divergence section pins specific symbols / sizes / R-multiples"
         >:: test_divergence_pins_specific_cells;
         "missed trades ordered by P&L descending"
         >:: test_missed_trades_ordered_by_pnl_descending;
         "no divergence: sentinel renders, no detail rows"
         >:: test_empty_divergence_renders_sentinel;
       ]

let () = run_test_tt_main suite
