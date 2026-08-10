open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                             *)
(* ------------------------------------------------------------------ *)

(** Minimal [Screener.scored_candidate] — [Entry_freeze.apply] only reads
    [ticker] and [suggested_entry], but the record must be fully populated.
    Long-side stub; the freeze logic is side-agnostic. *)
let make_candidate ?(side = Trading_base.Types.Long) ~ticker ~entry () =
  let open Weinstein_types in
  let stub_stage : Stage.result =
    {
      stage = Stage2 { weeks_advancing = 3; late = false };
      ma_value = entry *. 0.9;
      ma_direction = Rising;
      ma_slope_pct = 0.02;
      transition = None;
      above_ma_count = 3;
    }
  in
  let stub_analysis : Stock_analysis.t =
    {
      ticker;
      stage = stub_stage;
      rs = None;
      volume = None;
      breakout_price = Some entry;
      breakdown_price = None;
      local_range_top = None;
      resistance = None;
      support = None;
      prior_stage = Some (Stage1 { weeks_in_base = 10 });
      continuation = None;
      supply = None;
      virgin_readmission = false;
      range_top_freshness = None;
      require_breakout_volume = true;
      current_close = None;
      as_of_date = Date.of_string "2000-01-21";
    }
  in
  let stub_sector : Screener.sector_context =
    {
      sector_name = "Tech";
      rating = Neutral;
      stage = stub_analysis.stage.stage;
    }
  in
  {
    Screener.ticker;
    analysis = stub_analysis;
    sector = stub_sector;
    side;
    grade = Weinstein_types.A;
    score = 70;
    suggested_entry = entry;
    suggested_stop = entry *. 0.95;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "test" ];
  }

let entry_of (c : Screener.scored_candidate) = c.suggested_entry

let make_bar date price =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = price;
    high_price = price *. 1.02;
    low_price = price *. 0.98;
    close_price = price;
    adjusted_close = price;
    volume = 1000;
    active_through = None;
  }

(* ------------------------------------------------------------------ *)
(* Entry_freeze.apply — pin / release logic                            *)
(* ------------------------------------------------------------------ *)

(** OFF path: with the flag off, a symbol whose recomputed [E] rises weekly is
    returned with its current (rising) [E] every week — the weekly recompute is
    untouched and the pin table is never populated. *)
let test_off_path_leaves_rising_e_unchanged _ =
  let pending = Entry_freeze.create () in
  let held_set = String.Set.empty in
  let apply candidates =
    Entry_freeze.apply ~enabled:false ~pending ~held_set ~candidates
  in
  let wk1 = apply [ make_candidate ~ticker:"BDLN" ~entry:50.0 () ] in
  let wk2 = apply [ make_candidate ~ticker:"BDLN" ~entry:55.0 () ] in
  assert_that
    (List.map (wk1 @ wk2) ~f:entry_of)
    (elements_are [ float_equal 50.0; float_equal 55.0 ])

(** ON path: once a symbol qualifies, its [E] is pinned; a later week whose
    recomputed [E] has floated up reuses the FIRST-qualifying [E] (no chase). *)
let test_on_path_freezes_to_first_e _ =
  let pending = Entry_freeze.create () in
  let held_set = String.Set.empty in
  let apply candidates =
    Entry_freeze.apply ~enabled:true ~pending ~held_set ~candidates
  in
  let _wk1 = apply [ make_candidate ~ticker:"BDLN" ~entry:50.0 () ] in
  let wk2 = apply [ make_candidate ~ticker:"BDLN" ~entry:79.81 () ] in
  assert_that (List.map wk2 ~f:entry_of) (elements_are [ float_equal 50.0 ])

(** Release-on-expiry: a symbol that drops out of the candidate list while not
    held is released, so a later re-qualification earns a FRESH [E] (not the
    stale first pin). *)
let test_release_on_dropout_repins_fresh _ =
  let pending = Entry_freeze.create () in
  let apply ?(held_set = String.Set.empty) candidates =
    Entry_freeze.apply ~enabled:true ~pending ~held_set ~candidates
  in
  let _wk1 = apply [ make_candidate ~ticker:"AAA" ~entry:50.0 () ] in
  let _wk2 =
    apply []
    (* AAA drops out, not held -> pin released *)
  in
  let wk3 = apply [ make_candidate ~ticker:"AAA" ~entry:60.0 () ] in
  assert_that (List.map wk3 ~f:entry_of) (elements_are [ float_equal 60.0 ])

(** Release-on-round-trip: while a symbol is held (order resting / position
    open) its pin persists (dormant — held symbols are excluded from the walk);
    once it closes and no longer qualifies the pin is released, so the next
    setup re-pins fresh. *)
let test_pin_persists_while_held_then_repins _ =
  let pending = Entry_freeze.create () in
  let apply ?(held_set = String.Set.empty) candidates =
    Entry_freeze.apply ~enabled:true ~pending ~held_set ~candidates
  in
  let _wk1 = apply [ make_candidate ~ticker:"BBB" ~entry:50.0 () ] in
  (* Held: no candidate, but the position is open -> pin retained. *)
  let _wk2 = apply ~held_set:(String.Set.of_list [ "BBB" ]) [] in
  (* Closed: no longer held, still not qualifying -> pin released. *)
  let _wk3 = apply [] in
  let wk4 = apply [ make_candidate ~ticker:"BBB" ~entry:70.0 () ] in
  assert_that (List.map wk4 ~f:entry_of) (elements_are [ float_equal 70.0 ])

(** Discriminating held-persistence: wk1 pins E=50; wk2 the symbol is HELD and
    not a candidate — the [held_set] guard must RETAIN the pin; wk3 it
    re-qualifies (no longer held) at a chased E=70 — the emitted E must be the
    retained 50.0. Fails if the [not (Set.mem held_set sym)] clause in
    [_release_stale] is removed (wk2 would release, wk3 would re-pin at 70). *)
