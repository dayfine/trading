(** Tests for [Backtest.Tiered_strategy_wrapper] — the piece that turns the
    3f-part2 skeleton into a full Tiered simulator cycle.

    3f-part3 ships the wrapper that observes each [on_market_close] call and
    drives [Bar_loader] tier transitions. The observable contracts we pin here:

    1. On a Friday call, the wrapper promotes the universe to [Summary_tier] and
    (if the shadow screener admits candidates) further promotes them to
    [Full_tier]. On a non-Friday call, no Summary / Full promote is issued.
    Friday detection reads the primary index bar's day-of-week. 2. On a
    [CreateEntering] transition the wrapper promotes that symbol to [Full_tier]
    regardless of cadence. 3. When a portfolio's position transitions to
    [Closed] between calls, the wrapper demotes that symbol to [Metadata_tier]
    on the next call. 4. The wrapper is {b purely additive}: the inner
    strategy's transitions flow through unchanged, and errors from the inner
    strategy bypass all tier bookkeeping.

    These tests drive the wrapper directly with a stub [STRATEGY] module and a
    synthetic [Bar_loader] rooted in a temp data dir — no production data
    required. The full [run_backtest ~loader_strategy:Tiered] acceptance test
    lands in 3g alongside the Legacy-vs-Tiered parity gate. *)

open OUnit2
open Core
open Matchers
open Trading_strategy
module Bar_loader = Bar_loader

(* -------------------------------------------------------------------- *)
(* Fixtures                                                             *)
(* -------------------------------------------------------------------- *)

(** Fresh temp data dir + empty sector map. Combined with a universe of symbols
    with no CSVs on disk, [Bar_loader.promote] succeeds for Metadata (the
    bootstrap path) and then short-circuits for Summary / Full (no bars), but
    the [trace_hook] still fires per Bar_loader semantics. Good enough to
    observe the wrapper's tier-op issuance. *)
let _make_loader ~universe =
  let tmp_dir = Filename_unix.temp_dir "runner_tiered_cycle_" "" in
  let data_dir = Fpath.v tmp_dir in
  let sector_map = Hashtbl.create (module String) in
  let trace = Backtest.Trace.create () in
  let trace_hook : Bar_loader.trace_hook =
    let record :
        'a. tier_op:Bar_loader.tier_op -> symbols:int -> (unit -> 'a) -> 'a =
     fun ~tier_op ~symbols f ->
      let phase = Backtest.Runner.tier_op_to_phase tier_op in
      Backtest.Trace.record ~trace ~symbols_in:symbols phase f
    in
    { record }
  in
  let loader =
    Bar_loader.create ~data_dir ~sector_map ~universe ~trace_hook ()
  in
  (loader, trace)

