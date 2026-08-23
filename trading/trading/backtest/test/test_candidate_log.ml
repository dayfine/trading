(** Tests for {!Backtest.Candidate_log} and its wiring through
    {!Backtest.Trade_audit_recorder} — the per-week candidate artefact (#2490).

    Three contracts are pinned here, in the order they matter:

    - {b The no-op.} Capture is opt-in. Without a collector the recorder reports
      [capture_candidates = false] (so the strategy skips the projection
      entirely) and [emit ~enabled:false] writes no file. This is what makes the
      feature safe to merge default-off.
    - {b The G1 regression.} A Friday that funded {e nothing} still emits its
      candidate list. That is the whole bug: [alternatives_considered] is
      reachable only from a funded entry's audit row, so a zero-funded Friday
      used to lose the walk's decisions entirely.
    - {b The projection.} [signals] is field-for-field the decision-time subset
      of [Trade_audit.alternative_candidate], so the two artefacts cannot
      disagree about a candidate's signals. *)

open OUnit2
open Core
open Matchers
module CL = Backtest.Candidate_log
module TA = Backtest.Trade_audit
module AR = Weinstein_strategy.Audit_recorder

let _date s = Date.of_string s

(* Every field carries a distinct value so a projection that crosses two fields
   (or hardcodes one) fails the pin rather than passing by coincidence. *)
let _alternative : TA.alternative_candidate =
  {
    symbol = "ZZZZ";
    side = Trading_base.Types.Long;
    score = 71;
    grade = Weinstein_types.A;
    reason_skipped = TA.Insufficient_cash;
    stage = Weinstein_types.Stage2 { weeks_advancing = 9; late = false };
    weeks_advancing = Some 9;
    rs_value = Some 1.31;
    volume_ratio = Some 2.4;
    sector_name = "Technology";
    score_components = [];
  }

let _ticker = "ZZZZ"

let _stage : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 9; late = false };
    ma_value = 97.5;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 9;
  }

let _stock_analysis : Stock_analysis.t =
  {
    ticker = _ticker;
    stage = _stage;
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
    as_of_date = _date "2024-06-14";
  }

let _scored_candidate : Screener.scored_candidate =
  {
    ticker = _ticker;
    analysis = _stock_analysis;
    sector =
      {
        sector_name = "Technology";
        rating = Neutral;
        stage = Weinstein_types.Stage2 { weeks_advancing = 9; late = false };
      };
    side = Trading_base.Types.Long;
    grade = Weinstein_types.A;
    score = 71;
    suggested_entry = 100.0;
    suggested_stop = 92.0;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

let _diagnostics ~long_top_n : Screener.cascade_diagnostics =
  {
    total_stocks = 40;
    candidates_after_held = 38;
    macro_trend = Weinstein_types.Bullish;
    long_macro_admitted = 38;
    long_breakout_admitted = 9;
    long_failed_breakout_dropped = 0;
    long_sector_admitted = 6;
    long_grade_admitted = 4;
    long_top_n_admitted = long_top_n;
    short_macro_admitted = 0;
    short_breakdown_admitted = 0;
    short_sector_admitted = 0;
    short_rs_hard_gate_admitted = 0;
    short_grade_admitted = 0;
    short_top_n_admitted = 0;
  }

(* ------------------------------------------------------------------ *)
(* The projection                                                       *)
(* ------------------------------------------------------------------ *)

let test_signals_project_field_for_field _ =
  assert_that
    (CL.signals_of_alternative _alternative)
    (equal_to
       ({
          score = 71;
          grade = Weinstein_types.A;
          stage = Weinstein_types.Stage2 { weeks_advancing = 9; late = false };
          weeks_advancing = Some 9;
          rs_value = Some 1.31;
          volume_ratio = Some 2.4;
          sector_name = "Technology";
        }
         : CL.signals))

(* ------------------------------------------------------------------ *)
(* Collector + window filter                                            *)
(* ------------------------------------------------------------------ *)

let _week date = { CL.date = _date date; candidates = [] }

let test_collector_keeps_record_order _ =
  let c = CL.create () in
  List.iter [ "2024-06-07"; "2024-06-14"; "2024-06-21" ] ~f:(fun d ->
      CL.record c (_week d));
  assert_that (CL.weeks c)
    (elements_are
       [
         field (fun (w : CL.week) -> w.date) (equal_to (_date "2024-06-07"));
         field (fun (w : CL.week) -> w.date) (equal_to (_date "2024-06-14"));
         field (fun (w : CL.week) -> w.date) (equal_to (_date "2024-06-21"));
       ])

(** Warmup-window screens must not reach the artefact — the same treatment
    [Trade_audit.cascade_summary]s get in [Runner._assemble_result]. The
    boundary week itself is kept. *)
let test_filter_from_drops_warmup_weeks _ =
  let weeks = List.map [ "2024-06-07"; "2024-06-14"; "2024-06-21" ] ~f:_week in
  assert_that
    (CL.filter_from weeks ~start_date:(_date "2024-06-14"))
    (elements_are
       [
         field (fun (w : CL.week) -> w.date) (equal_to (_date "2024-06-14"));
         field (fun (w : CL.week) -> w.date) (equal_to (_date "2024-06-21"));
       ])

(* ------------------------------------------------------------------ *)
(* Emission                                                             *)
(* ------------------------------------------------------------------ *)

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "candidate_log_test" "" in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      Core_unix.system (sprintf "rm -rf %s" (Filename.quote dir)) |> ignore)

