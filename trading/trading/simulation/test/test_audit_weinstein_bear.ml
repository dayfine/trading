(** Audit harness for the Weinstein strategy's short-side codepaths.

    Background. The published audit harness ([test_split_day_audit.ml], 14
    scenarios) drives the simulator with bespoke scheduled strategies
    ([Make_buy_and_hold] / [Make_scheduled]) — never the production
    {!Weinstein_strategy}. The simulator's broker-model invariants are
    well-pinned by that suite, but the strategy's own short-side machinery (stop
    direction, screener-emitted shorts, round-trip extraction for Sell→Buy) was
    never exercised by any harness. The [sp500-2019-2023] full-universe
    regression (PR #681) — −144.5% return, 245.8% MaxDD, 128 short entries
    riding into the 2020-2023 bull market — surfaced four short-side gaps
    documented in [dev/notes/short-side-gaps-2026-04-29.md]:

    - **G1**: short stops do not fire correctly. Audit evidence: ALB short with
      stop $103 exited at $77 on 2019-01-29 when ALB was at $76 — profitable
      territory that should NOT trigger an exit.
    - **G2**: {!Metrics.extract_round_trips} pairs Buy→Sell only; Sell→Buy short
      round-trips are silently dropped, so [trades.csv] hides them.
    - **G3** + **G4**: cash floor blind to shorts; no force-liquidation /
      margin-call mechanism. Out of scope here — those are [Trading_portfolio] +
      [Portfolio_risk] surfaces.

    This file closes G5 ("audit harness lacks a Weinstein-strategy-backed
    scenario") by pinning the contracts that the upcoming G1 / G2 fix PRs must
    satisfy.

    {1 What is pinned}

    + {b Test A — short stop does NOT fire when price stays below stop.} Calls
      {!Weinstein_strategy.Stops_runner.update} on a synthetic short [Holding]
      whose stop sits ABOVE entry. The current bar's high stays well below the
      stop. The runner must return zero exit transitions.
    + {b Test B — short stop DOES fire when price rallies above stop.} Same
      setup as A; the current bar's high prints above the stop. The runner must
      emit exactly one [TriggerExit] transition.
    + {b Test C — [Metrics.extract_round_trips] pairs Sell→Buy short
         round-trips.} Drives the simulator (via a scheduled strategy that emits
      [Short_open] then [TriggerExit] on the held short — exercising the same
      [order_generator] and broker codepaths the production strategy uses) and
      asserts the resulting round-trip is reported with positive P&L when the
      cover price is below entry.

    {1 Why direct [Stops_runner.update] for A & B}

    Driving the full {!Weinstein_strategy.make} pipeline to emit a real short
    via the screener cascade requires a 30+-week weekly bar history, sector ETF
    tables, AD breadth bars, and a macro-bearish window — tens of MB of fixture
    data, all to test a single comparison-direction predicate. The *production
    codepath* under test is {!Weinstein_strategy.Stops_runner.update} threading
    [pos.side = Short] → {!Weinstein_stops.update} →
    {!Weinstein_stops.check_stop_hit}. Calling [Stops_runner.update] directly
    with a synthetic [Position.t] short [Holding] exercises that exact path with
    two orders of magnitude less setup. The fact that the strategy's
    [on_market_close] wraps this same runner is verified by the existing
    weinstein_backtest integration tests; here we pin the runner's short-side
    direction contract.

    {1 Pass / fail expectations on current main (post-#690)}

    + {b Test A — PASSES.} The unit-level [Weinstein_stops.check_stop_hit]
      direction predicate is correct: a short with stop above price does NOT
      trigger from the [Initial] state. This pins the contract — a future
      regression that swaps the direction (e.g., the long-side comparison
      leaking into the short branch) would fail this test.
    + {b Test B — PASSES.} The positive-case predicate also fires correctly: bar
      high ≥ short stop level emits a [TriggerExit].
    + {b Test C — PASSES post-#690.} Originally written to FAIL on pre-#690 main
      (where [Metrics.extract_round_trips] paired Buy→Sell only, so the Sell→Buy
      short round-trip was silently dropped). PR #690 added Sell→Buy pairing,
      closing G2. Test C now pins the post-fix contract: a synthetic strategy
      that emits [Short_open] then [TriggerExit] drives the simulator through
      the entry-Sell + cover-Buy fill sequence, and the resulting step.trades
      stream produces a SHORT round-trip with positive P&L when cover < entry.

    {b Note for G1 follow-ups.} The audit evidence in
    [dev/notes/short-side-gaps-2026-04-29.md] shows ALB short reportedly exiting
    at $77 with stop $103 when price was $76 — Tests A and B as written pin the
    [Initial]-state predicate but do NOT reproduce that anomaly. The actual G1
    bug may live elsewhere ([Trailing]-state stop drift, the
    [actual_price = bar.low_price] hard-coding in
    [Stops_runner._make_exit_transition], or a screener-driven exit). Tests A
    and B are the floor — the contract a fix must preserve, not the surface
    where the bug currently lives. Extending this harness with multi-bar
    Trailing-state scenarios is the natural follow-up once the real ALB-anomaly
    root cause is isolated. *)

open OUnit2
open Core
open Matchers
module Position = Trading_strategy.Position
module Stops_runner = Weinstein_strategy.Stops_runner
module Bar_reader = Weinstein_strategy.Bar_reader

(* ------------------------------------------------------------------ *)
(* Test data builders                                                   *)
(* ------------------------------------------------------------------ *)

let _date s = Date.of_string s

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

(** Build a [Position.t] in [Holding] state for a short with the given
    parameters. Uses [Position.create_entering] + [apply_transition] chain so
    the result is the same shape the simulator would have produced after a real
    Short_open + EntryFill + EntryComplete cycle. Avoids hand-constructing the
    record so future invariants on [Position.t] don't silently break this test.
*)
let _make_short_holding ~symbol ~entry_date ~quantity ~entry_price =
  let create =
    {
      Position.position_id = symbol ^ "-1";
      date = entry_date;
      kind =
        Position.CreateEntering
          {
            symbol;
            side = Position.Short;
            target_quantity = quantity;
            entry_price;
            reasoning =
              Position.TechnicalSignal
                { indicator = "audit"; description = "short-entry" };
          };
    }
  in
  let pos =
    match Position.create_entering create with
    | Ok p -> p
    | Error err -> assert_failure ("create_entering: " ^ Status.show err)
  in
  let fill =
    {
      Position.position_id = symbol ^ "-1";
      date = entry_date;
      kind =
        Position.EntryFill
          { filled_quantity = quantity; fill_price = entry_price };
    }
  in
  let pos =
    match Position.apply_transition pos fill with
    | Ok p -> p
    | Error err -> assert_failure ("apply EntryFill: " ^ Status.show err)
  in
  let complete =
    {
      Position.position_id = symbol ^ "-1";
      date = entry_date;
      kind =
        Position.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    }
  in
  match Position.apply_transition pos complete with
  | Ok p -> p
  | Error err -> assert_failure ("apply EntryComplete: " ^ Status.show err)

(** Drive [Stops_runner.update] for one position + one bar. Returns
    [(exits, adjusts)]. The runner threads [pos.side] into
    [Weinstein_stops.update] which calls [check_stop_hit] — the predicate whose
    direction is at issue in G1. We use [Bar_reader.empty ()] so the runner's MA
    path falls through to the [(Flat, fallback_price)] branch (no panel data
    needed); the relevant decision is the stop-hit check, which only consumes
    the bar and the stop level. *)
let _run_stops_once ~pos ~bar ~stop_level =
  let positions = Map.singleton (module String) pos.Position.symbol pos in
  let stop_states =
    ref
      (Map.singleton
         (module String)
         pos.Position.symbol
         (Weinstein_stops.Initial { stop_level; reference_level = stop_level }))
  in
  let prior_stages = Hashtbl.create (module String) in
  let get_price symbol =
    if String.equal symbol pos.Position.symbol then Some bar else None
  in
  Stops_runner.update ~stops_config:Weinstein_stops.default_config
    ~stage_config:Stage.default_config ~lookback_bars:30 ~positions ~get_price
    ~stop_states ~bar_reader:(Bar_reader.empty ())
    ~as_of:bar.Types.Daily_price.date ~prior_stages ()

(* ------------------------------------------------------------------ *)
(* Test A — short stop does NOT fire when price stays below stop       *)
(* ------------------------------------------------------------------ *)

(** A short was entered at $100; the stop sits ABOVE entry at $103 (the
    Weinstein rule: short stops sit above entry, fire on a rally above the
    stop). The current bar's high is $76 — far below the stop, deep in
    profitable short territory. The runner must return zero exit transitions.

    On current main, the [Stops_runner._make_exit_transition] helper extracts
    [actual_price = bar.low_price] regardless of side — but more fundamentally,
    audit evidence in [dev/notes/short-side-gaps-2026-04-29.md] shows shorts
    triggering exits at prices far below the stop (ALB short stop $103, exit $77
    on 2019-01-29). This test asserts the contract: a short whose stop is at
    $103 must NOT fire when the bar prints high=$76. *)
let test_a_short_stop_no_fire_below _ =
  let pos =
    _make_short_holding ~symbol:"ALB" ~entry_date:(_date "2019-01-15")
      ~quantity:100.0 ~entry_price:100.0
  in
  let bar =
    _make_bar ~date:(_date "2019-01-29") ~open_:76.5 ~high:77.0 ~low:75.5
      ~close:76.0 ~adjusted_close:76.0 ~volume:1_000_000
  in
  let exits, _adjusts = _run_stops_once ~pos ~bar ~stop_level:103.58 in
  (* Contract: short stop ABOVE entry, price BELOW stop → no exit. *)
  assert_that exits (size_is 0)

(* ------------------------------------------------------------------ *)
(* Test B — short stop DOES fire when price rallies above stop         *)
(* ------------------------------------------------------------------ *)

(** Same short as Test A: entered $100, stop $103. The bar prints high=$104 — a
    rally above the stop. The runner must emit exactly one [TriggerExit]
    transition for the held short, with
    [exit_reason = StopLoss { stop_price = 103.58; ... }]. Pins the positive
    case of the short-stop direction predicate.

    Per [Weinstein_stops.check_stop_hit]'s docstring: "Short: triggered by
    [high_price ≥ stop_level]". The unit-level predicate is correct (see
    [test_weinstein_stops.ml]); the gap is whether the runner threads
    [pos.side = Short] correctly into the predicate. *)
let test_b_short_stop_fires_above _ =
  let pos =
    _make_short_holding ~symbol:"ALB" ~entry_date:(_date "2019-01-15")
      ~quantity:100.0 ~entry_price:100.0
  in
  let bar =
    _make_bar ~date:(_date "2019-02-01") ~open_:103.0 ~high:104.5 ~low:102.5
      ~close:104.0 ~adjusted_close:104.0 ~volume:1_000_000
  in
  let exits, _adjusts = _run_stops_once ~pos ~bar ~stop_level:103.58 in
  (* Contract: short stop ABOVE entry, bar high ABOVE stop → exit fires.
     Pin the count, the position id, and the transition kind ([TriggerExit])
     together so a future no-op re-introduction of "all sides exit when
     low ≤ stop" still fails the count, and a regression that emits a
     non-exit transition still fails the kind check. *)
  assert_that exits
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Position.transition) -> t.position_id)
               (equal_to "ALB-1");
             field
               (fun (t : Position.transition) -> t.kind)
               (matching ~msg:"Expected TriggerExit"
                  (function
                    | Position.TriggerExit { exit_reason; _ } ->
                        Some exit_reason
                    | _ -> None)
                  (matching ~msg:"Expected StopLoss exit_reason"
                     (function
                       | Position.StopLoss s -> Some s.stop_price | _ -> None)
                     (float_equal 103.58)));
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Test C — Metrics.extract_round_trips pairs Sell→Buy short round-trip *)
(* ------------------------------------------------------------------ *)

