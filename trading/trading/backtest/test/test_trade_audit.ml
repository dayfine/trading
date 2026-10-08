(** Unit tests for [Backtest.Trade_audit].

    Covers:
    - sexp round-trip on every record type
    - collector accumulates correctly across record_entry / record_exit
    - exits are dropped when no matching entry was recorded
    - get_audit_records returns position-id-sorted output
    - empty collector returns []
    - [record_transitions] (issue #2076): reason-only [external_exit] capture
      for [TriggerExit]s that never go through the strategy's own [record_exit]
      path (margin exits, and other [StrategySignal] exits) — enriched [exit_]
      always wins, no-entry transitions are dropped, and only [TriggerExit] (not
      [TriggerPartialExit]) is handled. *)

open OUnit2
open Core
open Matchers
module TA = Backtest.Trade_audit
module TL = Backtest.Ticket_lifecycle
module Position = Trading_strategy.Position

(* Builders --------------------------------------------------------------- *)

let _date d = Date.of_string d

(** Minimal but realistic [entry_decision] for round-trip + collector tests.

    Optional parameters allow per-test overrides without forcing every test to
    write a 30-field literal — keeps the assertions focused on the field(s) each
    test actually cares about. *)
let make_entry ?(symbol = "AAPL") ?(entry_date = _date "2024-01-15")
    ?(position_id = "AAPL-wein-1") ?(side = Trading_base.Types.Long)
    ?(macro_trend = Weinstein_types.Bullish) ?(macro_confidence = 0.72)
    ?(macro_indicators = [])
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false })
    ?(ma_direction = Weinstein_types.Rising) ?(ma_slope_pct = 0.018)
    ?(rs_trend = Some Weinstein_types.Positive_rising) ?(rs_value = Some 1.05)
    ?(volume_quality = Some (Weinstein_types.Strong 2.4))
    ?(volume_ratio = Some 2.4)
    ?(resistance_quality = Some Weinstein_types.Clean)
    ?(support_quality = Some Weinstein_types.Clean)
    ?(sector_name = "Information Technology") ?(sector_rating = Screener.Strong)
    ?(cascade_score = 75) ?(cascade_grade = Weinstein_types.A)
    ?(cascade_score_components =
      [
        ("stage2_breakout", 30);
        ("strong_volume", 20);
        ("positive_rs", 20);
        ("clean_resistance", 15);
        ("sector_strong", 10);
      ]) ?(cascade_rationale = [ "Stage2 breakout"; "RS positive rising" ])
    ?(suggested_entry = 150.50) ?(close_at_decision = None)
    ?(adjusted_close_at_decision = None) ?(ma_value = None)
    ?(local_range_top = None) ?(screener_proxy_stop = 138.46)
    ?(installed_stop = 138.46) ?(stop_floor_kind = TA.Buffer_fallback)
    ?(split_safe_basis = TA.Flag_off) ?(risk_pct = 0.08)
    ?(initial_position_value = 75_000.0) ?(initial_risk_dollars = 6_000.0)
    ?(ticket_lifecycle = None) ?(alternatives_considered = []) () :
    TA.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend;
    macro_confidence;
    macro_indicators;
    stage;
    ma_direction;
    ma_slope_pct;
    rs_trend;
    rs_value;
    volume_quality;
    volume_ratio;
    resistance_quality;
    support_quality;
    sector_name;
    sector_rating;
    cascade_score;
    cascade_grade;
    cascade_score_components;
    cascade_rationale;
    side;
    suggested_entry;
    close_at_decision;
    adjusted_close_at_decision;
    ma_value;
    local_range_top;
    screener_proxy_stop;
    installed_stop;
    stop_floor_kind;
    split_safe_basis;
    risk_pct;
    initial_position_value;
    initial_risk_dollars;
    ticket_lifecycle;
    alternatives_considered;
  }

let make_exit ?(symbol = "AAPL") ?(exit_date = _date "2024-04-20")
    ?(position_id = "AAPL-wein-1")
    ?(exit_trigger =
      Backtest.Stop_log.Stop_loss { stop_price = 138.46; actual_price = 137.20 })
    ?(macro_trend_at_exit = Weinstein_types.Neutral)
    ?(macro_confidence_at_exit = 0.45)
    ?(stage_at_exit = Weinstein_types.Stage3 { weeks_topping = 2 })
    ?(rs_trend_at_exit = Some Weinstein_types.Positive_flat)
    ?(distance_from_ma_pct = -0.025) ?(max_favorable_excursion_pct = 0.082)
    ?(max_adverse_excursion_pct = -0.085) ?(weeks_macro_was_bearish = 0)
    ?(weeks_stage_left_2 = 1) () : TA.exit_decision =
  {
    symbol;
    exit_date;
    position_id;
    exit_trigger;
    macro_trend_at_exit;
    macro_confidence_at_exit;
    stage_at_exit;
    rs_trend_at_exit;
    distance_from_ma_pct;
    max_favorable_excursion_pct;
    max_adverse_excursion_pct;
    weeks_macro_was_bearish;
    weeks_stage_left_2;
  }

let _alt ~symbol ~score ~grade ~reason
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false })
    ?(weeks_advancing = Some 3) ?(rs_value = Some 1.02)
    ?(volume_ratio = Some 1.8) ?(sector_name = "Information Technology")
    ?(score_components = []) () : TA.alternative_candidate =
  {
    symbol;
    side = Trading_base.Types.Long;
    score;
    grade;
    reason_skipped = reason;
    stage;
    weeks_advancing;
    rs_value;
    volume_ratio;
    sector_name;
    score_components;
  }

(** A [TriggerExit] transition carrying a [StrategySignal] exit reason — what
    margin exits ([margin_call] / [buyin_stress] / [maintenance_reduce]) and the
    other externally-generated [StrategySignal] exits ([stage3_force_exit],
    [laggard_rotation], ...) look like on the [Position.transition] list
    [record_transitions] observes. *)
let _strategy_signal_trigger_exit ?(position_id = "AAPL-wein-1")
    ?(date = _date "2024-04-20") ?(label = "margin_call") ?(detail = None)
    ?(exit_price = 137.20) () : Position.transition =
  {
    position_id;
    date;
    kind =
      Position.TriggerExit
        { exit_reason = Position.StrategySignal { label; detail }; exit_price };
  }

(** A [TriggerPartialExit] transition carrying a [StrategySignal] exit reason —
    what a partial trim looks like on the [Position.transition] list
    [record_transitions] observes. Structurally adjacent to
    {!_strategy_signal_trigger_exit} (same [exit_reason] shape) except for
    [kind], so it genuinely discriminates [record_transitions]'s "only
    [TriggerExit], not [TriggerPartialExit]" behavior — unlike
    [UpdateRiskParams], which has no [exit_reason] field at all. *)
let _strategy_signal_trigger_partial_exit ?(position_id = "AAPL-wein-1")
    ?(date = _date "2024-04-20") ?(label = "partial_trim") ?(detail = None)
    ?(exit_price = 137.20) ?(target_quantity = 50.0) () : Position.transition =
  {
    position_id;
    date;
    kind =
      Position.TriggerPartialExit
        {
          exit_reason = Position.StrategySignal { label; detail };
          exit_price;
          target_quantity;
        };
  }

