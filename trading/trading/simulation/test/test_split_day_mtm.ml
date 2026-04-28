(** Regression: split-day mark-to-market on open positions.

    Bug: prior to PR-3 of the broker-model split redesign,
    [Simulator._compute_portfolio_value] used [Daily_price.close_price] (raw,
    unadjusted) to mark held positions to market, but the position quantity
    stored in [Trading_portfolio.Portfolio.positions] was the
    pre-corporate-action share count. On the day of a stock split, the raw close
    drops by the split factor (e.g. AAPL 4:1 on 2020-08-31: $499.23 → $129.04)
    while the held quantity is still the pre-split count, so a position held
    through the split sees a phantom one-day MtM crash even though the holder's
    economic value is unchanged. Surfaced on the sp500-2019-2023 golden as a
    2020-08-27..2020-08-31 equity-curve dip from ~$520K to ~$25K and back to
    ~$1.06M.

    Fix (PR-3): at the start of each daily step, before strategy invocation or
    order processing, [Simulator] runs [Split_detector.detect_split] on every
    held symbol's (yesterday, today) bar pair. When a split is detected, the
    simulator builds a [Split_event.t] and applies it to the portfolio via
    [Split_event.apply_to_portfolio], which multiplies the lot's quantity by the
    split factor while preserving total cost basis. On the split day, the
    post-split (×4) quantity multiplied by the post-split (÷4) close exactly
    cancels — portfolio value is continuous.

    The bar data itself is unchanged (no [_split_adjust_bar]); only the position
    ledger is touched. This keeps non-split-day output bit-identical to
    pre-broker-model main, so existing pinned goldens
    ([test_weinstein_backtest], [test_panel_loader_parity]) are stable. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers
module Split_event = Trading_portfolio.Split_event

let _date s = Date.of_string s

(** Build a [Daily_price.t] with explicit raw OHLC and adjusted close. *)
let _make_bar ~date ~open_ ~high ~low ~close ~adjusted_close ~volume =
  Types.Daily_price.
    {
      date;
      open_price = open_;
      high_price = high;
      low_price = low;
      close_price = close;
      adjusted_close;
      volume;
    }

(** Synthetic AAPL-like CSV spanning a 4:1 split.

    Pre-split (4 days): closes around $500. The adjusted_close on every
    pre-split day is split-back-rolled to ~$125, so the adjusted series is
    monotonic and continuous through the split.

    Split day (2020-08-31): raw close drops 4× to $125 while adjusted_close
    stays continuous at $125. The detector reads
    [adj_ratio /. raw_ratio = 1.0 / 0.25 = 4.0] and snaps it to the rational
    [4/1].

    Post-split (1 day): another flat $125 day to confirm continuity persists. *)
let _split_aapl_prices =
  [
    _make_bar ~date:(_date "2020-08-25") ~open_:498.0 ~high:500.0 ~low:495.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-26") ~open_:500.0 ~high:506.0 ~low:498.0
      ~close:504.0 ~adjusted_close:126.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-27") ~open_:504.0 ~high:508.0 ~low:496.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-28") ~open_:500.0 ~high:502.0 ~low:498.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    (* Split day: 4:1 forward — raw ÷4, adjusted continuous. *)
    _make_bar ~date:(_date "2020-08-31") ~open_:125.0 ~high:127.0 ~low:124.0
      ~close:125.0 ~adjusted_close:125.0 ~volume:4_000_000;
    _make_bar ~date:(_date "2020-09-01") ~open_:125.0 ~high:126.0 ~low:124.0
      ~close:125.0 ~adjusted_close:125.0 ~volume:4_000_000;
  ]

(** Default config for the split-day scenario. 100,000 cash, zero commission so
    we can pin portfolio_value precisely. *)