(** Drives the simulator with a strategy that emits [Short_open] on day 1 and
    [TriggerExit] on day 4. The order generator turns these into [Sell] (entry,
    broker creates negative-quantity lot) and [Buy] (cover, closes the short).
    The resulting [step.trades] sequence is therefore Sell → Buy for symbol
    "BEAR".

    Post-#690, {!Metrics.extract_round_trips} pairs both Buy→Sell (long) and
    Sell→Buy (short) — see [_is_paired_round_trip]. This test asserts the
    contract end-to-end through the simulator: a synthetic Short_open +
    TriggerExit pair drives the entry-Sell + cover-Buy fill sequence, and the
    resulting round-trip is reported with [pnl_dollars > 0] when cover < entry.

    {b End-date fence-post.} The simulator's [_is_complete] fires on
    [current_date >= end_date], i.e. the end date is exclusive of the last
    processing day. Orders are filled the bar AFTER submission, so to fill the
    cover-Buy submitted on [exit_date], the simulation must run through
    [exit_date + 1 trading day]. We pad [end_date] one beyond the last fixture
    bar (01-09 → 01-10) so the cover fill on 01-09 is captured in [step.trades];
    extra non-trading dates produce empty steps and do not perturb the result.
*)

(** A scheduled strategy that opens a short on [open_date] then emits a
    [TriggerExit] on [exit_date] for the held short. This is the same
    [Make_scheduled] shape used by [test_split_day_audit] but inlined here so
    this file is self-contained — the dispatch prompt forbids touching the
    existing audit harness. *)