(* Sexp round-trip ------------------------------------------------------- *)

let test_skip_reason_sexp_round_trip _ =
  let all : TA.skip_reason list =
    [
      Insufficient_cash;
      Already_held;
      Below_min_grade;
      Sized_to_zero;
      Sector_concentration;
      Top_n_cutoff;
      No_structural_stop;
      Share_class_held;
    ]
  in
  let parsed =
    List.map all ~f:(fun r -> TA.skip_reason_of_sexp (TA.sexp_of_skip_reason r))
  in
  assert_that parsed (elements_are (List.map all ~f:equal_to))

let test_stop_floor_kind_sexp_round_trip _ =
  let all : TA.stop_floor_kind list = [ Support_floor; Buffer_fallback ] in
  let parsed =
    List.map all ~f:(fun k ->
        TA.stop_floor_kind_of_sexp (TA.sexp_of_stop_floor_kind k))
  in
  assert_that parsed (elements_are (List.map all ~f:equal_to))

let test_split_safe_basis_sexp_round_trip _ =
  let all : TA.split_safe_basis list =
    [ Flag_off; Adjusted; Raw_fallback; Empty_window ]
  in
  let parsed =
    List.map all ~f:(fun b ->
        TA.split_safe_basis_of_sexp (TA.sexp_of_split_safe_basis b))
  in
  assert_that parsed (elements_are (List.map all ~f:equal_to))

(* [split_safe_basis] is [\[@sexp.default Flag_off\]] so that [trade_audit.sexp]
   files written before the field existed stay readable — they are read back by
   [Optimal_run_artefacts], [Validator_report] and [Trade_audit_report]. Drop the
   field from a serialized row and the parse must still succeed, defaulting to
   [Flag_off] (which is the truth for any run predating the field). *)
let test_entry_decision_sexp_tolerates_missing_split_safe_basis _ =
  let entry = make_entry ~split_safe_basis:TA.Raw_fallback () in
  let stripped =
    match TA.sexp_of_entry_decision entry with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "split_safe_basis" :: _) -> false
            | _ -> true))
    | other -> other
  in
  assert_that
    (TA.entry_decision_of_sexp stripped)
    (equal_to (make_entry ~split_safe_basis:TA.Flag_off () : TA.entry_decision))

(* The E-provenance fields ([close_at_decision] / [ma_value] /
   [local_range_top], entry-ticket right-basis plan 2026-08-08, plus
   [adjusted_close_at_decision], issue #2973) are [\[@sexp.option\]]: a
   [trade_audit.sexp] written before they existed carries no such fields and
   must parse with all four [None]. Serialize a row that
   HAS the fields, strip them, and the parse must still succeed with [None]s —
   the same tolerance contract [split_safe_basis] pins above. *)
let test_entry_decision_sexp_tolerates_missing_e_provenance_fields _ =
  let entry =
    make_entry ~close_at_decision:(Some 148.2)
      ~adjusted_close_at_decision:(Some 3.705) ~ma_value:(Some 140.0)
      ~local_range_top:(Some 151.0) ()
  in
  let stripped =
    match TA.sexp_of_entry_decision entry with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom name :: _) ->
                not
                  (List.mem
                     [
                       "close_at_decision";
                       "adjusted_close_at_decision";
                       "ma_value";
                       "local_range_top";
                     ]
                     name ~equal:String.equal)
            | _ -> true))
    | other -> other
  in
  assert_that
    (TA.entry_decision_of_sexp stripped)
    (equal_to (make_entry () : TA.entry_decision))

(* Issue #2975: the screener's proxy stop is written under the key
   [screener_proxy_stop] — never the legacy [suggested_stop], so a walkthrough
   reader cannot mistake it for the stop the entry used. *)
let _top_level_keys (sexp : Sexp.t) =
  match sexp with
  | Sexp.List fields ->
      List.filter_map fields ~f:(function
        | Sexp.List (Sexp.Atom key :: _) -> Some key
        | _ -> None)
  | Sexp.Atom _ -> []

let test_entry_decision_sexp_writes_screener_proxy_stop_key _ =
  let keys =
    _top_level_keys (TA.sexp_of_entry_decision (make_entry ()))
    |> List.filter ~f:(fun k ->
        List.mem
          [ "screener_proxy_stop"; "suggested_stop" ]
          k ~equal:String.equal)
  in
  assert_that keys (elements_are [ equal_to "screener_proxy_stop" ])

(* A [trade_audit.sexp] row written before issue #2975 carries the proxy under
   [suggested_stop]. Literal trimmed from a real pre-rename artefact
   ([dev/warmup-fix-runs/after-fix1-stop-log/bull-2019h2/trade_audit.sexp],
   AAPL 2019-06-21; [volume_ratio], a required field added after that file was
   written, is filled in) and read through the top-level codec every reader
   uses: the legacy value must land in [screener_proxy_stop], distinct from the
   [installed_stop] the entry actually used. *)
let _legacy_audit_records =
  {|(((entry
     ((symbol AAPL) (entry_date 2019-06-21) (position_id AAPL-wein-61)
      (macro_trend Bullish) (macro_confidence 1) (macro_indicators ())
      (stage (Stage2 (weeks_advancing 1) (late false))) (ma_direction Rising)
      (ma_slope_pct 0.017967958275741824) (rs_trend ()) (rs_value ())
      (volume_quality ((Adequate 1.7052120350790312))) (volume_ratio (1.71))
      (resistance_quality (Clean)) (support_quality (Virgin_territory))
      (sector_name "Information Technology") (sector_rating Strong)
      (cascade_score 65) (cascade_grade B) (cascade_score_components ())
      (cascade_rationale ("Adequate volume"))
      (side Long) (suggested_entry 211.17) (suggested_stop 194.2764)
      (installed_stop 163.4592) (stop_floor_kind Support_floor)
      (risk_pct 0.079999999999999974) (initial_position_value 130291.89)
      (initial_risk_dollars 29437.563599999987)
      (alternatives_considered ())))
    (exit_ ())))|}

let test_legacy_suggested_stop_key_parses_into_screener_proxy_stop _ =
  assert_that
    (TA.audit_records_of_sexp (Sexp.of_string _legacy_audit_records))
    (elements_are
       [
         field
           (fun (r : TA.audit_record) -> r.entry)
           (all_of
              [
                field
                  (fun (e : TA.entry_decision) -> e.screener_proxy_stop)
                  (float_equal 194.2764);
                field
                  (fun (e : TA.entry_decision) -> e.installed_stop)
                  (float_equal 163.4592);
                field
                  (fun (e : TA.entry_decision) -> e.split_safe_basis)
                  (equal_to (TA.Flag_off : TA.split_safe_basis));
              ]);
       ])

(* PR-5 ticket-lifecycle fields ---------------------------------------- *)

