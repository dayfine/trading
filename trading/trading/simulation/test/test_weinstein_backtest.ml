(** Weinstein strategy historical backtesting integration tests.

    Runs [Simulator.run] with [Weinstein_strategy] over a multi-year window on 7
    real stocks + GSPC.INDX index, using committed test data fixtures at
    [test_data/].

    All test data is committed and deterministic — assertions pin exact trade
    counts, symbols, and portfolio values. If the strategy logic changes, these
    tests catch it. *)

open OUnit2
open Core
open Matchers
open Trading_simulation
module Bar_reader = Weinstein_strategy.Bar_reader

(* ------------------------------------------------------------------ *)
(* Constants                                                            *)
(* ------------------------------------------------------------------ *)

let data_dir = Fpath.to_string (Data_path.default_data_dir ())
let universe = [ "AAPL"; "MSFT"; "JPM"; "JNJ"; "CVX"; "KO"; "HD" ]
let index_symbol = "GSPC.INDX"
let all_symbols = index_symbol :: universe
let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }
let initial_cash = 500_000.0

(* Conservative position sizing: 0.3% risk per trade keeps each position
   small enough to avoid cash exhaustion when multiple stocks enter. *)
let conservative_portfolio_config =
  {
    Portfolio_risk.default_config with
    risk_per_trade_pct = 0.003;
    max_positions = 10;
  }

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

(** Build a [Bar_reader.t] from per-symbol CSVs in [data_dir] for the universe +
    requested date range. Phase F.3.a-4 (`?bar_panels` retirement): previously
    constructed a [Bar_panels.t] via {!Ohlcv_panels.load_from_csv_calendar} and
    threaded it through [Weinstein_strategy.make ~bar_panels]. After the
    optional [?bar_panels] parameter was removed, the integration test loads
    each symbol's bars from CSV directly via {!Csv.Csv_storage.get} and routes
    them through {!Bar_reader.of_in_memory_bars} — no panel allocation. *)
let _build_bar_reader ~start_date ~end_date =
  let symbol_bars =
    List.map all_symbols ~f:(fun symbol ->
        let storage =
          match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
          | Ok s -> s
          | Error err ->
              assert_failure ("Csv_storage.create: " ^ Status.show err)
        in
        match Csv.Csv_storage.get storage ~start_date ~end_date () with
        | Ok bars -> (symbol, bars)
        | Error err -> assert_failure ("Csv_storage.get: " ^ Status.show err))
  in
  Bar_reader.of_in_memory_bars symbol_bars

(** Build a Weinstein strategy configured for the 7-stock universe. The
    [bar_reader] handle threads the snapshot-backed bar reader into the strategy
    so its [Stage]/[RS]/[Stock_analysis]/[Stops_runner] reads have a populated
    source. *)
let _make_strategy ~bar_reader =
  let ad_bars = Weinstein_strategy.Ad_bars.load ~data_dir in
  let ticker_sectors =
    Sector_map.load ~data_dir:(Data_path.default_data_dir ())
  in
  let base_config = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    { base_config with portfolio_config = conservative_portfolio_config }
  in
  Weinstein_strategy.make ~ad_bars ~ticker_sectors ~bar_reader config

(** Create simulator deps and config, then run the simulation. *)
let _run_backtest ~start_date ~end_date =
  let bar_reader = _build_bar_reader ~start_date ~end_date in
  let strategy = _make_strategy ~bar_reader in
  let deps =
    Simulator.create_deps ~symbols:all_symbols ~data_dir:(Fpath.v data_dir)
      ~strategy ~commission:sample_commission ()
  in
  let sim_config =
    Simulator.
      {
        start_date;
        end_date;
        initial_cash;
        commission = sample_commission;
        strategy_cadence = Types.Cadence.Daily;
      }
  in
  let sim =
    match Simulator.create ~config:sim_config ~deps with
    | Ok s -> s
    | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
  in
  match Simulator.run sim with
  | Ok r -> r
  | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)

let _count_by_side steps side =
  List.concat_map steps ~f:(fun s -> s.Simulator.trades)
  |> List.count ~f:(fun t ->
      Trading_base.Types.equal_side t.Trading_base.Types.side side)

let _traded_symbols steps =
  List.concat_map steps ~f:(fun s -> s.Simulator.trades)
  |> List.map ~f:(fun t -> t.Trading_base.Types.symbol)
  |> List.dedup_and_sort ~compare:String.compare

let _min_portfolio_value steps =
  List.fold steps ~init:Float.max_value ~f:(fun acc s ->
      Float.min acc s.Simulator.portfolio_value)

(* ------------------------------------------------------------------ *)
(* 6-year full lifecycle: 2018–2023                                     *)
(* ------------------------------------------------------------------ *)