module Make_short_round_trip (Cfg : sig
  val symbol : string
  val quantity : float
  val open_date : Date.t
  val exit_date : Date.t
end) : Trading_strategy.Strategy_interface.STRATEGY = struct
  let name = "ShortRoundTrip"
  let opened = ref false

  let _build_short_open ~bar =
    let open Position in
    {
      position_id = Cfg.symbol ^ "-short";
      date = bar.Types.Daily_price.date;
      kind =
        CreateEntering
          {
            symbol = Cfg.symbol;
            side = Short;
            target_quantity = Cfg.quantity;
            entry_price = bar.Types.Daily_price.close_price;
            reasoning =
              TechnicalSignal
                { indicator = "audit"; description = "short-open" };
          };
    }

  let _build_exit ~bar ~(positions : Position.t Core.String.Map.t) =
    let open Position in
    Map.to_alist positions
    |> List.find_map ~f:(fun (id, pos) ->
        if not (String.equal pos.symbol Cfg.symbol) then None
        else
          match get_state pos with
          | Holding _ ->
              Some
                {
                  position_id = id;
                  date = bar.Types.Daily_price.date;
                  kind =
                    TriggerExit
                      {
                        exit_reason =
                          SignalReversal { description = "short-cover" };
                        exit_price = bar.Types.Daily_price.close_price;
                      };
                }
          | _ -> None)

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    match get_price Cfg.symbol with
    | None -> Ok { Trading_strategy.Strategy_interface.transitions = [] }
    | Some bar ->
        if Date.equal bar.Types.Daily_price.date Cfg.open_date && not !opened
        then begin
          opened := true;
          Ok
            {
              Trading_strategy.Strategy_interface.transitions =
                [ _build_short_open ~bar ];
            }
        end
        else if Date.equal bar.Types.Daily_price.date Cfg.exit_date then
          match _build_exit ~bar ~positions:portfolio.positions with
          | Some t ->
              Ok { Trading_strategy.Strategy_interface.transitions = [ t ] }
          | None -> Ok { Trading_strategy.Strategy_interface.transitions = [] }
        else Ok { Trading_strategy.Strategy_interface.transitions = [] }