let test_held_guard_retains_pin_across_dormancy _ =
  let pending = Entry_freeze.create () in
  let apply ?(held_set = String.Set.empty) candidates =
    Entry_freeze.apply ~enabled:true ~pending ~held_set ~candidates
  in
  let _wk1 = apply [ make_candidate ~ticker:"DDD" ~entry:50.0 () ] in
  (* Held, not qualifying: only the held guard keeps the pin alive. *)
  let _wk2 = apply ~held_set:(String.Set.of_list [ "DDD" ]) [] in
  let wk3 = apply [ make_candidate ~ticker:"DDD" ~entry:70.0 () ] in
  assert_that (List.map wk3 ~f:entry_of) (elements_are [ float_equal 50.0 ])

(** Short-side symmetry: a short candidate's breakdown level is pinned the same
    way — a later LOWER recomputed level reuses the first pin (no chasing the
    breakdown down). *)
let test_short_side_pins_symmetrically _ =
  let pending = Entry_freeze.create () in
  let held_set = String.Set.empty in
  let apply candidates =
    Entry_freeze.apply ~enabled:true ~pending ~held_set ~candidates
  in
  let short = make_candidate ~side:Trading_base.Types.Short in
  let _wk1 = apply [ short ~ticker:"SSS" ~entry:50.0 () ] in
  let wk2 = apply [ short ~ticker:"SSS" ~entry:40.0 () ] in
  assert_that (List.map wk2 ~f:entry_of) (elements_are [ float_equal 50.0 ])

(** Distinct symbols pin independently: freezing one does not affect another. *)
let test_independent_pins_per_symbol _ =
  let pending = Entry_freeze.create () in
  let held_set = String.Set.empty in
  let apply candidates =
    Entry_freeze.apply ~enabled:true ~pending ~held_set ~candidates
  in
  let _wk1 = apply [ make_candidate ~ticker:"AAA" ~entry:50.0 () ] in
  let wk2 =
    apply
      [
        make_candidate ~ticker:"AAA" ~entry:60.0 ();
        make_candidate ~ticker:"CCC" ~entry:30.0 ();
      ]
  in
  assert_that (List.map wk2 ~f:entry_of)
    (elements_are [ float_equal 50.0; float_equal 30.0 ])

(* ------------------------------------------------------------------ *)
(* Integration: frozen E flows into the emitted entry price            *)
(* ------------------------------------------------------------------ *)

let entry_prices_of transitions =
  List.filter_map transitions
    ~f:(fun (t : Trading_strategy.Position.transition) ->
      match t.kind with
      | Trading_strategy.Position.CreateEntering { entry_price; _ } ->
          Some entry_price
      | _ -> None)

(** Run BDLN through [entries_from_candidates] twice (week-1 [E] = 50, week-2
    chased [E] = 79.81) sharing one [pending_entry_e] table, with the E-anchored
    fill family armed so the emitted [CreateEntering.entry_price] equals the
    effective entry [E]. Returns week-2's emitted entry prices. *)
let two_week_wk2_entry ~freeze =
  let cfg =
    {
      (default_config ~universe:[ "BDLN" ] ~index_symbol:"GSPCX") with
      freeze_entry_at_first_breakout = freeze;
      sim_entry_trigger_at_suggested = true;
      enable_sim_entry_stoplimit = true;
    }
  in
  let pending_entry_e = Entry_freeze.create () in
  let bar_reader = Bar_reader.empty () in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 1_000_000.0; positions = String.Map.empty }
  in
  let run ~entry =
    let stop_states = ref String.Map.empty in
    let get_price = fun _ -> Some (make_bar "2000-01-21" entry) in
    entries_from_candidates ~pending_entry_e ~config:cfg
      ~candidates:[ make_candidate ~ticker:"BDLN" ~entry () ]
      ~stop_states ~bar_reader ~portfolio ~get_price
      ~current_date:(Date.of_string "2000-01-21")
      ()
  in
  let _wk1 = run ~entry:50.0 in
  entry_prices_of (run ~entry:79.81)

(** Freeze ON: week 2's chased [E] (79.81) is overridden by the pinned first [E]
    (50.0), so the emitted ticket rests at the frozen breakout, not the
    extension. *)
let test_frozen_e_flows_to_entry_price _ =
  assert_that
    (two_week_wk2_entry ~freeze:true)
    (elements_are [ float_equal 50.0 ])

(** Control (freeze OFF): the same sequence emits at the chased week-2 [E],
    proving the frozen result above is the freeze doing the work, not a harness
    artifact. *)
let test_off_path_emits_chased_e _ =
  assert_that
    (two_week_wk2_entry ~freeze:false)
    (elements_are [ float_equal 79.81 ])

let suite =
  "entry_freeze"
  >::: [
         "off path leaves rising E unchanged"
         >:: test_off_path_leaves_rising_e_unchanged;
         "on path freezes to first E" >:: test_on_path_freezes_to_first_e;
         "release on dropout re-pins fresh"
         >:: test_release_on_dropout_repins_fresh;
         "pin persists while held then re-pins"
         >:: test_pin_persists_while_held_then_repins;
         "held guard retains pin across dormancy"
         >:: test_held_guard_retains_pin_across_dormancy;
         "short side pins symmetrically" >:: test_short_side_pins_symmetrically;
         "independent pins per symbol" >:: test_independent_pins_per_symbol;
         "frozen E flows to entry price" >:: test_frozen_e_flows_to_entry_price;
         "off path emits chased E" >:: test_off_path_emits_chased_e;
       ]

let () = run_test_tt_main suite
