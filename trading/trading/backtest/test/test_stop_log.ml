open OUnit2
open Core
open Trading_strategy
open Matchers

let date = Date.of_string "2024-01-15"

(* Compact builders for the stop-ratchet tests below. The older tests inline
   their transition literals; these would be unreadable at four transitions a
   piece. *)
let _create_entering ~position_id ~side : Position.transition =
  {
    position_id;
    date;
    kind =
      CreateEntering
        {
          symbol = "AAPL";
          side;
          target_quantity = 100.0;
          entry_price = 150.0;
          reasoning = ManualDecision { description = "test" };
        };
  }

let _risk_params stop_loss_price : Position.risk_params =
  { stop_loss_price; take_profit_price = None; max_hold_days = None }

let _entry_complete ~position_id ~stop : Position.transition =
  {
    position_id;
    date;
    kind = EntryComplete { risk_params = _risk_params stop };
  }

let _update_stop ~position_id ~stop : Position.transition =
  {
    position_id;
    date;
    kind = UpdateRiskParams { new_risk_params = _risk_params stop };
  }

(* Drive one position's transitions through a fresh collector and return its
   single [stop_info]. *)
let _run_one transitions : Backtest.Stop_log.stop_info =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log transitions;
  match Backtest.Stop_log.get_stop_infos log with
  | [ info ] -> info
  | infos ->
      assert_failure
        (Printf.sprintf "expected exactly one stop_info, got %d"
           (List.length infos))

let test_create_entering_records_symbol _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.position_id)
               (equal_to "AAPL-wein-1");
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.symbol)
               (equal_to "AAPL");
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
               is_none;
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)
               is_none;
           ];
       ])

let test_entry_complete_records_stop _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
               (is_some_and (float_equal 142.50));
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.exit_stop)
               (is_some_and (float_equal 142.50));
           ];
       ])

let test_update_risk_params_updates_stop _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-01-22";
        kind =
          UpdateRiskParams
            {
              new_risk_params =
                {
                  stop_loss_price = Some 148.00;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
               (is_some_and (float_equal 142.50));
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.exit_stop)
               (is_some_and (float_equal 148.00));
           ];
       ])

let test_trigger_exit_records_trigger _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-02-01";
        kind =
          TriggerExit
            {
              exit_reason =
                StopLoss
                  {
                    stop_price = 142.50;
                    actual_price = 141.80;
                    loss_percent = 5.47;
                  };
              exit_price = 141.80;
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)
           (is_some_and
              (equal_to
                 (Backtest.Stop_log.Stop_loss
                    { stop_price = 142.50; actual_price = 141.80 }
                   : Backtest.Stop_log.exit_trigger)));
       ])

let test_wrapper_passes_through _ =
  let log = Backtest.Stop_log.create () in
  let transitions =
    [
      {
        Position.position_id = "TEST-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "TEST";
              side = Long;
              target_quantity = 100.0;
              entry_price = 50.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
    ]
  in
  let module Inner = struct
    let name = "TestStrategy"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Ok { Strategy_interface.transitions }
  end in
  let wrapped =
    Backtest.Strategy_wrapper.wrap ~stop_log:log
      (module Inner : Strategy_interface.STRATEGY)
  in
  let module W = (val wrapped : Strategy_interface.STRATEGY) in
  let result =
    W.on_market_close
      ~get_price:(fun _ -> None)
      ~get_indicator:(fun _ _ _ _ -> None)
      ~portfolio:
        {
          Portfolio_view.cash = 100000.0;
          positions = Map.empty (module String);
        }
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> List.length o.transitions)
          (equal_to 1)));
  assert_that
    (Backtest.Stop_log.get_stop_infos log)
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.position_id)
               (equal_to "TEST-1");
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.symbol)
               (equal_to "TEST");
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
               is_none;
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)
               is_none;
           ];
       ])