let _triple : TL.triple_confirmation =
  {
    breakout_volume_multiple = Some 3.1;
    rs_zero_cross = true;
    in_base_advance_pct = Some 0.62;
  }

let _lifecycle ?(placement_date = _date "2024-03-01")
    ?(ticket_age_weeks_at_cancel = Some 3)
    ?(cancel_reason = Some "entry_ticket_ttl_expired")
    ?(ticket_age_weeks_at_fill = None) ?(fill_volume = None)
    ?(freshness_basis = TL.Range_top_breakout)
    ?(entry_anchor = Some TL.Continuation) ?(sized_down_wide_stop = true)
    ?(triple_confirmation = _triple) ?(reissued_from = None) () : TL.t =
  {
    placement_date;
    ticket_age_weeks_at_cancel;
    cancel_reason;
    ticket_age_weeks_at_fill;
    fill_volume;
    freshness_basis;
    entry_anchor;
    sized_down_wide_stop;
    triple_confirmation;
    reissued_from;
    cash_rejection = None;
  }

let _check verdict outcome : TL.fill_volume_check = { verdict; outcome }

(** Every [fill_volume_verdict] constructor — including the [No_verdict] cell
    the eject rate alone cannot see — survives the codec paired with an outcome,
    as do the other lifecycle fields around it. The third row is the divergence
    case: [Unconfirmed] that was NOT ejected because another exit channel had
    already claimed the position. *)
let test_entry_decision_sexp_round_trips_ticket_lifecycle _ =
  let checks =
    [
      Some (_check (TL.Confirmed_spike 3.4) TL.Held);
      Some (_check (TL.Confirmed_buildup 2.2) TL.Held);
      Some
        (_check
           (TL.Unconfirmed { spike_ratio = Some 1.1; buildup_multiple = None })
           TL.Skipped_other_exit);
      Some
        (_check
           (TL.Unconfirmed { spike_ratio = None; buildup_multiple = Some 1.2 })
           TL.Ejected);
      Some (_check TL.No_verdict TL.Held);
      None;
    ]
  in
  let entries =
    List.map checks ~f:(fun fill_volume ->
        make_entry ~ticket_lifecycle:(Some (_lifecycle ~fill_volume ())) ())
  in
  assert_that
    (List.map entries ~f:(fun e ->
         TA.entry_decision_of_sexp (TA.sexp_of_entry_decision e)))
    (elements_are
       (List.map entries ~f:(fun e -> equal_to (e : TA.entry_decision))))

(** [ticket_lifecycle] is [[@sexp.option]]: a [trade_audit.sexp] written before
    PR-5 carries no such field and must parse with [None]. *)
let test_entry_decision_sexp_tolerates_missing_ticket_lifecycle _ =
  let entry = make_entry ~ticket_lifecycle:(Some (_lifecycle ())) () in
  let stripped =
    match TA.sexp_of_entry_decision entry with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "ticket_lifecycle" :: _) -> false
            | _ -> true))
    | other -> other
  in
  assert_that
    (TA.entry_decision_of_sexp stripped)
    (equal_to (make_entry () : TA.entry_decision))

(** The three resolution-side fields inside the record are themselves
    [[@sexp.option]] — a still-resting ticket writes none of them, and a row
    missing all three parses back to the unresolved shape rather than to a zero
    age or a fabricated verdict. *)
let test_ticket_lifecycle_sexp_omits_unresolved_fill_fields _ =
  let unresolved =
    _lifecycle ~ticket_age_weeks_at_cancel:None ~cancel_reason:None
      ~ticket_age_weeks_at_fill:None ~fill_volume:None ()
  in
  let sexp = TL.sexp_of_t unresolved in
  let field_names =
    match sexp with
    | Sexp.List fields ->
        List.filter_map fields ~f:(function
          | Sexp.List (Sexp.Atom name :: _) -> Some name
          | _ -> None)
    | _ -> []
  in
  assert_that
    ( List.count field_names ~f:(fun n ->
          List.mem
            [
              "ticket_age_weeks_at_cancel";
              "cancel_reason";
              "ticket_age_weeks_at_fill";
              "fill_volume";
            ]
            n ~equal:String.equal),
      TL.t_of_sexp sexp )
    (equal_to (0, unresolved))

(** [age_weeks] clamps at [0]: a resolution dated before its own placement is a
    data anomaly, never a negative resting age. *)
let test_age_weeks_clamps_at_zero _ =
  assert_that
    ( TL.age_weeks ~placed:(_date "2024-03-22") ~resolved:(_date "2024-03-01"),
      TL.age_weeks ~placed:(_date "2024-03-01") ~resolved:(_date "2024-03-22")
    )
    (equal_to (0, 3))

(** Populated E-provenance fields survive the codec round trip. *)
let test_entry_decision_sexp_round_trips_e_provenance_fields _ =
  let entry =
    make_entry ~close_at_decision:(Some 148.2)
      ~adjusted_close_at_decision:(Some 3.705) ~ma_value:(Some 140.0)
      ~local_range_top:(Some 151.0) ()
  in
  let parsed = TA.entry_decision_of_sexp (TA.sexp_of_entry_decision entry) in
  assert_that parsed (equal_to entry)

let test_alternative_candidate_sexp_round_trip _ =
  (* Exercise the enriched decision-time fields (stage / weeks_advancing /
     rs_value / volume_ratio / sector_name / score_components) through the
     codec, not just the score+grade+reason base. *)
  let alt =
    _alt ~symbol:"MSFT" ~score:62 ~grade:Weinstein_types.B
      ~reason:TA.Insufficient_cash
      ~stage:(Weinstein_types.Stage2 { weeks_advancing = 6; late = true })
      ~weeks_advancing:(Some 6) ~rs_value:(Some 0.94) ~volume_ratio:(Some 2.1)
      ~sector_name:"Health Care"
      ~score_components:[ ("stage2_breakout", 30); ("strong_volume", 20) ]
      ()
  in
  let parsed =
    TA.alternative_candidate_of_sexp (TA.sexp_of_alternative_candidate alt)
  in
  assert_that parsed (equal_to alt)

let test_entry_decision_sexp_round_trip _ =
  let entry =
    make_entry
      ~alternatives_considered:
        [
          _alt ~symbol:"MSFT" ~score:62 ~grade:Weinstein_types.B
            ~reason:TA.Insufficient_cash ();
          _alt ~symbol:"NVDA" ~score:55 ~grade:Weinstein_types.B
            ~reason:TA.Sized_to_zero ();
        ]
      ()
  in
  let parsed = TA.entry_decision_of_sexp (TA.sexp_of_entry_decision entry) in
  assert_that parsed (equal_to entry)

let test_exit_decision_sexp_round_trip _ =
  let exit_ = make_exit () in
  let parsed = TA.exit_decision_of_sexp (TA.sexp_of_exit_decision exit_) in
  assert_that parsed (equal_to exit_)

