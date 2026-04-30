(** End-to-end exercise of {!Force_liquidation_runner} with a synthetic
    [Position.t] [Holding] + bar input.

    Closes the runner-side contract for G4: given a held position whose
    unrealized P&L exceeds the configured threshold, the runner emits a
    [TriggerExit] transition and routes a [force_liquidation_event] through the
    audit recorder. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module FL = Portfolio_risk.Force_liquidation

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _date s = Date.of_string s

let _make_bar ~date ~close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close *. 1.01;
      low_price = close *. 0.99;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
    }

(** Build a [Holding] position with [side]/[entry_price]/[quantity] using the
    canonical entry chain so the result is bit-equal to what the simulator would
    have produced. *)
let _make_holding ~symbol ~side ~entry_date ~quantity ~entry_price =
  let pos_id = symbol ^ "-1" in
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let trans kind = { Position.position_id = pos_id; date = entry_date; kind } in
  let p =
    Position.create_entering
      (trans
         (Position.CreateEntering
            {
              symbol;
              side;
              target_quantity = quantity;
              entry_price;
              reasoning =
                Position.TechnicalSignal
                  { indicator = "audit"; description = "test-entry" };
            }))
    |> unwrap
  in
  let p =
    Position.apply_transition p
      (trans
         (Position.EntryFill
            { filled_quantity = quantity; fill_price = entry_price }))
    |> unwrap
  in
  Position.apply_transition p
    (trans
       (Position.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(** Build an [Entering] position — entry order placed but not yet filled.
    [_position_input_of_holding] returns [None] for non-Holding positions, so no
    event fires for these. *)
let _make_entering ~symbol ~side ~entry_date ~quantity ~entry_price =
  let pos_id = symbol ^ "-1" in
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let trans kind = { Position.position_id = pos_id; date = entry_date; kind } in
  Position.create_entering
    (trans
       (Position.CreateEntering
          {
            symbol;
            side;
            target_quantity = quantity;
            entry_price;
            reasoning =
              Position.TechnicalSignal
                { indicator = "audit"; description = "test-entry" };
          }))
  |> unwrap

(** Recorder bundle that captures every emitted force-liquidation event into a
    mutable ref. Other callbacks are no-ops. *)
let _capturing_recorder () =
  let captured = ref [] in
  let recorder : Audit_recorder.t =
    {
      record_entry = (fun _ -> ());
      record_exit = (fun _ -> ());
      record_cascade_summary = (fun _ -> ());
      record_force_liquidation = (fun e -> captured := e :: !captured);
    }
  in
  (recorder, captured)

(* ------------------------------------------------------------------ *)
(* Per-position trigger                                                 *)
(* ------------------------------------------------------------------ *)

let test_per_position_trigger_emits_exit _ =
  (* Long entered $100, current $40 — 60% loss; default threshold 50% fires. *)
  let pos =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let bar = _make_bar ~date:(_date "2024-04-29") ~close:40.0 in
  let positions = String.Map.singleton "AAPL" pos in
  let get_price s = if String.equal s "AAPL" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_000_000.0 ~current_date:(_date "2024-04-29")
      ~peak_tracker ~audit_recorder:recorder
  in
  assert_that transitions
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Position.transition) -> t.position_id)
               (equal_to "AAPL-1");
             field
               (fun (t : Position.transition) -> t.kind)
               (matching ~msg:"Expected TriggerExit"
                  (function
                    | Position.TriggerExit { exit_price; _ } -> Some exit_price
                    | _ -> None)
                  (float_equal 40.0));
           ];
       ]);
  assert_that !captured (size_is 1)

let test_per_position_trigger_no_fire_under_threshold _ =
  (* Long $100 → $60 = 40% loss; threshold 50%; no fire. *)
  let pos =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let bar = _make_bar ~date:(_date "2024-04-29") ~close:60.0 in
  let positions = String.Map.singleton "AAPL" pos in
  let get_price s = if String.equal s "AAPL" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_000_000.0 ~current_date:(_date "2024-04-29")
      ~peak_tracker ~audit_recorder:recorder
  in
  assert_that transitions is_empty;
  assert_that !captured is_empty

