(** #2976 — [config.entry_ticket_macro_suspend]: suspend (not cancel) resting
    long entry tickets while the macro gate rejects new longs, re-issue them
    unchanged when it admits again. Book authority: Ch. 8, "Suspend buying even
    if you see a few stocks breaking out on their charts"
    ([docs/design/weinstein-book-reference.md] §2.1).

    Two layers are pinned:
    - {!Entry_ticket_suspend} directly — which tape suspends under each mode,
      the withdraw / stash / re-issue cycle, that the re-issued order is the
      withdrawn one (same symbol, side, quantity, entry level, reasoning, stop
      plan), that suspension time counts toward the TTL clock, and that an F2
      cancel wins over a suspension.
    - The simulator, end to end: with the flag [Off] a resting ticket fills on
      the cross even though that week reads Bearish (today's behaviour, R1);
      with it on the same cross does NOT fill, and the re-issued ticket fills
      after the gate re-admits, at a price inside the same [E]-anchored band. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module Mode = Entry_ticket_suspend_mode

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

let _index_symbol = "GSPCX"
let _friday = Date.of_string "2024-04-26"
let _week = 7
let _long_symbol = "AAA"
let _short_symbol = "SSS"
let _reasoning = Position.ManualDecision { description = "suspend test" }

let _initial_stop =
  Weinstein_stops.Initial { stop_level = 92.0; reference_level = 92.0 }

let _stage2 = Weinstein_types.Stage2 { weeks_advancing = 8; late = false }
let _stage4 = Weinstein_types.Stage4 { weeks_declining = 9 }

let _unwrap = function
  | Ok p -> p
  | Error err -> assert_failure ("position setup failed: " ^ Status.show err)

(** A resting [Entering] ticket — wholly unfilled unless [filled] books a
    partial fill of that many shares. *)
let _entering ?(side = Trading_base.Types.Long) ?(filled = 0.0) ~id ~symbol
    ~created () =
  let trans kind : Position.transition =
    { position_id = id; date = created; kind }
  in
  let pos =
    Position.create_entering
      (trans
         (Position.CreateEntering
            {
              symbol;
              side;
              target_quantity = 10.0;
              entry_price = 100.0;
              reasoning = _reasoning;
            }))
    |> _unwrap
  in
  if Float.equal filled 0.0 then pos
  else
    Position.apply_transition pos
      (trans
         (Position.EntryFill { filled_quantity = filled; fill_price = 100.0 }))
    |> _unwrap

let _positions ps =
  List.map ps ~f:(fun (p : Position.t) -> (p.id, p)) |> String.Map.of_alist_exn

(** A macro read whose composite [trend] and primary-index stage are set
    independently — the pairing that separates the two armed modes. *)
let _macro ~(trend : Weinstein_types.market_trend)
    ~(index_stage : Weinstein_types.stage) : Macro.result =
  {
    index_stage =
      {
        stage = index_stage;
        ma_value = 100.0;
        ma_direction = Weinstein_types.Flat;
        ma_slope_pct = 0.0;
        transition = None;
        above_ma_count = 0;
      };
    indicators = [];
    trend;
    breadth_state = Weinstein_types.breadth_state_of_market_trend trend;
    confidence = 0.5;
    regime_changed = false;
    rationale = [];
  }

let _bearish = _macro ~trend:Weinstein_types.Bearish ~index_stage:_stage2
let _bullish = _macro ~trend:Weinstein_types.Bullish ~index_stage:_stage2

let _config ?(max_rest_weeks = 0) mode =
  {
    (Weinstein_strategy_config.default_config ~universe:[ _long_symbol ]
       ~index_symbol:_index_symbol)
    with
    entry_ticket_macro_suspend = mode;
    entry_order_max_rest_weeks = max_rest_weeks;
  }

let _no_cancels _ = []

let _run ?(cancel_expired = _no_cancels) ?(stop_states = ref String.Map.empty)
    ?pending_entry_e ?audit_recorder ~store ~config ~macro_result ~positions
    ~date () =
  Entry_ticket_suspend.run ~store ?pending_entry_e ?audit_recorder ~config
    ~macro_result ~stop_states
    ~portfolio:{ cash = 100_000.0; positions = _positions positions }
    ~current_date:date ~cancel_expired ()

let _suspension_of id : Position.transition =
  {
    position_id = id;
    date = _friday;
    kind = Position.CancelEntry { reason = Entry_ticket_suspend.cancel_reason };
  }

let _reissue_kind =
  Position.CreateEntering
    {
      symbol = _long_symbol;
      side = Trading_base.Types.Long;
      target_quantity = 10.0;
      entry_price = 100.0;
      reasoning = _reasoning;
    }

let _created_date (pos : Position.t) =
  match Position.get_state pos with
  | Position.Entering e -> Some e.created_date
  | Position.Holding _ | Position.Exiting _ | Position.Closed _ -> None

(* ------------------------------------------------------------------ *)
(* Which tape suspends                                                  *)
(* ------------------------------------------------------------------ *)

(** Five (mode, trend, index stage) cells. [Off] never suspends, even on the
    worst tape. [On_bearish_macro] follows the composite. [On_index_stage4]
    ignores a [Bearish] composite while the index is not in Stage 4, and
    suspends on a Stage-4 index even under a [Bullish] composite — the 2022
    shape, where the composite stayed Bullish with the S&P below a falling MA.
*)
let test_suspends_by_mode _ =
  let reads mode ~trend ~index_stage =
    Entry_ticket_suspend.suspends ~config:(_config mode)
      ~macro_result:(_macro ~trend ~index_stage)
  in
  assert_that
    [
      reads Mode.Off ~trend:Weinstein_types.Bearish ~index_stage:_stage4;
      reads Mode.On_bearish_macro ~trend:Weinstein_types.Bearish
        ~index_stage:_stage2;
      reads Mode.On_bearish_macro ~trend:Weinstein_types.Bullish
        ~index_stage:_stage2;
      reads Mode.On_index_stage4 ~trend:Weinstein_types.Bearish
        ~index_stage:_stage2;
      reads Mode.On_index_stage4 ~trend:Weinstein_types.Bullish
        ~index_stage:_stage4;
    ]
    (equal_to [ false; true; false; false; true ])

(* ------------------------------------------------------------------ *)
(* R1: Off is exactly the F2 callback                                   *)
(* ------------------------------------------------------------------ *)

(** With the flag off a resting long in a Bearish week is neither withdrawn nor
    stashed — the next (Bullish) week re-issues nothing either. The only
    transitions are whatever the F2 callback returned ([[]] here). *)
let test_off_leaves_resting_ticket_alone _ =
  let store = Entry_ticket_suspend.create () in
  let config = _config Mode.Off in
  let long =
    _entering ~id:"L1" ~symbol:_long_symbol
      ~created:(Date.add_days _friday (-_week))
      ()
  in
  let week1 =
    _run ~store ~config ~macro_result:_bearish ~positions:[ long ] ~date:_friday
      ()
  in
  let week2 =
    _run ~store ~config ~macro_result:_bullish ~positions:[ long ]
      ~date:(Date.add_days _friday _week)
      ()
  in
  assert_that [ week1; week2 ]
    (elements_are [ pair is_empty is_empty; pair is_empty is_empty ])

(* ------------------------------------------------------------------ *)
(* On: withdraw, then re-issue unchanged                                *)
(* ------------------------------------------------------------------ *)

(** Bearish week: the resting LONG is withdrawn with the suspension reason and
    its symbol is reported held; the resting SHORT is untouched (longs only).
    Bullish week (the long's position is gone, as the simulator closes it): the
    ticket comes back as a [CreateEntering] with identical parameters under a
    fresh id, its stop plan is re-installed after being clobbered, and the new
    id reads its ORIGINAL placement date for the TTL clock. *)
let test_on_suspends_then_reissues_unchanged _ =
  let store = Entry_ticket_suspend.create () in
  let config = _config Mode.On_bearish_macro in
  let placed = Date.add_days _friday (-_week) in
  let stop_states = ref (String.Map.singleton _long_symbol _initial_stop) in
  let long = _entering ~id:"L1" ~symbol:_long_symbol ~created:placed () in
  let short =
    _entering ~side:Trading_base.Types.Short ~id:"S1" ~symbol:_short_symbol
      ~created:placed ()
  in
  let week1 =
    _run ~store ~config ~stop_states ~macro_result:_bearish
      ~positions:[ long; short ] ~date:_friday ()
  in
  stop_states := Map.remove !stop_states _long_symbol;
  let week2_date = Date.add_days _friday _week in
  let week2_transitions, week2_held =
    _run ~store ~config ~stop_states ~macro_result:_bullish ~positions:[ short ]
      ~date:week2_date ()
  in
  let reissued_positions =
    List.map week2_transitions ~f:(fun t ->
        _unwrap (Position.create_entering t))
  in
  let aged =
    Entry_ticket_suspend.aged_portfolio store
      { cash = 0.0; positions = _positions reissued_positions }
  in
  assert_that week1
    (pair
       (elements_are [ equal_to (_suspension_of "L1") ])
       (elements_are [ equal_to _long_symbol ]));
  assert_that week2_transitions
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Position.transition) -> t.kind)
               (equal_to _reissue_kind);
             field
               (fun (t : Position.transition) -> t.date)
               (equal_to week2_date);
             field
               (fun (t : Position.transition) ->
                 String.is_prefix t.position_id ~prefix:"AAA-wein-")
               (equal_to true);
           ];
       ]);
  assert_that week2_held (elements_are [ equal_to _long_symbol ]);
  assert_that
    (Map.find !stop_states _long_symbol)
    (is_some_and (equal_to _initial_stop));
  assert_that (Map.data aged.positions)
    (elements_are [ field _created_date (is_some_and (equal_to placed)) ])