let test_external_exit_decision_sexp_round_trip _ =
  let ext : TA.external_exit_decision =
    {
      symbol = "AAPL";
      exit_date = _date "2024-04-20";
      position_id = "AAPL-wein-1";
      exit_trigger =
        Backtest.Stop_log.Strategy_signal
          { label = "margin_call"; detail = Some "avg_cost=50.00" };
    }
  in
  let parsed =
    TA.external_exit_decision_of_sexp (TA.sexp_of_external_exit_decision ext)
  in
  assert_that parsed (equal_to ext)

let test_audit_record_sexp_round_trip _ =
  let record : TA.audit_record =
    {
      entry = make_entry ();
      exit_ = Some (make_exit ());
      external_exit = None;
      execution = None;
      stop_decisions = [];
    }
  in
  let parsed = TA.audit_record_of_sexp (TA.sexp_of_audit_record record) in
  assert_that parsed (equal_to record)

let test_audit_records_sexp_round_trip_through_top_level_codec _ =
  let records : TA.audit_record list =
    [
      {
        entry = make_entry ();
        exit_ = Some (make_exit ());
        external_exit = None;
        execution = None;
        stop_decisions = [];
      };
      {
        entry =
          make_entry ~symbol:"MSFT" ~position_id:"MSFT-wein-1"
            ~entry_date:(_date "2024-02-01") ();
        exit_ = None;
        external_exit = None;
        execution = None;
        stop_decisions = [];
      };
    ]
  in
  let sexp = TA.sexp_of_audit_records records in
  let parsed = TA.audit_records_of_sexp sexp in
  assert_that parsed (elements_are (List.map records ~f:equal_to))

(* PR-5 collector-side lifecycle merges ---------------------------------- *)

let _lifecycle_of (r : TA.audit_record) = r.entry.ticket_lifecycle

(** The F5 check arrives after the entry (at the fill week's closing tick) and
    is merged into that entry's lifecycle at drain time — verdict and outcome
    together. *)
let test_record_fill_volume_merges_into_the_entry_row _ =
  let t = TA.create () in
  TA.record_entry t
    (make_entry
       ~ticket_lifecycle:(Some (_lifecycle ~ticket_age_weeks_at_cancel:None ()))
       ());
  TA.record_fill_volume t ~position_id:"AAPL-wein-1"
    (_check TL.No_verdict TL.Held);
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field _lifecycle_of
           (is_some_and
              (field
                 (fun (l : TL.t) -> l.fill_volume)
                 (is_some_and
                    (equal_to
                       (_check TL.No_verdict TL.Held : TL.fill_volume_check)))));
       ])

(** No entry on record ⇒ the check is dropped, mirroring [record_exit]'s
    no-entry contract. *)
let test_record_fill_volume_without_entry_is_dropped _ =
  let t = TA.create () in
  TA.record_fill_volume t ~position_id:"GHOST-wein-9"
    (_check TL.No_verdict TL.Held);
  assert_that (TA.get_audit_records t) is_empty

(** F2's cancel path: a ticket cancelled three weeks after placement records a
    resting age of 3 in the CANCEL column
    {b and the transition's own reason token}, and leaves the fill column [None]
    — the two resolutions are mutually exclusive. This is the only place a
    never-filled ticket's age is observable; it produces no round-trip for the
    fill-side enrichment. *)
let test_cancel_entry_records_the_resting_age_in_weeks _ =
  let t = TA.create () in
  TA.record_entry t
    (make_entry
       ~ticket_lifecycle:
         (Some
            (_lifecycle ~placement_date:(_date "2024-03-01")
               ~ticket_age_weeks_at_cancel:None ~cancel_reason:None ()))
       ());
  TA.record_transitions t
    [
      {
        Position.position_id = "AAPL-wein-1";
        date = _date "2024-03-22";
        kind = Position.CancelEntry { reason = "entry_ticket_ttl_expired" };
      };
    ];
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field _lifecycle_of
           (is_some_and
              (all_of
                 [
                   field
                     (fun (l : TL.t) -> l.ticket_age_weeks_at_cancel)
                     (is_some_and (equal_to 3));
                   field
                     (fun (l : TL.t) -> l.cancel_reason)
                     (is_some_and (equal_to "entry_ticket_ttl_expired"));
                   field (fun (l : TL.t) -> l.ticket_age_weeks_at_fill) is_none;
                 ]));
       ])

(** The cause is carried through verbatim, so the two ways a resting ticket dies
    stay separable in [trade_audit.sexp]. A strategy-side TTL cancel is a
    {i decision}; a [Cancel_handler.portfolio_rejection_reason] cancel is an
    {i accident of capital timing} — a ticket that triggered, filled at the
    engine, and was then refused because the book could not fund it. Grouping a
    cancel-age column without this field averages a policy with a failure. *)
let test_cancel_reason_distinguishes_rejection_from_ttl _ =
  let record_cancel ~position_id ~reason =
    let t = TA.create () in
    TA.record_entry t
      (make_entry ~position_id
         ~ticket_lifecycle:
           (Some
              (_lifecycle ~placement_date:(_date "2024-03-01")
                 ~ticket_age_weeks_at_cancel:None ~cancel_reason:None ()))
         ());
    TA.record_transitions t
      [
        {
          Position.position_id;
          date = _date "2024-03-22";
          kind = Position.CancelEntry { reason };
        };
      ];
    List.filter_map (TA.get_audit_records t) ~f:(fun (r : TA.audit_record) ->
        Option.bind r.entry.ticket_lifecycle ~f:(fun (l : TL.t) ->
            l.cancel_reason))
  in
  assert_that
    ( record_cancel ~position_id:"AAPL-wein-1"
        ~reason:Trading_simulation.Cancel_handler.portfolio_rejection_reason,
      record_cancel ~position_id:"AAPL-wein-1"
        ~reason:"entry_ticket_ttl_expired" )
    (equal_to
       ([ "entry_fill_rejected_by_portfolio" ], [ "entry_ticket_ttl_expired" ]))

(** A row written before PR-5 carries no [ticket_lifecycle]; the collector must
    leave it alone rather than fabricate one from a late verdict. *)
let test_lifecycle_merges_are_inert_on_a_pre_pr5_row _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_fill_volume t ~position_id:"AAPL-wein-1"
    (_check TL.No_verdict TL.Held);
  assert_that (TA.get_audit_records t)
    (elements_are [ field _lifecycle_of is_none ])

