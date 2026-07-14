(** Unit tests for [Trade_audit_html.Html_report].

    Pins the self-contained HTML renderer on a small synthetic run fixture (same
    directory shape the markdown path consumes) plus a couple of direct [render]
    calls. Covers:
    - structural invariants of the emitted document ([const DATA=], one
      [<table id="trades">], the round-trip count in the subtitle, the
      [/*DATA*/] placeholder fully substituted, key template markers intact);
    - the analysis panels populated from the reused report aggregates;
    - graceful benchmark / utilization omission when no bar source is supplied,
      and their presence when one is;
    - JS-string escaping of an adversarial symbol. *)

open OUnit2
open Core
open Matchers
module TAR = Trade_audit_report
module Ratings = Trade_audit_report.Trade_audit_ratings
module HR = Trade_audit_html.Html_report
module TA = Backtest.Trade_audit

let _date = Date.of_string

let _write path text =
  Out_channel.with_file path ~f:(fun oc -> Out_channel.output_string oc text)

let _count s ~pattern =
  List.length (String.substr_index_all s ~may_overlap:false ~pattern)

let _has s sub = String.is_substring s ~substring:sub

(* Mirror of [Html_render]'s private quartile label so the passthrough
   assertions can build the exact emitted fragment. *)
let _qlabel = function
  | Ratings.Q1_top -> "Q1 (top)"
  | Q2 -> "Q2"
  | Q3 -> "Q3"
  | Q4_bottom -> "Q4 (bottom)"

(* Fixture writers ------------------------------------------------------- *)

let _canonical_header =
  "symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger,entry_stage,entry_volume_ratio,stop_initial_distance_pct,stop_trigger_kind,days_to_first_stop_trigger,screener_score_at_entry"

let _write_trades_csv path =
  _write path
    (String.concat ~sep:"\n"
       [
         _canonical_header;
         "AAPL,LONG,2020-04-25,2020-08-01,98,280.00,404.00,100,12400.00,44.20,260.00,400.00,signal_reversal,Stage2,2.4,0.07,gap_down,98,80";
         "WMT,LONG,2021-01-05,2021-03-01,55,140.00,150.00,200,2000.00,7.14,130.00,148.00,take_profit,Stage2,2.1,0.07,,55,70";
       ]
    ^ "\n")

let _write_summary path =
  _write path
    "((start_date 2020-04-24) (end_date 2021-03-01) (universe_size 500)\n\
    \ (n_steps 6) (initial_cash 1000000.00) (final_portfolio_value 1200000.00)\n\
    \ (n_round_trips 2) (stale_held_symbols (DELISTED1))\n\
    \ (metrics ((metric_types.metric_type.t.sharperatio 0.99)\n\
    \  (metric_types.metric_type.t.cagr 11.10)\n\
    \  (metric_types.metric_type.t.maxdrawdown 10.10)\n\
    \  (metric_types.metric_type.t.winrate 100.00))))\n"

let _write_equity path =
  _write path
    "date,portfolio_value\n\
     2020-04-24,1000000.00\n\
     2020-06-01,1080000.00\n\
     2020-08-01,1150000.00\n\
     2020-11-01,1160000.00\n\
     2021-01-05,1180000.00\n\
     2021-03-01,1200000.00\n"

let _write_opens path =
  _write path
    "symbol,side,entry_date,entry_price,quantity\n\
     MSFT,LONG,2020-06-10,250.00,200\n"

let _write_final_prices path = _write path "symbol,price\nMSFT,340.00\n"

(* A single AAPL audit record matching the AAPL round-trip so the analysis
   layer (ratings + behavioural + conformance + decision-quality) populates. *)
let _aapl_entry : TA.entry_decision =
  {
    symbol = "AAPL";
    entry_date = _date "2020-04-25";
    position_id = "AAPL-1";
    macro_trend = Weinstein_types.Bullish;
    macro_confidence = 0.72;
    macro_indicators = [];
    stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false };
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.018;
    rs_trend = Some Weinstein_types.Positive_rising;
    rs_value = Some 1.05;
    volume_quality = Some (Weinstein_types.Strong 2.4);
    volume_ratio = Some 2.4;
    resistance_quality = Some Weinstein_types.Clean;
    support_quality = Some Weinstein_types.Clean;
    sector_name = "Information Technology";
    sector_rating = Screener.Strong;
    cascade_score = 80;
    cascade_grade = Weinstein_types.A;
    cascade_score_components = [ ("stage2_breakout", 30) ];
    cascade_rationale = [ "Stage2 breakout" ];
    side = Trading_base.Types.Long;
    suggested_entry = 280.0;
    suggested_stop = 260.0;
    installed_stop = 260.0;
    stop_floor_kind = TA.Buffer_fallback;
    risk_pct = 0.08;
    initial_position_value = 28_000.0;
    initial_risk_dollars = 2_000.0;
    alternatives_considered = [];
  }