(** A second Bearish week after the withdrawal re-issues nothing and keeps the
    symbol held — the ticket sleeps for as long as the gate rejects. *)
let test_on_keeps_ticket_suspended_while_gate_rejects _ =
  let store = Entry_ticket_suspend.create () in
  let config = _config Mode.On_bearish_macro in
  let long =
    _entering ~id:"L1" ~symbol:_long_symbol
      ~created:(Date.add_days _friday (-_week))
      ()
  in
  let (_ : Position.transition list * string list) =
    _run ~store ~config ~macro_result:_bearish ~positions:[ long ] ~date:_friday
      ()
  in
  assert_that
    (_run ~store ~config ~macro_result:_bearish ~positions:[]
       ~date:(Date.add_days _friday _week)
       ())
    (pair is_empty (elements_are [ equal_to _long_symbol ]))

(* ------------------------------------------------------------------ *)
(* TTL: suspension time counts toward the clock                         *)
(* ------------------------------------------------------------------ *)

(** Clock of 4 weeks, ticket placed 3 weeks before it is suspended. Re-admitted
    one week later (age 4, within the clock) it is re-issued; re-admitted two
    weeks later (age 5) it is dropped instead — the weeks it slept count. *)
let test_ttl_expires_a_suspended_ticket _ =
  let reissued_at ~weeks_later =
    let store = Entry_ticket_suspend.create () in
    let config = _config ~max_rest_weeks:4 Mode.On_bearish_macro in
    let long =
      _entering ~id:"L1" ~symbol:_long_symbol
        ~created:(Date.add_days _friday (-3 * _week))
        ()
    in
    let (_ : Position.transition list * string list) =
      _run ~store ~config ~macro_result:_bearish ~positions:[ long ]
        ~date:_friday ()
    in
    _run ~store ~config ~macro_result:_bullish ~positions:[]
      ~date:(Date.add_days _friday (weeks_later * _week))
      ()
    |> fst
    |> List.map ~f:(fun (t : Position.transition) -> t.kind)
  in
  assert_that
    [ reissued_at ~weeks_later:1; reissued_at ~weeks_later:2 ]
    (elements_are [ elements_are [ equal_to _reissue_kind ]; is_empty ])