(* #2989 — re-issued suspended tickets ----------------------------------- *)

let _original_id = "AAPL-wein-1"
let _reissued_id = "AAPL-wein-7"
let _placed = _date "2024-03-01"
let _suspended_on = _date "2024-03-08"
let _reissued_on = _date "2024-03-22"

let _reissue_link : TL.reissue =
  { original_position_id = _original_id; reissue_date = _reissued_on }

(** The placement row the entry walk records: unresolved lifecycle, one rival, a
    support-floor stop — the fields a re-issued trade must be joinable to. *)
let _placement_row () =
  make_entry ~position_id:_original_id ~installed_stop:141.0
    ~stop_floor_kind:TA.Support_floor
    ~alternatives_considered:
      [
        _alt ~symbol:"MSFT" ~score:60 ~grade:Weinstein_types.B
          ~reason:TA.Top_n_cutoff ();
      ]
    ~ticket_lifecycle:
      (Some
         (_lifecycle ~placement_date:_placed ~ticket_age_weeks_at_cancel:None
            ~cancel_reason:None ()))
    ()

(** Suspend, re-issue and fill: the original placement is withdrawn with the
    suspension token, the re-issued id gets a row that is the original's
    placement-time entry (same alternatives, installed stop, floor kind,
    placement date) with [reissued_from] pointing back at the original id, and
    the re-issued position's exit attaches to that row. The original row keeps
    its own withdrawal and gains no link.

    MUTATION: making [record_reissue] a no-op leaves the exit with no row to
    attach to (the pre-#2989 shape) and turns the second element red. *)
let test_record_reissue_links_the_filled_copy_to_its_placement _ =
  let t = TA.create () in
  let original = _placement_row () in
  TA.record_entry t original;
  TA.record_transitions t
    [
      {
        Position.position_id = _original_id;
        date = _suspended_on;
        kind = Position.CancelEntry { reason = "entry_ticket_macro_suspended" };
      };
    ];
  let (_ : TA.entry_decision option) =
    TA.record_reissue t ~position_id:_reissued_id
      ~original_position_id:_original_id ~reissue_date:_reissued_on
  in
  TA.record_exit t (make_exit ~position_id:_reissued_id ());
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         all_of
           [
             field
               (fun (r : TA.audit_record) -> r.entry.position_id)
               (equal_to _original_id);
             field
               (fun (r : TA.audit_record) ->
                 Option.map r.entry.ticket_lifecycle ~f:(fun l ->
                     (l.cancel_reason, l.reissued_from)))
               (is_some_and
                  (equal_to (Some "entry_ticket_macro_suspended", None)));
             field (fun (r : TA.audit_record) -> r.exit_) is_none;
           ];
         all_of
           [
             field
               (fun (r : TA.audit_record) -> r.entry)
               (equal_to
                  ({
                     original with
                     position_id = _reissued_id;
                     (* Spelled out literally, not via [TL.with_reissue]:
                        the copy keeps the original [placement_date] (so its
                        fill age counts the suspended weeks) and every other
                        placement-time lifecycle field. *)
                     ticket_lifecycle =
                       Some
                         (_lifecycle ~placement_date:_placed
                            ~ticket_age_weeks_at_cancel:None ~cancel_reason:None
                            ~reissued_from:(Some _reissue_link) ());
                   }
                    : TA.entry_decision));
             field
               (fun (r : TA.audit_record) ->
                 Option.bind r.entry.ticket_lifecycle ~f:(fun l ->
                     l.reissued_from))
               (is_some_and (equal_to _reissue_link));
             field
               (fun (r : TA.audit_record) ->
                 Option.map r.exit_ ~f:(fun e -> e.position_id))
               (is_some_and (equal_to _reissued_id));
           ];
       ])

(** No placement on file for the named original → nothing is recorded and [None]
    is returned (the no-entry contract every [record_*] shares). *)
let test_record_reissue_without_original_is_dropped _ =
  let t = TA.create () in
  let copy =
    TA.record_reissue t ~position_id:_reissued_id
      ~original_position_id:_original_id ~reissue_date:_reissued_on
  in
  assert_that (copy, TA.get_audit_records t) (pair is_none is_empty)

(** [reissued_from] is [[@sexp.option]]: a [trade_audit.sexp] lifecycle written
    before #2989 has no such field and parses with [None]; a populated link
    survives the codec. The legacy record is spelled out as sexp text, not
    derived from today's serializer, so it pins the on-disk shape. *)
let test_ticket_lifecycle_sexp_reissued_from_is_optional _ =
  let legacy =
    Sexp.of_string
      "((placement_date 2024-03-01) (freshness_basis Ma_cross) \
       (sized_down_wide_stop false) (triple_confirmation \
       ((breakout_volume_multiple ()) (rs_zero_cross false) \
       (in_base_advance_pct ()))))"
  in
  let linked = _lifecycle ~reissued_from:(Some _reissue_link) () in
  assert_that
    (TL.t_of_sexp legacy, TL.t_of_sexp (TL.sexp_of_t linked))
    (pair (field (fun (l : TL.t) -> l.reissued_from) is_none) (equal_to linked))

(* Collector behaviour --------------------------------------------------- *)

let test_empty_collector_returns_empty _ =
  let t = TA.create () in
  assert_that (TA.get_audit_records t) is_empty

let test_record_entry_appears_in_audit _ =
  let t = TA.create () in
  let entry = make_entry () in
  TA.record_entry t entry;
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         all_of
           [
             field (fun (r : TA.audit_record) -> r.entry) (equal_to entry);
             field (fun (r : TA.audit_record) -> r.exit_) is_none;
           ];
       ])

let test_record_exit_attaches_to_existing_entry _ =
  let t = TA.create () in
  let entry = make_entry () in
  let exit_ = make_exit () in
  TA.record_entry t entry;
  TA.record_exit t exit_;
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         all_of
           [
             field (fun (r : TA.audit_record) -> r.entry) (equal_to entry);
             field
               (fun (r : TA.audit_record) -> r.exit_)
               (is_some_and (equal_to exit_));
           ];
       ])

let test_record_exit_without_entry_is_dropped _ =
  let t = TA.create () in
  TA.record_exit t (make_exit ~position_id:"ORPHAN-1" ());
  assert_that (TA.get_audit_records t) is_empty

(* #3138: a cash rejection for a position id with no recorded entry is
   dropped, like every sibling [record_*]; the entry on file is untouched. *)
let test_record_cash_rejection_without_entry_is_dropped _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_cash_rejection t
    {
      position_id = "ORPHAN-1";
      symbol = "ORPH";
      date = _date "2024-05-01";
      required = 1_000.0;
      available = 400.0;
    };
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field
           (fun (r : TA.audit_record) ->
             Option.bind r.entry.ticket_lifecycle
               ~f:(fun (l : Backtest.Ticket_lifecycle.t) -> l.cash_rejection))
           is_none;
       ])