let _aapl_exit : TA.exit_decision =
  {
    symbol = "AAPL";
    exit_date = _date "2020-08-01";
    position_id = "AAPL-1";
    exit_trigger = Backtest.Stop_log.Signal_reversal { description = "stage3" };
    macro_trend_at_exit = Weinstein_types.Neutral;
    macro_confidence_at_exit = 0.45;
    stage_at_exit = Weinstein_types.Stage3 { weeks_topping = 2 };
    rs_trend_at_exit = Some Weinstein_types.Positive_flat;
    distance_from_ma_pct = -0.025;
    max_favorable_excursion_pct = 0.50;
    max_adverse_excursion_pct = -0.05;
    weeks_macro_was_bearish = 0;
    weeks_stage_left_2 = 1;
  }

let _write_audit path =
  Sexp.save_hum path
    (TA.sexp_of_audit_records
       [ { entry = _aapl_entry; exit_ = Some _aapl_exit } ])

let _stage_dir () =
  let dir = Core_unix.mkdtemp "/tmp/trade_audit_html_" in
  let sd = Filename.concat dir "top3000-fixture" in
  Core_unix.mkdir_p sd;
  _write_trades_csv (Filename.concat sd "trades.csv");
  _write_summary (Filename.concat sd "summary.sexp");
  _write_equity (Filename.concat sd "equity_curve.csv");
  _write_opens (Filename.concat sd "open_positions.csv");
  _write_final_prices (Filename.concat sd "final_prices.csv");
  _write_audit (Filename.concat sd "trade_audit.sexp");
  sd

let _load_fixture ?bar_close () =
  let scenario_dir = _stage_dir () in
  let report = TAR.load ~scenario_dir () in
  (report, HR.render (HR.load ?bar_close ~report ~scenario_dir ()))

let _render_fixture ?bar_close () = snd (_load_fixture ?bar_close ())

(* Tests ----------------------------------------------------------------- *)

let test_structural_invariants _ =
  let html = _render_fixture () in
  assert_that html
    (all_of
       [
         field (fun s -> _count s ~pattern:"const DATA=") (equal_to 1);
         field (fun s -> _count s ~pattern:"<table id=\"trades\">") (equal_to 1);
         field (fun s -> _has s "/*DATA*/") (equal_to false);
         (* subtitle carries the round-trip count, computed OCaml-side *)
         field (fun s -> _has s "2 round-trips") (equal_to true);
         (* both round-trip symbols made it into the trade payload *)
         field (fun s -> _has s "AAPL") (equal_to true);
         field (fun s -> _has s "WMT") (equal_to true);
         (* key generic template markers intact (balanced ${...} JS) *)
         field (fun s -> _has s "DATA.kpis.map") (equal_to true);
         field (fun s -> _has s "renderTrades()") (equal_to true);
       ])

let test_kpi_values_are_data_derived _ =
  (* The KPI tiles are computed from the fixture (initial 1.0M, final 1.2M,
     2/2 winners, cagr 11.10, sharpe 0.99, maxdd 10.10), not hardcoded like the
     hand-built mock. Pin the exact emitted [label,value,sub,hero] tuples. *)
  let html = _render_fixture () in
  assert_that html
    (all_of
       [
         field
           (fun s ->
             _has s "[\"Final NAV\",\"$1.20M\",\"cash + marked opens\",1]")
           (equal_to true);
         field
           (fun s ->
             _has s "[\"MTM return\",\"+20.0%\",\"on initial $1.00M\",0]")
           (equal_to true);
         field
           (fun s -> _has s "[\"Win rate\",\"100.0%\",\"2 / 2\",0]")
           (equal_to true);
         field
           (fun s -> _has s "[\"CAGR\",\"11.1%\",\"annualized\",0]")
           (equal_to true);
         field
           (fun s -> _has s "[\"Sharpe\",\"0.99\",\"MaxDD 10.1%\",0]")
           (equal_to true);
       ])