(** An F2 cancel (TTL / re-screen) of the same ticket wins: the ticket is
    retired once, not also suspended — a second [CancelEntry] on an already
    closed position would be an invalid transition. *)
let test_f2_cancel_wins_over_suspension _ =
  let store = Entry_ticket_suspend.create () in
  let ttl_cancel : Position.transition =
    {
      position_id = "L1";
      date = _friday;
      kind = Position.CancelEntry { reason = "entry_ticket_ttl_expired" };
    }
  in
  let long =
    _entering ~id:"L1" ~symbol:_long_symbol
      ~created:(Date.add_days _friday (-_week))
      ()
  in
  assert_that
    (_run
       ~cancel_expired:(fun _ -> [ ttl_cancel ])
       ~store
       ~config:(_config Mode.On_bearish_macro)
       ~macro_result:_bearish ~positions:[ long ] ~date:_friday ())
    (pair (elements_are [ equal_to ttl_cancel ]) is_empty)

(* ------------------------------------------------------------------ *)
(* Guards: partial fills, held-elsewhere, pin release, clock wiring     *)
(* ------------------------------------------------------------------ *)

(** A partially filled long [Entering] has booked shares, so a suspending tape
    leaves it alone: no withdrawal, nothing stashed, nothing held. A wholly
    unfilled ticket on the same tape is the control that does get withdrawn.

    MUTATION: weakening [_resting_long]'s unfilled-only guard
    ([Float.equal e.filled_quantity 0.0]) lets the partial fill through and
    turns the first element red. *)