(* record_transitions (#2076) --------------------------------------------- *)

let _external_exit_of t ~position_id =
  TA.get_audit_records t
  |> List.find ~f:(fun (r : TA.audit_record) ->
      String.equal r.entry.position_id position_id)
  |> Option.bind ~f:(fun (r : TA.audit_record) -> r.external_exit)

let test_record_transitions_captures_margin_call_as_external_exit _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_transitions t
    [
      _strategy_signal_trigger_exit ~label:"margin_call"
        ~detail:(Some "avg_cost=50.00") ~date:(_date "2024-05-01")
        ~exit_price:65.0 ();
    ];
  assert_that
    (_external_exit_of t ~position_id:"AAPL-wein-1")
    (is_some_and
       (all_of
          [
            field
              (fun (e : TA.external_exit_decision) -> e.symbol)
              (equal_to "AAPL");
            field
              (fun (e : TA.external_exit_decision) -> e.exit_date)
              (equal_to (_date "2024-05-01"));
            field
              (fun (e : TA.external_exit_decision) -> e.position_id)
              (equal_to "AAPL-wein-1");
            field
              (fun (e : TA.external_exit_decision) -> e.exit_trigger)
              (equal_to
                 (Backtest.Stop_log.Strategy_signal
                    { label = "margin_call"; detail = Some "avg_cost=50.00" }));
          ]));
  (* No enriched exit_ was ever recorded — this position's exit is
     reason-only. *)
  assert_that (TA.get_audit_records t)
    (elements_are [ field (fun (r : TA.audit_record) -> r.exit_) is_none ])

(* Extra credit (#2076): the SAME generic path also fixes the other
   [StrategySignal] exit sources that never routed through
   [Weinstein_strategy.Exit_audit_capture] — no per-label special-casing was
   needed to cover [stage3_force_exit] alongside [margin_call]. *)
let test_record_transitions_captures_any_strategy_signal_label _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_transitions t
    [ _strategy_signal_trigger_exit ~label:"stage3_force_exit" ~detail:None () ];
  assert_that
    (_external_exit_of t ~position_id:"AAPL-wein-1")
    (is_some_and
       (field
          (fun (e : TA.external_exit_decision) -> e.exit_trigger)
          (equal_to
             (Backtest.Stop_log.Strategy_signal
                { label = "stage3_force_exit"; detail = None }))))

let test_record_transitions_enriched_exit_wins_no_overwrite _ =
  let t = TA.create () in
  let enriched_exit = make_exit () in
  TA.record_entry t (make_entry ());
  TA.record_exit t enriched_exit;
  (* A same-position TriggerExit arriving afterwards (as [on_transitions]
     would, one step later than the strategy's own enriched-path recording)
     must NOT touch [exit_] or populate [external_exit] — enriched always
     wins. *)
  TA.record_transitions t [ _strategy_signal_trigger_exit () ];
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         all_of
           [
             field
               (fun (r : TA.audit_record) -> r.exit_)
               (is_some_and (equal_to enriched_exit));
             field (fun (r : TA.audit_record) -> r.external_exit) is_none;
           ];
       ])

let test_record_transitions_without_entry_is_dropped _ =
  let t = TA.create () in
  TA.record_transitions t
    [ _strategy_signal_trigger_exit ~position_id:"ORPHAN-1" () ];
  assert_that (TA.get_audit_records t) is_empty

let test_record_transitions_ignores_non_trigger_exit_kinds _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  let update_risk_params : Position.transition =
    {
      position_id = "AAPL-wein-1";
      date = _date "2024-04-20";
      kind =
        Position.UpdateRiskParams
          {
            new_risk_params =
              {
                stop_loss_price = Some 145.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    }
  in
  TA.record_transitions t [ update_risk_params ];
  assert_that (_external_exit_of t ~position_id:"AAPL-wein-1") is_none

let test_record_transitions_ignores_partial_exit _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_transitions t
    [
      _strategy_signal_trigger_partial_exit ~label:"partial_trim"
        ~target_quantity:50.0 ();
    ];
  (* A partial trim does not close the position, so [record_transitions]
     must not synthesize an [external_exit] for it — confirmed against the
     wildcard match arm in [_process_transition_for_external_exit]. *)
  assert_that (_external_exit_of t ~position_id:"AAPL-wein-1") is_none;
  assert_that (TA.get_audit_records t)
    (elements_are [ field (fun (r : TA.audit_record) -> r.exit_) is_none ])

let test_record_entry_overwrites_same_position_id _ =
  let t = TA.create () in
  let first = make_entry ~cascade_score:50 () in
  let second = make_entry ~cascade_score:80 () in
  TA.record_entry t first;
  TA.record_entry t second;
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field
           (fun (r : TA.audit_record) -> r.entry.cascade_score)
           (equal_to 80);
       ])

let test_get_audit_records_sorts_by_position_id _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ~position_id:"ZZZ-wein-1" ~symbol:"ZZZ" ());
  TA.record_entry t (make_entry ~position_id:"AAA-wein-1" ~symbol:"AAA" ());
  TA.record_entry t (make_entry ~position_id:"MMM-wein-1" ~symbol:"MMM" ());
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field
           (fun (r : TA.audit_record) -> r.entry.position_id)
           (equal_to "AAA-wein-1");
         field
           (fun (r : TA.audit_record) -> r.entry.position_id)
           (equal_to "MMM-wein-1");
         field
           (fun (r : TA.audit_record) -> r.entry.position_id)
           (equal_to "ZZZ-wein-1");
       ])

let test_collector_round_trips_through_sexp _ =
  let t = TA.create () in
  TA.record_entry t
    (make_entry
       ~alternatives_considered:
         [
           _alt ~symbol:"MSFT" ~score:62 ~grade:Weinstein_types.B
             ~reason:TA.Top_n_cutoff ();
         ]
       ());
  TA.record_exit t (make_exit ());
  TA.record_entry t (make_entry ~symbol:"NVDA" ~position_id:"NVDA-wein-1" ());
  let original = TA.get_audit_records t in
  let parsed = TA.audit_records_of_sexp (TA.sexp_of_audit_records original) in
  assert_that parsed (elements_are (List.map original ~f:equal_to))

(* Cascade summary builders + tests --------------------------------------- *)

(** Minimal but realistic [cascade_summary] builder. Defaults model a typical
    Bullish-macro Friday with modest long-side activity and one entry. *)
let make_cascade_summary ?(date = _date "2024-01-19") ?(total_stocks = 20)
    ?(candidates_after_held = 18) ?(macro_trend = Weinstein_types.Bullish)
    ?(long_macro_admitted = 18) ?(long_breakout_admitted = 5)
    ?(long_sector_admitted = 5) ?(long_grade_admitted = 3)
    ?(long_top_n_admitted = 3) ?(short_macro_admitted = 18)
    ?(short_breakdown_admitted = 0) ?(short_sector_admitted = 0)
    ?(short_rs_hard_gate_admitted = 0) ?(short_grade_admitted = 0)
    ?(short_top_n_admitted = 0) ?(entered = 1) ?(decisions = []) () :
    TA.cascade_summary =
  {
    date;
    total_stocks;
    candidates_after_held;
    macro_trend;
    breadth_state = Weinstein_types.breadth_state_of_market_trend macro_trend;
    long_macro_admitted;
    long_breakout_admitted;
    long_sector_admitted;
    long_grade_admitted;
    long_top_n_admitted;
    short_macro_admitted;
    short_breakdown_admitted;
    short_sector_admitted;
    short_rs_hard_gate_admitted;
    short_grade_admitted;
    short_top_n_admitted;
    entered;
    decisions;
  }

let test_cascade_summary_sexp_round_trip _ =
  let s = make_cascade_summary () in
  let parsed = TA.cascade_summary_of_sexp (TA.sexp_of_cascade_summary s) in
  assert_that parsed (equal_to s)

