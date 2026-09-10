(** [Weinstein_strategy.config.deteriorating_blocks_longs] — the default-off
    long-admission gate on a [Deteriorating] breadth tape (issue #2755).

    The gate rule itself ({!Screener.longs_admitted_by_breadth}) and its effect
    on {b fresh} candidates are pinned on real data in
    [analysis/weinstein/screener/test/test_screener_e2e.ml]. This file pins the
    two things only the strategy can show:

    - the top-level config field reaches the Friday screen (the "silent null"
      thread that {!Screener.deteriorating_blocks_longs} depends on), and
    - the F2 {b resting-ticket} re-screen asks the same question, so a ticket
      already resting on a symbol is cancelled under [Deteriorating] rather than
      quietly surviving a tape that rejects every fresh candidate.

    Driven through
    {!Weinstein_strategy.Weinstein_strategy_macro
     .run_screen_after_macro},
    which takes the [Macro.result] as an argument. That is the only seam at
    which a [Deteriorating] state is reachable:
    [Internal_for_test.on_market_close] is deliberately breadth-inert
    ([breadth_series = None]), so a macro result it computes can only ever carry
    the three-state projection — the same limitation
    [test_stop_buffer_by_state.ml] records for the sibling knob. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module WSM = Weinstein_strategy.Weinstein_strategy_macro

let _index_symbol = "GSPCX"
let _long_symbol = "LONGY"
let _short_symbol = "SHORTY"
let _friday = Date.of_string "2024-04-26"

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

let _daily_bar ~date ~price : Types.Daily_price.t =
  {
    date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through = None;
  }

let _daily_bars ~n ~start_price ~step =
  let start_date = Date.add_days _friday (-(n - 1)) in
  List.init n ~f:(fun i ->
      _daily_bar
        ~date:(Date.add_days start_date i)
        ~price:(start_price +. (Float.of_int i *. step)))

(* [_long_symbol] rises for five years (Stage 2 under a rising 30-week MA), so
   a resting LONG ticket on it survives the stage half of the F2 re-screen and
   only the macro half can cancel it. [_short_symbol] falls (Stage 4), the
   mirror for the short-side arm. *)
let _bar_reader =
  Bar_reader.of_in_memory_bars
    [
      (_index_symbol, _daily_bars ~n:260 ~start_price:100.0 ~step:1.0);
      (_long_symbol, _daily_bars ~n:260 ~start_price:200.0 ~step:1.0);
      (_short_symbol, _daily_bars ~n:260 ~start_price:400.0 ~step:(-1.0));
    ]

let _index_view =
  Bar_reader.weekly_view_for _bar_reader ~symbol:_index_symbol ~n:52
    ~as_of:_friday

(** A macro result in the given breadth state, with [trend] its projection — the
    invariant {!Macro.result} documents and {!Screener.screen_with_cooldown}
    requires of its two macro arguments. Only those two fields are read here. *)
let _macro_in ~(state : Weinstein_types.breadth_state) : Macro.result =
  {
    index_stage =
      {
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
        ma_value = 100.0;
        ma_direction = Weinstein_types.Rising;
        ma_slope_pct = 0.01;
        transition = None;
        above_ma_count = 8;
      };
    indicators = [];
    trend = Weinstein_types.market_trend_of_breadth_state state;
    breadth_state = state;
    confidence = 0.5;
    regime_changed = false;
    rationale = [];
  }

let _unwrap = function
  | Ok p -> p
  | Error err -> assert_failure ("position setup failed: " ^ Status.show err)

(** A resting (unfilled) [Entering] ticket — the F2 cancel's only candidate
    shape. *)
let _resting_ticket ~id ~symbol ~side =
  let created = Date.add_days _friday (-7) in
  Position.create_entering
    {
      position_id = id;
      date = created;
      kind =
        Position.CreateEntering
          {
            symbol;
            side;
            target_quantity = 10.0;
            entry_price = 100.0;
            reasoning = ManualDecision { description = "#2755 test" };
          };
    }
  |> _unwrap

let _positions ps =
  List.map ps ~f:(fun (p : Position.t) -> (p.id, p)) |> String.Map.of_alist_exn

let _config ?(deteriorating_blocks_longs = false)
    ?(neutral_blocks_shorts = true) ~universe () =
  {
    (Weinstein_strategy_config.default_config ~universe
       ~index_symbol:_index_symbol)
    with
    deteriorating_blocks_longs;
    neutral_blocks_shorts;
    (* Arms the F2 re-screen half only; the clock backstop stays unbounded so
       every cancel below is attributable to the re-screen, never to age. *)
    enable_entry_ticket_rescreen = true;
    entry_order_max_rest_weeks = 0;
  }

(** One real Friday screen with [macro_result], returning the ids of the tickets
    it cancelled. *)
let _cancelled_ids ~config ~macro_result ~positions =
  WSM.run_screen_after_macro ~pending_entry_e:(Entry_freeze.create ())
    ~fold_start_date:None ~config ~stop_states:(ref String.Map.empty)
    ~last_stop_out_dates:(Hashtbl.create (module String))
    ~bar_reader:_bar_reader
    ~prior_stages:(Hashtbl.create (module String))
    ~sector_prior_stages:(Hashtbl.create (module String))
    ~ticker_sectors:(Hashtbl.create (module String))
    ~get_price:(fun _ -> None)
    ~portfolio:{ cash = 100_000.0; positions }
    ~current_date:_friday ~index_view:_index_view
    ~audit_recorder:Audit_recorder.noop ~macro_result
  |> List.filter_map ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CancelEntry _ -> Some t.position_id
      | _ -> None)

let _long_ticket_cancelled_in ?deteriorating_blocks_longs state =
  _cancelled_ids
    ~config:(_config ?deteriorating_blocks_longs ~universe:[ _long_symbol ] ())
    ~macro_result:(_macro_in ~state)
    ~positions:
      (_positions
         [
           _resting_ticket ~id:"L1" ~symbol:_long_symbol
             ~side:Trading_base.Types.Long;
         ])

(* ------------------------------------------------------------------ *)
(* R1 — the default                                                     *)
(* ------------------------------------------------------------------ *)

(** R1 ([.claude/rules/experiment-flag-discipline.md]): the shipped default is
    the no-op, so merging the mechanism moves no golden. Asserted on the real
    [default_config] rather than a literal, which is what a default flip would
    have to change. *)
let test_the_shipped_default_is_off _ =
  assert_that
    (Weinstein_strategy_config.default_config ~universe:[]
       ~index_symbol:_index_symbol)
      .deteriorating_blocks_longs
    (equal_to false)

(** R2 ([.claude/rules/experiment-flag-discipline.md]): the flag is a real
    [config] field, so [Overlay_validator] resolves it and
    [((flag deteriorating_blocks_longs))] expands as a [Variant_matrix] axis.
    Pinned on the sexp round-trip the validator's deep merge reads — a field
    that failed to serialise under its own name would make the axis unusable
    while every behavioural test above still passed. *)
let _sexp_value_of_field config name =
  match Weinstein_strategy_config.sexp_of_config config with
  | Sexp.List fields ->
      List.find_map fields ~f:(function
        | Sexp.List [ Sexp.Atom key; Sexp.Atom value ]
          when String.equal key name ->
            Some value
        | _ -> None)
  | Sexp.Atom _ -> None

let test_the_flag_round_trips_under_its_own_sexp_key _ =
  assert_that
    (List.map [ false; true ] ~f:(fun on ->
         _sexp_value_of_field
           { (_config ~universe:[] ()) with deteriorating_blocks_longs = on }
           "deteriorating_blocks_longs"))
    (elements_are
       [ is_some_and (equal_to "false"); is_some_and (equal_to "true") ])

(* ------------------------------------------------------------------ *)
(* F2 — the resting-ticket re-screen                                    *)
(* ------------------------------------------------------------------ *)

(** The load-bearing wiring claim, and the {b effectiveness pin} for the
    config→screen thread.

    EFFECTIVENESS-PIN: deteriorating_blocks_longs — severing
    [Screener.deteriorating_blocks_longs = config.deteriorating_blocks_longs] in
    [_run_screener], or reverting [_macro_admits_side] to
    [longs_admitted_by_macro], leaves the flag-on arm below uncancelled and this
    assertion red. Both halves of the thread are covered because the F2
    predicate and the cascade read the same gate function.

    Discriminating on both axes at once: the same tape and the same ticket, and
    only the flag differs. The symbol is in a five-year uptrend, so the stage
    half of the re-screen keeps admitting it — the cancel can only come from the
    macro half. *)
let test_a_resting_long_ticket_is_cancelled_under_deteriorating _ =
  assert_that
    [
      _long_ticket_cancelled_in ~deteriorating_blocks_longs:false Deteriorating;
      _long_ticket_cancelled_in ~deteriorating_blocks_longs:true Deteriorating;
    ]
    (elements_are [ is_empty; elements_are [ equal_to "L1" ] ])

(** The narrowness claim at the F2 site: with the flag ON, a ticket resting on
    the same symbol survives every other admitting state — [Recovering] above
    all, which is the cohort {!neutral_blocks_longs} would have cancelled along
    with [Deteriorating]. [Bearish_breadth] cancels, but it did so before this
    flag existed. *)
let test_only_deteriorating_cancels_when_the_flag_is_on _ =
  assert_that
    (List.map
       [
         Weinstein_types.Recovering;
         Neutral_breadth;
         Bullish_breadth;
         Bearish_breadth;
       ]
       ~f:(_long_ticket_cancelled_in ~deteriorating_blocks_longs:true))
    (elements_are
       [ is_empty; is_empty; is_empty; elements_are [ equal_to "L1" ] ])

(** Shorts are untouched. [neutral_blocks_shorts] is forced [false] so the
    [Neutral] projection of [Deteriorating] admits shorts at all — otherwise the
    short ticket would be cancelled by that unrelated default and the arm would
    prove nothing. With shorts admitted, arming the long flag leaves the resting
    short ticket alone. *)
let test_a_resting_short_ticket_is_untouched_by_the_long_flag _ =
  let cancelled_with deteriorating_blocks_longs =
    _cancelled_ids
      ~config:
        (_config ~deteriorating_blocks_longs ~neutral_blocks_shorts:false
           ~universe:[ _short_symbol ] ())
      ~macro_result:(_macro_in ~state:Deteriorating)
      ~positions:
        (_positions
           [
             _resting_ticket ~id:"S1" ~symbol:_short_symbol
               ~side:Trading_base.Types.Short;
           ])
  in
  assert_that
    [ cancelled_with false; cancelled_with true ]
    (elements_are [ is_empty; is_empty ])

(** The documented inert-without-the-breadth-read contract at the strategy
    level: with [macro_config.breadth_direction] off — the default —
    [Macro.result.breadth_state] is exactly
    [breadth_state_of_market_trend trend], so the three reachable states leave
    an armed flag with nothing to fire on. Built through the real projection
    function so a change to what the three-state read projects onto moves this
    test with it. *)
let test_the_flag_is_inert_at_the_three_state_projections _ =
  assert_that
    (List.map [ Weinstein_types.Bullish; Neutral ] ~f:(fun trend ->
         _long_ticket_cancelled_in ~deteriorating_blocks_longs:true
           (Weinstein_types.breadth_state_of_market_trend trend)))
    (elements_are [ is_empty; is_empty ])

let suite =
  "deteriorating_blocks_longs"
  >::: [
         "the shipped default is off" >:: test_the_shipped_default_is_off;
         "the flag round-trips under its own sexp key"
         >:: test_the_flag_round_trips_under_its_own_sexp_key;
         "a resting long ticket is cancelled under Deteriorating"
         >:: test_a_resting_long_ticket_is_cancelled_under_deteriorating;
         "only Deteriorating cancels when the flag is on"
         >:: test_only_deteriorating_cancels_when_the_flag_is_on;
         "a resting short ticket is untouched by the long flag"
         >:: test_a_resting_short_ticket_is_untouched_by_the_long_flag;
         "the flag is inert at the three-state projections"
         >:: test_the_flag_is_inert_at_the_three_state_projections;
       ]

let () = run_test_tt_main suite