let test_partial_fill_is_not_suspended _ =
  let suspend_of ~filled =
    _run
      ~store:(Entry_ticket_suspend.create ())
      ~config:(_config Mode.On_bearish_macro)
      ~macro_result:_bearish
      ~positions:
        [
          _entering ~filled ~id:"L1" ~symbol:_long_symbol
            ~created:(Date.add_days _friday (-_week))
            ();
        ]
      ~date:_friday ()
  in
  assert_that
    [ suspend_of ~filled:4.0; suspend_of ~filled:0.0 ]
    (elements_are
       [
         pair is_empty is_empty;
         pair
           (elements_are [ equal_to (_suspension_of "L1") ])
           (elements_are [ equal_to _long_symbol ]);
       ])

(** Minimal long [Screener.scored_candidate] for probing the {!Entry_freeze} pin
    table — [Entry_freeze.apply] reads only [ticker] and [suggested_entry], but
    the record must be fully populated. *)
let _candidate ~entry : Screener.scored_candidate =
  let stage : Stage.result =
    {
      stage = _stage2;
      ma_value = entry *. 0.9;
      ma_direction = Weinstein_types.Rising;
      ma_slope_pct = 0.02;
      transition = None;
      above_ma_count = 3;
    }
  in
  let analysis : Stock_analysis.t =
    {
      ticker = _long_symbol;
      stage;
      rs = None;
      volume = None;
      breakout_price = Some entry;
      breakdown_price = None;
      local_range_top = None;
      resistance = None;
      support = None;
      prior_stage = None;
      continuation = None;
      supply = None;
      virgin_readmission = false;
      range_top_freshness = None;
      require_breakout_volume = true;
      current_close = None;
      as_of_date = _friday;
    }
  in
  {
    ticker = _long_symbol;
    analysis;
    sector =
      { sector_name = "Tech"; rating = Screener.Neutral; stage = stage.stage };
    side = Trading_base.Types.Long;
    grade = Weinstein_types.A;
    score = 70;
    suggested_entry = entry;
    suggested_stop = entry *. 0.95;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "suspend test" ];
  }

let _pinned_entry = 100.0
let _probe_entry = 130.0

(** A pin table holding [_long_symbol] at [_pinned_entry]. *)
let _pinned () =
  let pins = Entry_freeze.create () in
  let (_ : Screener.scored_candidate list) =
    Entry_freeze.apply ~enabled:true ~pending:pins
      ~held_set:(String.Set.singleton _long_symbol)
      ~candidates:[ _candidate ~entry:_pinned_entry ]
  in
  pins

(** The [E] a re-qualifying [_long_symbol] would carry: [_pinned_entry] while
    the pin survives, the fresh [_probe_entry] once it has been released. *)
let _entry_after_requalifying pins =
  Entry_freeze.apply ~enabled:true ~pending:pins
    ~held_set:(String.Set.singleton _long_symbol)
    ~candidates:[ _candidate ~entry:_probe_entry ]
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.suggested_entry)

(** Clock of 4 weeks, ticket placed 3 weeks before it is suspended, with a
    no-chase pin on its symbol. Re-admitted one week later (within the clock) it
    is re-issued and the pin is kept; two weeks later (past the clock) the
    stashed ticket is dropped AND its pin is released, so a later
    re-qualification earns a fresh [E].

    MUTATION: removing [Entry_freeze.release] from [_drop] leaves the expired
    arm reading [_pinned_entry] and turns the second element red. *)
