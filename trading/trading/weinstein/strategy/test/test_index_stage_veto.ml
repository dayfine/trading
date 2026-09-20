(** [Weinstein_strategy.config.index_stage_veto_blocks_longs] — the default-off
    long-entry veto on a primary index in Stage 4.

    The gate rule itself ({!Screener.longs_admitted_by_index_stage}) and its
    effect on a screener-lib [config] are pinned in
    [analysis/weinstein/screener/test/test_index_stage_veto_gate.ml]. This file
    pins the four things only the strategy can show:

    - the top-level config field survives a sexp round-trip under its own name
      and defaults to [false] when absent, which is what makes it a
      [Variant_matrix] axis {!Backtest.Overlay_validator} can resolve (R2),
    - the {b fresh}-candidate half of the strategy→cascade thread — a symbol the
      cascade admits from a {!Weinstein_strategy.config} stops being admitted
      when the flag is armed under a Stage-4 index, which is the behaviour the
      pre-registered experiment reads,
    - the F2 {b resting-ticket} re-screen asks the same question, so a resting
      long ticket is cancelled under a Stage-4 index rather than quietly
      surviving a tape that rejects every fresh candidate, and
    - the short side is untouched by the long-side veto.

    Driven through
    {!Weinstein_strategy.Weinstein_strategy_macro.run_screen_after_macro}, which
    takes the [Macro.result] as an argument — the only seam at which a [Bullish]
    trend can be paired with a Stage-4 index, which is the 2022 configuration
    the flag exists for ([dev/experiments/pit-universe-2026-09-14/README.md]
    §"Drawdown dissection"). Mirrors [test_deteriorating_blocks_longs.ml]. *)

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

(** A macro result whose composite reads {b Bullish} while the index itself
    carries [index_stage]. That pairing is the whole point: [Macro.analyze]
    weighs the index stage at 3.0 of 10.0, so a [confidence > 0.65] composite
    can stay [Bullish] with the index below a falling 30-week MA — which it did
    for most of 2022. Nothing but the new veto separates the two arms below;
    [trend] is held at [Bullish] so the three-state gate always admits. *)
let _macro_with ~(index_stage : Weinstein_types.stage) : Macro.result =
  {
    index_stage =
      {
        stage = index_stage;
        ma_value = 100.0;
        ma_direction = Weinstein_types.Declining;
        ma_slope_pct = -0.01;
        transition = None;
        above_ma_count = 0;
      };
    indicators = [];
    trend = Weinstein_types.Bullish;
    breadth_state = Weinstein_types.Bullish_breadth;
    confidence = 0.8;
    regime_changed = false;
    rationale = [];
  }

let _stage4 = Weinstein_types.Stage4 { weeks_declining = 9 }
let _stage3 = Weinstein_types.Stage3 { weeks_topping = 6 }
let _stage2 = Weinstein_types.Stage2 { weeks_advancing = 8; late = false }

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
            reasoning = ManualDecision { description = "index-stage veto test" };
          };
    }
  |> _unwrap

let _positions ps =
  List.map ps ~f:(fun (p : Position.t) -> (p.id, p)) |> String.Map.of_alist_exn