let test_wrapper_handles_error _ =
  let log = Backtest.Stop_log.create () in
  let module Inner = struct
    let name = "FailStrategy"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Error (Status.internal_error "test error")
  end in
  let wrapped =
    Backtest.Strategy_wrapper.wrap ~stop_log:log
      (module Inner : Strategy_interface.STRATEGY)
  in
  let module W = (val wrapped : Strategy_interface.STRATEGY) in
  let result =
    W.on_market_close
      ~get_price:(fun _ -> None)
      ~get_indicator:(fun _ _ _ _ -> None)
      ~portfolio:
        {
          Portfolio_view.cash = 100000.0;
          positions = Map.empty (module String);
        }
  in
  assert_that result is_error;
  assert_that (Backtest.Stop_log.get_stop_infos log) (size_is 0)

(** ExitComplete without a preceding TriggerExit (the simulator's end-of-run
    auto-close path) tags the position with [End_of_period]. This is the
    fallback that prevents [trades.csv] from emitting an empty [exit_trigger]
    column for positions liquidated at scenario end without a strategy-emitted
    trigger (sp500-2019-2023 reproducer: JPM 2019-05-04, HD 2021-03-27 — see
    dev/notes/sp500-trade-quality-findings-2026-04-30.md). *)
let test_exit_complete_without_trigger_tags_end_of_period _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  (* End-of-period auto-close: ExitFill + ExitComplete with no preceding
     TriggerExit. *)
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-12-31";
        kind = ExitFill { filled_quantity = 100.0; fill_price = 200.0 };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-12-31";
        kind = ExitComplete;
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)
           (is_some_and
              (equal_to
                 (Backtest.Stop_log.End_of_period
                   : Backtest.Stop_log.exit_trigger)));
       ])

(** ExitComplete arriving AFTER an explicit TriggerExit must NOT overwrite the
    strategy's trigger. Pins that the End_of_period fallback only fires when
    [exit_trigger] is still None — a stop-loss that fires the normal TriggerExit
    -> ExitFill -> ExitComplete sequence keeps its Stop_loss label. *)
let test_exit_complete_does_not_overwrite_trigger_exit _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-02-01";
        kind =
          TriggerExit
            {
              exit_reason =
                StopLoss
                  {
                    stop_price = 142.50;
                    actual_price = 141.80;
                    loss_percent = 5.47;
                  };
              exit_price = 141.80;
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-02-01";
        kind = ExitFill { filled_quantity = 100.0; fill_price = 141.80 };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-02-01";
        kind = ExitComplete;
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)
           (is_some_and
              (equal_to
                 (Backtest.Stop_log.Stop_loss
                    { stop_price = 142.50; actual_price = 141.80 }
                   : Backtest.Stop_log.exit_trigger)));
       ])

(* Regression: warmup-emit leak. The runner calls [set_current_date] before
   each step so [EntryComplete] stamps [entry_date]; the runner then drops
   [stop_info]s whose [entry_date < start_date]. Without this stamp, warmup-
   window stop events leak into [trades.csv] when the same symbol re-trades
   across the [start_date] boundary (FIFO-pop in [_pop_stop_info]). *)
let test_set_current_date_stamps_entry_date _ =
  let log = Backtest.Stop_log.create () in
  let entry_date = Date.of_string "2024-03-15" in
  Backtest.Stop_log.set_current_date log entry_date;
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date = entry_date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date = entry_date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.entry_date)
           (is_some_and (equal_to entry_date));
       ])

let test_unset_current_date_leaves_entry_date_none _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [ field (fun (i : Backtest.Stop_log.stop_info) -> i.entry_date) is_none ])

(* classify_stop_trigger_kind ------------------------------------------- *)

let test_classify_long_stop_no_gap_is_intraday _ =
  let trigger : Backtest.Stop_log.exit_trigger =
    Stop_loss { stop_price = 100.0; actual_price = 99.99 }
  in
  let kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~side:Trading_base.Types.Long
      trigger
  in
  assert_that kind (equal_to Backtest.Stop_log.Intraday)

let test_classify_long_stop_with_gap_is_gap_down _ =
  let trigger : Backtest.Stop_log.exit_trigger =
    Stop_loss { stop_price = 100.0; actual_price = 90.0 }
  in
  let kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~side:Trading_base.Types.Long
      trigger
  in
  assert_that kind (equal_to Backtest.Stop_log.Gap_through)