let test_expired_stash_releases_its_entry_pin _ =
  let entry_after ~weeks_later =
    let store = Entry_ticket_suspend.create () in
    let pending_entry_e = _pinned () in
    let config = _config ~max_rest_weeks:4 Mode.On_bearish_macro in
    let long =
      _entering ~id:"L1" ~symbol:_long_symbol
        ~created:(Date.add_days _friday (-3 * _week))
        ()
    in
    let (_ : Position.transition list * string list) =
      _run ~pending_entry_e ~store ~config ~macro_result:_bearish
        ~positions:[ long ] ~date:_friday ()
    in
    let (_ : Position.transition list * string list) =
      _run ~pending_entry_e ~store ~config ~macro_result:_bullish ~positions:[]
        ~date:(Date.add_days _friday (weeks_later * _week))
        ()
    in
    _entry_after_requalifying pending_entry_e
  in
  assert_that
    [ entry_after ~weeks_later:1; entry_after ~weeks_later:2 ]
    (elements_are
       [
         elements_are [ float_equal _pinned_entry ];
         elements_are [ float_equal _probe_entry ];
       ])

(** A stashed long whose symbol is held by another open position at re-issue
    time (here a short entered during the suspension) is dropped, not re-issued
    — and not deferred either: the next admitting week, with the short gone,
    re-issues nothing. The drop releases the ticket's no-chase pin.

    MUTATION: forcing [_held_elsewhere] to [false] re-issues the long beside the
    short and turns the week-2 transitions red. *)
let test_stash_held_elsewhere_is_dropped _ =
  let store = Entry_ticket_suspend.create () in
  let pending_entry_e = _pinned () in
  let config = _config Mode.On_bearish_macro in
  let long =
    _entering ~id:"L1" ~symbol:_long_symbol
      ~created:(Date.add_days _friday (-_week))
      ()
  in
  let short =
    _entering ~side:Trading_base.Types.Short ~id:"S2" ~symbol:_long_symbol
      ~created:_friday ()
  in
  let run_week ~weeks_later ~macro_result ~positions =
    _run ~pending_entry_e ~store ~config ~macro_result ~positions
      ~date:(Date.add_days _friday (weeks_later * _week))
      ()
    |> fst
  in
  let week1 =
    run_week ~weeks_later:0 ~macro_result:_bearish ~positions:[ long ]
  in
  let week2 =
    run_week ~weeks_later:1 ~macro_result:_bullish ~positions:[ short ]
  in
  let week3 = run_week ~weeks_later:2 ~macro_result:_bullish ~positions:[] in
  assert_that
    (week1, week2, week3, _entry_after_requalifying pending_entry_e)
    (all_of
       [
         field
           (fun (w1, _, _, _) -> w1)
           (elements_are [ equal_to (_suspension_of "L1") ]);
         field (fun (_, w2, _, _) -> w2) is_empty;
         field (fun (_, _, w3, _) -> w3) is_empty;
         field
           (fun (_, _, _, e) -> e)
           (elements_are [ float_equal _probe_entry ]);
       ])

(** The positions a week's re-issues open, as the simulator would hold them. *)
let _opened (transitions : Position.transition list) =
  List.filter_map transitions ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CreateEntering _ -> Some (_unwrap (Position.create_entering t))
      | _ -> None)

(** The real F2 clock ({!Entry_ticket_ttl.run}, clock only) as the screening
    module wires it into [cancel_expired]. *)
let _clock ~max_rest_weeks ~current_date
    (portfolio : Trading_strategy.Portfolio_view.t) =
  Entry_ticket_ttl.run ~rescreen:false ~max_rest_weeks
    ~pending_entry_e:(Entry_freeze.create ()) ~positions:portfolio.positions
    ~still_qualifies:(fun ~symbol:_ ~side:_ -> true)
    ~current_date

(** Two full suspend / re-issue cycles under a 6-week clock, then the real F2
    clock on the twice-re-issued ticket. Placed 3 weeks before the first
    suspension: suspended at age 3, re-issued at 4, suspended again at 5,
    re-issued again at 6 (still within the clock). One week later — age 7 from
    the ORIGINAL placement, but only 1 week from the latest re-issue — the clock
    cancels it. So suspension time counts toward [entry_order_max_rest_weeks]
    both while stashed and once resting again, across every cycle.

    MUTATIONS: handing [cancel_expired] the raw portfolio instead of
    [aged_portfolio] (the clock then reads the re-issue date, age 1), or
    re-basing [origin_date] on the latest re-issue (age 3), each leave the
    ticket alive and turn the final assertion red. *)
