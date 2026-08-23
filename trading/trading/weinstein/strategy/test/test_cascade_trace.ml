(** Pins {!Weinstein_strategy.Cascade_trace} — the per-Friday capture handle
    that fills [Audit_recorder.cascade_event.candidates] for the
    [candidates.sexp] artefact (#2490).

    Two arms, both deterministic and free of any backtest run:

    - {b Capturing.} With [recorder.capture_candidates = true],
      {!Cascade_trace.on_walk_candidates} returns a sink, and whatever the entry
      walk hands that sink reaches the recorded [cascade_event] {i verbatim}.
      This is the hop the end-to-end pin cannot isolate: a [record] that emitted
      a constant [[]] instead of the walk's contents would still produce a
      structurally valid artefact — one week per Friday, every list empty —
      which reads as "the walk passed nothing over", the exact inverse of what
      the artefact exists to say.
    - {b Inert.} With [capture_candidates = false] (the default, and every
      non-audit context) {!Cascade_trace.on_walk_candidates} is [None], so the
      entry walk never computes the projection, and the emitted event carries
      [candidates = []] — bit-identical to the pre-#2490 cascade event. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module AR = Audit_recorder

let _date s = Date.of_string s
let _current_date = _date "2024-06-14"

let _stage_result : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
    ma_value = 100.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 8;
  }

let _stock_analysis ~ticker : Stock_analysis.t =
  {
    ticker;
    stage = _stage_result;
    rs = None;
    volume = None;
    resistance = None;
    support = None;
    breakout_price = None;
    breakdown_price = None;
    local_range_top = None;
    prior_stage = None;
    continuation = None;
    supply = None;
    virgin_readmission = false;
    range_top_freshness = None;
    require_breakout_volume = true;
    current_close = None;
    as_of_date = _current_date;
  }

let _candidate ~ticker : Screener.scored_candidate =
  {
    ticker;
    analysis = _stock_analysis ~ticker;
    sector =
      {
        sector_name = "Test";
        rating = Neutral;
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
      };
    side = Trading_base.Types.Long;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = 100.0;
    suggested_stop = 92.0;
    risk_pct = 0.08;
    rationale = [ "test breakout" ];
    swing_target = None;
  }

(* Two elements, distinct in both ticker and reason, so a [record] that dropped
   one, reordered them, or substituted a constant fails the pin rather than
   passing by coincidence. *)
let _walk_contents : AR.alternative_input list =
  [
    { candidate = _candidate ~ticker:"AAAA"; reason = AR.Insufficient_cash };
    { candidate = _candidate ~ticker:"BBBB"; reason = AR.Sector_exposure_cap };
  ]

let _diagnostics : Screener.cascade_diagnostics =
  {
    total_stocks = 40;
    candidates_after_held = 38;
    macro_trend = Weinstein_types.Bullish;
    long_macro_admitted = 38;
    long_breakout_admitted = 9;
    long_failed_breakout_dropped = 0;
    long_sector_admitted = 6;
    long_grade_admitted = 4;
    long_top_n_admitted = 2;
    short_macro_admitted = 0;
    short_breakdown_admitted = 0;
    short_sector_admitted = 0;
    short_rs_hard_gate_admitted = 0;
    short_grade_admitted = 0;
    short_top_n_admitted = 0;
  }

(** A recorder that captures the one [cascade_event] {!Cascade_trace.record}
    routes through it. [capture_candidates] is the only knob under test. *)
let _capturing_recorder ~capture_candidates =
  let captured = ref None in
  let recorder =
    {
      AR.noop with
      capture_candidates;
      record_cascade_summary = (fun e -> captured := Some e);
    }
  in
  (recorder, captured)

(* A minimal screener result carrying the diagnostics under test. The
   candidate lists are empty, so [record]'s drop derivation is a no-op and the
   unit under test stays the walk-capture hop (G2's drop derivation is pinned
   by the screener anti-drift tests). *)
let _screen_result : Screener.result =
  {
    buy_candidates = [];
    short_candidates = [];
    watchlist = [];
    macro_trend = Weinstein_types.Bullish;
    cascade_diagnostics = _diagnostics;
  }

(** Drive one Friday: create the handle, feed the sink whatever the entry walk
    would have passed over (when the handle offers one), then record. Returns
    the sink option and the event the recorder saw. *)
let _run_one_friday ~capture_candidates =
  let recorder, captured = _capturing_recorder ~capture_candidates in
  let t = Cascade_trace.create recorder in
  let sink = Cascade_trace.on_walk_candidates t in
  Option.iter sink ~f:(fun f -> f _walk_contents);
  Cascade_trace.record t ~audit_recorder:recorder ~date:_current_date
    ~config:Screener.default_config ~macro_trend:Weinstein_types.Bullish
    ~result:_screen_result ~entered:0;
  (sink, !captured)

(* ------------------------------------------------------------------ *)
(* Capturing arm                                                        *)
(* ------------------------------------------------------------------ *)

(** The load-bearing pin: what the walk handed the sink is what the recorded
    event carries — same tickers, same reasons, same order. [entered = 0] keeps
    it on the G1 shape (a Friday that funded nothing still reports its walk). *)
let test_capture_on_routes_walk_contents_to_the_event _ =
  let _, event = _run_one_friday ~capture_candidates:true in
  assert_that event
    (is_some_and
       (all_of
          [
            field
              (fun (e : AR.cascade_event) -> e.date)
              (equal_to _current_date);
            field (fun (e : AR.cascade_event) -> e.entered) (equal_to 0);
            field
              (fun (e : AR.cascade_event) -> e.candidates)
              (elements_are
                 [
                   all_of
                     [
                       field
                         (fun (a : AR.alternative_input) -> a.candidate.ticker)
                         (equal_to "AAAA");
                       field
                         (fun (a : AR.alternative_input) -> a.reason)
                         (equal_to AR.Insufficient_cash);
                     ];
                   all_of
                     [
                       field
                         (fun (a : AR.alternative_input) -> a.candidate.ticker)
                         (equal_to "BBBB");
                       field
                         (fun (a : AR.alternative_input) -> a.reason)
                         (equal_to AR.Sector_exposure_cap);
                     ];
                 ]);
          ]))

(** With capture on the handle must offer a sink at all — the entry walk's
    [?on_candidates_considered] is [Option.iter]-ed, so a [None] here silently
    disables the whole feature. *)
let test_capture_on_offers_a_sink _ =
  let sink, _ = _run_one_friday ~capture_candidates:true in
  assert_that (Option.is_some sink) (equal_to true)

(* ------------------------------------------------------------------ *)
(* Inert arm — the default path                                         *)
(* ------------------------------------------------------------------ *)

(** No sink when the recorder did not opt in, so the entry walk never computes
    [all_alternatives_of_decisions] and the default path allocates nothing. *)
let test_capture_off_offers_no_sink _ =
  let sink, _ = _run_one_friday ~capture_candidates:false in
  assert_that sink is_none

(** The inert handle still records the Friday's event — counts and date are
    unchanged from the pre-#2490 shape — but with an empty candidate list. *)
let test_capture_off_records_an_empty_candidate_list _ =
  let _, event = _run_one_friday ~capture_candidates:false in
  assert_that event
    (is_some_and
       (all_of
          [
            field
              (fun (e : AR.cascade_event) -> e.date)
              (equal_to _current_date);
            field
              (fun (e : AR.cascade_event) -> e.diagnostics.long_top_n_admitted)
              (equal_to 2);
            field (fun (e : AR.cascade_event) -> e.candidates) (size_is 0);
          ]))

let () =
  run_test_tt_main
    ("cascade_trace"
    >::: [
           "capture on routes the walk's contents to the event"
           >:: test_capture_on_routes_walk_contents_to_the_event;
           "capture on offers a sink" >:: test_capture_on_offers_a_sink;
           "capture off offers no sink" >:: test_capture_off_offers_no_sink;
           "capture off records an empty candidate list"
           >:: test_capture_off_records_an_empty_candidate_list;
         ])
