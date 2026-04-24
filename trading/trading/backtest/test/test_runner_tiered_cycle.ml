(** Tests for [Backtest.Tiered_strategy_wrapper] — the piece that turns the
    3f-part2 skeleton into a full Tiered simulator cycle, extended by the
    2026-04-22 strategy↔bar_loader integration to also throttle the inner
    strategy's [get_price] view and seed [Bar_history] on Full promotion.

    Observable contracts pinned here:

    1. On a Friday call, the wrapper promotes the universe to [Summary_tier] and
    (if the shadow screener admits candidates) further promotes them to
    [Full_tier]. On a non-Friday call, no Summary / Full promote is issued. The
    Friday cycle fires {b before} the inner strategy — so the wrapper's
    Full-tier promotions (and the seeded [Bar_history] bars) are visible to the
    inner screener on the same day. 2. On a [CreateEntering] transition the
    wrapper promotes that symbol to [Full_tier] regardless of cadence. Runs
    post-inner. 3. When a portfolio's position transitions to [Closed] between
    calls, the wrapper demotes that symbol to [Metadata_tier] on the next call.
    4. The wrapper is {b purely additive}: the inner strategy's transitions flow
    through unchanged. 5. The inner strategy's view of [get_price] is throttled
    — symbols not in [always_loaded_symbols], not at [Full_tier], and not
    currently held in the portfolio resolve to [None]. Symbols in any of those
    three categories pass through unchanged. [Bar_history.accumulate] silently
    skips [None] returns, which is the core memory win.

    These tests drive the wrapper directly with a stub [STRATEGY] module and a
    synthetic [Bar_loader] rooted in a temp data dir — no production data
    required. The full [run_backtest ~loader_strategy:Tiered] acceptance test
    lives at [test_tiered_loader_parity.ml]. *)

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

let _wrapper_config ~loader ~bar_history ~universe ~primary_index
    ?(always_loaded = []) () : Backtest.Tiered_strategy_wrapper.config =
  {
    bar_loader = loader;
    bar_history;
    universe;
    always_loaded_symbols = String.Set.of_list (primary_index :: always_loaded);
    seed_warmup_start = Date.create_exn ~y:2023 ~m:Jan ~d:1;
    stop_log = Backtest.Stop_log.create ();
    primary_index;
  }

let _friday = Date.create_exn ~y:2024 ~m:Jan ~d:5
(* 2024-01-05 is a Friday. *)

let _tuesday = Date.create_exn ~y:2024 ~m:Jan ~d:9
(* 2024-01-09 is a Tuesday. *)

let _primary_index = "SPY.INDX"

type _wrapper_under_test = {
  wrapper : (module Strategy_interface.STRATEGY);
  trace : Backtest.Trace.t;
  transitions_ref : Position.transition list ref;
}
(** Wrapper handle returned by [_setup]: the instantiated strategy module, the
    trace collector, and the mutable transitions ref the caller can update
    between calls to script inner-strategy output. *)

(** Single-line setup for a wrapper-under-test. [universe] defaults to
    [["AAA"]]; the primary index is always prepended to the loader universe.
    Tests that need to script inner-strategy transitions mutate
    [out.transitions_ref] between [on_market_close] calls. *)
let _setup ?(universe = [ "AAA" ]) () : _wrapper_under_test =
  let loader, trace = _make_loader ~universe:(_primary_index :: universe) in
  let bar_history = Weinstein_strategy.Bar_history.create () in
  let transitions_ref = ref [] in
  let stub = _stub_strategy ~transitions_ref in
  let config =
    _wrapper_config ~loader ~bar_history ~universe ~primary_index:_primary_index
      ()
  in
  let wrapper = Backtest.Tiered_strategy_wrapper.wrap ~config stub in
  { wrapper; trace; transitions_ref }

let _phases_from trace =
  Backtest.Trace.snapshot trace
  |> List.map ~f:(fun (m : Backtest.Trace.phase_metrics) -> m.phase)

(** [_count_phase trace phase] — number of times [phase] appears in [trace]'s
    recorded phase sequence. Preferred over [List.exists] so assertions can pin
    exact counts rather than "at least one" (which hides a wrapper that fires
    twice when it should fire once). *)
let _count_phase trace phase =
  List.count (_phases_from trace) ~f:(Backtest.Trace.Phase.equal phase)