let test_reissued_ticket_expires_on_its_original_clock _ =
  let store = Entry_ticket_suspend.create () in
  let max_rest_weeks = 6 in
  let config = _config ~max_rest_weeks Mode.On_bearish_macro in
  let week n = Date.add_days _friday (n * _week) in
  let step ~n ~macro_result ~positions =
    let current_date = week n in
    _run
      ~cancel_expired:(_clock ~max_rest_weeks ~current_date)
      ~store ~config ~macro_result ~positions ~date:current_date ()
    |> fst
  in
  let placed =
    _entering ~id:"L1" ~symbol:_long_symbol ~created:(week (-3)) ()
  in
  let (_ : Position.transition list) =
    step ~n:0 ~macro_result:_bearish ~positions:[ placed ]
  in
  let first = _opened (step ~n:1 ~macro_result:_bullish ~positions:[]) in
  let (_ : Position.transition list) =
    step ~n:2 ~macro_result:_bearish ~positions:first
  in
  let second = _opened (step ~n:3 ~macro_result:_bullish ~positions:[]) in
  let expiring = step ~n:4 ~macro_result:_bullish ~positions:second in
  assert_that (first, second, expiring)
    (all_of
       [
         field (fun (f, _, _) -> f) (size_is 1);
         field (fun (_, s, _) -> s) (size_is 1);
         field
           (fun (_, _, e) -> e)
           (elements_are
              [
                field
                  (fun (t : Position.transition) -> t.kind)
                  (equal_to
                     (Position.CancelEntry
                        { reason = "entry_ticket_ttl_expired" }));
              ]);
       ])