let test_classify_short_stop_with_gap_is_gap_down _ =
  let trigger : Backtest.Stop_log.exit_trigger =
    Stop_loss { stop_price = 100.0; actual_price = 110.0 }
  in
  let kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~side:Trading_base.Types.Short
      trigger
  in
  assert_that kind (equal_to Backtest.Stop_log.Gap_through)

let test_classify_short_stop_no_gap_is_intraday _ =
  let trigger : Backtest.Stop_log.exit_trigger =
    Stop_loss { stop_price = 100.0; actual_price = 100.10 }
  in
  let kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~side:Trading_base.Types.Short
      trigger
  in
  assert_that kind (equal_to Backtest.Stop_log.Intraday)

let test_classify_end_of_period_passes_through _ =
  let kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~side:Trading_base.Types.Long
      Backtest.Stop_log.End_of_period
  in
  assert_that kind (equal_to Backtest.Stop_log.End_of_period)

let test_classify_take_profit_is_non_stop_exit _ =
  let trigger : Backtest.Stop_log.exit_trigger =
    Take_profit { target_price = 110.0; actual_price = 110.0 }
  in
  let kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~side:Trading_base.Types.Long
      trigger
  in
  assert_that kind (equal_to Backtest.Stop_log.Non_stop_exit)

let test_classify_signal_reversal_is_non_stop_exit _ =
  let trigger : Backtest.Stop_log.exit_trigger =
    Signal_reversal { description = "Stage 4" }
  in
  let kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~side:Trading_base.Types.Long
      trigger
  in
  assert_that kind (equal_to Backtest.Stop_log.Non_stop_exit)

let test_classify_custom_threshold_changes_classification _ =
  let trigger : Backtest.Stop_log.exit_trigger =
    Stop_loss { stop_price = 100.0; actual_price = 99.95 }
  in
  let default_kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~side:Trading_base.Types.Long
      trigger
  in
  let strict_kind =
    Backtest.Stop_log.classify_stop_trigger_kind ~gap_threshold_pct:0.0001
      ~side:Trading_base.Types.Long trigger
  in
  assert_that
    (default_kind, strict_kind)
    (equal_to (Backtest.Stop_log.Intraday, Backtest.Stop_log.Gap_through))

(* Stop-ratchet observability (max_stop / n_stop_raises) ---------------- *)

let _pid = "AAPL-wein-1"

let test_ratchet_counts_each_strict_raise _ =
  assert_that
    (_run_one
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:(Some 142.50);
         _update_stop ~position_id:_pid ~stop:(Some 148.00);
         _update_stop ~position_id:_pid ~stop:(Some 152.00);
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 2);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 152.00));
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.exit_stop)
           (is_some_and (float_equal 152.00));
       ])

(* A stop that never moves after entry: zero raises, and the high-water mark is
   the entry stop itself (not [None]). *)
let test_ratchet_zero_when_stop_never_moves _ =
  assert_that
    (_run_one
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:(Some 142.50);
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 0);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 142.50));
       ])

(* Re-installing the same level is not a raise — the comparison is strict. *)
let test_ratchet_ignores_unchanged_reinstall _ =
  assert_that
    (_run_one
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:(Some 142.50);
         _update_stop ~position_id:_pid ~stop:(Some 142.50);
       ])
    (field
       (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
       (equal_to 0))

(* A split rescales price and stop DOWN together. For a long that is strictly
   less protective, so it cannot inflate the count — but a genuine ratchet
   after the split still counts, being compared against the rescaled level.
   [max_stop] stays on the pre-split scale (documented caveat in the .mli). *)
let test_ratchet_split_rescale_does_not_count_but_later_raise_does _ =
  assert_that
    (_run_one
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:(Some 142.50);
         _update_stop ~position_id:_pid ~stop:(Some 71.25);
         _update_stop ~position_id:_pid ~stop:(Some 75.00);
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 1);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 142.50));
       ])

(* For a short, "more protective" is DOWNWARD: a falling stop is the raise and
   [max_stop] is the running minimum. *)