(** [_call w ~date ~portfolio] drives the wrapper's [on_market_close] against
    the configured date and portfolio. Asserts the call returned [Ok] before
    returning — a silent [Error] here would let downstream trace assertions pass
    vacuously. *)
let _call (w : _wrapper_under_test) ~date ~portfolio =
  let (module W) = w.wrapper in
  let result =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index:_primary_index ~date)
      ~get_indicator:_no_indicator ~portfolio
  in
  assert_that result is_ok

(* -------------------------------------------------------------------- *)
(* Position fixtures                                                    *)
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

let _portfolio_of_positions positions : Portfolio_view.t =
  { cash = 0.0; positions = String.Map.of_alist_exn positions }

let _create_entering ~position_id ~symbol : Position.transition =
  {
    position_id;
    date = _tuesday;
    kind =
      CreateEntering
        {
          symbol;
          side = Position.Long;
          target_quantity = 10.0;
          entry_price = 100.0;
          reasoning =
            Position.TechnicalSignal
              { indicator = "Stub"; description = "test" };
        };
  }

(* -------------------------------------------------------------------- *)
(* 1. Friday cadence isolation                                          *)
(* -------------------------------------------------------------------- *)

(** On a Friday call, the wrapper issues a [Promote_to_full] tier-op per
    universe symbol. Per-symbol promotion (rather than a batch
    [Bar_loader.promote ~symbols:t.universe ~to_:Full_tier ~as_of] call) is
    load-bearing for parity on broad universes — see [_promote_each_to] in the
    .ml — because batched [Bar_loader.promote] short-circuits on the first
    per-symbol error. The test pins the per-symbol expectation: with two
    universe symbols, two Promote_to_full tier-ops fire. (The 2-symbol universe
    is also extended to include the primary index in the loader, but the primary
    index is promoted to Metadata before the wrapper runs and is not in
    [t.universe], so it doesn't add Full tier-ops here.)

    Note: prior to the bull-crash A/B parity fix this function went through an
    intermediate Summary promote pass; with the fix [_run_friday_cycle] drives
    Full directly so [Bar_history] gets populated even for symbols that don't
    yet have enough weekly bars to resolve Summary scalars. *)
let test_friday_triggers_full_promote _ =
  let w = _setup ~universe:[ "AAA"; "BBB" ] () in
  _call w ~date:_friday ~portfolio:_empty_portfolio;
  assert_that
    (_count_phase w.trace Backtest.Trace.Phase.Promote_full)
    (equal_to 2)

let test_non_friday_skips_full_promote _ =
  let w = _setup ~universe:[ "AAA"; "BBB" ] () in
  _call w ~date:_tuesday ~portfolio:_empty_portfolio;
  assert_that
    (_count_phase w.trace Backtest.Trace.Phase.Promote_full)
    (equal_to 0)

(* -------------------------------------------------------------------- *)
(* 2. Per-CreateEntering promote to Full                                *)
(* -------------------------------------------------------------------- *)

(** A single [CreateEntering] transition triggers exactly one Full-tier promote
    on every call, regardless of day-of-week. *)
let test_create_entering_promotes_to_full _ =
  let w = _setup () in
  w.transitions_ref := [ _create_entering ~position_id:"pos-1" ~symbol:"AAA" ];
  _call w ~date:_tuesday ~portfolio:_empty_portfolio;
  assert_that
    (_count_phase w.trace Backtest.Trace.Phase.Promote_full)
    (equal_to 1)

(** Multi-symbol CreateEntering batch: the wrapper issues one Full-tier promote
    {b per symbol} (not one for the whole batch) so a single missing-CSV symbol
    can't short-circuit the rest of the batch (see [_promote_each_to] in the
    .ml). With two distinct CreateEntering transitions, two Promote_to_full
    tier-ops fire — pinned exactly. *)
let test_multi_symbol_create_entering_per_symbol_promote _ =
  let w = _setup ~universe:[ "AAA"; "BBB" ] () in
  w.transitions_ref :=
    [
      _create_entering ~position_id:"pos-1" ~symbol:"AAA";
      _create_entering ~position_id:"pos-2" ~symbol:"BBB";
    ];
  _call w ~date:_tuesday ~portfolio:_empty_portfolio;
  assert_that
    (_count_phase w.trace Backtest.Trace.Phase.Promote_full)
    (equal_to 2)

