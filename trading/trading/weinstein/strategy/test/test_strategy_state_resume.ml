(** Resumable backtests (#3477, PR 4): the strategy's per-run state survives a
    capture / sexp / restore round trip.

    The end-to-end claim: run the real [on_market_close] to a date D, arm the
    no-chase freeze pin and a suspended resting ticket, capture the state, then
    (a) keep running the same strategy to the end and (b) restore the snapshot
    into a fresh strategy via [make_with_state] and run that to the end. Both
    must emit identical transitions and end in identical state. The stashed
    ticket is re-issued under a fresh position id on the first admitting Friday,
    so the id (the process-global counter) is part of what must match. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module Peak = Portfolio_risk.Force_liquidation.Peak_tracker

let _index_symbol = "GSPCX"
let _stashed_symbol = "ZZZ"
let _rising_symbol = "AAA"
let _arm_date = Date.of_string "2025-04-09"
let _last_date = Date.of_string "2025-05-09"
let _bar_count = 300

let _daily_bar ~date ~price =
  {
    Types.Daily_price.date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through = None;
  }

let _daily_bars ~start_price ~step =
  let start_date = Date.add_days _last_date (-(_bar_count - 1)) in
  List.init _bar_count ~f:(fun i ->
      _daily_bar
        ~date:(Date.add_days start_date i)
        ~price:(start_price +. (Float.of_int i *. step)))

let _bar_reader =
  Bar_reader.of_in_memory_bars
    [
      (_index_symbol, _daily_bars ~start_price:100.0 ~step:1.0);
      (_rising_symbol, _daily_bars ~start_price:50.0 ~step:0.5);
      (_stashed_symbol, _daily_bars ~start_price:100.0 ~step:0.1);
    ]

let _lib_config =
  {
    (Weinstein_strategy_config.default_config
       ~universe:[ _rising_symbol; _stashed_symbol ]
       ~index_symbol:_index_symbol)
    with
    freeze_entry_at_first_breakout = true;
    entry_ticket_macro_suspend = Entry_ticket_suspend_mode.On_bearish_macro;
  }

(* [Weinstein_strategy.config] is a re-declared twin of the library config;
   cross over by sexp. *)
let _config =
  Weinstein_strategy.config_of_sexp
    (Weinstein_strategy_config.sexp_of_config _lib_config)

let _get_price ~current_date symbol =
  List.last (Bar_reader.daily_bars_for _bar_reader ~symbol ~as_of:current_date)

let _ok_or_fail what r =
  Result.map_error r ~f:Status.show
  |> Result.map_error ~f:(fun e -> what ^ " failed: " ^ e)
  |> Result.ok_or_failwith

let _empty_portfolio : Trading_strategy.Portfolio_view.t =
  { cash = 100_000.0; positions = String.Map.empty }

(* One strategy tick on [date]; the transitions as shown strings, so a mismatch
   prints readably. The portfolio never changes: outputs depend on state only. *)
let _tick (module S : Trading_strategy.Strategy_interface.STRATEGY) date =
  S.on_market_close
    ~get_price:(_get_price ~current_date:date)
    ~get_indicator:(fun _ _ _ _ -> None)
    ~portfolio:_empty_portfolio
  |> _ok_or_fail "on_market_close"
  |> fun (out : Trading_strategy.Strategy_interface.output) ->
  List.map out.transitions ~f:Position.show_transition

let _run strategy ~from_date ~to_date =
  List.init
    (Date.diff to_date from_date + 1)
    ~f:(fun i -> _tick strategy (Date.add_days from_date i))
  |> List.concat

let _screening_stage : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
    ma_value = 100.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 8;
  }

let _bearish_macro : Macro.result =
  {
    index_stage = _screening_stage;
    indicators = [];
    trend = Weinstein_types.Bearish;
    breadth_state =
      Weinstein_types.breadth_state_of_market_trend Weinstein_types.Bearish;
    confidence = 0.2;
    regime_changed = false;
    rationale = [];
  }

(* A wholly unfilled long ticket whose trigger (1000) is well above the market,
   so a later admitting screen re-issues rather than drops it. *)
let _resting_ticket =
  let transition kind : Position.transition =
    { position_id = "ZZZ-1"; date = _arm_date; kind }
  in
  Position.create_entering
    (transition
       (Position.CreateEntering
          {
            symbol = _stashed_symbol;
            side = Trading_base.Types.Long;
            target_quantity = 10.0;
            entry_price = 1000.0;
            reasoning = ManualDecision { description = "3477 test" };
          }))
  |> _ok_or_fail "ticket setup"

let _pinned_e =
  Entry_freeze.snapshot_of_sexp
    (Sexp.of_string "((ZZZ ((entry 1000) (anchor Breakout))))")
  |> Entry_freeze.restore

(* Arm freeze and suspend on [state]: pin a no-chase E, then suspend the
   resting ticket under a bearish screen, which stashes it. Returns the armed
   state ([pending_entry_e] is replaced, so the record is rebuilt). *)
let _arm (state : Weinstein_strategy_state.t) =
  let state = { state with pending_entry_e = _pinned_e } in
  let stop_states =
    ref
      (String.Map.singleton _stashed_symbol
         (Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }))
  in
  let _transitions, _held =
    Entry_ticket_suspend.run ~store:state.suspended_tickets
      ~pending_entry_e:state.pending_entry_e ~config:_lib_config
      ~macro_result:_bearish_macro ~stop_states
      ~current_close:(fun _ -> Some 100.0)
      ~portfolio:
        {
          _empty_portfolio with
          positions = String.Map.singleton "ZZZ-1" _resting_ticket;
        }
      ~current_date:_arm_date
      ~cancel_expired:(fun _ -> [])
      ()
  in
  state