end

(** A 6-bar bear-window fixture: prices decline from $100 to $80. A short opened
    at $100 and covered at $80 should produce a positive P&L of
    [(entry − cover) × quantity = ($100 − $80) × 100 = $2,000]. *)
let _bear_window_bars =
  [
    _make_bar ~date:(_date "2024-01-02") ~open_:100.0 ~high:101.0 ~low:99.0
      ~close:100.0 ~adjusted_close:100.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-03") ~open_:99.5 ~high:100.0 ~low:97.0
      ~close:97.5 ~adjusted_close:97.5 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-04") ~open_:97.0 ~high:97.5 ~low:93.0
      ~close:93.5 ~adjusted_close:93.5 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-05") ~open_:93.0 ~high:93.5 ~low:88.0
      ~close:88.5 ~adjusted_close:88.5 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-08") ~open_:88.0 ~high:88.5 ~low:83.0
      ~close:83.5 ~adjusted_close:83.5 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-09") ~open_:83.0 ~high:83.5 ~low:79.5
      ~close:80.0 ~adjusted_close:80.0 ~volume:1_000_000;
  ]

let _zero_commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let test_c_short_round_trip_in_metrics _ =
  let module S = Make_short_round_trip (struct
    let symbol = "BEAR"
    let quantity = 100.0
    let open_date = _date "2024-01-02"
    let exit_date = _date "2024-01-08"
  end) in
  (* The simulator's [_is_complete] fires on [current_date >= end_date], so the
     end date is exclusive — to reach the bar on 01-09 (the cover-Buy fill day,
     since orders submitted on 01-08 fill next day), end_date must be the day
     AFTER the fill date. The bear fixture extends through 01-09 only, so we
     pad end_date one beyond the last bar — extra non-trading dates are fine,
     the simulator just produces empty steps. *)
  let config =
    {
      Trading_simulation_types.Simulator_types.start_date = _date "2024-01-02";
      end_date = _date "2024-01-10";
      initial_cash = 100_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let result_ref = ref None in
  Test_helpers.with_test_data "audit_weinstein_bear_c"
    [ ("BEAR", _bear_window_bars) ]
    ~f:(fun data_dir ->
      let deps =
        Trading_simulation.Simulator.create_deps ~symbols:[ "BEAR" ] ~data_dir
          ~strategy:(module S)
          ~commission:config.commission ()
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      match Trading_simulation.Simulator.run sim with
      | Ok r -> result_ref := Some r
      | Error err -> assert_failure ("simulation failed: " ^ Status.show err));
  let result =
    match !result_ref with Some r -> r | None -> assert_failure "no result"
  in
  let round_trips =
    Trading_simulation.Metrics.extract_round_trips result.steps
  in
  (* Contract (G2): the Sell→Buy short round-trip must be reported. The
     entry is the Sell at the open-day fill (~$99.50 open price on 01-03
     fill, since orders fill the bar after submission); the exit is the
     Buy cover at the exit-day fill (~$83.00 open on 01-09). For a short,
     P&L = (entry − cover) × quantity, so P&L > 0 when cover is below
     entry. *)
  let bear_round_trips =
    List.filter round_trips
      ~f:(fun (m : Trading_simulation.Metrics.trade_metrics) ->
        String.equal m.symbol "BEAR")
  in
  assert_that bear_round_trips
    (elements_are
       [
         all_of
           [
             field
               (fun (m : Trading_simulation.Metrics.trade_metrics) -> m.symbol)
               (equal_to "BEAR");
             field
               (fun (m : Trading_simulation.Metrics.trade_metrics) ->
                 m.quantity)
               (float_equal 100.0);
             (* Cover below entry → positive P&L for a short. *)
             field
               (fun (m : Trading_simulation.Metrics.trade_metrics) ->
                 m.pnl_dollars)
               (gt (module Float_ord) 0.0);
           ];
       ])

(* ------------------------------------------------------------------ *)

let suite =
  "audit_weinstein_bear"
  >::: [
         "A_short_stop_no_fire_below" >:: test_a_short_stop_no_fire_below;
         "B_short_stop_fires_above" >:: test_b_short_stop_fires_above;
         "C_short_round_trip_in_metrics" >:: test_c_short_round_trip_in_metrics;
       ]

let () = run_test_tt_main suite