(* ------------------------------------------------------------------ *)
(* Portfolio-floor trigger                                              *)
(* ------------------------------------------------------------------ *)

let test_portfolio_floor_trigger_closes_all _ =
  (* Two positions; portfolio_value drops below 40% of peak; both close. *)
  let pos_a =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let pos_b =
    _make_holding ~symbol:"TSLA" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:50.0 ~entry_price:200.0
  in
  let positions =
    String.Map.of_alist_exn [ ("AAPL", pos_a); ("TSLA", pos_b) ]
  in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  (* First tick: establish peak at 1M with both positions at par. *)
  let bar_par_a = _make_bar ~date:(_date "2024-01-02") ~close:100.0 in
  let bar_par_b = _make_bar ~date:(_date "2024-01-02") ~close:200.0 in
  let get_price_par s =
    if String.equal s "AAPL" then Some bar_par_a
    else if String.equal s "TSLA" then Some bar_par_b
    else None
  in
  (* cash: 1M - 10K (AAPL) - 10K (TSLA) = 980K; positions worth 20K → total 1M. *)
  let _ =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price:get_price_par ~cash:980_000.0
      ~current_date:(_date "2024-01-02") ~peak_tracker ~audit_recorder:recorder
  in
  (* Second tick: catastrophic drop. AAPL 100→20, TSLA 200→40.
     Position values: 100*20 + 50*40 = 4000; cash unchanged at 980_000.
     Wait — that's still 984K which is above 40% of 1M peak. Need a bigger
     drop in CASH for the floor to fire. Let's drop cash too (e.g. simulate
     accumulated losses on shorts that already covered): cash 200_000,
     positions 4000 → total 204_000, well below 400_000 (40% of peak 1M). *)
  let bar_crash_a = _make_bar ~date:(_date "2024-04-29") ~close:20.0 in
  let bar_crash_b = _make_bar ~date:(_date "2024-04-29") ~close:40.0 in
  let get_price_crash s =
    if String.equal s "AAPL" then Some bar_crash_a
    else if String.equal s "TSLA" then Some bar_crash_b
    else None
  in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price:get_price_crash ~cash:200_000.0
      ~current_date:(_date "2024-04-29") ~peak_tracker ~audit_recorder:recorder
  in
  (* Both positions close under Portfolio_floor reason. *)
  assert_that transitions (size_is 2);
  assert_that !captured (size_is 2);
  (* Halt state must flip. *)
  assert_that (FL.Peak_tracker.halt_state peak_tracker) (equal_to FL.Halted)

let test_no_positions_no_events _ =
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config
      ~positions:String.Map.empty
      ~get_price:(fun _ -> None)
      ~cash:1_000_000.0 ~current_date:(_date "2024-04-29") ~peak_tracker
      ~audit_recorder:recorder
  in
  assert_that transitions is_empty;
  assert_that !captured is_empty