(* -------------------------------------------------------------------- *)
(* 3. Per-Closed demote                                                 *)
(* -------------------------------------------------------------------- *)

(** A position that transitioned from [Holding] to [Closed] between calls
    triggers a Demote tier-op on the next call. The wrapper detects the
    transition via its own [prior_positions] memo — keyed by position_id — so
    the first call with a Holding position doesn't issue a demote, and the
    second call with the same id now in [Closed] does. *)
let test_newly_closed_position_triggers_demote _ =
  let w = _setup () in
  let holding_portfolio =
    _portfolio_of_positions
      [ ("pos-1", _holding_position ~id:"pos-1" ~symbol:"AAA") ]
  in
  _call w ~date:_tuesday ~portfolio:holding_portfolio;
  assert_that (_count_phase w.trace Backtest.Trace.Phase.Demote) (equal_to 0);
  let closed_portfolio =
    _portfolio_of_positions
      [ ("pos-1", _closed_position ~id:"pos-1" ~symbol:"AAA") ]
  in
  _call w ~date:_tuesday ~portfolio:closed_portfolio;
  assert_that (_count_phase w.trace Backtest.Trace.Phase.Demote) (equal_to 1)

(** A position that is [Closed] on the very first call is still treated as
    "newly closed" and issues a demote — the wrapper has no prior memo to
    consult, which per its contract means "not yet demoted". Pins the behaviour
    so no one "optimizes" the prior-memo lookup to drop symbols that arrive
    already-Closed. *)
let test_closed_on_first_call_triggers_demote _ =
  let w = _setup () in
  let closed_portfolio =
    _portfolio_of_positions
      [ ("pos-1", _closed_position ~id:"pos-1" ~symbol:"AAA") ]
  in
  _call w ~date:_tuesday ~portfolio:closed_portfolio;
  assert_that (_count_phase w.trace Backtest.Trace.Phase.Demote) (equal_to 1)

(** A position that was already [Closed] on the previous call does NOT issue a
    second demote — idempotency across successive calls. *)
let test_already_closed_not_re_demoted _ =
  let w = _setup () in
  let closed_portfolio =
    _portfolio_of_positions
      [ ("pos-1", _closed_position ~id:"pos-1" ~symbol:"AAA") ]
  in
  _call w ~date:_tuesday ~portfolio:closed_portfolio;
  _call w ~date:_tuesday ~portfolio:closed_portfolio;
  assert_that (_count_phase w.trace Backtest.Trace.Phase.Demote) (equal_to 1)

(** A symbol that cycles [Closed → fresh Entering under a new position_id]
    demotes exactly once for the first id and promotes exactly once for the
    second. This is the reason [_is_newly_closed] keys on position_id rather
    than symbol — a same-symbol second entry under a new id must not share the
    "already demoted" memo of the prior id. *)
let test_symbol_recycle_under_new_position_id _ =
  let w = _setup () in
  (* Step 1: position AAA/pos-1 is Closed — demote fires for the first id. *)
  let closed_portfolio =
    _portfolio_of_positions
      [ ("pos-1", _closed_position ~id:"pos-1" ~symbol:"AAA") ]
  in
  _call w ~date:_tuesday ~portfolio:closed_portfolio;
  (* Step 2: AAA re-enters under pos-2 (Holding). No new demote; one
     Full-promote for the new entry. *)
  w.transitions_ref := [ _create_entering ~position_id:"pos-2" ~symbol:"AAA" ];
  let recycled_portfolio =
    _portfolio_of_positions
      [
        ("pos-1", _closed_position ~id:"pos-1" ~symbol:"AAA");
        ("pos-2", _holding_position ~id:"pos-2" ~symbol:"AAA");
      ]
  in
  _call w ~date:_tuesday ~portfolio:recycled_portfolio;
  assert_that (_count_phase w.trace Backtest.Trace.Phase.Demote) (equal_to 1);
  assert_that
    (_count_phase w.trace Backtest.Trace.Phase.Promote_full)
    (equal_to 1)

(* -------------------------------------------------------------------- *)
(* 4. Pass-through                                                      *)
(* -------------------------------------------------------------------- *)

(** The wrapper delegates transitions unchanged from the inner strategy — the
    simulator sees exactly what the inner strategy returned. Identity, not just
    count, is pinned: a wrapper that dropped one transition and invented another
    with the same count would fail this test. *)