let _split_config =
  {
    start_date = _date "2020-08-25";
    end_date = _date "2020-09-02";
    initial_cash = 100_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

(** Strategy that buys [target_quantity] shares of [symbol] on its first
    invocation (using today's bar as context) and then holds passively. No exits
    — lets the simulator walk through every day so we can observe split-day MtM
    behaviour on a held position. *)
module Make_buy_and_hold (Cfg : sig
  val symbol : string
  val target_quantity : float
end) : Trading_strategy.Strategy_interface.STRATEGY = struct
  let name = "BuyAndHold"
  let entered = ref false

  let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
    if !entered then Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else
      match get_price Cfg.symbol with
      | None -> Ok { Trading_strategy.Strategy_interface.transitions = [] }
      | Some (bar : Types.Daily_price.t) ->
          entered := true;
          let open Trading_strategy.Position in
          let trans =
            {
              position_id = Cfg.symbol ^ "-hold";
              date = bar.date;
              kind =
                CreateEntering
                  {
                    symbol = Cfg.symbol;
                    side = Long;
                    target_quantity = Cfg.target_quantity;
                    entry_price = bar.close_price;
                    reasoning =
                      TechnicalSignal
                        { indicator = "test"; description = "buy-and-hold" };
                  };
            }
          in
          Ok { Trading_strategy.Strategy_interface.transitions = [ trans ] }
end

(** Largest absolute one-day fractional drop in [step.portfolio_value] across
    consecutive trading-day steps with open positions. Skips:
    - steps where the portfolio holds no position (no MtM to check);
    - steps where [portfolio_value ~ current_cash] (the simulator falls back to
      [portfolio_value = cash] on non-trading days / when bars are missing, a
      known artefact unrelated to the split bug). *)
let _max_one_day_drop steps =
  let values =
    List.filter_map steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        let cash = s.portfolio.Trading_portfolio.Portfolio.current_cash in
        let has_pos =
          not (List.is_empty s.portfolio.Trading_portfolio.Portfolio.positions)
        in
        let is_marked = Float.(abs (s.portfolio_value -. cash) > 1e-2) in
        if has_pos && is_marked && Float.(s.portfolio_value > 0.0) then
          Some s.portfolio_value
        else None)
  in
  match values with
  | [] | [ _ ] -> 0.0
  | first :: rest ->
      let _, max_drop =
        List.fold rest ~init:(first, 0.0) ~f:(fun (prev, max_d) curr ->
            let drop = (prev -. curr) /. prev in
            (curr, Float.max max_d drop))
      in
      max_drop

(** Fetch the simulator step for a specific date. Fails the test if the date is
    missing from [steps]. *)
let _step_on ~date steps =
  match
    List.find steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.equal s.date date)
  with
  | Some s -> s
  | None ->
      assert_failure
        (Printf.sprintf "no step on %s; have %d steps" (Date.to_string date)
           (List.length steps))

(* ------------------------------------------------------------------ *)
(* Test 1: portfolio value continuous through a 4:1 split              *)
(* ------------------------------------------------------------------ *)

(** With 100 shares held through a 4:1 split:

    - Day 1 (08-25): strategy submits a 100-share entry; order pending.
    - Day 2 (08-26): order fills at open=500, cash=100,000-50,000=50,000.
      Position: 100 shares. Close=504. portfolio_value=50,000+50,400=100,400.
    - Days 3-4: position unchanged at 100 shares × close.
    - Day 5 (08-31, split day): detector fires. After
      [Split_event.apply_to_portfolio], position becomes 400 shares with the
      same total cost basis 50,000 (per-share cost: 500 → 125). Today's
      close=125. portfolio_value = 50,000 + 400 × 125 = 100,000.
    - Day 6 (09-01): 50,000 + 400 × 125 = 100,000 still.

    Pre-fix: day 5's portfolio_value would have been 50,000 + 100 × 125 = 62,500
    — a 37.5% one-day drop. Post-fix: 0% drop. The 5% threshold cleanly
    separates the two regimes. *)
let test_portfolio_value_continuous_through_split _ =
  with_test_data "split_day_mtm_continuous"
    [ ("AAPL", _split_aapl_prices) ]
    ~f:(fun data_dir ->
      let module Hold = Make_buy_and_hold (struct
        let symbol = "AAPL"
        let target_quantity = 100.0
      end) in
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Hold)
          ~commission:_split_config.commission ()
      in
      let sim = create_exn ~config:_split_config ~deps in
      let result =
        match run sim with
        | Ok r -> r
        | Error err -> assert_failure ("simulation failed: " ^ Status.show err)
      in
      (* Smoke: simulation produced ≥ 6 trading days of output and the
         held position survived to the end of the window. *)
      let last = List.last_exn result.steps in
      assert_that last.portfolio.positions (size_is 1);
      (* No phantom MtM drop on the split day. Pre-fix this would be 37.5%;
         post-fix it should be effectively zero. *)
      assert_that (_max_one_day_drop result.steps) (lt (module Float_ord) 0.05);
      (* Pinned values: split-day portfolio_value = $100,000 (50,000 cash +
         400 shares × $125), continuous with day 4's $100,000. Post-split
         day still $100,000. Both pinned to 1¢ tolerance. *)
      let split_day = _step_on ~date:(_date "2020-08-31") result.steps in
      assert_that split_day
        (all_of
           [
             field
               (fun s -> s.portfolio_value)
               (float_equal ~epsilon:0.01 100_000.0);
             field (fun s -> List.length s.splits_applied) (equal_to 1);
             field
               (fun s -> s.splits_applied)
               (elements_are
                  [
                    all_of
                      [
                        field (fun e -> e.Split_event.symbol) (equal_to "AAPL");
                        field (fun e -> e.Split_event.factor) (float_equal 4.0);
                        field
                          (fun e -> e.Split_event.date)
                          (equal_to (_date "2020-08-31"));
                      ];
                  ]);
           ]);
      let post_split = _step_on ~date:(_date "2020-09-01") result.steps in
      assert_that post_split
        (all_of
           [
             field
               (fun s -> s.portfolio_value)
               (float_equal ~epsilon:0.01 100_000.0);
             field (fun s -> List.length s.splits_applied) (equal_to 0);
           ]))