let _config ?(index_stage_veto_blocks_longs = false)
    ?(neutral_blocks_shorts = true) ?(index_symbol = _index_symbol) ~universe ()
    =
  {
    (Weinstein_strategy_config.default_config ~universe ~index_symbol) with
    index_stage_veto_blocks_longs;
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
    ~fold_start_date:None ~universe_membership_at:None ~config
    ~stop_states:(ref String.Map.empty)
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

let _long_ticket_cancelled_in ?index_stage_veto_blocks_longs index_stage =
  _cancelled_ids
    ~config:
      (_config ?index_stage_veto_blocks_longs ~universe:[ _long_symbol ] ())
    ~macro_result:(_macro_with ~index_stage)
    ~positions:
      (_positions
         [
           _resting_ticket ~id:"L1" ~symbol:_long_symbol
             ~side:Trading_base.Types.Long;
         ])

(* ------------------------------------------------------------------ *)
(* Fresh-candidate fixture                                              *)
(*                                                                      *)
(* The F2 helpers above reach the gate through the resting-ticket       *)
(* re-screen. A ticket's symbol is held, so it is never in the          *)
(* cascade's candidate list — a fresh, unheld symbol the cascade        *)
(* actually admits is the only way to exercise the other half of the    *)
(* thread. Lifted from [test_deteriorating_blocks_longs.ml], whose      *)
(* sibling flag is wired at the same two seams.                         *)
(* ------------------------------------------------------------------ *)

let _fresh_symbol = "FRESHY"
let _fresh_index_symbol = "FRESHX"

(* Weinstein's Stage-1 base into a volume breakout, at the shape
   [Synthetic_source.Breakout] generates — rebuilt here rather than reused so
   the series can be anchored to [_friday], putting the breakout a fixed number
   of weeks before the screen. Six advancing weeks is the minimum that clears
   the stage gate from a cold start: [Stage.default_config.confirm_weeks = 6]
   needs at least five of the last six weekly closes above the MA before
   [_infer_initial_stage] will call it Stage 2. *)
let _base_price = 150.0
let _base_noise_pct = 0.02
let _base_volume = 1_000_000
let _breakout_volume_mult = 3
let _breakout_start_factor = 1.05
let _daily_gain = 1.004 (* ≈ 2% per five-day week *)
let _advance_weeks = 6
let _history_weeks = 52
let _bars_per_week = 5
let _flat_index_price = 4500.0
let _noise_period = 10

(** The [n] weekdays ending at [last], oldest first. *)
let _weekdays_ending_at last n =
  let prev d =
    match Date.day_of_week d with
    | Day_of_week.Sun -> Date.add_days d (-2)
    | Day_of_week.Mon -> Date.add_days d (-3)
    | _ -> Date.add_days d (-1)
  in
  let rec back d k acc =
    if k = 0 then acc else back (prev d) (k - 1) (d :: acc)
  in
  back last n []

let _fresh_dates = _weekdays_ending_at _friday (_history_weeks * _bars_per_week)

(** One basing bar: a ±[_base_noise_pct] oscillation around [_base_price], which
    keeps every base high below the breakout level. *)
let _basing_bar ~date ~i =
  let phase = Float.of_int (i % _noise_period) /. Float.of_int _noise_period in
  let offset =
    _base_price *. _base_noise_pct *. Float.sin (phase *. 2.0 *. Float.pi)
  in
  _daily_bar ~date ~price:(_base_price +. offset)

(** One advancing bar, [k] bars into the breakout. The first week carries
    [_breakout_volume_mult]× volume so
    [Stock_analysis.config.breakout_event_lookback] finds a peak-volume week
    whose ratio against the base clears [Volume]'s adequate threshold. *)
let _advancing_bar ~date ~k =
  let price =
    _base_price *. _breakout_start_factor *. (_daily_gain ** Float.of_int k)
  in
  let bar = _daily_bar ~date ~price in
  if k < _bars_per_week then
    { bar with volume = _base_volume * _breakout_volume_mult }
  else { bar with volume = _base_volume }

let _fresh_bars =
  let advance_start = (_history_weeks - _advance_weeks) * _bars_per_week in
  List.mapi _fresh_dates ~f:(fun i date ->
      if i < advance_start then
        { (_basing_bar ~date ~i) with volume = _base_volume }
      else _advancing_bar ~date ~k:(i - advance_start))

(* A flat benchmark. Mansfield RS then reads [_fresh_symbol]'s own shape — a
   flat base lifting into an advance — which is comfortably above its own
   moving average, clearing [min_rs_normalized = 0.0]. *)
let _flat_index_bars =
  List.map _fresh_dates ~f:(fun date ->
      _daily_bar ~date ~price:_flat_index_price)

let _fresh_bar_reader =
  Bar_reader.of_in_memory_bars
    [ (_fresh_index_symbol, _flat_index_bars); (_fresh_symbol, _fresh_bars) ]

let _fresh_index_view =
  Bar_reader.weekly_view_for _fresh_bar_reader ~symbol:_fresh_index_symbol ~n:52
    ~as_of:_friday

let _fresh_last_bar = List.last _fresh_bars

let _fresh_get_price symbol =
  if String.equal symbol _fresh_symbol then _fresh_last_bar else None

(** One real Friday screen over an {b empty} portfolio, so the candidate is
    unheld and goes through the whole cascade. Returns the symbols entry tickets
    were opened on. *)
let _fresh_entry_symbols ~index_stage_veto_blocks_longs index_stage =
  WSM.run_screen_after_macro ~pending_entry_e:(Entry_freeze.create ())
    ~fold_start_date:None ~universe_membership_at:None
    ~config:
      (_config ~index_stage_veto_blocks_longs ~index_symbol:_fresh_index_symbol
         ~universe:[ _fresh_symbol ] ())
    ~stop_states:(ref String.Map.empty)
    ~last_stop_out_dates:(Hashtbl.create (module String))
    ~bar_reader:_fresh_bar_reader
    ~prior_stages:(Hashtbl.create (module String))
    ~sector_prior_stages:(Hashtbl.create (module String))
    ~ticker_sectors:(Hashtbl.create (module String))
    ~get_price:_fresh_get_price
    ~portfolio:{ cash = 100_000.0; positions = String.Map.empty }
    ~current_date:_friday ~index_view:_fresh_index_view
    ~audit_recorder:Audit_recorder.noop ~macro_result:(_macro_with ~index_stage)
  |> List.filter_map ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CreateEntering { symbol; _ } -> Some symbol
      | _ -> None)

(* ------------------------------------------------------------------ *)
(* R1 / R2 — flag discipline                                            *)
(* ------------------------------------------------------------------ *)

(** R1 ([.claude/rules/experiment-flag-discipline.md]): the shipped default is
    the no-op, so merging the mechanism moves no golden. Asserted on the real
    [default_config] rather than a literal, which is what a default flip would
    have to change. *)
let test_the_shipped_default_is_off _ =
  assert_that
    (Weinstein_strategy_config.default_config ~universe:[]
       ~index_symbol:_index_symbol)
      .index_stage_veto_blocks_longs
    (equal_to false)

let _sexp_value_of_field config name =
  match Weinstein_strategy_config.sexp_of_config config with
  | Sexp.List fields ->
      List.find_map fields ~f:(function
        | Sexp.List [ Sexp.Atom key; Sexp.Atom value ]
          when String.equal key name ->
            Some value
        | _ -> None)
  | Sexp.Atom _ -> None

(** R2: the flag is a real [config] field, so [Overlay_validator] resolves it
    and [((flag index_stage_veto_blocks_longs))] expands as a [Variant_matrix]
    axis. Pinned on the sexp round-trip the validator's deep merge reads — a
    field that failed to serialise under its own name would make the axis
    unusable while every behavioural test below still passed. *)
let test_the_flag_round_trips_under_its_own_sexp_key _ =
  assert_that
    (List.map [ false; true ] ~f:(fun on ->
         _sexp_value_of_field
           { (_config ~universe:[] ()) with index_stage_veto_blocks_longs = on }
           "index_stage_veto_blocks_longs"))
    (elements_are
       [ is_some_and (equal_to "false"); is_some_and (equal_to "true") ])

(** Backward compatibility: a config sexp written before this field existed
    still parses, and reads [false]. Built by deleting the field from a real
    serialised config, which is exactly the shape every committed scenario spec
    and golden has. *)
let test_a_sexp_without_the_field_parses_as_off _ =
  let without_field =
    match
      Weinstein_strategy_config.sexp_of_config (_config ~universe:[] ())
    with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom key :: _) ->
                not (String.equal key "index_stage_veto_blocks_longs")
            | _ -> true))
    | other -> other
  in
  assert_that
    (Weinstein_strategy_config.config_of_sexp without_field)
      .index_stage_veto_blocks_longs (equal_to false)

