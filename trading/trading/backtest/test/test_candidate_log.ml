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

let _week date =
  {
    CL.date = _date date;
    candidates = [];
    tickets_placed = None;
    long_cash_left_pct = None;
  }

(* A row off the top-N view: every field the pre-top-N writer knew about. *)
let _row ~symbol ~outcome : CL.candidate =
  {
    symbol;
    side = Trading_base.Types.Long;
    outcome;
    breakout_gate = None;
    signals = CL.signals_of_alternative _alternative;
    rank = None;
    walk = None;
    shadow = None;
  }

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
            (_week "2024-06-14") with
            candidates = [ _row ~symbol:"ZZZZ" ~outcome:CL.Admitted ];
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

(* #3139: with no candidate collector (capture off), the walk's decisions
   still reach [trade_audit.sexp]'s cascade summary, one outcome per name. *)
let test_decisions_reach_the_summary_without_capture _ =
  let trade_audit = TA.create () in
  let recorder =
    Backtest.Trade_audit_recorder.of_collector ~trade_audit
      ~force_liquidation_log:(Backtest.Force_liquidation_log.create ())
      ()
  in
  recorder.record_cascade_summary
    {
      date = _date "2024-06-14";
      diagnostics = _diagnostics ~long_top_n:2;
      breadth_state = Weinstein_types.Bullish_breadth;
      entered = 1;
      candidates = [];
      drops = [];
      long_cash_left_pct = None;
      decisions =
        [
          { AR.ranked = _scored_candidate; outcome = AR.Placed };
          {
            AR.ranked = _scored_candidate;
            outcome = AR.Skipped AR.Insufficient_cash;
          };
          {
            AR.ranked = _scored_candidate;
            outcome =
              AR.Skipped
                (AR.No_structural_stop
                   {
                     floor_kind = AR.Buffer_fallback;
                     floor_price = 46.0;
                     distance_pct = 0.08;
                   });
          };
        ];
    };
  assert_that
    (TA.get_cascade_summaries trade_audit)
    (elements_are
       [
         field
           (fun (s : TA.cascade_summary) -> s.decisions)
           (equal_to
              ([
                 {
                   symbol = _ticker;
                   side = Trading_base.Types.Long;
                   outcome = Placed;
                   stop_floor = None;
                 };
                 {
                   symbol = _ticker;
                   side = Trading_base.Types.Long;
                   outcome = Skipped Insufficient_cash;
                   stop_floor = None;
                 };
                 {
                   symbol = _ticker;
                   side = Trading_base.Types.Long;
                   outcome = Skipped No_structural_stop;
                   stop_floor =
                     Some
                       {
                         floor_kind = Buffer_fallback;
                         floor_price = 46.0;
                         distance_pct = 0.08;
                       };
                 };
               ]
                : TA.weekly_decision list));
       ])

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
      breadth_state = Weinstein_types.Bullish_breadth;
      entered = 0;
      candidates =
        [ { AR.candidate = _scored_candidate; reason = AR.Insufficient_cash } ];
      drops = [];
      decisions = [];
      long_cash_left_pct = None;
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

(* ------------------------------------------------------------------ *)
(* G2 — the cascade population                                          *)
(* ------------------------------------------------------------------ *)

let _drop ?top_n ~ticker ~(phase : Screener.cascade_phase) () : AR.cascade_drop
    =
  {
    analysis = { _stock_analysis with ticker };
    sector =
      {
        sector_name = "Technology";
        rating = Neutral;
        stage = Weinstein_types.Stage2 { weeks_advancing = 9; late = false };
      };
    side = Trading_base.Types.Long;
    outcome = { ticker; phase; score = 71; grade = Weinstein_types.A };
    top_n;
  }

(* Drive one cascade event through the recorder; the one week it records. *)
let _record_week ?(entered = 0) ?long_cash_left_pct ~drops ~candidates () =
  let c = CL.create () in
  (_recorder ~candidate_log:c ()).record_cascade_summary
    {
      date = _date "2024-06-14";
      diagnostics = _diagnostics ~long_top_n:1;
      breadth_state = Weinstein_types.Bullish_breadth;
      entered;
      candidates;
      drops;
      decisions = [];
      long_cash_left_pct;
    };
  match CL.weeks c with
  | [ w ] -> w
  | ws ->
      assert_failure
        (sprintf "expected exactly one week, got %d" (List.length ws))

let _week_with ~drops ~candidates =
  (_record_week ~drops ~candidates ()).candidates

(* One ticker per [Screener.cascade_phase] constructor, paired with the
   artefact outcome [_outcome_of_phase] must produce for it. Exhaustive by
   construction: the phase enum is closed at seven, and this list names all
   seven, so a transposition of two adjacent constructors (the failure mode a
   compile error cannot catch, since both arms typecheck either way) moves a
   ticker's outcome and fails the pin. *)
let _phase_cases : (string * Screener.cascade_phase * CL.cascade_outcome) list =
  [
    ("AAAA", Admitted, CL.Admitted);
    ("BBBB", Dropped_at_macro, CL.Dropped_at_macro);
    ("CCCC", Dropped_at_breakout Price_floor, CL.Dropped_at_breakout);
    ("DDDD", Dropped_at_sector, CL.Dropped_at_sector);
    ("EEEE", Dropped_at_rs, CL.Dropped_at_rs);
    ("FFFF", Dropped_at_grade, CL.Dropped_at_grade);
    ("GGGG", Dropped_at_top_n, CL.Dropped_at_top_n);
  ]

(** Every cascade phase reaches the artefact under its own name — the drops are
    what G2 adds over G1's top-N-only view. A mapping that collapsed two phases,
    or swapped two of them, would fail here rather than silently mislabel a
    candidate. All seven constructors are exercised; see {!_phase_cases}. *)
let test_drops_carry_their_cascade_phase _ =
  let week =
    _week_with ~candidates:[]
      ~drops:
        (List.map _phase_cases ~f:(fun (ticker, phase, _) ->
             _drop ~ticker ~phase ()))
  in
  assert_that
    (List.map week ~f:(fun (x : CL.candidate) -> (x.symbol, x.outcome)))
    (equal_to
       (List.map _phase_cases ~f:(fun (ticker, _, outcome) -> (ticker, outcome))))

(** The cascade population already contains the entry walk's top-N as its
    [Admitted] tail, so emitting the G1 list alongside it would double-count
    those names under two different outcome vocabularies. *)
let test_drops_supersede_the_entry_walk_list _ =
  assert_that
    (_week_with
       ~candidates:
         [ { AR.candidate = _scored_candidate; reason = AR.Insufficient_cash } ]
       ~drops:[ _drop ~ticker:"AAAA" ~phase:Admitted () ])
    (elements_are
       [ field (fun (x : CL.candidate) -> x.symbol) (equal_to "AAAA") ])

(** A G1-only caller — no trace captured — keeps the pre-G2 behaviour exactly:
    the entry-walk list is still the week's population. *)
let test_no_drops_falls_back_to_the_entry_walk_list _ =
  assert_that
    (_week_with ~drops:[]
       ~candidates:
         [ { AR.candidate = _scored_candidate; reason = AR.Insufficient_cash } ])
    (elements_are
       [ field (fun (x : CL.candidate) -> x.symbol) (equal_to _ticker) ])

(** The two projections into {!CL.signals} — one off an [alternative_candidate]
    (entry-walk rows), one off a [Stock_analysis.t] (cascade rows) — must agree
    on a candidate reachable through both, or one artefact would describe the
    same name two ways depending on how far it got.

    The analysis fixture carries real [rs] / [volume] results rather than
    [None], so the two extractions are compared where they actually do work:
    with both absent, an [rs_value] / [volume_ratio] swap would be invisible. *)
let test_both_signal_projections_agree _ =
  let analysis =
    {
      _stock_analysis with
      rs =
        Some
          {
            current_rs = 1.05;
            current_normalized = 1.31;
            trend = Weinstein_types.Positive_rising;
            history = [];
          };
      volume =
        Some
          {
            confirmation = Weinstein_types.Strong 2.4;
            event_volume = 2400;
            avg_volume = 1000.0;
            volume_ratio = 2.4;
          };
    }
  in
  assert_that
    (CL.signals_of_analysis ~analysis ~sector_name:_alternative.sector_name
       ~score:_alternative.score ~grade:_alternative.grade)
    (equal_to (CL.signals_of_alternative _alternative))

(* ------------------------------------------------------------------ *)
(* G3 — the breakout sub-reason (#2533)                                 *)
(* ------------------------------------------------------------------ *)

(* One ticker per [Screener.breakout_gate] constructor, paired with the
   artefact gate [_gate_of_screener_gate] must produce for it. Exhaustive by
   construction: the gate enum is closed at six and this list names all six, so
   a transposition of two adjacent constructors — which typechecks either way,
   and which would silently reattribute drops between dials — moves a ticker's
   gate and fails the pin. *)
let _gate_cases : (string * Screener.breakout_gate * CL.breakout_gate) list =
  [
    ("HAAA", Price_floor, CL.Price_floor);
    ("HBBB", Stage_setup, CL.Stage_setup);
    ("HCCC", Breakout_volume, CL.Breakout_volume);
    ("HDDD", Rs_declining, CL.Rs_declining);
    ("HEEE", Failed_breakout, CL.Failed_breakout);
    ("HFFF", Volume_band, CL.Volume_band);
  ]

(** Each breakout sub-gate reaches the artefact under its own name. Without
    this, [Dropped_at_breakout] stays the single opaque bucket #2490 measured
    killing 51% of book-conformant candidates. *)
let test_breakout_drops_carry_their_sub_gate _ =
  let week =
    _week_with ~candidates:[]
      ~drops:
        (List.map _gate_cases ~f:(fun (ticker, gate, _) ->
             _drop ~ticker ~phase:(Dropped_at_breakout gate) ()))
  in
  assert_that
    (List.map week ~f:(fun (x : CL.candidate) -> (x.symbol, x.breakout_gate)))
    (equal_to
       (List.map _gate_cases ~f:(fun (ticker, _, gate) -> (ticker, Some gate))))

(** The sub-gate is [None] on every non-breakout row, so a reader can treat
    [Some _] as "this row was dropped in the breakout phase" without also
    consulting [outcome]. Covers all six non-breakout phases plus a G1
    entry-walk row, which has no cascade phase at all. *)
let test_non_breakout_rows_carry_no_sub_gate _ =
  let week =
    _week_with
      ~candidates:
        [ { AR.candidate = _scored_candidate; reason = AR.Insufficient_cash } ]
      ~drops:
        (List.filter_map _phase_cases ~f:(fun (ticker, phase, _) ->
             match phase with
             | Screener.Dropped_at_breakout _ -> None
             | _ -> Some (_drop ~ticker ~phase ())))
  in
  assert_that
    (List.count week ~f:(fun (x : CL.candidate) ->
         Option.is_some x.breakout_gate))
    (equal_to 0)

(** Back-compat pin: a [candidates.sexp] written before #2533 has no
    [breakout_gate] field on any row, and this module must still read it —
    [@sexp.option] accepts the absent field as [None]. Written as a literal
    rather than round-tripped through {!CL.sexp_of_week}, because the point is
    to hold the {i old} on-disk shape fixed even as the type grows. *)
let test_parses_pre_g3_candidates_sexp _ =
  let legacy =
    Sexp.of_string
      {|((date 2024-06-14)
         (candidates
           (((symbol ZZZZ) (side Long) (outcome Dropped_at_breakout)
             (signals ((score 71) (grade A)
                       (stage (Stage2 (weeks_advancing 9) (late false)))
                       (weeks_advancing (9)) (rs_value (1.31))
                       (volume_ratio (2.4)) (sector_name Technology)))))))|}
  in
  assert_that
    (List.map (CL.week_of_sexp legacy).candidates ~f:(fun (x : CL.candidate) ->
         (x.outcome, x.breakout_gate)))
    (elements_are [ equal_to (CL.Dropped_at_breakout, None) ])

(** The write half of the additive-format claim: a row with no sub-gate emits no
    [breakout_gate] field, so a file whose rows all pre-date the decomposition
    is byte-identical to what the pre-#2533 writer produced. *)
let test_absent_sub_gate_is_omitted_from_the_sexp _ =
  let sexp =
    CL.sexp_of_week
      {
        (_week "2024-06-14") with
        candidates = [ _row ~symbol:"ZZZZ" ~outcome:CL.Admitted ];
      }
  in
  assert_that
    (String.is_substring (Sexp.to_string sexp) ~substring:"breakout_gate")
    (equal_to false)

(* ------------------------------------------------------------------ *)
(* The top-N view                                                       *)
(* ------------------------------------------------------------------ *)

let _top_n rank verdict = { AR.Top_n.rank; verdict }

let _walked outcome stop_distance_pct =
  AR.Top_n.Walked { outcome; stop_distance_pct }

(** Rank reaches both row kinds that cleared the cascade — the kept ([Admitted])
    and the cut ([Dropped_at_top_n]) — and no other. *)
let test_rank_on_both_row_kinds _ =
  let week =
    _week_with ~candidates:[]
      ~drops:
        [
          _drop ~ticker:"AAAA" ~phase:Admitted
            ~top_n:(_top_n 3 (_walked AR.Placed (Some 0.07)))
            ();
          _drop ~ticker:"GGGG" ~phase:Dropped_at_top_n
            ~top_n:(_top_n 21 (AR.Top_n.Shadow (Buyable 0.09)))
            ();
          _drop ~ticker:"FFFF" ~phase:Dropped_at_grade ();
        ]
  in
  assert_that
    (List.map week ~f:(fun (x : CL.candidate) -> (x.symbol, x.rank)))
    (equal_to [ ("AAAA", Some 3); ("GGGG", Some 21); ("FFFF", None) ])

(* One cut row per shadow constructor, paired with the on-disk verdict the hop
   must produce. All four, so a transposition fails the pin. *)
let _shadow_cases : (AR.Top_n.shadow * CL.shadow_verdict) list =
  [
    (Buyable 0.09, CL.Buyable 0.09);
    (No_structural_stop, CL.No_structural_stop);
    (Stop_too_wide 0.22, CL.Stop_too_wide 0.22);
    (Already_held, CL.Already_held);
  ]

(** Every shadow constructor reaches the [Dropped_at_top_n] row under its own
    name with its distance; a cut row never carries a walk outcome. *)
let test_every_shadow_verdict_reaches_the_row _ =
  let week =
    _week_with ~candidates:[]
      ~drops:
        (List.mapi _shadow_cases ~f:(fun i (shadow, _) ->
             _drop ~ticker:(sprintf "S%d" i) ~phase:Dropped_at_top_n
               ~top_n:(_top_n (21 + i) (AR.Top_n.Shadow shadow))
               ()))
  in
  assert_that
    (List.map week ~f:(fun (x : CL.candidate) -> (x.walk, x.shadow)))
    (equal_to
       (List.map _shadow_cases ~f:(fun (_, verdict) -> (None, Some verdict))))

(** An [Admitted] row carries what the walk did: a funded name with its stop
    distance, a [Stop_too_wide] skip with the distance the gate measured, and a
    name the walk never reached with neither. A kept row never carries a shadow.
*)
let test_admitted_rows_carry_the_walk_outcome _ =
  let week =
    _week_with ~candidates:[]
      ~drops:
        [
          _drop ~ticker:"AAAA" ~phase:Admitted
            ~top_n:(_top_n 1 (_walked AR.Placed (Some 0.07)))
            ();
          _drop ~ticker:"BBBB" ~phase:Admitted
            ~top_n:
              (_top_n 2 (_walked (AR.Skipped AR.Stop_too_wide) (Some 0.22)))
            ();
          _drop ~ticker:"CCCC" ~phase:Admitted
            ~top_n:(_top_n 3 AR.Top_n.Not_reached)
            ();
        ]
  in
  assert_that
    (List.map week ~f:(fun (x : CL.candidate) -> (x.walk, x.shadow)))
    (equal_to
       ([
          (Some { result = Funded; stop_distance_pct = Some 0.07 }, None);
          ( Some
              {
                result = Skipped TA.Stop_too_wide;
                stop_distance_pct = Some 0.22;
              },
            None );
          (Some { result = Not_reached; stop_distance_pct = None }, None);
        ]
         : (CL.walk_result option * CL.shadow_verdict option) list))

(** The week carries the walk's ticket count and the long side's unspent cash.
*)
let test_week_carries_tickets_and_long_cash _ =
  assert_that
    (_record_week ~entered:2 ~long_cash_left_pct:0.31 ~drops:[] ~candidates:[]
       ())
    (all_of
       [
         field (fun (w : CL.week) -> w.tickets_placed) (equal_to (Some 2));
         field
           (fun (w : CL.week) -> w.long_cash_left_pct)
           (is_some_and (float_equal 0.31));
       ])

(** Back-compat pin: a [candidates.sexp] written before the top-N view — no
    [rank] / [walk] / [shadow] on any row, no [tickets_placed] /
    [long_cash_left_pct] on the week — still parses, with every new field
    [None]. A literal, so the old on-disk shape stays fixed as the type grows.
*)
let test_parses_pre_top_n_candidates_sexp _ =
  let legacy =
    Sexp.of_string
      {|((date 2024-06-14)
         (candidates
           (((symbol GGGG) (side Long) (outcome Dropped_at_top_n)
             (signals ((score 71) (grade A)
                       (stage (Stage2 (weeks_advancing 9) (late false)))
                       (weeks_advancing (9)) (rs_value (1.31))
                       (volume_ratio (2.4)) (sector_name Technology)))))))|}
  in
  assert_that (CL.week_of_sexp legacy)
    (all_of
       [
         field (fun (w : CL.week) -> w.tickets_placed) is_none;
         field (fun (w : CL.week) -> w.long_cash_left_pct) is_none;
         field
           (fun (w : CL.week) -> w.candidates)
           (elements_are
              [
                field
                  (fun (x : CL.candidate) ->
                    (x.outcome, x.rank, x.walk, x.shadow))
                  (equal_to (CL.Dropped_at_top_n, None, None, None));
              ]);
       ])

(** The write half: a week whose rows carry the whole top-N view round-trips
    through its sexp, so a reader recovers exactly what the writer saw. *)
let test_top_n_week_round_trips _ =
  let week =
    {
      (_week "2024-06-14") with
      tickets_placed = Some 2;
      long_cash_left_pct = Some 0.31;
      candidates =
        [
          {
            (_row ~symbol:"AAAA" ~outcome:CL.Admitted) with
            rank = Some 1;
            walk =
              Some
                {
                  result = Skipped TA.Stop_too_wide;
                  stop_distance_pct = Some 0.22;
                };
          };
          {
            (_row ~symbol:"GGGG" ~outcome:CL.Dropped_at_top_n) with
            rank = Some 21;
            shadow = Some (CL.Buyable 0.09);
          };
        ];
    }
  in
  assert_that (CL.week_of_sexp (CL.sexp_of_week week)) (equal_to week)

(** A row off the top-N view prints none of the new fields, and neither does a
    week built without them: such a file is byte-identical to what the pre-top-N
    writer produced. *)
let test_absent_top_n_fields_are_omitted _ =
  let printed =
    Sexp.to_string
      (CL.sexp_of_week
         {
           (_week "2024-06-14") with
           candidates = [ _row ~symbol:"ZZZZ" ~outcome:CL.Dropped_at_grade ];
         })
  in
  assert_that
    (List.filter
       [ "rank"; "walk"; "shadow"; "tickets_placed"; "long_cash_left_pct" ]
       ~f:(fun name -> String.is_substring printed ~substring:name))
    (size_is 0)

let () =
  run_test_tt_main
    ("candidate_log"
    >::: [
           "top-N: rank on both row kinds" >:: test_rank_on_both_row_kinds;
           "top-N: every shadow verdict reaches the row"
           >:: test_every_shadow_verdict_reaches_the_row;
           "top-N: admitted rows carry the walk outcome"
           >:: test_admitted_rows_carry_the_walk_outcome;
           "top-N: week carries tickets and long cash"
           >:: test_week_carries_tickets_and_long_cash;
           "top-N: parses a pre-top-N candidates.sexp"
           >:: test_parses_pre_top_n_candidates_sexp;
           "top-N: a top-N week round-trips" >:: test_top_n_week_round_trips;
           "top-N: absent fields are omitted from the sexp"
           >:: test_absent_top_n_fields_are_omitted;
           "#3139: decisions reach the summary without capture"
           >:: test_decisions_reach_the_summary_without_capture;
           "G3: breakout drops carry their sub-gate"
           >:: test_breakout_drops_carry_their_sub_gate;
           "G3: non-breakout rows carry no sub-gate"
           >:: test_non_breakout_rows_carry_no_sub_gate;
           "G3: parses a pre-#2533 candidates.sexp"
           >:: test_parses_pre_g3_candidates_sexp;
           "G3: absent sub-gate is omitted from the sexp"
           >:: test_absent_sub_gate_is_omitted_from_the_sexp;
           "G2: drops carry their cascade phase"
           >:: test_drops_carry_their_cascade_phase;
           "G2: drops supersede the entry-walk list"
           >:: test_drops_supersede_the_entry_walk_list;
           "G2: no drops falls back to the entry-walk list"
           >:: test_no_drops_falls_back_to_the_entry_walk_list;
           "G2: both signal projections agree"
           >:: test_both_signal_projections_agree;
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