let test_inner_transitions_pass_through _ =
  let w = _setup () in
  let inner_transitions =
    [ _create_entering ~position_id:"pos-1" ~symbol:"AAA" ]
  in
  w.transitions_ref := inner_transitions;
  let (module W) = w.wrapper in
  let result =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index:_primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:_empty_portfolio
  in
  let expected_ids =
    List.map inner_transitions ~f:(fun (t : Position.transition) ->
        t.position_id)
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun { Strategy_interface.transitions } ->
            List.map transitions ~f:(fun (t : Position.transition) ->
                t.position_id))
          (equal_to expected_ids)))

(** An error returned by the inner strategy bubbles up unchanged and no
    {b post-inner} tier bookkeeping happens — the wrapper's Demote /
    per-[CreateEntering] Full-promote paths rely on the inner having returned
    [Ok]. The Friday cycle runs {b before} inner (so its Full-tier promotions
    are visible to the inner screener same-day), so on a Friday call with a
    failing inner we still see the pre-inner promote — that's the contract.
    Running this test on a non-Friday pins the pure no-op contract for the
    post-inner path. *)
let test_inner_error_skips_post_inner_tier_bookkeeping _ =
  let universe = [ "AAA" ] in
  let loader, trace = _make_loader ~universe:(_primary_index :: universe) in
  let bar_history = Weinstein_strategy.Bar_history.create () in
  let module Failing = struct
    let name = "Failing"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Error (Status.invalid_argument_error "test error")
  end in
  let config =
    _wrapper_config ~loader ~bar_history ~universe ~primary_index:_primary_index
      ()
  in
  let (module W) =
    Backtest.Tiered_strategy_wrapper.wrap ~config (module Failing)
  in
  let result =
    W.on_market_close
      ~get_price:(_make_get_price ~primary_index:_primary_index ~date:_tuesday)
      ~get_indicator:_no_indicator ~portfolio:_empty_portfolio
  in
  assert_that result is_error;
  assert_that (_phases_from trace) (size_is 0)

(* -------------------------------------------------------------------- *)
(* 5. get_price throttle                                                *)
(* -------------------------------------------------------------------- *)

