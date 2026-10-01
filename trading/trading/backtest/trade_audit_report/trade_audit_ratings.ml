(** Per-trade ratings, behavioural metrics, and Weinstein-conformance scoring.

    See [trade_audit_ratings.mli] for the contract. *)

open Core
module TA = Backtest.Trade_audit
module WT = Weinstein_types
include Trade_audit_ratings_types
include Trade_audit_ratings_behavioral
include Trade_audit_ratings_rules

(* Look up the pre-entry daily closes for a record's symbol. Defaults to "no
   bar source" — R6 then reports N/A. The report/bin wires a snapshot-backed
   lookup so R6 evaluates on the same bars the strategy screened on. *)
type closes_lookup = symbol:string -> as_of:Date.t -> pre_entry_closes

let _no_closes_lookup : closes_lookup = fun ~symbol:_ ~as_of:_ -> _no_closes

let evaluate_rules ?(pre_entry_closes = _no_closes) ~config
    (record : TA.audit_record) : rule_evaluation list =
  let e = record.entry in
  let x = record.exit_ in
  [
    { rule = R1_long_above_30w_ma_flat_or_rising; outcome = _eval_r1 e };
    { rule = R2_long_breakout_volume_2x; outcome = _eval_r2 ~config e };
    { rule = R3_no_long_in_stage_4; outcome = _eval_r3 e };
    { rule = R4_short_below_30w_ma_flat_or_falling; outcome = _eval_r4 e };
    { rule = R5_short_stage_4_breakdown; outcome = _eval_r5 e };
    {
      rule = R6_no_recent_plunge;
      outcome = _eval_r6 ~config ~closes:pre_entry_closes e;
    };
    {
      rule = R7_exit_on_stage_3_to_4;
      outcome = _eval_r7 e x record.external_exit;
    };
    { rule = R8_macro_alignment; outcome = _eval_r8 e };
  ]

(* Resolve the pre-entry closes for a record via [closes_lookup]. *)
let _closes_for (closes_lookup : closes_lookup) (record : TA.audit_record) =
  closes_lookup ~symbol:record.entry.symbol ~as_of:record.entry.entry_date

let _outcome_weight = function
  | Pass -> Some 1.0
  | Marginal -> Some 0.5
  | Fail -> Some 0.0
  | Not_applicable -> None

let score_of_rules (evals : rule_evaluation list) : float =
  let weights = List.filter_map evals ~f:(fun e -> _outcome_weight e.outcome) in
  match weights with
  | [] -> Float.nan
  | _ ->
      List.fold weights ~init:0.0 ~f:( +. )
      /. Float.of_int (List.length weights)

(* Per-trade rating ------------------------------------------------------- *)

let _hold_time_anomaly_of (trade : Trading_simulation.Metrics.trade_metrics) =
  if trade.days_held <= 3 then Stopped_immediately
  else if trade.days_held >= 365 then Held_indefinitely
  else Normal

let _outcome_of (trade : Trading_simulation.Metrics.trade_metrics) =
  if Float.( > ) trade.pnl_dollars 0.0 then Win else Loss

let _r_multiple_of (record : TA.audit_record)
    (trade : Trading_simulation.Metrics.trade_metrics) =
  if Float.( <= ) record.entry.initial_risk_dollars 0.0 then Float.nan
  else trade.pnl_dollars /. record.entry.initial_risk_dollars

let _mfe_mae_of (record : TA.audit_record) =
  match record.exit_ with
  | Some x -> (x.max_favorable_excursion_pct, x.max_adverse_excursion_pct)
  | None -> (0.0, 0.0)

let rate ?(pre_entry_closes = _no_closes) ~config (record : TA.audit_record)
    (trade : Trading_simulation.Metrics.trade_metrics) : rating =
  let evals = evaluate_rules ~pre_entry_closes ~config record in
  let mfe, mae = _mfe_mae_of record in
  {
    symbol = record.entry.symbol;
    entry_date = record.entry.entry_date;
    r_multiple = _r_multiple_of record trade;
    mfe_pct = mfe;
    mae_pct = mae;
    hold_time_anomaly = _hold_time_anomaly_of trade;
    outcome = _outcome_of trade;
    weinstein_score = score_of_rules evals;
  }