(** Stub STRATEGY module that returns a prescribed list of transitions from an
    external ref. Lets tests inject [CreateEntering] / [TriggerExit] transitions
    and observe the wrapper's bookkeeping response. *)
let _stub_strategy ~transitions_ref =
  let module Stub = struct
    let name = "Stub"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Ok { Strategy_interface.transitions = !transitions_ref }
  end in
  (module Stub : Strategy_interface.STRATEGY)

(** Build a [get_price] closure that returns a daily bar with the given date for
    a configured symbol. Every other symbol resolves to [None]. Used so the
    wrapper can look up the "current date" via the primary index. *)
let _make_get_price ~primary_index ~date : Strategy_interface.get_price_fn =
  let bar : Types.Daily_price.t =
    {
      date;
      open_price = 100.0;
      high_price = 100.0;
      low_price = 100.0;
      close_price = 100.0;
      adjusted_close = 100.0;
      volume = 0;
    }
  in
  fun sym -> if String.equal sym primary_index then Some bar else None

let _no_indicator : Strategy_interface.get_indicator_fn = fun _ _ _ _ -> None

let _empty_portfolio : Portfolio_view.t =
  { cash = 0.0; positions = String.Map.empty }

let _screening_config : Screener.config = Screener.default_config

let _wrapper_config ~loader ~universe ~primary_index :
    Backtest.Tiered_strategy_wrapper.config =
  {
    bar_loader = loader;
    universe;
    screening_config = _screening_config;
    full_candidate_limit = 5;
    stop_log = Backtest.Stop_log.create ();
    primary_index;
  }

let _phases_from trace =
  Backtest.Trace.snapshot trace
  |> List.map ~f:(fun (m : Backtest.Trace.phase_metrics) -> m.phase)

let _friday = Date.create_exn ~y:2024 ~m:Jan ~d:5 (* 2024-01-05 is a Friday *)
let _tuesday = Date.create_exn ~y:2024 ~m:Jan ~d:9
(* 2024-01-09 is a Tuesday *)

(* -------------------------------------------------------------------- *)
(* 1. Friday cadence isolation                                          *)
(* -------------------------------------------------------------------- *)

(** On a Friday call, the wrapper issues a [Promote_to_summary] tier-op for the
    universe. No promote is issued on a non-Friday call. Held only to the "at
    least one Summary promote on Friday; zero Summary promotes off- Friday"
    contract because the rest of the Full-promote path depends on shadow
    screener output which requires real bars. *)
let test_friday_triggers_summary_promote _ =
  let universe = [ "AAA"; "BBB" ] in
  let primary_index = "SPY.INDX" in
  let loader, trace = _make_loader ~universe:(primary_index :: universe) in
  let transitions_ref = ref [] in
  let stub = _stub_strategy ~transitions_ref in
  let config = _wrapper_config ~loader ~universe ~primary_index in
  let (module W) = Backtest.Tiered_strategy_wrapper.wrap ~config stub in
  let _ =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_friday)
      ~get_indicator:_no_indicator ~portfolio:_empty_portfolio
  in
  let phases = _phases_from trace in
  assert_that
    (List.exists phases ~f:(fun p ->
         Backtest.Trace.Phase.equal p Backtest.Trace.Phase.Promote_summary))
    (equal_to true)

let test_non_friday_skips_summary_promote _ =
  let universe = [ "AAA"; "BBB" ] in
  let primary_index = "SPY.INDX" in
  let loader, trace = _make_loader ~universe:(primary_index :: universe) in
  let transitions_ref = ref [] in
  let stub = _stub_strategy ~transitions_ref in
  let config = _wrapper_config ~loader ~universe ~primary_index in
  let (module W) = Backtest.Tiered_strategy_wrapper.wrap ~config stub in
  let _ =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:_empty_portfolio
  in
  let phases = _phases_from trace in
  assert_that
    (List.exists phases ~f:(fun p ->
         Backtest.Trace.Phase.equal p Backtest.Trace.Phase.Promote_summary))
    (equal_to false)

(* -------------------------------------------------------------------- *)
(* 2. Per-CreateEntering promote to Full                                *)
(* -------------------------------------------------------------------- *)

(** A [CreateEntering] transition emitted by the inner strategy triggers a
    Full-tier promote for the entering symbol on every call, regardless of
    day-of-week. *)
let test_create_entering_promotes_to_full _ =
  let universe = [ "AAA" ] in
  let primary_index = "SPY.INDX" in
  let loader, trace = _make_loader ~universe:(primary_index :: universe) in
  let transitions_ref =
    ref
      [
        {
          Position.position_id = "pos-1";
          date = _tuesday;
          kind =
            CreateEntering
              {
                symbol = "AAA";
                side = Position.Long;
                target_quantity = 10.0;
                entry_price = 100.0;
                reasoning =
                  Position.TechnicalSignal
                    { indicator = "Stub"; description = "test" };
              };
        };
      ]
  in
  let stub = _stub_strategy ~transitions_ref in
  let config = _wrapper_config ~loader ~universe ~primary_index in
  let (module W) = Backtest.Tiered_strategy_wrapper.wrap ~config stub in
  let _ =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:_empty_portfolio
  in
  let phases = _phases_from trace in
  assert_that
    (List.exists phases ~f:(fun p ->
         Backtest.Trace.Phase.equal p Backtest.Trace.Phase.Promote_full))
    (equal_to true)

(* -------------------------------------------------------------------- *)
(* 3. Per-Closed demote                                                 *)
(* -------------------------------------------------------------------- *)