let _candidates_path dir = Filename.concat dir "candidates.sexp"

let test_emit_disabled_writes_no_file _ =
  _with_temp_dir (fun dir ->
      CL.emit ~enabled:false ~scenario_dir:dir [ _week "2024-06-14" ];
      assert_that
        (Sys_unix.file_exists_exn (_candidates_path dir))
        (equal_to false))

let test_emit_enabled_round_trips _ =
  _with_temp_dir (fun dir ->
      let weeks =
        [
          {
            CL.date = _date "2024-06-14";
            candidates =
              [
                {
                  CL.symbol = "ZZZZ";
                  side = Trading_base.Types.Long;
                  outcome = CL.Admitted;
                  signals = CL.signals_of_alternative _alternative;
                };
              ];
          };
        ]
      in
      CL.emit ~enabled:true ~scenario_dir:dir weeks;
      assert_that
        (CL.t_of_sexp (Sexp.load_sexp (_candidates_path dir)))
        (equal_to weeks ~cmp:(List.equal CL.equal_week)))

(** Pins the failure-isolation contract ([candidate_log.mli]
    {i Failure isolation}): a writer failure — here an unwritable [scenario_dir]
    that does not exist — is logged to [stderr] and swallowed, never raised. The
    caller ([scenario_runner]) invokes [emit] unguarded {i after} [actual.sexp]
    is already on disk, so a raising diagnostic would abort a finished
    multi-hour backtest. Same shape as
    [test_scenario_post_step.ml::test_emit_swallows_runner_failure], whose
    contract this one claims parity with. *)
let test_emit_swallows_writer_failure _ =
  let raised =
    try
      CL.emit ~enabled:true
        ~scenario_dir:"/nonexistent-dir-for-candidate-log-test"
        [ _week "2024-06-14" ];
      false
    with _ -> true
  in
  assert_that raised (equal_to false)

(* ------------------------------------------------------------------ *)
(* Recorder wiring — the no-op and the G1 regression                    *)
(* ------------------------------------------------------------------ *)

let _recorder ?candidate_log () =
  Backtest.Trade_audit_recorder.of_collector ?candidate_log
    ~trade_audit:(TA.create ())
    ~force_liquidation_log:(Backtest.Force_liquidation_log.create ())
    ()

let test_capture_is_off_without_a_collector _ =
  assert_that (_recorder ()).capture_candidates (equal_to false)

let test_capture_is_on_with_a_collector _ =
  assert_that (_recorder ~candidate_log:(CL.create ()) ()).capture_candidates
    (equal_to true)

(** The G1 pin. [entered = 0] — nothing was funded this Friday — and the week
    still carries its candidates. Before #2490 this list existed only as a
    funded entry's [alternatives_considered], so with no funded entry it was
    dropped on the floor. *)
let test_zero_funded_week_still_carries_its_candidates _ =
  let c = CL.create () in
  let recorder = _recorder ~candidate_log:c () in
  recorder.record_cascade_summary
    {
      date = _date "2024-06-14";
      diagnostics = _diagnostics ~long_top_n:1;
      entered = 0;
      candidates =
        [ { AR.candidate = _scored_candidate; reason = AR.Insufficient_cash } ];
    };
  assert_that (CL.weeks c)
    (elements_are
       [
         all_of
           [
             field (fun (w : CL.week) -> w.date) (equal_to (_date "2024-06-14"));
             field
               (fun (w : CL.week) -> w.candidates)
               (elements_are
                  [
                    all_of
                      [
                        field
                          (fun (x : CL.candidate) -> x.symbol)
                          (equal_to _ticker);
                        (* Reaching the entry walk means the cascade admitted
                           it; naming the pre-top-N drops is G2's job. *)
                        field
                          (fun (x : CL.candidate) -> x.outcome)
                          (equal_to CL.Admitted);
                      ];
                  ]);
           ];
       ])

let () =
  run_test_tt_main
    ("candidate_log"
    >::: [
           "signals project field-for-field onto alternative_candidate"
           >:: test_signals_project_field_for_field;
           "collector keeps record order" >:: test_collector_keeps_record_order;
           "filter_from drops warmup weeks"
           >:: test_filter_from_drops_warmup_weeks;
           "emit disabled writes no file" >:: test_emit_disabled_writes_no_file;
           "emit enabled round-trips" >:: test_emit_enabled_round_trips;
           "emit swallows writer failures (does not raise)"
           >:: test_emit_swallows_writer_failure;
           "capture is off without a collector"
           >:: test_capture_is_off_without_a_collector;
           "capture is on with a collector"
           >:: test_capture_is_on_with_a_collector;
           "G1: zero-funded week still carries its candidates"
           >:: test_zero_funded_week_still_carries_its_candidates;
         ])