let test_ratchet_short_side_counts_downward_moves _ =
  assert_that
    (_run_one
       [
         _create_entering ~position_id:_pid ~side:Short;
         _entry_complete ~position_id:_pid ~stop:(Some 160.00);
         _update_stop ~position_id:_pid ~stop:(Some 155.00);
         _update_stop ~position_id:_pid ~stop:(Some 158.00);
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 1);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 155.00));
       ])

(* The first level ever installed on a position is an install, not a raise —
   even when it arrives as an [UpdateRiskParams] with no [EntryComplete]
   before it. *)
let test_ratchet_first_install_is_not_a_raise _ =
  assert_that
    (_run_one
       [
         _create_entering ~position_id:_pid ~side:Long;
         _update_stop ~position_id:_pid ~stop:(Some 142.50);
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 0);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 142.50));
       ])

(* A position that reaches [EntryComplete] carrying no stop, and never gets one
   installed afterwards, has no high-water mark at all — [max_stop] is [None]
   rather than some seeded level, and nothing was ever raised. *)
let test_ratchet_max_stop_none_when_no_stop_ever_installed _ =
  assert_that
    (_run_one
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:None;
       ])
    (all_of
       [
         field (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop) is_none;
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 0);
       ])

(* The collector tolerates a transition stream whose [CreateEntering] it never
   observed, and treats such a position as [Long]. This pins the SIGN of that
   default: a rising stop is the raise and [max_stop] is the running maximum.
   Were the default [Short], both fields would read 0 / 142.50 instead. *)
let test_ratchet_side_defaults_to_long_without_create_entering _ =
  assert_that
    (_run_one
       [
         _entry_complete ~position_id:_pid ~stop:(Some 142.50);
         _update_stop ~position_id:_pid ~stop:(Some 148.00);
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 1);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 148.00));
       ])

(* Issue #2974: the Weinstein path. The strategy's installed stop reaches the
   log through [record_installed_stop] (from the entry-decision audit, BEFORE
   the position's [CreateEntering] is recorded), and the simulator's
   [EntryComplete] carries no stop. [moves] are applied after the transitions,
   as the strategy's silent-move feed would. *)
let _run_weinstein ?(moves = []) ~installed transitions :
    Backtest.Stop_log.stop_info =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_installed_stop log ~position_id:_pid ~symbol:"AAPL"
    ~level:installed;
  Backtest.Stop_log.record_transitions log transitions;
  List.iter moves ~f:(fun level ->
      Backtest.Stop_log.record_stop_move log ~position_id:_pid ~level);
  match Backtest.Stop_log.get_stop_infos log with
  | [ info ] -> info
  | infos ->
      assert_failure
        (Printf.sprintf "expected exactly one stop_info, got %d"
           (List.length infos))

(* Entry with stop S, then one raise: [entry_stop] is S and the raise counts
   once. Before the fix the raise was booked as the install ([entry_stop]
   blank, [n_stop_raises] 0). *)
let test_installed_stop_then_one_raise _ =
  assert_that
    (_run_weinstein ~installed:142.50
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:None;
         _update_stop ~position_id:_pid ~stop:(Some 148.00);
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.symbol)
           (equal_to "AAPL");
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
           (is_some_and (float_equal 142.50));
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 1);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 148.00));
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.exit_stop)
           (is_some_and (float_equal 148.00));
       ])

(* Entry with stop S and no raise: zero raises, and [entry_stop] / [max_stop] /
   [exit_stop] all read S — the stop-less [EntryComplete] does not erase it. *)
let test_installed_stop_no_raise _ =
  assert_that
    (_run_weinstein ~installed:142.50
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:None;
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
           (is_some_and (float_equal 142.50));
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 0);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 142.50));
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.exit_stop)
           (is_some_and (float_equal 142.50));
       ])

(* A tightening move (no transition, reported via [record_stop_move]) counts
   as a raise and becomes the high-water mark and the resting level. *)
let test_tightening_move_is_counted _ =
  assert_that
    (_run_weinstein ~installed:142.50 ~moves:[ 146.00 ]
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:None;
       ])
    (all_of
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
           (is_some_and (float_equal 142.50));
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
           (equal_to 1);
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.max_stop)
           (is_some_and (float_equal 146.00));
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.exit_stop)
           (is_some_and (float_equal 146.00));
       ])

