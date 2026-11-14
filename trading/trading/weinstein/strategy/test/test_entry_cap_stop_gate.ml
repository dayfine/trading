(** Pins [entry_cap_stop_gate_on_uncapped] ({!Entry_cap_stop_gate}): with the
    stale-entry cap lowering a long's trigger [E] to [E′], the stop-width
    decisions read [E] while the price, the installed stop and the size follow
    [E′].

    Fixture: one shallow-pullback series whose support-floor stop sits near 91
    whatever the entry. Two tickets the cap lowered:
    - [_wide]: [E] = 115, [E′] = 105. The floor is ~21 % below [E] and ~13 %
      below [E′], so it decides admission (the record skips it, the cap admits
      it).
    - [_in_band]: [E] = 105, [E′] = 98. The floor is within 15 % of both. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position

let _ticker = "CAPD"
let _other = "NARW"
let _current_date = Date.of_string "2024-06-14"

(* Peak 108, correction low 95 (oldest first, one bar per Friday). *)
let _hlc =
  [
    (104.0, 100.0, 103.0);
    (108.0, 103.0, 106.0);
    (106.0, 98.0, 100.0);
    (102.0, 95.0, 97.0);
    (100.0, 96.0, 99.0);
    (103.0, 98.0, 101.0);
    (105.0, 99.0, 103.0);
  ]

let _bars =
  let n = List.length _hlc in
  List.mapi _hlc ~f:(fun i (high, low, close) : Types.Daily_price.t ->
      {
        date = Date.add_days _current_date (-7 * (n - 1 - i));
        open_price = close;
        high_price = high;
        low_price = low;
        close_price = close;
        adjusted_close = close;
        volume = 1_000_000;
        active_through = None;
      })

let _reader () =
  Bar_reader.of_in_memory_bars [ (_ticker, _bars); (_other, _bars) ]

let _base_config =
  Weinstein_strategy_config.default_config ~universe:[ _ticker; _other ]
    ~index_symbol:"SPY"

let _buffer = _base_config.screening_config.candidate_params.entry_buffer_pct

(* The record's E-family entry and investor stop gate, with the cap at 4. *)
let _config ?(cap_weeks = 4) ~gate () =
  {
    _base_config with
    enable_sim_entry_stoplimit = true;
    sim_entry_trigger_at_suggested = true;
    stop_anchor_at_entry_base = true;
    require_structural_stop = true;
    entry_cap_local_range_weeks = cap_weeks;
    entry_cap_stop_gate_on_uncapped = gate;
  }

let _stage : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false };
    ma_value = 90.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 3;
  }

(* A long as the screener builds it: [local_range_top = Some t] is the cap's
   level ([Local_range_top] arm), [None] the uncapped [Breakout] arm. *)
let _candidate ?(ticker = _ticker) ?(side = Trading_base.Types.Long) ~breakout
    ~cap () : Screener.scored_candidate =
  let entry =
    Screener.suggested_entry ~entry_buffer_pct:_buffer
      (Option.value cap ~default:breakout)
  in
  {
    ticker;
    analysis =
      {
        ticker;
        stage = _stage;
        rs = None;
        volume = None;
        resistance = None;
        support = None;
        breakout_price = Some breakout;
        breakdown_price = None;
        local_range_top = cap;
        prior_stage = None;
        continuation = None;
        supply = None;
        virgin_readmission = false;
        range_top_freshness = None;
        require_breakout_volume = true;
        current_close = None;
        as_of_date = _current_date;
      };
    sector = { sector_name = "Test"; rating = Neutral; stage = _stage.stage };
    side;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = entry;
    suggested_stop = entry *. 0.92;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [ "fixture" ];
  }

let _wide ?(capped = true) () =
  _candidate ~breakout:114.43 ~cap:(if capped then Some 104.48 else None) ()

let _in_band ?(capped = true) () =
  _candidate ~breakout:104.48 ~cap:(if capped then Some 97.51 else None) ()