let test_six_year_full_lifecycle _ =
  let result =
    _run_backtest
      ~start_date:(Date.of_string "2018-01-02")
      ~end_date:(Date.of_string "2023-12-29")
  in
  let n_buys = _count_by_side result.steps Trading_base.Types.Buy in
  let n_sells = _count_by_side result.steps Trading_base.Types.Sell in
  let final_value = (List.last_exn result.steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips result.steps in
  let symbols = _traded_symbols result.steps in
  let stats = Metrics.compute_summary round_trips in
  let max_drawdown_pct =
    (initial_cash -. _min_portfolio_value result.steps) /. initial_cash
  in
  (* Stage 3 PR 3.2 (post-rework): pin the deterministic post-3.2 values.
     With [Bar_history] deleted, panel-backed reads make bars visible
     up-front rather than via the pre-3.2 incremental cache. The trade
     counts shifted from the buggy pre-3.2 numbers (23/21 with 10W/11L)
     to the correct post-3.2 numbers captured below. The exact set of
     traded tickers, win/loss split, and a tight final-value band
     guarantee the strategy path is reproducible end-to-end.

     Short-side cascade-rules update (2026-04): n_buys/n_sells bumped
     from 36/33 → 39/36 after the support-below clean-space signal
     joined the short-side score. Three additional short trades in
     2018-2020 bear with no change to the round-trip count or
     traded-symbol set; final value drift well inside the ±$3K band.

     G14 (2026-05-01) — Fix B (Position.t.entry_price = current close at
     order placement) plus split-boundary lookback truncation. Position
     sizing now correctly uses [effective_entry] (current close) rather
     than [cand.suggested_entry] (a buffered breakout level historically
     above current price).

     G15 step 3 (2026-05-01) — Pre-entry stop-width gate (15% cap) +
     sizing-uses-installed-stop. Sizing now keys off the support-floor-
     derived [installed_stop] instead of [cand.suggested_stop]. Wider
     structural stops → smaller risk_per_share → fewer shares → less
     cash consumed per entry, so more candidates fit the running cash
     budget. Net effect on this 6-year window:
     - 30 buys / 27 sells (up from 27 / 25 pre-G15-step-3) across the
       same 7-symbol set
     - 27 round-trips (5W/22L) — same risk profile, just more entries
     - max drawdown 54% (down from 95% pre-G15-step-3) reflects the
       smaller per-entry exposure capping the underlying short-side
       drawdown amplitude. *)
  (* A-D-live default flip (2026-06-23, PR #1725): the synthetic breadth tail
     makes the macro gate live for 2020-2023, admitting one fewer entry in this
     2018-2023 window (29/26, 26 round-trips, 4W/22L vs 30/27, 27, 5W/22L).
     Same 7-symbol set; final value and max-DD still inside their bands. *)
  (* neutral_blocks_shorts default flip (2026-07-09, false->true; faithfulness
     flip, user mandate — see weinstein_strategy_config.mli): the flip blocks
     ONE Neutral-tape short in this window — HD, opened 2018-11-17, covered
     2019-01-08 during the Q4-2018 correction (a Neutral tape, not a confirmed
     Bearish one), a -$353 loser. Removing that short round-trip drops one
     Sell-open + its cover Buy: buys 29->28, sells 26->25, round-trips 26->25,
     losses 22->21 (wins unchanged at 4). Same 7-symbol set (HD still trades
     long). Final value 484,438.68 -> 484,753.99 (still in band); realized
     max drawdown ~5.6% -> ~5.5% (the old "54.25%" pin-comment below is stale
     from the G15 era; the loose < 0.60 assertion masked it). Delta is small,
     consistent with the ~0-cost deep-cell attribution
     (dev/notes/p1a-deep-short-screens-364-2026-07-09.md §Attribution). *)
  (* Book-faithful stops basis (2026-08-24, issue #2486): two default flips,
     decomposed by running each arm alone on this exact window —

       arm                       buys/sells  rts  W/L    final       maxDD
       baseline (1.02, false)      28/25      25  4/21   484,753.99  5.54%
       reset_anchor=true only      28/25      25  5/20   489,926.68  4.52%
       initial_stop_buffer=1.0 only 26/22     22  2/20   501,292.61  3.69%
       BOTH (shipped)              28/24      24  4/20   491,691.09  3.65%

     [initial_stop_buffer] 1.02 -> 1.0 widens the fallback stop 2.08% -> 4%,
     which halves risk-bound entry sizes and moves stops below the tight
     cluster that was cutting positions at ~2%; [reset_anchor_on_stalled_cycle]
     false -> true lets fallback positions ratchet from their SECOND completed
     cycle. Combined, one 2018-2023 round-trip that previously closed at a loss
     is still open at the window end (sells/rts 25 -> 24, losses 21 -> 20) and
     the realized max drawdown drops 5.54% -> 3.65%. Same 7-symbol set, same
     28 buys. *)
  (* RS-trend fix (2026-08-25, issue #2380): [lookback_bars] 52 -> 56, the
     minimum weekly depth at which [Rs._classify_trend] can classify at all.
     Before it, the RS history was one entry long and EVERY candidate in EVERY
     run came back [Positive_flat], so the screener's RS scoring term was a
     constant [w_positive_rs / 2] carrying zero ranking information. With the
     term live, ranking differentiates and two more entries clear the top-N on
     this window: buys 28 -> 30, sells 24 -> 26, round-trips 24 -> 26, losses
     20 -> 22 (wins unchanged at 4), final value 491,691.09 -> 487,853.30,
     realized max drawdown 3.65% -> 4.41%. Same 7-symbol set, same 2187 steps.

     This is a CORRECTNESS re-pin, not a result claim: the direction of the
     move on one 7-symbol fixture is noise, and no return improvement was
     expected or is asserted (rs_value carries no measurable ranking edge —
     permutation p = 0.182, issue #2380). The deeper view also reaches every
     other standard weekly consumer (volume, breakout/resistance zones), so
     part of the delta is that widening rather than the RS term alone. *)
  assert_that (List.length result.steps) (equal_to 2187);
  assert_that n_buys (equal_to 30);
  assert_that n_sells (equal_to 26);
  assert_that symbols
    (elements_are
       [
         equal_to "AAPL";
         equal_to "CVX";
         equal_to "HD";
         equal_to "JNJ";
         equal_to "JPM";
         equal_to "KO";
         equal_to "MSFT";
       ]);
  assert_that (List.length round_trips) (equal_to 26);
  assert_that stats
    (is_some_and
       (all_of
          [
            field (fun s -> s.Metrics.win_count) (equal_to 4);
            field (fun s -> s.Metrics.loss_count) (equal_to 22);
          ]));
  (* Final value $487,853.30 under the 2026-08-25 RS-trend fix (was
     $491,691.09); band re-centred at ±$3K around the new value. *)
  assert_that final_value
    (is_between (module Float_ord) ~low:484_853.30 ~high:490_853.30);
  (* Realized max drawdown ~4.4% under the fix; pin loose at < 0.60. *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.60)

(* ------------------------------------------------------------------ *)
(* Entry/exit cycle around COVID crash: 2019–mid 2020                   *)
(* ------------------------------------------------------------------ *)

let test_entry_exit_cycle_around_covid _ =
  let result =
    _run_backtest
      ~start_date:(Date.of_string "2019-01-02")
      ~end_date:(Date.of_string "2020-06-30")
  in
  let n_buys = _count_by_side result.steps Trading_base.Types.Buy in
  let n_sells = _count_by_side result.steps Trading_base.Types.Sell in
  let final_value = (List.last_exn result.steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips result.steps in
  let symbols = _traded_symbols result.steps in
  let stats = Metrics.compute_summary round_trips in
  let max_drawdown_pct =
    (initial_cash -. _min_portfolio_value result.steps) /. initial_cash
  in
  (* Stage 3 PR 3.2 (post-rework): pinned post-3.2 deterministic values.
     Pre-3.2 was 6 buys / 6 sells; post-3.2 the cycle yields 11 buys / 10
     sells across {AAPL, HD, JNJ, KO} with 4W/6L and final ≈ $512,025.

     G14 (2026-05-01): realised-entry sizing reduces trade count to
     8 / 7 (same symbol set), 7 round-trips with 2W/5L.

     G15 step 3 (2026-05-01): same trade count + W/L (8/7, 2W/5L) on
     same symbol set; final value drops to $506,145 because sizing-
     uses-installed-stop trims per-entry size on the longs that worked,
     reducing compounding upside. Max drawdown 48.6% (down from 54.4%
     pre-G15-step-3) for the same reason.

     Book-faithful stops basis (2026-08-24, issue #2486), decomposed on this
     window —

       arm                        buys/sells rts W/L   final
       baseline (1.02, false)       8/7       7  2/5   506,145.21
       reset_anchor=true only       8/8       8  3/5   495,458.77
       initial_stop_buffer=1.0 only 8/6       6  0/6   505,130.26
       BOTH (shipped)               8/7       7  1/6   494,474.24

     The two flips pull the exit count in opposite directions here — the
     unfreeze lets a ratcheted trailing stop close one extra position, the
     wider fallback stop keeps two positions alive past the COVID low — and
     land back on 7 sells with a different win/loss split (2W/5L -> 1W/6L):
     one winner that used to be trailed out now runs into the crash and closes
     red. Entry count and symbol set are unchanged. *)
  assert_that (List.length result.steps) (equal_to 545);
  assert_that n_buys (equal_to 8);
  assert_that n_sells (equal_to 7);
  assert_that symbols
    (elements_are
       [ equal_to "AAPL"; equal_to "HD"; equal_to "JNJ"; equal_to "KO" ]);
  assert_that (List.length round_trips) (equal_to 7);
  assert_that stats
    (is_some_and
       (all_of
          [
            field (fun s -> s.Metrics.win_count) (equal_to 1);
            field (fun s -> s.Metrics.loss_count) (equal_to 6);
          ]));
  (* 2026-08-24 stops-basis flips: final value $494,474.24 ± $5K (was
     $506,145.21 at the G15 step-3 pin). *)
  assert_that final_value
    (is_between (module Float_ord) ~low:489_474.24 ~high:499_474.24);
  (* G15 step 3 (2026-05-01): max drawdown 48.59%; pin loose at < 0.52. *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.52)

(* ------------------------------------------------------------------ *)
(* Portfolio value stays positive: 2020–2021                            *)
(* ------------------------------------------------------------------ *)

let test_portfolio_value_stays_positive _ =
  let result =
    _run_backtest
      ~start_date:(Date.of_string "2020-01-02")
      ~end_date:(Date.of_string "2021-12-31")
  in
  let n_buys = _count_by_side result.steps Trading_base.Types.Buy in
  let n_sells = _count_by_side result.steps Trading_base.Types.Sell in
  let min_value = _min_portfolio_value result.steps in
  let max_drawdown_pct = (initial_cash -. min_value) /. initial_cash in
  let final_value = (List.last_exn result.steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips result.steps in
  let symbols = _traded_symbols result.steps in
  let stats = Metrics.compute_summary round_trips in
  (* Stage 3 PR 3.2 (post-rework): pinned post-3.2 values. The 2020-2021
     window opens during the COVID crash, so every step has positive PV
     and the strategy completes 4 buys / 3 sells across {HD, KO} with
     1W/2L and final ≈ $505,302.82.

     G14 (2026-05-01): realised-entry sizing yields 3 / 2 trades on the
     same symbol set, 2 round-trips with 1W/1L.

     G15 step 3 (2026-05-01): smaller per-entry sizing admits one extra
     candidate that previously got cash-rejected → 4 / 3 trades, 3
     round-trips with 1W/2L on same {HD, KO} symbol set. Final
     $523,068; max drawdown 16.94% (up from 9.63% — the additional
     entry is a loser whose MTM swing dominates the new minimum PV).
     PV still stays positive throughout.

     Book-faithful stops basis (2026-08-24, issue #2486): trade counts, symbol
     set and W/L are all UNCHANGED here — only the final value moves,
     $523,067.89 -> $511,354.54, and it moves entirely under the
     [initial_stop_buffer] flip (the [reset_anchor_on_stalled_cycle] arm run
     alone reproduces $523,067.89 to the cent). Smaller risk-bound sizes on the
     same three round-trips means less compounding upside; the minimum PV
     actually improves, $496,490.82 -> $497,514.40, so max drawdown falls
     0.70% -> 0.50%. *)
  assert_that (List.length result.steps) (equal_to 729);
  assert_that n_buys (equal_to 4);
  assert_that n_sells (equal_to 3);
  assert_that symbols (elements_are [ equal_to "HD"; equal_to "KO" ]);
  assert_that (List.length round_trips) (equal_to 3);
  assert_that stats
    (is_some_and
       (all_of
          [
            field (fun s -> s.Metrics.win_count) (equal_to 1);
            field (fun s -> s.Metrics.loss_count) (equal_to 2);
          ]));
  assert_that min_value (gt (module Float_ord) 0.0);
  (* Max drawdown ~0.50% under the 2026-08-24 flips; cap kept loose at < 0.20
     (the "16.94%" figure in the comment above is stale from the G15 era). *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.20);
  (* 2026-08-24 stops-basis flips: final value $511,354.54 ± $3K (was
     $523,067.89 at the G15 step-3 pin). *)
  assert_that final_value
    (is_between (module Float_ord) ~low:508_354.54 ~high:514_354.54)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "weinstein_backtest"
  >::: [
         "6-year full lifecycle" >:: test_six_year_full_lifecycle;
         "entry/exit cycle around COVID" >:: test_entry_exit_cycle_around_covid;
         "portfolio value stays positive"
         >:: test_portfolio_value_stays_positive;
       ]

let () = run_test_tt_main suite