let _closed_position ~id ~symbol : Position.t =
  {
    id;
    symbol;
    side = Long;
    entry_reasoning =
      TechnicalSignal { indicator = "Stub"; description = "test" };
    exit_reason = None;
    state =
      Closed
        {
          quantity = 10.0;
          entry_price = 100.0;
          exit_price = 110.0;
          gross_pnl = None;
          entry_date = _tuesday;
          exit_date = _tuesday;
          days_held = 0;
        };
    last_updated = _tuesday;
    portfolio_lot_ids = [];
  }

let _holding_position ~id ~symbol : Position.t =
  {
    id;
    symbol;
    side = Long;
    entry_reasoning =
      TechnicalSignal { indicator = "Stub"; description = "test" };
    exit_reason = None;
    state =
      Holding
        {
          quantity = 10.0;
          entry_price = 100.0;
          entry_date = _tuesday;
          risk_params =
            {
              stop_loss_price = Some 90.0;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = _tuesday;
    portfolio_lot_ids = [];
  }

(** A position that transitioned from [Holding] to [Closed] between calls
    triggers a Demote tier-op on the next call. The wrapper detects the
    transition via its own [prior_positions] memo — keyed by position_id — so
    the first call with a Holding position doesn't issue a demote, and the
    second call with the same id now in [Closed] does. *)
let test_newly_closed_position_triggers_demote _ =
  let universe = [ "AAA" ] in
  let primary_index = "SPY.INDX" in
  let loader, trace = _make_loader ~universe:(primary_index :: universe) in
  let transitions_ref = ref [] in
  let stub = _stub_strategy ~transitions_ref in
  let config = _wrapper_config ~loader ~universe ~primary_index in
  let (module W) = Backtest.Tiered_strategy_wrapper.wrap ~config stub in
  (* Step 1: position is Holding. No demote should happen. *)
  let holding_portfolio : Portfolio_view.t =
    {
      cash = 0.0;
      positions =
        String.Map.of_alist_exn
          [ ("pos-1", _holding_position ~id:"pos-1" ~symbol:"AAA") ];
    }
  in
  let _ =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:holding_portfolio
  in
  let phases_after_step_1 = _phases_from trace in
  assert_that
    (List.exists phases_after_step_1 ~f:(fun p ->
         Backtest.Trace.Phase.equal p Backtest.Trace.Phase.Demote))
    (equal_to false);
  (* Step 2: same position_id now in Closed. Demote fires. *)
  let closed_portfolio : Portfolio_view.t =
    {
      cash = 0.0;
      positions =
        String.Map.of_alist_exn
          [ ("pos-1", _closed_position ~id:"pos-1" ~symbol:"AAA") ];
    }
  in
  let _ =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:closed_portfolio
  in
  let phases_after_step_2 = _phases_from trace in
  assert_that
    (List.exists phases_after_step_2 ~f:(fun p ->
         Backtest.Trace.Phase.equal p Backtest.Trace.Phase.Demote))
    (equal_to true)

(** A position that is [Closed] on the very first call is still treated as
    "newly closed" and issues a demote — the wrapper has no prior memo to
    consult, which per its contract means "not yet demoted". Pins the behaviour
    so no one "optimizes" the prior-memo lookup to drop symbols that arrive
    already-Closed. *)
let test_closed_on_first_call_triggers_demote _ =
  let universe = [ "AAA" ] in
  let primary_index = "SPY.INDX" in
  let loader, trace = _make_loader ~universe:(primary_index :: universe) in
  let transitions_ref = ref [] in
  let stub = _stub_strategy ~transitions_ref in
  let config = _wrapper_config ~loader ~universe ~primary_index in
  let (module W) = Backtest.Tiered_strategy_wrapper.wrap ~config stub in
  let closed_portfolio : Portfolio_view.t =
    {
      cash = 0.0;
      positions =
        String.Map.of_alist_exn
          [ ("pos-1", _closed_position ~id:"pos-1" ~symbol:"AAA") ];
    }
  in
  let _ =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:closed_portfolio
  in
  let phases = _phases_from trace in
  assert_that
    (List.exists phases ~f:(fun p ->
         Backtest.Trace.Phase.equal p Backtest.Trace.Phase.Demote))
    (equal_to true)

(** A position that was already [Closed] on the previous call does NOT issue a
    second demote — idempotency across successive calls. *)
let test_already_closed_not_re_demoted _ =
  let universe = [ "AAA" ] in
  let primary_index = "SPY.INDX" in
  let loader, trace = _make_loader ~universe:(primary_index :: universe) in
  let transitions_ref = ref [] in
  let stub = _stub_strategy ~transitions_ref in
  let config = _wrapper_config ~loader ~universe ~primary_index in
  let (module W) = Backtest.Tiered_strategy_wrapper.wrap ~config stub in
  let closed_portfolio : Portfolio_view.t =
    {
      cash = 0.0;
      positions =
        String.Map.of_alist_exn
          [ ("pos-1", _closed_position ~id:"pos-1" ~symbol:"AAA") ];
    }
  in
  let _ =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:closed_portfolio
  in
  (* Second call with same Closed position. *)
  let _ =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:closed_portfolio
  in
  let demote_count =
    List.count (_phases_from trace) ~f:(fun p ->
        Backtest.Trace.Phase.equal p Backtest.Trace.Phase.Demote)
  in
  assert_that demote_count (equal_to 1)

(* -------------------------------------------------------------------- *)
(* 4. Pass-through                                                      *)
(* -------------------------------------------------------------------- *)

(** The wrapper delegates transitions unchanged from the inner strategy — the
    simulator sees exactly what the inner strategy returned. This is the "purely
    additive" half of the contract. *)
let test_inner_transitions_pass_through _ =
  let universe = [ "AAA" ] in
  let primary_index = "SPY.INDX" in
  let loader, _trace = _make_loader ~universe:(primary_index :: universe) in
  let inner_transitions =
    [
      {
        Position.position_id = "pos-1";
        date = _tuesday;
        kind =
          CreateEntering
            {
              symbol = "AAA";
              side = Position.Long;
              target_quantity = 5.0;
              entry_price = 50.0;
              reasoning =
                Position.TechnicalSignal
                  { indicator = "Stub"; description = "test" };
            };
      };
    ]
  in
  let transitions_ref = ref inner_transitions in
  let stub = _stub_strategy ~transitions_ref in
  let config = _wrapper_config ~loader ~universe ~primary_index in
  let (module W) = Backtest.Tiered_strategy_wrapper.wrap ~config stub in
  let result =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:_empty_portfolio
  in
  match result with
  | Error err -> assert_failure ("unexpected error: " ^ Status.show err)
  | Ok { transitions } ->
      assert_that transitions (size_is (List.length inner_transitions))

(** An error returned by the inner strategy bubbles up unchanged and no tier
    bookkeeping happens. The tier ops that {e would} have fired are
    side-effectful, so asserting an empty trace is the cleanest way to check the
    no-op contract. *)
let test_inner_error_skips_tier_bookkeeping _ =
  let universe = [ "AAA" ] in
  let primary_index = "SPY.INDX" in
  let loader, trace = _make_loader ~universe:(primary_index :: universe) in
  let module Failing = struct
    let name = "Failing"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Error (Status.invalid_argument_error "test error")
  end in
  let config = _wrapper_config ~loader ~universe ~primary_index in
  let (module W) =
    Backtest.Tiered_strategy_wrapper.wrap ~config (module Failing)
  in
  let result =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index ~date:_friday)
      ~get_indicator:_no_indicator ~portfolio:_empty_portfolio
  in
  assert_that result is_error;
  (* Trace must be empty — no Summary promote, no Full promote, no Demote. *)
  let phases = _phases_from trace in
  assert_that phases (size_is 0)

let suite =
  "Runner_tiered_cycle"
  >::: [
         "Friday call triggers Summary promote"
         >:: test_friday_triggers_summary_promote;
         "Non-Friday call skips Summary promote"
         >:: test_non_friday_skips_summary_promote;
         "CreateEntering transition promotes symbol to Full"
         >:: test_create_entering_promotes_to_full;
         "Newly-Closed position triggers Demote"
         >:: test_newly_closed_position_triggers_demote;
         "Closed on first call triggers Demote"
         >:: test_closed_on_first_call_triggers_demote;
         "Already-Closed position not re-demoted"
         >:: test_already_closed_not_re_demoted;
         "Inner strategy transitions pass through unchanged"
         >:: test_inner_transitions_pass_through;
         "Inner strategy error skips tier bookkeeping"
         >:: test_inner_error_skips_tier_bookkeeping;
       ]

let () = run_test_tt_main suite