(* An ordinary ratchet raise (142.50 -> 144) followed by a tightening move
   (144 -> 146): two raises, each against the level immediately before it. *)
let test_raise_then_tightening_counts_both _ =
  assert_that
    (_run_weinstein ~installed:142.50 ~moves:[ 146.00 ]
       [
         _create_entering ~position_id:_pid ~side:Long;
         _entry_complete ~position_id:_pid ~stop:None;
         _update_stop ~position_id:_pid ~stop:(Some 144.00);
       ])
    (field
       (fun (i : Backtest.Stop_log.stop_info) -> i.n_stop_raises)
       (equal_to 2))

let test_with_fill_price_preserves_reason _ =
  let open Backtest.Stop_log in
  assert_that
    (List.map
       [
         Stop_loss { stop_price = 100.0; actual_price = 80.0 };
         Take_profit { target_price = 110.0; actual_price = 120.0 };
         Strategy_signal { label = "delisted"; detail = Some "last bar" };
         End_of_period;
       ]
       ~f:(fun trigger -> with_fill_price trigger ~fill_price:105.0))
    (elements_are
       [
         equal_to (Stop_loss { stop_price = 100.0; actual_price = 105.0 });
         equal_to (Take_profit { target_price = 110.0; actual_price = 105.0 });
         equal_to
           (Strategy_signal { label = "delisted"; detail = Some "last bar" });
         equal_to (End_of_period : exit_trigger);
       ])