(* The walk's entries as (entry price, quantity), and the installed stop. *)
let _walk ~config cand =
  let stop_states = ref String.Map.empty in
  let entries =
    Entry_walk.entries_from_candidates ~config ~candidates:[ cand ] ~stop_states
      ~bar_reader:(_reader ())
      ~portfolio:
        {
          Trading_strategy.Portfolio_view.cash = 1_000_000.0;
          positions = String.Map.empty;
        }
      ~get_price:(fun _ -> None)
      ~current_date:_current_date ()
    |> List.filter_map ~f:(fun (t : Position.transition) ->
        match t.kind with
        | Position.CreateEntering e -> Some (e.entry_price, e.target_quantity)
        | _ -> None)
  in
  let stop =
    Map.find !stop_states _ticker
    |> Option.map ~f:Weinstein_stops.get_stop_level
  in
  (entries, stop)

(* One ticket, direct, so the result names the gate that fired. *)
let _attempt ?gate_entry ~require_structural_stop cand =
  Entry_audit_capture.make_entry_transition ~trigger_at_suggested:true
    ~stop_anchor_at_entry_base:true ~require_structural_stop ?gate_entry
    ~portfolio_risk_config:_base_config.portfolio_config
    ~stops_config:_base_config.stops_config ~initial_stop_buffer:1.0
    ~stop_states:(ref String.Map.empty) ~bar_reader:(_reader ())
    ~portfolio_value:1_000_000.0 ~current_date:_current_date cand

let _no_structural_stop_kind = function
  | Entry_audit_capture.No_structural_stop d -> Some d.floor_kind
  | _ -> None

let _entry_ok = function
  | Entry_audit_capture.Entry_ok (_, meta) -> Some meta
  | _ -> None

let test_gate_entry_is_uncapped_trigger _ =
  assert_that
    (Entry_cap_stop_gate.gate_entry ~config:(_config ~gate:true ()) (_wide ()))
    (is_some_and (float_equal 115.0))

let test_gate_entry_none_unless_applies _ =
  let gate ?(config = _config ~gate:true ()) cand =
    Entry_cap_stop_gate.gate_entry ~config cand
  in
  let no_trigger =
    { (_config ~gate:true ()) with sim_entry_trigger_at_suggested = false }
  in
  assert_that
    [
      gate ~config:(_config ~gate:false ()) (_wide ());
      gate ~config:(_config ~cap_weeks:0 ~gate:true ()) (_wide ());
      gate ~config:no_trigger (_wide ());
      gate (_wide ~capped:false ());
      gate
        (_candidate ~side:Trading_base.Types.Short ~breakout:114.43
           ~cap:(Some 104.48) ());
    ]
    (each is_none)

(** (a) Flag off is today: the cap admits [_wide] at [E′] = 105, a name the
    record skips. *)
let test_flag_off_cap_admits _ =
  assert_that
    (fst (_walk ~config:(_config ~gate:false ()) (_wide ())))
    (elements_are [ pair (float_equal 105.0) __ ])

(** (b) Flag on: [_wide] is skipped, as the cap-off ticket is, and for the same
    reason ([No_structural_stop] on a re-anchored buffer stop). *)
let test_flag_on_skips_as_cap_off _ =
  assert_that (fst (_walk ~config:(_config ~gate:true ()) (_wide ()))) is_empty;
  assert_that
    (fst
       (_walk
          ~config:(_config ~cap_weeks:0 ~gate:false ())
          (_wide ~capped:false ())))
    is_empty;
  assert_that
    (_attempt ~gate_entry:115.0 ~require_structural_stop:true (_wide ()))
    (matching _no_structural_stop_kind
       (equal_to
          (Audit_recorder.Buffer_fallback : Audit_recorder.stop_floor_kind)))

(** (c) Flag on, floor within 15 % of [E]: placed at [E′] = 98 with the cap-off
    ticket's floor stop, sized from [E′] minus that stop. *)
let test_flag_on_places_at_capped_trigger _ =
  let _, floor_stop =
    _walk
      ~config:(_config ~cap_weeks:0 ~gate:false ())
      (_in_band ~capped:false ())
  in
  let floor_stop = Option.value_exn floor_stop in
  let shares =
    (Portfolio_risk.compute_position_size ~config:_base_config.portfolio_config
       ~portfolio_value:1_000_000.0 ~side:`Long ~entry_price:98.0
       ~stop_price:floor_stop ())
      .shares
  in
  assert_that
    (_walk ~config:(_config ~gate:true ()) (_in_band ()))
    (pair
       (elements_are
          [ pair (float_equal 98.0) (float_equal (Float.of_int shares)) ])
       (is_some_and (float_equal floor_stop)))

(** (d) Flag on with the cap off does nothing. *)
let test_flag_on_cap_off_is_noop _ =
  let walk gate = _walk ~config:(_config ~cap_weeks:0 ~gate ()) (_wide ()) in
  assert_that (walk true) (equal_to (walk false))

(** (e) A ticket the cap did not lower is unchanged by the flag. *)
let test_uncapped_ticket_unchanged _ =
  let walk gate =
    _walk ~config:(_config ~gate ()) (_in_band ~capped:false ())
  in
  assert_that (walk true) (equal_to (walk false));
  assert_that (fst (walk true)) (elements_are [ pair (float_equal 105.0) __ ])

(** A re-anchored buffer stop kept without [require_structural_stop] sits below
    [E′], the ticket's own entry, not below [E]. *)
let test_kept_reanchored_stop_below_capped_trigger _ =
  let buffer_below_capped =
    Weinstein_stops.compute_initial_stop ~config:_base_config.stops_config
      ~side:Long ~reference_level:105.0
    |> Weinstein_stops.get_stop_level
  in
  assert_that
    (_attempt ~gate_entry:115.0 ~require_structural_stop:false (_wide ()))
    (matching _entry_ok
       (all_of
          [
            field
              (fun (m : Entry_audit_capture.entry_meta) -> m.installed_stop)
              (float_equal buffer_below_capped);
            field
              (fun (m : Entry_audit_capture.entry_meta) -> m.stop_floor_kind)
              (equal_to
                 (Audit_recorder.Buffer_fallback
                   : Audit_recorder.stop_floor_kind));
          ]))

(** The [Demote_over_max] pass reads the same entry as the gate: with the
    re-anchor off, [_wide] is wide from [E] and narrow from [E′]. *)
let test_demote_order_reads_uncapped_trigger _ =
  let order gate =
    let config =
      {
        (_config ~gate ()) with
        stop_anchor_at_entry_base = false;
        stop_width_mode = Stop_width_mode.Demote_over_max;
      }
    in
    Entry_stop_width_order.prefer_narrow_stops ~config ~bar_reader:(_reader ())
      ~current_date:_current_date
      [ _wide (); _candidate ~ticker:_other ~breakout:97.51 ~cap:None () ]
    |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)
  in
  assert_that (order false) (equal_to [ _ticker; _other ]);
  assert_that (order true) (equal_to [ _other; _ticker ])

let _raises config =
  try
    Entry_cap_stop_gate.validate config;
    false
  with Failure _ -> true

let test_validate _ =
  let armed = _config ~gate:true () in
  assert_that
    [
      _raises _base_config;
      _raises armed;
      _raises { armed with entry_anchor_local_range_weeks = 13 };
      _raises { armed with freeze_entry_at_first_breakout = true };
      _raises
        {
          (_config ~cap_weeks:0 ~gate:true ()) with
          entry_anchor_local_range_weeks = 13;
        };
    ]
    (equal_to [ false; false; true; true; false ])

let suite =
  "entry_cap_stop_gate"
  >::: [
         "gate entry is the uncapped trigger"
         >:: test_gate_entry_is_uncapped_trigger;
         "gate entry none unless the flag applies"
         >:: test_gate_entry_none_unless_applies;
         "flag off: the cap admits" >:: test_flag_off_cap_admits;
         "flag on: skipped as with the cap off"
         >:: test_flag_on_skips_as_cap_off;
         "flag on: placed at the capped trigger"
         >:: test_flag_on_places_at_capped_trigger;
         "flag on, cap off: no-op" >:: test_flag_on_cap_off_is_noop;
         "uncapped ticket unchanged" >:: test_uncapped_ticket_unchanged;
         "kept re-anchored stop below the capped trigger"
         >:: test_kept_reanchored_stop_below_capped_trigger;
         "demote order reads the uncapped trigger"
         >:: test_demote_order_reads_uncapped_trigger;
         "validate" >:: test_validate;
       ]

let () = run_test_tt_main suite