(** [breadth_state]'s [[@sexp.default]] is reached only when the field is
    ABSENT, which the round-trip above never exercises. Reproduce the
    pre-feature on-disk shape by dropping the field from a serialized summary —
    this is the ~200 legacy [trade_audit.sexp] artefacts the [.mli] claims still
    parse — and assert [Neutral_breadth] comes back. The builder's default is
    [Bullish_breadth], so a no-op strip would fail this. *)
let test_cascade_summary_without_breadth_state_defaults _ =
  let s = make_cascade_summary ~macro_trend:Weinstein_types.Bullish () in
  let legacy =
    match TA.sexp_of_cascade_summary s with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "breadth_state" :: _) -> false
            | _ -> true))
    | other -> other
  in
  assert_that
    (TA.cascade_summary_of_sexp legacy)
    (equal_to { s with breadth_state = Weinstein_types.Neutral_breadth })

(* #3139: the weekly decision record round-trips with every outcome shape, and
   a summary written before the field existed parses to [decisions = []]. *)
let test_cascade_summary_decisions_round_trip _ =
  let decisions : TA.weekly_decision list =
    [
      { symbol = "CCCC"; side = Trading_base.Types.Long; outcome = Placed };
      {
        symbol = "AAAA";
        side = Trading_base.Types.Long;
        outcome = Skipped No_structural_stop;
      };
      {
        symbol = "SSSS";
        side = Trading_base.Types.Short;
        outcome = Skipped Insufficient_cash;
      };
    ]
  in
  let s = make_cascade_summary ~decisions () in
  let legacy =
    match TA.sexp_of_cascade_summary s with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "decisions" :: _) -> false
            | _ -> true))
    | other -> other
  in
  assert_that
    ( TA.cascade_summary_of_sexp (TA.sexp_of_cascade_summary s),
      TA.cascade_summary_of_sexp legacy )
    (pair (equal_to s) (equal_to { s with decisions = [] }))

let test_record_cascade_summary_appears_in_collector _ =
  let t = TA.create () in
  let s = make_cascade_summary () in
  TA.record_cascade_summary t s;
  assert_that (TA.get_cascade_summaries t) (elements_are [ equal_to s ])

let test_get_cascade_summaries_sorts_by_date _ =
  let t = TA.create () in
  let s1 = make_cascade_summary ~date:(_date "2024-03-15") () in
  let s2 = make_cascade_summary ~date:(_date "2024-01-19") () in
  let s3 = make_cascade_summary ~date:(_date "2024-02-09") () in
  TA.record_cascade_summary t s1;
  TA.record_cascade_summary t s2;
  TA.record_cascade_summary t s3;
  assert_that
    (TA.get_cascade_summaries t)
    (elements_are
       [
         field
           (fun (s : TA.cascade_summary) -> Date.to_string s.date)
           (equal_to "2024-01-19");
         field
           (fun (s : TA.cascade_summary) -> Date.to_string s.date)
           (equal_to "2024-02-09");
         field
           (fun (s : TA.cascade_summary) -> Date.to_string s.date)
           (equal_to "2024-03-15");
       ])

let test_audit_blob_round_trip _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_exit t (make_exit ());
  TA.record_cascade_summary t (make_cascade_summary ());
  TA.record_cascade_summary t
    (make_cascade_summary ~date:(_date "2024-01-26")
       ~macro_trend:Weinstein_types.Bearish ~long_macro_admitted:0
       ~long_breakout_admitted:0 ~long_sector_admitted:0 ~long_grade_admitted:0
       ~long_top_n_admitted:0 ~entered:0 ());
  let blob = TA.get_audit_blob t in
  let parsed = TA.audit_blob_of_sexp (TA.sexp_of_audit_blob blob) in
  assert_that parsed (equal_to blob)

let test_empty_collector_returns_empty_blob _ =
  let t = TA.create () in
  let blob = TA.get_audit_blob t in
  assert_that blob
    (all_of
       [
         field (fun (b : TA.audit_blob) -> b.audit_records) is_empty;
         field (fun (b : TA.audit_blob) -> b.cascade_summaries) is_empty;
       ])

(* Stop decisions (issue #2977) ----------------------------------------- *)

module SD = Weinstein_stops.Stop_decision

let _stop_decision ?(position_id = "AAPL-wein-1") ~date ~reason () : SD.t =
  {
    SD.date = _date date;
    position_id;
    state_before = SD.Trailing;
    state_after = SD.Trailing;
    stop_before = 90.0;
    stop_after = 90.0;
    candidate = None;
    correction_count_before = 0;
    correction_count = 0;
    last_trend_extreme = Some 110.0;
    last_correction_extreme = Some 104.0;
    ma_value = 100.0;
    reason;
  }

(** Decisions land on their entry's row in recording (= date) order. *)
let test_record_stop_decision_appends_to_the_entry_row _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_stop_decision t
    (_stop_decision ~date:"2024-01-19" ~reason:SD.Seeded_trailing ());
  TA.record_stop_decision t
    (_stop_decision ~date:"2024-01-26" ~reason:SD.No_correction_yet ());
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field
           (fun (r : TA.audit_record) -> r.stop_decisions)
           (elements_are
              [
                field (fun (d : SD.t) -> d.reason) (equal_to SD.Seeded_trailing);
                field
                  (fun (d : SD.t) -> d.reason)
                  (equal_to SD.No_correction_yet);
              ]);
       ])

(** No entry on record ⇒ the decision is dropped (the shared no-entry contract).
*)
let test_record_stop_decision_without_entry_is_dropped _ =
  let t = TA.create () in
  TA.record_stop_decision t
    (_stop_decision ~position_id:"GHOST-wein-9" ~date:"2024-01-19"
       ~reason:SD.Raised ());
  assert_that (TA.get_audit_records t) is_empty

(** Daily holds collapse to one row per ISO week, with no look-ahead: the week
    of 2024-03-25 ends on Thursday the 28th (Good Friday 2024-03-29 is a market
    holiday) and still keeps exactly one hold row, dated that Thursday. The next
    Monday's hold is a new week, so a new row; the Monday seed is not a hold, so
    it is never collapsed. *)
let test_record_stop_decision_collapses_holds_per_week _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_stop_decision t
    (_stop_decision ~date:"2024-03-25" ~reason:SD.Seeded_trailing ());
  List.iter [ "2024-03-26"; "2024-03-27"; "2024-03-28"; "2024-04-01" ]
    ~f:(fun date ->
      TA.record_stop_decision t
        (_stop_decision ~date ~reason:SD.No_correction_yet ()));
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field
           (fun (r : TA.audit_record) ->
             List.map r.stop_decisions ~f:(fun (d : SD.t) -> (d.date, d.reason)))
           (equal_to
              [
                (_date "2024-03-25", SD.Seeded_trailing);
                (_date "2024-03-28", SD.No_correction_yet);
                (_date "2024-04-01", SD.No_correction_yet);
              ]);
       ])

