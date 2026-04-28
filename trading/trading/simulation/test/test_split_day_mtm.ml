(** Regression: split-day mark-to-market on open positions.

    Bug: prior to the fix, [Simulator._compute_portfolio_value] used
    [Daily_price.close_price] (raw, unadjusted) to mark open positions to
    market. On the day of a stock split the raw close drops by the split factor
    (e.g. AAPL 4:1 on 2020-08-31: $499.23 → $129.04), so a position held through
    the split sees a ~75% one-day MtM crash even though the holder's economic
    value is unchanged.

    Surfaced on the sp500-2019-2023 golden as a 2020-08-27..2020-08-31
    equity-curve dip from ~$520K to ~$25K and back to ~$1.06M
    (dev/notes/goldens-performance-baselines-2026-04-28.md).

    Fix: scale every OHLC field returned to the simulator by
    [adjusted_close / close_price] so the engine's order-fill path AND
    [_compute_portfolio_value] both see split-adjusted prices. The trade
    record's [price] (and therefore the portfolio's [cost_basis]) ends up in the
    same "adjusted units" as the MtM, preserving continuity through splits.

    The test constructs a synthetic AAPL-like CSV with a 4:1 split between day 2
    and day 3, holds a position spanning the split, and asserts portfolio_value
    never drops by more than a small per-day tolerance — in particular, no >10%
    drop on the split day. Without the fix the drop is 75%; with the fix it's
    effectively zero. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

(** Build a [Daily_price.t] with explicit raw OHLC + adjusted close. *)
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

    Pre-split: prices ~$500. The four pre-split bars sit on consecutive
    weekdays.

    Split day: raw close drops 4× to ~$125 while adjusted_close stays
    continuous. Adjusted closes on pre-split days are the split-back-rolled
    versions (~$125 too) so the adjusted series is monotonic and continuous.

    Post-split: another flat day at $125 to confirm continuity persists. *)
let _split_aapl_prices =
  [
    _make_bar
      ~date:(date_of_string "2020-08-25")
      ~open_:498.0 ~high:500.0 ~low:495.0 ~close:500.0 ~adjusted_close:125.0
      ~volume:1_000_000;
    _make_bar
      ~date:(date_of_string "2020-08-26")
      ~open_:500.0 ~high:506.0 ~low:498.0 ~close:504.0 ~adjusted_close:126.0
      ~volume:1_000_000;
    _make_bar
      ~date:(date_of_string "2020-08-27")
      ~open_:504.0 ~high:508.0 ~low:496.0 ~close:500.0 ~adjusted_close:125.0
      ~volume:1_000_000;
    _make_bar
      ~date:(date_of_string "2020-08-28")
      ~open_:500.0 ~high:502.0 ~low:498.0 ~close:500.0 ~adjusted_close:125.0
      ~volume:1_000_000;
    (* Split day: 4:1, raw drops 4×, adjusted continuous. *)
    _make_bar
      ~date:(date_of_string "2020-08-31")
      ~open_:125.0 ~high:127.0 ~low:124.0 ~close:125.0 ~adjusted_close:125.0
      ~volume:4_000_000;
    _make_bar
      ~date:(date_of_string "2020-09-01")
      ~open_:125.0 ~high:126.0 ~low:124.0 ~close:125.0 ~adjusted_close:125.0
      ~volume:4_000_000;
  ]

let _config =
  {
    start_date = date_of_string "2020-08-25";
    end_date = date_of_string "2020-09-02";
    initial_cash = 100_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

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

(** Strategy that creates a long entry of [target_quantity] AAPL shares on its
    first call (using the simulator's current_date taken from [get_price]) and
    then holds passively. No exits; lets the simulator walk through every day so
    we can observe split-day MtM behaviour on a held position. *)
module Make_hold_through_split () :
  Trading_strategy.Strategy_interface.STRATEGY = struct
  let name = "HoldThroughSplit"
  let entered = ref false

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    let _ = portfolio in
    if !entered then Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else
      match get_price "AAPL" with
      | None -> Ok { Trading_strategy.Strategy_interface.transitions = [] }
      | Some (bar : Types.Daily_price.t) ->
          entered := true;
          let open Trading_strategy.Position in
          let trans =
            {
              position_id = "AAPL-hold";
              date = bar.date;
              kind =
                CreateEntering
                  {
                    symbol = "AAPL";
                    side = Long;
                    target_quantity = 100.0;
                    entry_price = bar.close_price;
                    reasoning =
                      TechnicalSignal
                        {
                          indicator = "test";
                          description = "hold through split";
                        };
                  };
            }
          in
          Ok { Trading_strategy.Strategy_interface.transitions = [ trans ] }
end

let test_portfolio_value_continuous_through_split _ =
  with_test_data "split_day_mtm"
    [ ("AAPL", _split_aapl_prices) ]
    ~f:(fun data_dir ->
      (* Strategy enters AAPL on day 1, holds through the split, never
         exits. The simulator marks-to-market each step using the bar's
         close. *)
      let module Hold = Make_hold_through_split () in
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Hold)
          ~commission:_config.commission ()
      in
      let sim = create_exn ~config:_config ~deps in
      let result =
        match run sim with
        | Ok r -> r
        | Error err -> assert_failure ("simulation failed: " ^ Status.show err)
      in
      (* Sanity: 100 shares should fill at the day-2 open (= 500.0 raw, or
         125.0 adjusted post-fix). Either way the position exists. *)
      let last = List.last_exn result.steps in
      assert_that last.portfolio.positions (size_is 1);
      (* The split day's MtM must not crash. Pre-fix the synthetic 4:1
         split caused a ~37.5% one-day MtM drop on the held position;
         post-fix it's effectively zero (only the small intra-week price
         moves the synthetic data has). 5% is a comfortable ceiling. *)
      assert_that (_max_one_day_drop result.steps) (lt (module Float_ord) 0.05))

(** Companion: when adjusted_close == close_price for every bar (no split, no
    dividend in window), the fix is a no-op. Verifies bit-exact continuity using
    prices that match the raw closes. *)
let test_no_split_window_unchanged _ =
  let no_split_prices =
    [
      _make_bar
        ~date:(date_of_string "2024-01-02")
        ~open_:150.0 ~high:155.0 ~low:149.0 ~close:154.0 ~adjusted_close:154.0
        ~volume:1_000_000;
      _make_bar
        ~date:(date_of_string "2024-01-03")
        ~open_:154.0 ~high:158.0 ~low:153.0 ~close:157.0 ~adjusted_close:157.0
        ~volume:1_200_000;
      _make_bar
        ~date:(date_of_string "2024-01-04")
        ~open_:157.0 ~high:160.0 ~low:155.0 ~close:159.0 ~adjusted_close:159.0
        ~volume:900_000;
    ]
  in
  with_test_data "no_split_window"
    [ ("AAPL", no_split_prices) ]
    ~f:(fun data_dir ->
      let config =
        {
          start_date = date_of_string "2024-01-02";
          end_date = date_of_string "2024-01-05";
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
      (* No positions, no trades — portfolio_value stays at initial cash. *)
      assert_that result.steps
        (elements_are
           (List.init (List.length result.steps) ~f:(fun _ ->
                field
                  (fun (s :
                         Trading_simulation_types.Simulator_types.step_result)
                     -> s.portfolio_value)
                  (float_equal 10_000.0)))))

let suite =
  "split_day_mtm"
  >::: [
         "portfolio_value_continuous_through_split"
         >:: test_portfolio_value_continuous_through_split;
         "no_split_window_unchanged" >:: test_no_split_window_unchanged;
       ]

let () = run_test_tt_main suite