(* ------------------------------------------------------------------ *)
(* F2 — the resting-ticket re-screen                                    *)
(* ------------------------------------------------------------------ *)

(** The wiring claim at the F2 seam, on the configuration the flag exists for: a
    [Bullish] composite over a Stage-4 index. Same tape, same ticket, only the
    flag differs. The symbol is in a five-year uptrend, so the stage half of the
    re-screen keeps admitting it — the cancel can only come from the macro half.

    EFFECTIVENESS-PIN: dropping the {!Long_entry_macro_gate}
    [longs_admitted_by_index_stage] conjunct, or reverting
    [_macro_admits_side]'s [Long] branch to [Screener.longs_admitted_by_breadth]
    alone, leaves the flag-on arm uncancelled and this assertion red. *)
let test_a_resting_long_ticket_is_cancelled_under_a_stage4_index _ =
  assert_that
    [
      _long_ticket_cancelled_in ~index_stage_veto_blocks_longs:false _stage4;
      _long_ticket_cancelled_in ~index_stage_veto_blocks_longs:true _stage4;
    ]
    (elements_are [ is_empty; elements_are [ equal_to "L1" ] ])

(** Narrowness at the F2 site: with the flag ON, a ticket resting on the same
    symbol survives every non-Stage-4 index. [Stage3] is the load-bearing one —
    the book calls an index top caution, not a suspension. *)
let test_only_a_stage4_index_cancels_when_the_flag_is_on _ =
  assert_that
    (List.map [ _stage2; _stage3 ]
       ~f:(_long_ticket_cancelled_in ~index_stage_veto_blocks_longs:true))
    (elements_are [ is_empty; is_empty ])