let test_audit_record_sexp_round_trips_stop_decisions _ =
  let record : TA.audit_record =
    {
      entry = make_entry ();
      exit_ = None;
      external_exit = None;
      execution = None;
      stop_decisions =
        [
          _stop_decision ~date:"2024-01-19" ~reason:SD.Correction_not_recovered
            ();
          _stop_decision ~date:"2024-01-26" ~reason:SD.Raised ();
        ];
    }
  in
  assert_that
    (TA.audit_record_of_sexp (TA.sexp_of_audit_record record))
    (equal_to record)

(** [@sexp.list]: an empty list is omitted, so a record with no decisions
    serialises exactly as a pre-#2977 record did — and that pre-#2977 shape
    parses back with [stop_decisions = []]. *)
let test_audit_record_sexp_omits_empty_stop_decisions _ =
  let record : TA.audit_record =
    {
      entry = make_entry ();
      exit_ = None;
      external_exit = None;
      execution = None;
      stop_decisions = [];
    }
  in
  let sexp = TA.sexp_of_audit_record record in
  assert_that
    ( String.is_substring (Sexp.to_string sexp) ~substring:"stop_decisions",
      (TA.audit_record_of_sexp sexp).stop_decisions )
    (pair (equal_to false) is_empty)

let suite =
  "Trade_audit"
  >::: [
         "cascade summary decisions round trip (#3139)"
         >:: test_cascade_summary_decisions_round_trip;
         "skip_reason sexp round-trip" >:: test_skip_reason_sexp_round_trip;
         "stop_floor_kind sexp round-trip"
         >:: test_stop_floor_kind_sexp_round_trip;
         "split_safe_basis sexp round-trip"
         >:: test_split_safe_basis_sexp_round_trip;
         "entry_decision sexp tolerates a missing split_safe_basis"
         >:: test_entry_decision_sexp_tolerates_missing_split_safe_basis;
         "entry_decision sexp tolerates missing E-provenance fields"
         >:: test_entry_decision_sexp_tolerates_missing_e_provenance_fields;
         "entry_decision sexp writes the screener_proxy_stop key"
         >:: test_entry_decision_sexp_writes_screener_proxy_stop_key;
         "legacy suggested_stop key parses into screener_proxy_stop"
         >:: test_legacy_suggested_stop_key_parses_into_screener_proxy_stop;
         "entry_decision sexp round-trips E-provenance fields"
         >:: test_entry_decision_sexp_round_trips_e_provenance_fields;
         "entry_decision sexp round-trips every ticket_lifecycle verdict"
         >:: test_entry_decision_sexp_round_trips_ticket_lifecycle;
         "entry_decision sexp tolerates a missing ticket_lifecycle"
         >:: test_entry_decision_sexp_tolerates_missing_ticket_lifecycle;
         "ticket_lifecycle sexp omits the unresolved fill/cancel fields"
         >:: test_ticket_lifecycle_sexp_omits_unresolved_fill_fields;
         "age_weeks clamps at zero" >:: test_age_weeks_clamps_at_zero;
         "record_fill_volume merges into the entry row"
         >:: test_record_fill_volume_merges_into_the_entry_row;
         "record_fill_volume without an entry is dropped"
         >:: test_record_fill_volume_without_entry_is_dropped;
         "record_stop_decision appends to the entry row"
         >:: test_record_stop_decision_appends_to_the_entry_row;
         "record_stop_decision without an entry is dropped"
         >:: test_record_stop_decision_without_entry_is_dropped;
         "record_stop_decision collapses holds per ISO week"
         >:: test_record_stop_decision_collapses_holds_per_week;
         "audit_record sexp round-trips stop_decisions"
         >:: test_audit_record_sexp_round_trips_stop_decisions;
         "audit_record sexp omits empty stop_decisions"
         >:: test_audit_record_sexp_omits_empty_stop_decisions;
         "CancelEntry records the resting age in weeks"
         >:: test_cancel_entry_records_the_resting_age_in_weeks;
         "cancel_reason distinguishes a portfolio rejection from a TTL cancel"
         >:: test_cancel_reason_distinguishes_rejection_from_ttl;
         "lifecycle merges are inert on a pre-PR-5 row"
         >:: test_lifecycle_merges_are_inert_on_a_pre_pr5_row;
         "record_reissue links the filled copy to its placement"
         >:: test_record_reissue_links_the_filled_copy_to_its_placement;
         "record_reissue without original is dropped"
         >:: test_record_reissue_without_original_is_dropped;
         "ticket_lifecycle sexp: reissued_from is optional"
         >:: test_ticket_lifecycle_sexp_reissued_from_is_optional;
         "alternative_candidate sexp round-trip"
         >:: test_alternative_candidate_sexp_round_trip;
         "entry_decision sexp round-trip"
         >:: test_entry_decision_sexp_round_trip;
         "exit_decision sexp round-trip" >:: test_exit_decision_sexp_round_trip;
         "external_exit_decision sexp round-trip"
         >:: test_external_exit_decision_sexp_round_trip;
         "audit_record sexp round-trip" >:: test_audit_record_sexp_round_trip;
         "audit_records list sexp round-trip"
         >:: test_audit_records_sexp_round_trip_through_top_level_codec;
         "empty collector returns []" >:: test_empty_collector_returns_empty;
         "record_entry appears in audit" >:: test_record_entry_appears_in_audit;
         "record_exit attaches to existing entry"
         >:: test_record_exit_attaches_to_existing_entry;
         "record_exit without entry is dropped"
         >:: test_record_exit_without_entry_is_dropped;
         "record_cash_rejection without entry is dropped"
         >:: test_record_cash_rejection_without_entry_is_dropped;
         "record_transitions captures margin_call as external_exit"
         >:: test_record_transitions_captures_margin_call_as_external_exit;
         "record_transitions captures any StrategySignal label"
         >:: test_record_transitions_captures_any_strategy_signal_label;
         "record_transitions: enriched exit wins, no overwrite"
         >:: test_record_transitions_enriched_exit_wins_no_overwrite;
         "record_transitions without entry is dropped"
         >:: test_record_transitions_without_entry_is_dropped;
         "record_transitions ignores non-TriggerExit transition kinds"
         >:: test_record_transitions_ignores_non_trigger_exit_kinds;
         "record_transitions ignores TriggerPartialExit"
         >:: test_record_transitions_ignores_partial_exit;
         "record_entry overwrites same position_id"
         >:: test_record_entry_overwrites_same_position_id;
         "get_audit_records sorts by position_id"
         >:: test_get_audit_records_sorts_by_position_id;
         "collector round-trips through sexp"
         >:: test_collector_round_trips_through_sexp;
         "cascade_summary sexp round-trip"
         >:: test_cascade_summary_sexp_round_trip;
         "cascade_summary without breadth_state defaults to Neutral_breadth"
         >:: test_cascade_summary_without_breadth_state_defaults;
         "record_cascade_summary appears in collector"
         >:: test_record_cascade_summary_appears_in_collector;
         "get_cascade_summaries sorts by date"
         >:: test_get_cascade_summaries_sorts_by_date;
         "audit_blob round-trips through sexp" >:: test_audit_blob_round_trip;
         "empty collector returns empty audit_blob"
         >:: test_empty_collector_returns_empty_blob;
       ]

let () = run_test_tt_main suite