(* ------------------------------------------------------------------ *)
(* Test 2: no-split window is bit-identical to pre-broker-model main   *)
(* ------------------------------------------------------------------ *)

(** When [adjusted_close = close_price] for every bar (no split, no dividend in
    window), the broker-model fix is a no-op: the detector never fires, no
    [Split_event] is produced, and the simulator's per-step output matches what
    it would have been before PR-3.

    Verifies bit-equality on a no-strategy run: 3 trading days of
    [Noop_strategy], no positions,
    [portfolio_value = current_cash = initial_cash] every step. The point of
    this test is the negative result — [splits_applied] is empty on every step.
*)
let test_no_split_window_unchanged _ =
  let no_split_prices =
    [
      _make_bar ~date:(_date "2024-01-02") ~open_:150.0 ~high:155.0 ~low:149.0
        ~close:154.0 ~adjusted_close:154.0 ~volume:1_000_000;
      _make_bar ~date:(_date "2024-01-03") ~open_:154.0 ~high:158.0 ~low:153.0
        ~close:157.0 ~adjusted_close:157.0 ~volume:1_200_000;
      _make_bar ~date:(_date "2024-01-04") ~open_:157.0 ~high:160.0 ~low:155.0
        ~close:159.0 ~adjusted_close:159.0 ~volume:900_000;
    ]
  in
  with_test_data "split_day_mtm_no_split"
    [ ("AAPL", no_split_prices) ]
    ~f:(fun data_dir ->
      let config =
        {
          start_date = _date "2024-01-02";
          end_date = _date "2024-01-05";
          initial_cash = 10_000.0;
          commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
          strategy_cadence = Types.Cadence.Daily;
        }
      in
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Noop_strategy)
          ~commission:config.commission ()
      in
      let sim = create_exn ~config ~deps in
      let result =
        match run sim with
        | Ok r -> r
        | Error err -> assert_failure ("simulation failed: " ^ Status.show err)
      in
      (* Every step: portfolio_value = initial cash (no positions ever),
         and no split events. *)
      let expected_step =
        all_of
          [
            field
              (fun (s : Trading_simulation_types.Simulator_types.step_result) ->
                s.portfolio_value)
              (float_equal 10_000.0);
            field (fun s -> s.splits_applied) (size_is 0);
          ]
      in
      assert_that result.steps
        (elements_are
           (List.init (List.length result.steps) ~f:(fun _ -> expected_step))))

(* ------------------------------------------------------------------ *)
(* Test 3: split day for a symbol NOT in the portfolio is a no-op      *)
(* ------------------------------------------------------------------ *)

(** Distinguishes the broker-model fix from the band-aid (the closed PR #641's
    [_split_adjust_bar], which rescaled bars universe-wide for any symbol with a
    future corporate action). The broker model only touches the portfolio on
    splits for {b held} symbols.

    Setup: same 4:1-split AAPL CSV as test 1, but the strategy does nothing — we
    never enter a position. The simulator should produce 0 split events on every
    step (the detector still has data to read, but
    [_detect_splits_for_held_positions] iterates only over held positions and
    the held set is always empty). Cash and position ledger are unchanged from
    initial. *)
let test_split_day_with_no_position_held _ =
  with_test_data "split_day_mtm_no_position"
    [ ("AAPL", _split_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Noop_strategy)
          ~commission:_split_config.commission ()
      in
      let sim = create_exn ~config:_split_config ~deps in
      let result =
        match run sim with
        | Ok r -> r
        | Error err -> assert_failure ("simulation failed: " ^ Status.show err)
      in
      (* Every step: no positions, portfolio_value = initial cash, no split
         events recorded — the split is observable in the bars but the
         broker model only acts on held symbols. *)
      let expected_step =
        all_of
          [
            field
              (fun (s : Trading_simulation_types.Simulator_types.step_result) ->
                s.portfolio_value)
              (float_equal _split_config.initial_cash);
            field (fun s -> List.length s.portfolio.positions) (equal_to 0);
            field (fun s -> s.splits_applied) (size_is 0);
          ]
      in
      assert_that result.steps
        (elements_are
           (List.init (List.length result.steps) ~f:(fun _ -> expected_step))))

let suite =
  "split_day_mtm"
  >::: [
         "portfolio_value_continuous_through_split"
         >:: test_portfolio_value_continuous_through_split;
         "no_split_window_unchanged" >:: test_no_split_window_unchanged;
         "split_day_with_no_position_held"
         >:: test_split_day_with_no_position_held;
       ]

let () = run_test_tt_main suite