(** Shorts are untouched. [neutral_blocks_shorts] is irrelevant here because the
    trend is [Bullish], which blocks shorts outright — so the short arm is run
    on a [Bearish] trend where shorts are admitted, and the long flag is shown
    to leave the resting short ticket alone under a Stage-4 index. *)
let test_a_resting_short_ticket_is_untouched_by_the_long_veto _ =
  let bearish_with_stage4 =
    { (_macro_with ~index_stage:_stage4) with trend = Weinstein_types.Bearish }
  in
  let cancelled_with index_stage_veto_blocks_longs =
    _cancelled_ids
      ~config:
        (_config ~index_stage_veto_blocks_longs ~neutral_blocks_shorts:false
           ~universe:[ _short_symbol ] ())
      ~macro_result:bearish_with_stage4
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

(* ------------------------------------------------------------------ *)
(* The cascade's fresh-candidate gate                                   *)
(* ------------------------------------------------------------------ *)

(** The other half of the wiring claim — "flag on + Stage-4 index = zero long
    entries", read from a {!Weinstein_strategy.config} rather than from inside
    the screener lib, and on a [Bullish] composite, which is the 2022
    configuration the mechanism exists for.

    EFFECTIVENESS-PIN: index_stage_veto_blocks_longs (fresh candidates) — this
    assertion goes red if either half of the strategy→cascade thread is severed:
    deleting
    [Screener.index_stage_veto_blocks_longs =
     config.index_stage_veto_blocks_longs] from [_run_screener] (the flag never
    reaches the screener config), or dropping
    [~index_stage:macro_result.Macro.index_stage.Stage.stage] from its
    [screen_with_cooldown] call (the cascade never sees the index stage). Both
    were live mutations that survived a full root [dune runtest] while the F2
    tests above were the only coverage — the same gap issue #2755's PR closed
    for the sibling flag, recurring here.

    [_fresh_symbol] is unheld, so unlike a resting ticket it goes through the
    full cascade: price floor, sector gate, breakout setup, volume confirmation,
    RS, score floor. Only the flag differs between the two arms. *)
let test_a_fresh_stage2_candidate_is_rejected_under_a_stage4_index _ =
  assert_that
    [
      _fresh_entry_symbols ~index_stage_veto_blocks_longs:false _stage4;
      _fresh_entry_symbols ~index_stage_veto_blocks_longs:true _stage4;
    ]
    (elements_are [ elements_are [ equal_to _fresh_symbol ]; is_empty ])

(** Narrowness at the cascade site, mirroring
    {!test_only_a_stage4_index_cancels_when_the_flag_is_on} at the F2 site: with
    the flag ON, a fresh candidate is still admitted under every non-Stage-4
    index. [Stage3] is the load-bearing one — [weinstein-book-reference.md] §2.1
    "Resolved 2026-09-16" reads an index top as caution, not a suspension. *)
let test_a_fresh_candidate_survives_a_stage3_index_when_the_flag_is_on _ =
  assert_that
    (List.map [ _stage2; _stage3 ]
       ~f:(_fresh_entry_symbols ~index_stage_veto_blocks_longs:true))
    (elements_are
       [
         elements_are [ equal_to _fresh_symbol ];
         elements_are [ equal_to _fresh_symbol ];
       ])

let suite =
  "index_stage_veto_blocks_longs"
  >::: [
         "the shipped default is off" >:: test_the_shipped_default_is_off;
         "the flag round-trips under its own sexp key"
         >:: test_the_flag_round_trips_under_its_own_sexp_key;
         "a sexp without the field parses as off"
         >:: test_a_sexp_without_the_field_parses_as_off;
         "a resting long ticket is cancelled under a Stage4 index"
         >:: test_a_resting_long_ticket_is_cancelled_under_a_stage4_index;
         "only a Stage4 index cancels when the flag is on"
         >:: test_only_a_stage4_index_cancels_when_the_flag_is_on;
         "a resting short ticket is untouched by the long veto"
         >:: test_a_resting_short_ticket_is_untouched_by_the_long_veto;
         "a fresh Stage2 candidate is rejected under a Stage4 index"
         >:: test_a_fresh_stage2_candidate_is_rejected_under_a_stage4_index;
         "a fresh candidate survives a Stage3 index when the flag is on"
         >:: test_a_fresh_candidate_survives_a_stage3_index_when_the_flag_is_on;
       ]

let () = run_test_tt_main suite