(* Joining audit + trades -------------------------------------------------- *)

let rate_all ?(closes_lookup = _no_closes_lookup) ~config ~audit ~trades () =
  let idx = audit_index audit in
  List.filter_map trades
    ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
      match Map.find idx t.symbol with
      | None -> None
      | Some records ->
          nearest_within ~entry_date:t.entry_date
            ~date_of:(fun (r : TA.audit_record) -> r.entry.entry_date)
            records
          |> Option.map ~f:(fun record ->
              rate
                ~pre_entry_closes:(_closes_for closes_lookup record)
                ~config record t))

(* Weinstein aggregate ---------------------------------------------------- *)

let _summarise_rule (rule : rule_id)
    (evals_per_trade : rule_evaluation list list) : rule_violation_summary =
  let outcomes =
    List.filter_map evals_per_trade ~f:(fun evals ->
        List.find evals ~f:(fun (e : rule_evaluation) ->
            equal_rule_id e.rule rule)
        |> Option.map ~f:(fun (e : rule_evaluation) -> e.outcome))
  in
  let applicable =
    List.filter outcomes ~f:(fun o -> not (equal_rule_outcome o Not_applicable))
  in
  let fails = List.count applicable ~f:(equal_rule_outcome Fail) in
  let marginals = List.count applicable ~f:(equal_rule_outcome Marginal) in
  let passes = List.count applicable ~f:(equal_rule_outcome Pass) in
  let n = List.length applicable in
  let pct =
    if n = 0 then 0.0 else Float.of_int passes /. Float.of_int n *. 100.0
  in
  {
    rule;
    fail_count = fails;
    marginal_count = marginals;
    applicable_count = n;
    pass_rate_pct = pct;
  }

let _critical_violations ~config audit =
  List.filter_map audit ~f:(fun (record : TA.audit_record) ->
      let evals = evaluate_rules ~config record in
      let r3 =
        List.find evals ~f:(fun e -> equal_rule_id e.rule R3_no_long_in_stage_4)
      in
      match r3 with
      | Some { outcome = Fail; _ } ->
          Some
            {
              symbol = record.entry.symbol;
              entry_date = record.entry.entry_date;
              metric = "Long entered in Stage 4 (R3 violation)";
            }
      | _ -> None)

let weinstein_aggregate_of ?(closes_lookup = _no_closes_lookup) ~config ~ratings
    ~audit () : weinstein_aggregate =
  let evals_per_trade =
    List.map audit ~f:(fun record ->
        evaluate_rules
          ~pre_entry_closes:(_closes_for closes_lookup record)
          ~config record)
  in
  let per_rule =
    List.map all_rules ~f:(fun r -> _summarise_rule r evals_per_trade)
  in
  let scores =
    List.filter_map ratings ~f:(fun r ->
        if Float.is_nan r.weinstein_score then None else Some r.weinstein_score)
  in
  let spirit =
    match scores with
    | [] -> Float.nan
    | _ ->
        List.fold scores ~init:0.0 ~f:( +. )
        /. Float.of_int (List.length scores)
  in
  {
    per_rule;
    spirit_score = spirit;
    trades_with_critical_violation = _critical_violations ~config audit;
  }

(* Decision-quality matrix ------------------------------------------------ *)

let decision_quality_matrix_of ~audit ~ratings : decision_quality_matrix =
  let assignments = quartile_assignments_by_score ~audit ratings in
  let per_quartile = quartile_stats assignments in
  let total = List.length ratings in
  let total_wins =
    List.count ratings ~f:(fun r -> equal_outcome r.outcome Win)
  in
  let overall =
    if total = 0 then 0.0
    else Float.of_int total_wins /. Float.of_int total *. 100.0
  in
  { per_quartile; total_trades = total; overall_win_rate_pct = overall }

include Trade_audit_ratings_format