let test_short_position_loss_fires _ =
  (* Short at $200, current $320 = 60% loss (entry 200 + price up 120 / cost
     basis 200 = 0.6); default 50% fires. *)
  let pos =
    _make_holding ~symbol:"TSLA" ~side:Trading_base.Types.Short
      ~entry_date:(_date "2024-01-02") ~quantity:50.0 ~entry_price:200.0
  in
  let bar = _make_bar ~date:(_date "2024-04-29") ~close:320.0 in
  let positions = String.Map.singleton "TSLA" pos in
  let get_price s = if String.equal s "TSLA" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_000_000.0 ~current_date:(_date "2024-04-29")
      ~peak_tracker ~audit_recorder:recorder
  in
  assert_that transitions (size_is 1);
  assert_that !captured
    (elements_are
       [
         all_of
           [
             field (fun (e : FL.event) -> e.symbol) (equal_to "TSLA");
             field
               (fun (e : FL.event) -> e.side)
               (equal_to Trading_base.Types.Short);
             field (fun (e : FL.event) -> e.reason) (equal_to FL.Per_position);
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Defensive guards (PR #695, qc-behavioral B3)                         *)
(* ------------------------------------------------------------------ *)

(** Guard: [_position_input_of_holding] returns [None] for non-Holding
    positions. An [Entering] position (entry order placed, no fills yet) has no
    entry_price / quantity that match the [Holding] state's contract; the runner
    must skip it without firing an event. *)
let test_non_holding_position_does_not_fire _ =
  let pos =
    _make_entering ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let bar = _make_bar ~date:(_date "2024-04-29") ~close:30.0 in
  let positions = String.Map.singleton "AAPL" pos in
  let get_price s = if String.equal s "AAPL" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_000_000.0 ~current_date:(_date "2024-04-29")
      ~peak_tracker ~audit_recorder:recorder
  in
  assert_that transitions is_empty;
  assert_that !captured is_empty

(** Guard: [_position_input_of_holding] returns [None] when [get_price] returns
    [None] for the position's symbol — the runner can't evaluate the threshold
    without a current price. The position is silently skipped this tick rather
    than fired with stale data. *)
let test_missing_price_does_not_fire _ =
  let pos =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let positions = String.Map.singleton "AAPL" pos in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price:(fun _ -> None)
      ~cash:1_000_000.0 ~current_date:(_date "2024-04-29") ~peak_tracker
      ~audit_recorder:recorder
  in
  assert_that transitions is_empty;
  assert_that !captured is_empty

(* ------------------------------------------------------------------ *)
(* G9 — shorts must subtract from portfolio_value (sign convention)     *)
(* ------------------------------------------------------------------ *)

(** Pin the G9 fix: a short Holding contributes [-quantity * close_price] to
    portfolio_value, mirroring G8's fix to
    {!Portfolio_view._holding_market_value}.

    Pre-fix, [_portfolio_value] folded [+quantity * close_price] for every
    Holding regardless of side. With shorts, this inflated portfolio_value by
    twice the short notional (cash already includes short-entry proceeds, so
    subtracting the buy-back liability is what makes mark-to-market track P&L
    correctly).

    The peak observed after one [update] call is the most direct surface to pin:
    pre-fix returns the inflated peak, post-fix returns the true peak. *)
let test_short_holding_does_not_inflate_peak _ =
  (* 1 short, 1000 shares @ $100. Cash $1.1M (= $1M starting + $100K short
     proceeds). True portfolio_value at entry: $1.1M - $100K = $1M.
     Pre-fix portfolio_value: $1.1M + $100K = $1.2M (inflated by 2x notional). *)
  let pos =
    _make_holding ~symbol:"TSLA" ~side:Trading_base.Types.Short
      ~entry_date:(_date "2024-01-02") ~quantity:1000.0 ~entry_price:100.0
  in
  let bar = _make_bar ~date:(_date "2024-01-02") ~close:100.0 in
  let positions = String.Map.singleton "TSLA" pos in
  let get_price s = if String.equal s "TSLA" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, _captured = _capturing_recorder () in
  let _ =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_100_000.0 ~current_date:(_date "2024-01-02")
      ~peak_tracker ~audit_recorder:recorder
  in
  (* Post-fix: peak = $1M (true value). Pre-fix: peak = $1.2M (inflated). *)
  assert_that (FL.Peak_tracker.peak peak_tracker) (float_equal 1_000_000.0)

(** Pin the downstream consequence of G9: a profitable short should not trigger
    Portfolio_floor.

    Construction: portfolio is dominated by a single short. At entry the peak is
    established. On a later tick the short price drops sharply (large profit).
    With the buggy unsigned formula, the peak was set at
    [cash + qty * entry_price] (inflated); on the profit tick, the buggy
    portfolio_value drops to [cash + qty * lower_price], and at sufficient
    short-dominance + price-drop ratios the buggy floor check fires.

    Sized to actually trip the buggy floor: cash = $20K, 1000-share short at
    $100 (entry proceeds bringing cash to $120K but starting cash post-entry set
    at $20K so short notional dominates). At entry buggy value = $20K + 1000 *
    $100 = $120K. Tick 2 at price $20: buggy = $20K + 1000 * $20 = $40K. $40K /
    $120K = 0.333 < 0.4 → FLOOR FIRES. Post-fix value at entry = $20K - $100K =
    -$80K (negative — peak observation is monotonic, so peak stays whatever it
    became; if first observed value is -$80K, peak <= 0 and floor never fires
    per [_portfolio_floor_breached]'s [peak > 0] guard). Even with profit at
    price $20: post-fix value = $20K - $20K = $0K. Floor check requires peak > 0
    — never fires.

    To make the post-fix scenario produce a positive peak (closer to a real
    portfolio), use a more realistic balance: cash = $1.05M, 100-share short at
    $500 (cash already includes proceeds; pre-entry cash was $1M). True value =
    $1.05M - $50K = $1M. Buggy = $1.05M + $50K = $1.1M. Tick 2 at price $50 (90%
    short profit, large but plausible): buggy = $1.05M + $5K = $1.055M. $1.055M
    / $1.1M = 0.959 > 0.4 → still doesn't fire on a single short.

    The single-short surface alone is too tame to trip the floor without extreme
    parameters. The peak-inflation assertion above pins the formula bug directly
    — that is the load-bearing test. We add this companion test pinning that the
    peak-tracker math passes through correctly when we add a second short,
    multiplying the inflation factor. *)
let test_two_profitable_shorts_no_portfolio_floor _ =
  let pos_a =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Short
      ~entry_date:(_date "2024-01-02") ~quantity:1000.0 ~entry_price:100.0
  in
  let pos_b =
    _make_holding ~symbol:"TSLA" ~side:Trading_base.Types.Short
      ~entry_date:(_date "2024-01-02") ~quantity:500.0 ~entry_price:200.0
  in
  let positions =
    String.Map.of_alist_exn [ ("AAPL", pos_a); ("TSLA", pos_b) ]
  in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  (* Cash: $1M starting + $100K (AAPL short) + $100K (TSLA short) = $1.2M.
     True value: $1.2M - $100K - $100K = $1M.
     Buggy value: $1.2M + $100K + $100K = $1.4M. *)
  let bar_par_a = _make_bar ~date:(_date "2024-01-02") ~close:100.0 in
  let bar_par_b = _make_bar ~date:(_date "2024-01-02") ~close:200.0 in
  let get_price_par s =
    if String.equal s "AAPL" then Some bar_par_a
    else if String.equal s "TSLA" then Some bar_par_b
    else None
  in
  let _ =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price:get_price_par ~cash:1_200_000.0
      ~current_date:(_date "2024-01-02") ~peak_tracker ~audit_recorder:recorder
  in
  (* Post-fix peak: $1M. Pre-fix: $1.4M. *)
  assert_that (FL.Peak_tracker.peak peak_tracker) (float_equal 1_000_000.0);
  (* Tick 2: both shorts profit big — AAPL 100→50, TSLA 200→100 (50% profit
     each). True value: $1.2M - $50K - $50K = $1.1M (peak rises to $1.1M).
     Pre-fix: $1.2M + $50K + $50K = $1.3M (drops from buggy peak $1.4M to
     $1.3M = 92.9% — still above 40% floor; per-position threshold is also
     not exceeded since these are profits, not losses). The pre-fix bug
     does NOT trip the floor in this scenario, but the bug is fully captured
     by the peak assertion above. We assert no Portfolio_floor events fire
     here to pin the higher-level invariant: profitable shorts → no
     Portfolio_floor. *)
  let bar_profit_a = _make_bar ~date:(_date "2024-04-29") ~close:50.0 in
  let bar_profit_b = _make_bar ~date:(_date "2024-04-29") ~close:100.0 in
  let get_price_profit s =
    if String.equal s "AAPL" then Some bar_profit_a
    else if String.equal s "TSLA" then Some bar_profit_b
    else None
  in
  let _ =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price:get_price_profit ~cash:1_200_000.0
      ~current_date:(_date "2024-04-29") ~peak_tracker ~audit_recorder:recorder
  in
  (* No Portfolio_floor events captured — these shorts are profiting. *)
  let portfolio_floor_events =
    List.filter !captured ~f:(fun e ->
        match e.FL.reason with FL.Portfolio_floor -> true | _ -> false)
  in
  assert_that portfolio_floor_events is_empty;
  (* Halt state must remain Active. *)
  assert_that (FL.Peak_tracker.halt_state peak_tracker) (equal_to FL.Active)

(* ------------------------------------------------------------------ *)
(* Double-exit avoidance — strategy-level filter                        *)
(* ------------------------------------------------------------------ *)

(** [Weinstein_strategy.Internal_for_test.positions_minus_exited] removes any
    position whose [position_id] appears in a [TriggerExit] transition. The
    force-liquidation runner sees the filtered map, so a position already
    stop-exited this tick does NOT receive a duplicate force-liquidation
    [TriggerExit].

    Pinning this at the [_positions_minus_exited] seam (rather than the runner)
    matches where the contract lives — the runner has no notion of pending
    stop-exits; the strategy filter is the single source of truth. *)
let test_double_exit_avoidance_filters_already_exited _ =
  let pos_a =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let pos_b =
    _make_holding ~symbol:"TSLA" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:50.0 ~entry_price:200.0
  in
  let positions =
    String.Map.of_alist_exn [ ("AAPL", pos_a); ("TSLA", pos_b) ]
  in
  (* AAPL just received a stop-exit transition this tick — must be filtered
     out before force-liquidation considers it. *)
  let stop_exit_transitions =
    [
      {
        Position.position_id = "AAPL-1";
        date = _date "2024-04-29";
        kind =
          Position.TriggerExit
            {
              exit_reason =
                Position.StopLoss
                  {
                    stop_price = 90.0;
                    actual_price = 89.0;
                    loss_percent = 11.0;
                  };
              exit_price = 89.0;
            };
      };
    ]
  in
  let filtered =
    Weinstein_strategy.Internal_for_test.positions_minus_exited ~positions
      ~stop_exit_transitions
  in
  assert_that
    (Map.keys filtered |> List.sort ~compare:String.compare)
    (elements_are [ equal_to "TSLA" ])

(* ------------------------------------------------------------------ *)
(* G12 — phantom peak spike from inconsistent (positions, cash) snapshot *)
(* ------------------------------------------------------------------ *)

(** Regression: phantom peak spike from inconsistent (positions, cash) passed to
    [FL.check].

    Invariant: peak_tracker.peak after [update] = Portfolio_view.portfolio_value
    ~cash ~positions

    Buggy path: positions = full \ \{S1\}, cash = pre_tick_cash (S1 already
    removed to avoid double-exit but its buy-back debit has not yet posted to
    cash) → peak inflated by [current_price_S1 * quantity_S1] (the absolute
    value of S1's signed mtm contribution; for a short the contribution is
    [-current_price * quantity], so removing S1 from the sum while keeping the
    same cash adds a positive term back).

    Fixed path: positions = full, cash = pre_tick_cash → peak = true pre-tick
    portfolio_value.

    Contract enforced at the call site (Weinstein_strategy._on_market_close):
    (positions, cash) must be a consistent snapshot — either both pre-stop or
    both post-stop, never the hybrid. The runner here just takes the arguments
    it's given; this test pins the math at the runner boundary so a desync
    (caller passing inconsistent snapshots) shows up as a measurable peak
    divergence on the very same tick, without needing to run forward to the
    floor breach. The breach is downstream — the load-bearing witness is the
    peak value after a single [update] call. *)
let test_inconsistent_positions_cash_phantom_spikes_peak _ =
  let make_short ~symbol ~entry_price ~qty =
    _make_holding ~symbol ~side:Trading_base.Types.Short
      ~entry_date:(_date "2024-01-02") ~quantity:qty ~entry_price
  in
  let s1 = make_short ~symbol:"S1" ~entry_price:100.0 ~qty:1000.0 in
  let s2 = make_short ~symbol:"S2" ~entry_price:200.0 ~qty:500.0 in
  (* Both shorts profitable: current < entry. *)
  let bar_s1 = _make_bar ~date:(_date "2024-01-15") ~close:80.0 in
  let bar_s2 = _make_bar ~date:(_date "2024-01-15") ~close:180.0 in
  let get_price s =
    if String.equal s "S1" then Some bar_s1
    else if String.equal s "S2" then Some bar_s2
    else None
  in
  (* Pre-tick cash = $1.2M (post-entry: $1M starting + $100K S1 proceeds +
     $100K S2 proceeds).
     True portfolio_value:
       1_200_000 + (-80 * 1000) + (-180 * 500)
       = 1_200_000 - 80_000 - 90_000 = 1_030_000.
     S1's mtm magnitude (which the buggy desync adds back to the sum):
       current_price_S1 * quantity_S1 = 80 * 1000 = 80_000. *)
  let pre_tick_cash = 1_200_000.0 in
  let true_pv = 1_030_000.0 in
  let s1_mtm_magnitude = 80_000.0 in
  let recorder, _ = _capturing_recorder () in
  let positions_full = String.Map.of_alist_exn [ ("S1", s1); ("S2", s2) ] in
  let positions_buggy = String.Map.singleton "S2" s2 in
  let date = _date "2024-01-15" in
  (* Fixed path: consistent snapshot (full positions, pre-tick cash). *)
  let peak_fixed = FL.Peak_tracker.create () in
  let _ =
    Force_liquidation_runner.update ~config:FL.default_config
      ~positions:positions_full ~get_price ~cash:pre_tick_cash
      ~current_date:date ~peak_tracker:peak_fixed ~audit_recorder:recorder
  in
  assert_that (FL.Peak_tracker.peak peak_fixed) (float_equal true_pv);
  (* Buggy path: positions filtered as if S1 already removed, cash NOT yet
     debited for the buy-back — the exact desync the WIP G12 fix prevents at
     the call site. *)
  let peak_buggy = FL.Peak_tracker.create () in
  let _ =
    Force_liquidation_runner.update ~config:FL.default_config
      ~positions:positions_buggy ~get_price ~cash:pre_tick_cash
      ~current_date:date ~peak_tracker:peak_buggy ~audit_recorder:recorder
  in
  assert_that
    (FL.Peak_tracker.peak peak_buggy)
    (float_equal (true_pv +. s1_mtm_magnitude))

let suite =
  "force_liquidation_runner"
  >::: [
         "per_position_trigger_emits_exit"
         >:: test_per_position_trigger_emits_exit;
         "per_position_trigger_no_fire_under_threshold"
         >:: test_per_position_trigger_no_fire_under_threshold;
         "portfolio_floor_trigger_closes_all"
         >:: test_portfolio_floor_trigger_closes_all;
         "no_positions_no_events" >:: test_no_positions_no_events;
         "short_position_loss_fires" >:: test_short_position_loss_fires;
         "non-Holding position does not fire"
         >:: test_non_holding_position_does_not_fire;
         "missing price does not fire" >:: test_missing_price_does_not_fire;
         "double-exit avoidance filters already-exited"
         >:: test_double_exit_avoidance_filters_already_exited;
         "G9 — short holding does not inflate peak"
         >:: test_short_holding_does_not_inflate_peak;
         "G9 — two profitable shorts do not trigger portfolio_floor"
         >:: test_two_profitable_shorts_no_portfolio_floor;
         "G12 — inconsistent (positions, cash) phantom-spikes peak"
         >:: test_inconsistent_positions_cash_phantom_spikes_peak;
       ]

let () = run_test_tt_main suite