(* #3147 ---------------------------------------------------------------- *)

let _exit ~d reason : Position.transition =
  {
    position_id = "ALX-1";
    date = Date.of_string d;
    kind = TriggerExit { exit_reason = reason; exit_price = 100.0 };
  }

let _signal label : Position.exit_reason =
  StrategySignal { label; detail = None }

let _short_exit_trigger batches =
  let log = Backtest.Stop_log.create () in
  List.iter batches ~f:(Backtest.Stop_log.record_transitions log);
  match Backtest.Stop_log.get_stop_infos log with
  | [ info ] -> info.exit_trigger
  | _ -> failwith "expected one stop_info"

let _entered = [ _create_entering ~position_id:"ALX-1" ~side:Position.Short ]

(* ALX 2008-11-25: the strategy's force liquidation and the margin runner's
   cover fire on the same day; [Margin_runner] keeps its own transition, so the
   post-dedup batch carries only [margin_call]. The label keeps the force
   liquidation, as [force_liquidations.sexp] records it. *)
let test_force_cover_keeps_force_liquidation_label _ =
  assert_that
    (_short_exit_trigger
       [
         _entered;
         [ _exit ~d:"2008-11-25" (_signal "force_liquidation") ];
         [ _exit ~d:"2008-11-25" (_signal "margin_call") ];
       ])
    (is_some_and
       (equal_to
          (Backtest.Stop_log.Strategy_signal
             { label = "force_liquidation"; detail = None })))

(* A short squeezed through its stop the day the maintenance check flags it
   (SUN1 2009-05-07 shape): the stop-loss label survives the margin cover,
   whether the cover is a [buyin_stress] or a [maintenance_reduce]. *)
let test_squeeze_stop_keeps_stop_loss_label _ =
  let stop : Position.exit_reason =
    StopLoss { stop_price = 20.0; actual_price = 21.0; loss_percent = 5.0 }
  in
  let after_margin label =
    _short_exit_trigger
      [
        _entered;
        [ _exit ~d:"2009-05-07" stop ];
        [ _exit ~d:"2009-05-07" (_signal label) ];
      ]
  in
  let stop_loss =
    is_some_and
      (equal_to
         (Backtest.Stop_log.Stop_loss { stop_price = 20.0; actual_price = 21.0 }))
  in
  assert_that
    (after_margin "buyin_stress", after_margin "maintenance_reduce")
    (pair stop_loss stop_loss)

(* Controls: a margin call alone is labelled [margin_call]; so is one a day
   after an earlier strategy exit (reverted and re-held in between). *)
let test_margin_call_alone_or_later_day_labelled_margin_call _ =
  let margin =
    Backtest.Stop_log.Strategy_signal { label = "margin_call"; detail = None }
  in
  assert_that
    ( _short_exit_trigger
        [ _entered; [ _exit ~d:"2008-11-25" (_signal "margin_call") ] ],
      _short_exit_trigger
        [
          _entered;
          [ _exit ~d:"2008-11-24" (_signal "force_liquidation") ];
          [ _exit ~d:"2008-11-25" (_signal "margin_call") ];
        ] )
    (pair (is_some_and (equal_to margin)) (is_some_and (equal_to margin)))

let suite =
  "Stop_log"
  >::: [
         "fill price preserves reason" >:: test_with_fill_price_preserves_reason;
         "#3147 force cover keeps force_liquidation label"
         >:: test_force_cover_keeps_force_liquidation_label;
         "#3147 squeeze stop keeps stop_loss label"
         >:: test_squeeze_stop_keeps_stop_loss_label;
         "#3147 margin call alone or a later day is margin_call"
         >:: test_margin_call_alone_or_later_day_labelled_margin_call;
         "create_entering records symbol"
         >:: test_create_entering_records_symbol;
         "entry_complete records stop" >:: test_entry_complete_records_stop;
         "update_risk_params updates stop"
         >:: test_update_risk_params_updates_stop;
         "trigger_exit records trigger" >:: test_trigger_exit_records_trigger;
         "exit_complete without trigger tags End_of_period"
         >:: test_exit_complete_without_trigger_tags_end_of_period;
         "exit_complete does not overwrite TriggerExit"
         >:: test_exit_complete_does_not_overwrite_trigger_exit;
         "wrapper passes through" >:: test_wrapper_passes_through;
         "wrapper handles error" >:: test_wrapper_handles_error;
         "set_current_date stamps entry_date on EntryComplete"
         >:: test_set_current_date_stamps_entry_date;
         "unset current_date leaves entry_date None"
         >:: test_unset_current_date_leaves_entry_date_none;
         "classify long stop no gap = Intraday"
         >:: test_classify_long_stop_no_gap_is_intraday;
         "classify long stop with gap = Gap_through"
         >:: test_classify_long_stop_with_gap_is_gap_down;
         "classify short stop with gap = Gap_through"
         >:: test_classify_short_stop_with_gap_is_gap_down;
         "classify short stop no gap = Intraday"
         >:: test_classify_short_stop_no_gap_is_intraday;
         "classify End_of_period passes through"
         >:: test_classify_end_of_period_passes_through;
         "classify take_profit = Non_stop_exit"
         >:: test_classify_take_profit_is_non_stop_exit;
         "classify signal_reversal = Non_stop_exit"
         >:: test_classify_signal_reversal_is_non_stop_exit;
         "classify custom threshold changes outcome"
         >:: test_classify_custom_threshold_changes_classification;
         "ratchet counts each strict raise"
         >:: test_ratchet_counts_each_strict_raise;
         "ratchet is zero when the stop never moves"
         >:: test_ratchet_zero_when_stop_never_moves;
         "ratchet ignores an unchanged re-install"
         >:: test_ratchet_ignores_unchanged_reinstall;
         "ratchet: split rescale does not count, later raise does"
         >:: test_ratchet_split_rescale_does_not_count_but_later_raise_does;
         "ratchet: short side counts downward moves"
         >:: test_ratchet_short_side_counts_downward_moves;
         "ratchet: first install is not a raise"
         >:: test_ratchet_first_install_is_not_a_raise;
         "ratchet: max_stop is None when no stop was ever installed"
         >:: test_ratchet_max_stop_none_when_no_stop_ever_installed;
         "ratchet: side defaults to Long without CreateEntering"
         >:: test_ratchet_side_defaults_to_long_without_create_entering;
         "installed stop, then one raise" >:: test_installed_stop_then_one_raise;
         "installed stop, no raise" >:: test_installed_stop_no_raise;
         "tightening move is counted" >:: test_tightening_move_is_counted;
         "raise then tightening counts both"
         >:: test_raise_then_tightening_counts_both;
       ]

let () = run_test_tt_main suite