(* ------------------------------------------------------------------ *)
(* #2989: the audit link from a re-issue back to its first placement    *)
(* ------------------------------------------------------------------ *)

(** Two suspend / re-issue cycles of one ticket placed as ["L1"], with a
    recorder capturing every {!Audit_recorder.reissue_event}. Returns the events
    in order and the ids of the positions the two re-issues opened. *)
let _reissue_events_over_two_cycles mode =
  let events = ref [] in
  let audit_recorder =
    {
      Audit_recorder.noop with
      record_reissue = (fun e -> events := e :: !events);
    }
  in
  let store = Entry_ticket_suspend.create () in
  let config = _config mode in
  let week n = Date.add_days _friday (n * _week) in
  let step ~n ~macro_result ~positions =
    _run ~audit_recorder ~store ~config ~macro_result ~positions ~date:(week n)
      ()
    |> fst |> _opened
  in
  let placed =
    _entering ~id:"L1" ~symbol:_long_symbol ~created:(week (-1)) ()
  in
  let (_ : Position.t list) =
    step ~n:0 ~macro_result:_bearish ~positions:[ placed ]
  in
  let first = step ~n:1 ~macro_result:_bullish ~positions:[] in
  let (_ : Position.t list) =
    step ~n:2 ~macro_result:_bearish ~positions:first
  in
  let second = step ~n:3 ~macro_result:_bullish ~positions:[] in
  (List.rev !events, List.map (first @ second) ~f:(fun (p : Position.t) -> p.id))

(** Every re-issue tells the recorder which placement it descends from, and it
    is always the FIRST one — ["L1"] — even for the second re-issue, whose
    withdrawn position was itself a re-issue. That is the join key the audit
    needs: ["L1"] is the only id the entry walk recorded an entry for. With the
    flag [Off] the recorder is never called.

    MUTATIONS: deleting the [record_reissue] call in [_reissue_one] empties the
    events (red); defaulting [origin_id] to the withdrawn position's own id
    instead of reading the [origins] table names the first re-issue as the
    second's original (red). *)
let test_reissue_event_names_the_first_placement _ =
  let week n = Date.add_days _friday (n * _week) in
  let events, ids = _reissue_events_over_two_cycles Mode.On_bearish_macro in
  let expected =
    List.map2_exn ids
      [ week 1; week 3 ]
      ~f:(fun id reissue_date ->
        ({
           reissued_position_id = id;
           original_position_id = "L1";
           reissue_date;
         }
          : Audit_recorder.reissue_event))
  in
  assert_that
    (ids, events, fst (_reissue_events_over_two_cycles Mode.Off))
    (all_of
       [
         field (fun (i, _, _) -> i) (size_is 2);
         field (fun (_, e, _) -> e) (equal_to expected);
         field (fun (_, _, off) -> off) is_empty;
       ])

(* ------------------------------------------------------------------ *)
(* Simulator, end to end                                                *)
(* ------------------------------------------------------------------ *)

let _sim_symbol = "AAPL"
let _sim_entry = 160.0
let _sim_cap_pct = 15.0

let _bar ~date ~open_price ~high ~low ~close =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(** Below [E = 160] until 01-05, which trades through it (high 165); the
    re-issued ticket's cross is 01-09 (high 166). The tape reads Bearish from
    01-03 through 01-05 and Bullish again from 01-08. *)
let _sim_bars =
  [
    _bar ~date:"2024-01-02" ~open_price:150.0 ~high:152.0 ~low:149.0
      ~close:151.0;
    _bar ~date:"2024-01-03" ~open_price:151.0 ~high:153.0 ~low:150.0
      ~close:152.0;
    _bar ~date:"2024-01-04" ~open_price:152.0 ~high:154.0 ~low:151.0
      ~close:153.0;
    _bar ~date:"2024-01-05" ~open_price:153.0 ~high:165.0 ~low:152.0
      ~close:155.0;
    _bar ~date:"2024-01-08" ~open_price:154.0 ~high:156.0 ~low:153.0
      ~close:155.0;
    _bar ~date:"2024-01-09" ~open_price:158.0 ~high:166.0 ~low:157.0
      ~close:163.0;
  ]

let _bearish_from = Date.of_string "2024-01-03"
let _bullish_from = Date.of_string "2024-01-08"

(** The smallest strategy that exercises the production module: one long ticket
    on its first call, then {!Entry_ticket_suspend.run} on every call against a
    scripted tape. The F2 callback is empty, so every withdrawal and re-issue is
    this module's. *)
module Scripted_suspend_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : Entry_ticket_suspend_mode.t -> unit
end = struct
  let name = "ScriptedSuspend"
  let emitted = ref false
  let store = ref (Entry_ticket_suspend.create ())
  let mode = ref Mode.Off

  let reset m =
    emitted := false;
    store := Entry_ticket_suspend.create ();
    mode := m

  let _macro_on date =
    if Date.( >= ) date _bearish_from && Date.( < ) date _bullish_from then
      _bearish
    else _bullish

  let _first_entry ~date : Position.transition list =
    if !emitted then []
    else (
      emitted := true;
      [
        {
          position_id = "AAPL-FIRST";
          date;
          kind =
            Position.CreateEntering
              {
                symbol = _sim_symbol;
                side = Trading_base.Types.Long;
                target_quantity = 10.0;
                entry_price = _sim_entry;
                reasoning = _reasoning;
              };
        };
      ])

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    match get_price _sim_symbol with
    | None -> Ok { Trading_strategy.Strategy_interface.transitions = [] }
    | Some (bar : Types.Daily_price.t) ->
        let transitions, _held =
          Entry_ticket_suspend.run ~store:!store
            ~config:{ (_config !mode) with universe = [ _sim_symbol ] }
            ~macro_result:(_macro_on bar.date)
            ~stop_states:(ref String.Map.empty) ~portfolio
            ~current_date:bar.date ~cancel_expired:_no_cancels ()
        in
        Ok
          {
            Trading_strategy.Strategy_interface.transitions =
              _first_entry ~date:bar.date @ transitions;
          }
end

let _write_bars ~data_dir bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) _sim_symbol with
  | Error e -> assert_failure ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> assert_failure ("csv save: " ^ Status.show e)
      | Ok () -> ())

let _sim_config =
  Trading_simulation.Simulator.
    {
      start_date = Date.of_string "2024-01-02";
      end_date = Date.of_string "2024-01-10";
      initial_cash = 100_000.0;
      commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
      strategy_cadence = Types.Cadence.Daily;
    }

(** Run the six-bar simulation under [mode] and return its steps. The
    simulator steps every calendar day in [start_date, end_date), so the
    01-06/01-07 weekend appears as two bar-less steps. *)
let _simulate mode =
  let data_dir = Core_unix.mkdtemp "/tmp/test_entry_ticket_suspend" in
  Fun.protect
    ~finally:(fun () ->
      let (_ : Core_unix.Exit_or_signal.t) =
        Core_unix.system (Printf.sprintf "rm -rf %s" data_dir)
      in
      ())
    (fun () ->
      _write_bars ~data_dir _sim_bars;
      Scripted_suspend_strategy.reset mode;
      let deps =
        Trading_simulation.Simulator.create_deps ~symbols:[ _sim_symbol ]
          ~data_dir:(Fpath.v data_dir)
          ~strategy:(module Scripted_suspend_strategy)
          ~commission:_sim_config.commission
          ~entry_extension_max_pct:_sim_cap_pct ()
      in
      let sim =
        match Trading_simulation.Simulator.create ~config:_sim_config ~deps with
        | Ok s -> s
        | Error e -> assert_failure ("create failed: " ^ Status.show e)
      in
      match Trading_simulation.Simulator.run sim with
      | Error e -> assert_failure ("run failed: " ^ Status.show e)
      | Ok result -> result.steps)

let _fills_per_step steps =
  List.map steps ~f:(fun (step : Trading_simulation.Simulator.step_result) ->
      (Date.to_string step.date, List.length step.trades))

let _fill_prices steps =
  List.concat_map steps
    ~f:(fun (step : Trading_simulation.Simulator.step_result) ->
      List.map step.trades ~f:(fun (t : Trading_base.Types.trade) -> t.price))

let _in_band =
  is_between
    (module Float_ord)
    ~low:_sim_entry
    ~high:(_sim_entry *. (1.0 +. (_sim_cap_pct /. 100.0)))

(** R1 pin: flag [Off] — the ticket rests through the Bearish weeks and fills on
    the 01-05 cross, inside the Bearish stretch. This is the 14 %-of-fills shape
    #2976 measured. *)
let test_sim_off_fills_during_bearish_tape _ =
  let steps = _simulate Mode.Off in
  assert_that (_fills_per_step steps)
    (elements_are
       [
         equal_to ("2024-01-02", 0);
         equal_to ("2024-01-03", 0);
         equal_to ("2024-01-04", 0);
         equal_to ("2024-01-05", 1);
         equal_to ("2024-01-06", 0);
         equal_to ("2024-01-07", 0);
         equal_to ("2024-01-08", 0);
         equal_to ("2024-01-09", 0);
       ]);
  assert_that (_fill_prices steps) (elements_are [ _in_band ])

(** Flag on: the ticket is withdrawn on 01-03, so the 01-05 cross does NOT fill
    (the order really left the simulator — a strategy-side close alone would
    still have filled). It is re-issued on 01-08 when the tape re-admits and
    fills on the 01-09 cross, inside the same [E]-anchored band. *)
let test_sim_on_withholds_then_fills_after_readmission _ =
  let steps = _simulate Mode.On_bearish_macro in
  assert_that (_fills_per_step steps)
    (elements_are
       [
         equal_to ("2024-01-02", 0);
         equal_to ("2024-01-03", 0);
         equal_to ("2024-01-04", 0);
         equal_to ("2024-01-05", 0);
         equal_to ("2024-01-06", 0);
         equal_to ("2024-01-07", 0);
         equal_to ("2024-01-08", 0);
         equal_to ("2024-01-09", 1);
       ]);
  assert_that (_fill_prices steps) (elements_are [ _in_band ])

let () =
  run_test_tt_main
    ("entry_ticket_suspend"
    >::: [
           "suspends: per-mode tape table" >:: test_suspends_by_mode;
           "Off leaves a resting ticket alone (R1)"
           >:: test_off_leaves_resting_ticket_alone;
           "On: withdraw, then re-issue unchanged"
           >:: test_on_suspends_then_reissues_unchanged;
           "On: stays suspended while the gate rejects"
           >:: test_on_keeps_ticket_suspended_while_gate_rejects;
           "TTL still expires a suspended ticket"
           >:: test_ttl_expires_a_suspended_ticket;
           "F2 cancel wins over suspension"
           >:: test_f2_cancel_wins_over_suspension;
           "a partial fill is not suspended"
           >:: test_partial_fill_is_not_suspended;
           "an expired stash releases its entry pin"
           >:: test_expired_stash_releases_its_entry_pin;
           "a stash held elsewhere is dropped"
           >:: test_stash_held_elsewhere_is_dropped;
           "a re-issued ticket expires on its original clock"
           >:: test_reissued_ticket_expires_on_its_original_clock;
           "a re-issue event names the first placement"
           >:: test_reissue_event_names_the_first_placement;
           "sim: Off fills during a Bearish tape (R1 pin)"
           >:: test_sim_off_fills_during_bearish_tape;
           "sim: On withholds, then fills after re-admission"
           >:: test_sim_on_withholds_then_fills_after_readmission;
         ])