let test_analysis_panels_match_report _ =
  (* AAPL audit matched → analysis is Some → the conformance + decision panels
     are a verbatim passthrough of [report.analysis]: assert the emitted spirit
     score and every quartile [label,trades,wins,winrate] tuple equal the loaded
     report's fields, not just key-presence. *)
  let report, html = _load_fixture () in
  let analysis = Option.value_exn report.TAR.analysis in
  let w = analysis.weinstein in
  let spirit_str =
    if Float.is_finite w.spirit_score then sprintf "%.2f" w.spirit_score
    else "0"
  in
  let quartile_frags =
    List.map analysis.decision_quality.per_quartile
      ~f:(fun (q : Ratings.cascade_quartile_stat) ->
        sprintf "[\"%s\",%d,%d,\"%.1f%%\"]" (_qlabel q.quartile) q.trade_count
          q.win_count q.win_rate_pct)
  in
  assert_that html
    (all_of
       ([
          field (fun s -> _has s "\"conformance\":null") (equal_to false);
          field
            (fun s -> _has s (sprintf "{\"spirit\":%s" spirit_str))
            (equal_to true);
          (* the AAPL entry's stop_trigger_kind column surfaces in the table *)
          field (fun s -> _has s "gap_down") (equal_to true);
        ]
       @ List.map quartile_frags ~f:(fun frag ->
           field (fun s -> _has s frag) (equal_to true))))

let test_no_snapshot_omits_benchmark_and_util _ =
  let html = _render_fixture () in
  assert_that html
    (all_of
       [
         field (fun s -> _has s "\"has_benchmark\":false") (equal_to true);
         field (fun s -> _has s "\"util\":null") (equal_to true);
       ])

let test_bar_close_populates_benchmark_and_util _ =
  (* Constant close 100 over the 2-point downsampled curve
     [(2020-04-24, 1.0M); (2021-03-01, 1.2M)]:
       - benchmark indexes flat to initial cash (100/100) → 1.0M at both dates,
         so each curve row is [date, strat, 1000000];
       - utilization is 0% at 2020-04-24 (no position open yet) and, at
         2021-03-01, (WMT 200sh + MSFT 200sh) * 100 / 1.2M * 100 = 3.3333%. *)
  let bar_close ~symbol:_ ~as_of:_ = Some 100.0 in
  let html = _render_fixture ~bar_close () in
  assert_that html
    (all_of
       [
         field (fun s -> _has s "\"has_benchmark\":true") (equal_to true);
         field
           (fun s ->
             _has s
               "\"curve\":[[\"2020-04-24\",1000000.0000,1000000.0000],[\"2021-03-01\",1200000.0000,1000000.0000]]")
           (equal_to true);
         field (fun s -> _has s "\"util\":[0.0000,3.3333]") (equal_to true);
       ])

let _row ~symbol : HR.trade_row =
  {
    symbol;
    entry_date = _date "2020-01-01";
    exit_date = _date "2020-02-01";
    days_held = 31;
    entry_price = 1.0;
    exit_price = 2.0;
    quantity = 1.0;
    pnl_dollars = 1.0;
    pnl_percent = 100.0;
    exit_trigger = "stop_loss";
    stage = "Stage2";
    stop_kind = "";
    cascade_score = None;
  }

let _data_with_trade ~symbol : HR.data =
  {
    scenario_name = "esc";
    subtitle = "esc fixture";
    initial_cash = 1_000_000.0;
    final_nav = 1_000_000.0;
    curve =
      [ (_date "2020-01-01", 1_000_000.0); (_date "2020-02-01", 1_100_000.0) ];
    benchmark = None;
    benchmark_label = "SPY TR";
    utilization = None;
    opens = [];
    stale_held = [];
    kpis = [];
    analysis = None;
    trades = [ _row ~symbol ];
  }

let test_symbol_escaping _ =
  (* A symbol with an embedded double-quote must be escaped so it cannot break
     out of its JS string literal; the [/*DATA*/] placeholder is still gone. *)
  let html = HR.render (_data_with_trade ~symbol:"A\"B") in
  assert_that html
    (all_of
       [
         field (fun s -> _has s "A\\\"B") (equal_to true);
         field (fun s -> _has s "/*DATA*/") (equal_to false);
         field (fun s -> _count s ~pattern:"const DATA=") (equal_to 1);
       ])

let test_script_close_escaping _ =
  (* A symbol containing a script-closing tag must not inject a real one: the
     [<] is escaped to [<], so the only [</script>] in the document is the
     genuine one that terminates the inline script. *)
  let html = HR.render (_data_with_trade ~symbol:"</script>") in
  assert_that html
    (all_of
       [
         field (fun s -> _has s "\\u003c/script>") (equal_to true);
         field (fun s -> _count s ~pattern:"</script>") (equal_to 1);
       ])

let suite =
  "Trade_audit_html.Html_report"
  >::: [
         "structural invariants" >:: test_structural_invariants;
         "kpi values are data-derived" >:: test_kpi_values_are_data_derived;
         "analysis panels match report" >:: test_analysis_panels_match_report;
         "no snapshot omits benchmark and util"
         >:: test_no_snapshot_omits_benchmark_and_util;
         "bar_close populates benchmark and util"
         >:: test_bar_close_populates_benchmark_and_util;
         "symbol escaping" >:: test_symbol_escaping;
         "script-close escaping" >:: test_script_close_escaping;
       ]

let () = run_test_tt_main suite