let _strategy_over state =
  Weinstein_strategy.make_with_state ~bar_reader:_bar_reader ~state _config

let _first_day = Date.add_days _arm_date (-14)

(* Run to the arm date, arm freeze + suspend, and snapshot. Returns the armed
   state and its snapshot after a trip through the sexp text form. *)
let _armed_at_d () =
  let state =
    Weinstein_strategy_state.init ~initial_stop_states:String.Map.empty
  in
  let strategy = _strategy_over state in
  let _warmup = _run strategy ~from_date:_first_day ~to_date:_arm_date in
  let armed = _arm state in
  (armed, Weinstein_strategy_state.capture armed)

let _through_text snap =
  Weinstein_strategy_state.sexp_of_snapshot snap
  |> Sexp.to_string |> Sexp.of_string
  |> Weinstein_strategy_state.snapshot_of_sexp

let _sexp_text snap =
  Sexp.to_string (Weinstein_strategy_state.sexp_of_snapshot snap)

(* The armed state is rebuilt on a strategy that shares no mutable value with
   the original, and both are run to the end. Run A first (it advances the
   global position counter), then restore, which resets the counter. *)
let _resume_both () =
  let state, snap = _armed_at_d () in
  let after_d = Date.add_days _arm_date 1 in
  let a_out =
    _run (_strategy_over state) ~from_date:after_d ~to_date:_last_date
  in
  let a_end = Weinstein_strategy_state.capture state in
  let restored = Weinstein_strategy_state.restore (_through_text snap) in
  let b_out =
    _run (_strategy_over restored) ~from_date:after_d ~to_date:_last_date
  in
  let b_end = Weinstein_strategy_state.capture restored in
  (snap, (a_out, a_end), (b_out, b_end))

let test_armed_snapshot_holds_freeze_and_suspend _ =
  let _, snap = _armed_at_d () in
  assert_that (_sexp_text snap)
    (all_of
       [
         field (String.is_substring ~substring:"ZZZ-1") (equal_to true);
         field (String.is_substring ~substring:"(entry 1000)") (equal_to true);
       ])

let test_capture_restore_round_trips _ =
  let _, snap = _armed_at_d () in
  assert_that
    (_sexp_text
       (Weinstein_strategy_state.capture
          (Weinstein_strategy_state.restore snap)))
    (equal_to (_sexp_text snap))

let test_resumed_run_emits_identical_transitions _ =
  let _, (a_out, _), (b_out, _) = _resume_both () in
  assert_that b_out (equal_to (a_out : string list))

let test_resumed_run_reissues_the_stashed_ticket _ =
  let _, (_, _), (b_out, _) = _resume_both () in
  assert_that
    (List.count b_out ~f:(String.is_substring ~substring:"CreateEntering"))
    (gt (module Int_ord) 0)

let test_resumed_run_ends_in_identical_state _ =
  let _, (_, a_end), (_, b_end) = _resume_both () in
  assert_that (_sexp_text b_end) (equal_to (_sexp_text a_end))

let test_peak_tracker_halt_survives_restore _ =
  let state =
    Weinstein_strategy_state.init ~initial_stop_states:String.Map.empty
  in
  Peak.observe state.peak_tracker ~portfolio_value:123_456.0;
  Peak.mark_halted state.peak_tracker;
  let restored =
    Weinstein_strategy_state.restore
      (_through_text (Weinstein_strategy_state.capture state))
  in
  assert_that restored.peak_tracker
    (all_of
       [
         field Peak.peak (float_equal 123_456.0);
         field Peak.halt_state
           (equal_to Portfolio_risk.Force_liquidation.Halted);
       ])

let suite =
  "strategy_state_resume"
  >::: [
         "armed snapshot holds freeze pin and stashed ticket"
         >:: test_armed_snapshot_holds_freeze_and_suspend;
         "capture / restore round trips" >:: test_capture_restore_round_trips;
         "resumed run emits identical transitions"
         >:: test_resumed_run_emits_identical_transitions;
         "resumed run re-issues the stashed ticket"
         >:: test_resumed_run_reissues_the_stashed_ticket;
         "resumed run ends in identical state"
         >:: test_resumed_run_ends_in_identical_state;
         "peak tracker halt survives restore"
         >:: test_peak_tracker_halt_survives_restore;
       ]

let () = run_test_tt_main suite