(** Stub STRATEGY module that captures which symbols the wrapper's throttled
    [get_price'] resolves and what it returns, then emits no transitions. *)
let _probe_strategy ~probe_symbols ~out =
  let module Probe = struct
    let name = "Probe"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      out :=
        List.map probe_symbols ~f:(fun sym ->
            (sym, Option.is_some (get_price sym)));
      Ok { Strategy_interface.transitions = [] }
  end in
  (module Probe : Strategy_interface.STRATEGY)

(** Build a [get_price] closure that returns a daily bar with the given date for
    every symbol in [symbols_with_bars]. Used so the throttle's pass-through
    path has something concrete to return when it elects to forward the outer
    [get_price]. *)
let _get_price_for_all ~symbols_with_bars ~date :
    Strategy_interface.get_price_fn =
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
  let set = String.Set.of_list symbols_with_bars in
  fun sym -> if Set.mem set sym then Some bar else None

let _run_probe ~universe ~probe_symbols ~always_loaded ~date ~portfolio =
  let loader, _trace = _make_loader ~universe:(_primary_index :: universe) in
  let bar_history = Weinstein_strategy.Bar_history.create () in
  let out = ref [] in
  let probe = _probe_strategy ~probe_symbols ~out in
  let config =
    _wrapper_config ~loader ~bar_history ~universe ~primary_index:_primary_index
      ~always_loaded ()
  in
  let (module W) = Backtest.Tiered_strategy_wrapper.wrap ~config probe in
  let result =
    W.on_market_close
      ~get_price:
        (_get_price_for_all
           ~symbols_with_bars:(_primary_index :: probe_symbols)
           ~date)
      ~get_indicator:_no_indicator ~portfolio
  in
  assert_that result is_ok;
  (loader, !out)

(** Primary index always passes through. Used by the wrapper itself for
    day-of-week detection and forwarded by the throttle so the inner strategy's
    macro pipeline and sector-map builder keep working. *)
let test_throttle_passes_primary_index _ =
  let _loader, results =
    _run_probe ~universe:[ "AAA" ] ~probe_symbols:[ _primary_index ]
      ~always_loaded:[] ~date:_tuesday ~portfolio:_empty_portfolio
  in
  assert_that results
    (elements_are [ equal_to ((_primary_index, true) : string * bool) ])

(** Symbols in [always_loaded_symbols] (sector ETFs, global indices) pass
    through regardless of tier or held status. *)
let test_throttle_passes_always_loaded _ =
  let _loader, results =
    _run_probe ~universe:[ "AAA"; "XLF"; "XLK" ] ~probe_symbols:[ "XLF"; "XLK" ]
      ~always_loaded:[ "XLF"; "XLK" ] ~date:_tuesday ~portfolio:_empty_portfolio
  in
  assert_that results
    (elements_are
       [
         equal_to (("XLF", true) : string * bool);
         equal_to (("XLK", true) : string * bool);
       ])

(** Symbols that are in the universe but not at Full tier, not held, and not
    always-loaded resolve to [None] — the core memory win. *)
let test_throttle_blocks_metadata_universe _ =
  let _loader, results =
    _run_probe ~universe:[ "AAA"; "BBB" ] ~probe_symbols:[ "AAA"; "BBB" ]
      ~always_loaded:[] ~date:_tuesday ~portfolio:_empty_portfolio
  in
  assert_that results
    (elements_are
       [
         equal_to (("AAA", false) : string * bool);
         equal_to (("BBB", false) : string * bool);
       ])

(** A symbol held in the portfolio passes through even if the loader has it at
    Metadata tier (the defensive path — in practice held positions are also at
    Full because we promote on CreateEntering). *)
let test_throttle_passes_held_position _ =
  let holding_portfolio =
    _portfolio_of_positions
      [ ("pos-1", _holding_position ~id:"pos-1" ~symbol:"AAA") ]
  in
  let _loader, results =
    _run_probe ~universe:[ "AAA"; "BBB" ] ~probe_symbols:[ "AAA"; "BBB" ]
      ~always_loaded:[] ~date:_tuesday ~portfolio:holding_portfolio
  in
  assert_that results
    (elements_are
       [
         equal_to (("AAA", true) : string * bool);
         equal_to (("BBB", false) : string * bool);
       ])

(** An unknown symbol (not in universe, not in always_loaded, not held) resolves
    to [None]. This is the "don't accumulate random stuff" guarantee. *)
let test_throttle_blocks_unknown_symbol _ =
  let _loader, results =
    _run_probe ~universe:[ "AAA" ] ~probe_symbols:[ "ZZZ" ] ~always_loaded:[]
      ~date:_tuesday ~portfolio:_empty_portfolio
  in
  assert_that results
    (elements_are [ equal_to (("ZZZ", false) : string * bool) ])

let suite =
  "Runner_tiered_cycle"
  >::: [
         "Friday call triggers Full promote"
         >:: test_friday_triggers_full_promote;
         "Non-Friday call skips Full promote"
         >:: test_non_friday_skips_full_promote;
         "CreateEntering transition promotes symbol to Full"
         >:: test_create_entering_promotes_to_full;
         "Multi-symbol CreateEntering → per-symbol Full-tier promote"
         >:: test_multi_symbol_create_entering_per_symbol_promote;
         "Newly-Closed position triggers Demote"
         >:: test_newly_closed_position_triggers_demote;
         "Closed on first call triggers Demote"
         >:: test_closed_on_first_call_triggers_demote;
         "Already-Closed position not re-demoted"
         >:: test_already_closed_not_re_demoted;
         "Symbol recycles under a new position_id — one demote + one promote"
         >:: test_symbol_recycle_under_new_position_id;
         "Inner strategy transitions pass through unchanged"
         >:: test_inner_transitions_pass_through;
         "Inner strategy error skips post-inner tier bookkeeping"
         >:: test_inner_error_skips_post_inner_tier_bookkeeping;
         "get_price throttle passes primary index"
         >:: test_throttle_passes_primary_index;
         "get_price throttle passes always-loaded symbols"
         >:: test_throttle_passes_always_loaded;
         "get_price throttle blocks metadata-tier universe symbols"
         >:: test_throttle_blocks_metadata_universe;
         "get_price throttle passes held position (even at metadata tier)"
         >:: test_throttle_passes_held_position;
         "get_price throttle blocks unknown symbol"
         >:: test_throttle_blocks_unknown_symbol;
       ]

let () = run_test_tt_main suite
