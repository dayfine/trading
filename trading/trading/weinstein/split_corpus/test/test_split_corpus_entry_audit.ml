(** Split corpus x entry audit — the first concrete failing case of issue #2973.

    The 26y walkthrough read NVDA's 2021-04-23 entry as close 610.61 beside MA
    13.67. Both numbers were right, on different bases: [close_at_decision] is
    the RAW close (it prices the ticket), while the MA is the stage
    classifier's, built from ADJUSTED closes — and the corpus vintage
    back-adjusts NVDA for its later 4:1 (2021) and 10:1 (2024) splits, a 40x
    factor.

    The trading decision was never mixed: the classifier compares adjusted close
    with adjusted MA, and the ticket is raw on both sides. The defect was the
    record printing one of each. The fix adds [adjusted_close_at_decision], so
    the audit reports close-vs-MA on the classifier's (adjusted) basis while
    [close_at_decision] stays raw.

    Driven through the real [Entry_audit_capture.make_entry_transition] on the
    corpus's real NVDA bars, so a mis-wire of either close (raw where adjusted
    belongs, or the reverse) fails on the values themselves. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _entry_name = "NVDA-2021-07-20"
let _ticker = "NVDA"
let _decision_date = Date.of_string "2021-04-23"

(* The bar store's 2021-04-23 row: raw close and its back-adjusted close. *)
let _raw_close = 610.61
let _adjusted_close = 15.2091

(* Admit any stop width: this test is about the audit record, not the §5.1
   width gate (NVDA's real support floor sits ~20% under the close). *)
let _admit_any_width : Stop_width_mode.policy =
  { mode = Stop_width_mode.Size_down; size_down_max_pct = 1.0 }

let _load () : Split_corpus.entry =
  match Split_corpus.find_root () with
  | Some root -> Split_corpus.load ~root _entry_name
  | None -> assert_failure "trading/test_data/split_corpus not found above cwd"

(** The classifier's view on [_decision_date]: weekly bars built from the
    corpus's daily bars up to that date, classified on adjusted closes exactly
    as the screener does. *)
let _stage_on_decision_date (entry : Split_corpus.entry) : Stage.result =
  let bars =
    List.take_while entry.bars ~f:(fun (b : Types.Daily_price.t) ->
        Date.( <= ) b.date _decision_date)
  in
  Stage.classify ~config:Stage.default_config
    ~bars:
      (Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars)
    ~prior_stage:None

let _analysis (stage : Stage.result) : Stock_analysis.t =
  {
    ticker = _ticker;
    stage;
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
    as_of_date = _decision_date;
  }

let _candidate (stage : Stage.result) : Screener.scored_candidate =
  {
    ticker = _ticker;
    analysis = _analysis stage;
    sector =
      {
        sector_name = "Information Technology";
        rating = Screener.Neutral;
        stage = stage.stage;
      };
    side = Trading_base.Types.Long;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = _raw_close;
    suggested_stop = _raw_close *. 0.9;
    risk_pct = 0.1;
    swing_target = None;
    rationale = [ "split corpus" ];
  }

let _macro (stage : Stage.result) : Macro.result =
  {
    index_stage = stage;
    indicators = [];
    trend = Weinstein_types.Bullish;
    breadth_state = Weinstein_types.Bullish_breadth;
    confidence = 0.8;
    regime_changed = false;
    rationale = [ "split corpus" ];
  }

(** The audit [entry_event] for the NVDA 2021-04-23 entry, plus the classifier
    result it was built from. *)
let _entry_event () =
  let entry = _load () in
  let stage = _stage_on_decision_date entry in
  let cand = _candidate stage in
  let meta =
    match
      Entry_audit_capture.make_entry_transition ~stop_width:_admit_any_width
        ~portfolio_risk_config:Portfolio_risk.default_config
        ~stops_config:Weinstein_stops.default_config ~initial_stop_buffer:0.92
        ~stop_states:(ref String.Map.empty)
        ~bar_reader:(Bar_reader.of_in_memory_bars [ (_ticker, entry.bars) ])
        ~portfolio_value:1_000_000.0 ~current_date:_decision_date cand
    with
    | Entry_audit_capture.Entry_ok (_, meta) -> meta
    | _ -> assert_failure "make_entry_transition did not return Entry_ok"
  in
  ( stage,
    Entry_audit_emit.build_entry_event ~macro:(_macro stage)
      ~current_date:_decision_date ~candidate:cand ~meta ~alternatives:[] )

let _over_ma (stage : Stage.result) close =
  Option.map close ~f:(fun c -> c /. stage.ma_value)

(** The audit row carries both closes; the adjusted one sits a Stage-2 ~11%
    above the classifier's MA (issue: 15.21 vs 13.67), while the raw one is a
    whole split factor (40x) away — the mismatch the reader saw. The ticket
    itself stays raw: [effective_entry_price] is the raw close, so no trading
    decision moved. *)
let test_entry_audit_reports_close_vs_ma_on_one_basis _ =
  let stage, event = _entry_event () in
  assert_that event
    (all_of
       [
         field
           (fun (e : Audit_recorder.entry_event) -> e.close_at_decision)
           (is_some_and (float_equal _raw_close));
         field
           (fun (e : Audit_recorder.entry_event) ->
             e.adjusted_close_at_decision)
           (is_some_and (float_equal _adjusted_close));
         field
           (fun (e : Audit_recorder.entry_event) ->
             _over_ma stage e.adjusted_close_at_decision)
           (is_some_and (is_between (module Float_ord) ~low:1.0 ~high:1.25));
         field
           (fun (e : Audit_recorder.entry_event) ->
             _over_ma stage e.close_at_decision)
           (is_some_and (gt (module Float_ord) 30.0));
         field
           (fun (e : Audit_recorder.entry_event) ->
             e.initial_position_value /. Float.of_int e.shares)
           (float_equal ~epsilon:1e-6 _raw_close);
       ])

let suite =
  "split_corpus_entry_audit"
  >::: [
         "entry_audit_reports_close_vs_ma_on_one_basis"
         >:: test_entry_audit_reports_close_vs_ma_on_one_basis;
       ]

let () = run_test_tt_main suite
