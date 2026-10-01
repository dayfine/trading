(** Per-trade ratings, behavioural metrics, and Weinstein-conformance scoring.

    See [trade_audit_ratings.mli] for the contract. *)

open Core
module TA = Backtest.Trade_audit
module WT = Weinstein_types
include Trade_audit_ratings_types
include Trade_audit_ratings_behavioral

(* Rule predicates -------------------------------------------------------- *)

let _is_long (e : TA.entry_decision) =
  Trading_base.Types.equal_position_side e.side Long

let _is_short (e : TA.entry_decision) =
  Trading_base.Types.equal_position_side e.side Short

let _is_stage2 = function WT.Stage2 _ -> true | _ -> false
let _is_stage3 = function WT.Stage3 _ -> true | _ -> false
let _is_stage4 = function WT.Stage4 _ -> true | _ -> false

let _ma_flat_or_rising (m : WT.ma_direction) =
  match m with WT.Rising | WT.Flat -> true | WT.Declining -> false

let _ma_flat_or_falling (m : WT.ma_direction) =
  match m with WT.Declining | WT.Flat -> true | WT.Rising -> false

let _eval_r1 (e : TA.entry_decision) =
  if not (_is_long e) then Not_applicable
  else if _is_stage2 e.stage && _ma_flat_or_rising e.ma_direction then Pass
  else Fail

let _eval_r2 ~config (e : TA.entry_decision) =
  if not (_is_long e) then Not_applicable
  else
    match e.volume_quality with
    | None -> Not_applicable
    | Some (WT.Strong ratio)
      when Float.( >= ) ratio config.volume_confirmation_min_ratio ->
        Pass
    | Some (WT.Strong _) -> Marginal
    | Some (WT.Adequate _) -> Marginal
    | Some (WT.Weak _) -> Fail

let _eval_r3 (e : TA.entry_decision) =
  if not (_is_long e) then Not_applicable
  else if _is_stage4 e.stage then Fail
  else Pass

let _eval_r4 (e : TA.entry_decision) =
  if not (_is_short e) then Not_applicable
  else if _ma_flat_or_falling e.ma_direction then Pass
  else Fail

let _eval_r5 (e : TA.entry_decision) =
  if not (_is_short e) then Not_applicable
  else if _is_stage4 e.stage then Pass
  else Fail

(* R6 pre-entry price context: daily closes at or before the entry, oldest
   first. Supplied by the report/bin from a bar source (the audit record itself
   carries no pre-entry bars). Empty when no bar source was wired in — R6 then
   reports [Not_applicable] rather than synthesising a verdict. *)
type pre_entry_closes = (Date.t * float) list

let _no_closes : pre_entry_closes = []

(* Restrict [closes] to the lookback window [entry_date - lookback, entry_date)
   — bars strictly before the entry, within [lookback] calendar days. *)
let _closes_in_window ~lookback ~entry_date (closes : pre_entry_closes) =
  List.filter closes ~f:(fun (d, _) ->
      let gap = Date.diff entry_date d in
      gap > 0 && gap <= lookback)

(* Deepest peak-to-trough drop in [closes] plus the trough's date. Scans oldest
   first tracking the running peak; the max drop is [(peak - close) / peak] at
   the trough. Returns [None] when there is no positive peak to measure against.
*)
let _max_drawdown (closes : pre_entry_closes) : (float * Date.t) option =
  List.fold closes ~init:(0.0, None) ~f:(fun (peak, best) (d, close) ->
      let peak = Float.max peak close in
      if Float.( <= ) peak 0.0 then (peak, best)
      else
        let drop = (peak -. close) /. peak in
        match best with
        | Some (bd, _) when Float.( >= ) bd drop -> (peak, best)
        | _ -> (peak, Some (drop, d)))
  |> snd

(** Weinstein Ch.4 plunge-buy avoidance. A long entry is flagged [Fail] when a
    drop of at least [config.recent_plunge_min_drop_pct] occurred within
    [config.recent_plunge_lookback_days] before the entry AND that drop's trough
    sits within [config.recent_plunge_proximity_days] of the entry — i.e. the
    strategy bought into a fresh plunge. Otherwise [Pass]. Reports
    [Not_applicable] when fewer than two in-window closes are available
    (insufficient pre-entry history to judge). *)
let _recent_plunge_verdict ~config ~entry_date (closes : pre_entry_closes) =
  let window =
    _closes_in_window ~lookback:config.recent_plunge_lookback_days ~entry_date
      closes
  in
  if List.length window < 2 then Not_applicable
  else
    match _max_drawdown window with
    | None -> Not_applicable
    | Some (drop, trough_date) ->
        let near_entry =
          Date.diff entry_date trough_date
          <= config.recent_plunge_proximity_days
        in
        if Float.( >= ) drop config.recent_plunge_min_drop_pct && near_entry
        then Fail
        else Pass

let _eval_r6 ~config ~closes (e : TA.entry_decision) =
  if not (_is_long e) then Not_applicable
  else _recent_plunge_verdict ~config ~entry_date:e.entry_date closes

(* The [exit_trigger] label the drawdown breaker stamps on every
   force-liquidation exit — [Weinstein_strategy.Force_liquidation_runner
   .exit_label], carried on the transition's [StrategySignal] and mapped to
   [Stop_log.Strategy_signal] by [exit_trigger_of_reason]. Spelled literally
   rather than taken as a library dependency, for the same reason
   [Validator_types._default_fallback_exit_labels] spells it: this analysis
   layer sits below the strategy layer that owns the token. *)
let _force_liquidation_exit_label = "force_liquidation"

(* Whether an exit trigger is a drawdown-breaker (force-liquidation) exit. *)
let _is_force_liquidation (trigger : Backtest.Stop_log.exit_trigger) =
  match trigger with
  | Strategy_signal { label; _ } ->
      String.equal label _force_liquidation_exit_label
  | _ -> false

(* R7's verdict from an exit trigger plus the entry/exit stage shape. Two
   distinct failure modes, checked in this order:

   1. Force-liquidation — the drawdown breaker is the safety net, not a
      strategy signal, so its firing is by construction evidence the
      protective stop never removed the position. Unconditional [Fail]:
      unlike the held-through shape below it needs no stage comparison, so it
      also catches the breaker firing on a short, or while the classifier
      still reads Stage 2/3 (the case where the stop most clearly failed).
   2. Held through Stage3 -> Stage4 — a long entered in Stage 2/3 and exited
      in Stage 4 on anything other than [Stop_loss] / [Signal_reversal] rode
      the transition down instead of exiting on signal. *)
let _r7_of_trigger ~entered_long ~entered_stage_2_or_3 ~exited_in_stage_4
    (trigger : Backtest.Stop_log.exit_trigger) =
  if _is_force_liquidation trigger then Fail
  else if entered_long && entered_stage_2_or_3 && exited_in_stage_4 then
    match trigger with Stop_loss _ | Signal_reversal _ -> Pass | _ -> Fail
  else Pass

(** R7 reads the enriched [exit_] when the record has one. When it does not, the
    reason-only [external_exit] can still answer failure mode 1 — it carries an
    [exit_trigger] but no [stage_at_exit], and mode 1 needs none. Every other
    trigger on that path stays {!Not_applicable}, as does a still-open position.
*)
let _eval_r7 (e : TA.entry_decision) (x : TA.exit_decision option)
    (ext : TA.external_exit_decision option) =
  match x with
  | Some exit_d ->
      _r7_of_trigger ~entered_long:(_is_long e)
        ~entered_stage_2_or_3:(_is_stage2 e.stage || _is_stage3 e.stage)
        ~exited_in_stage_4:(_is_stage4 exit_d.stage_at_exit)
        exit_d.exit_trigger
  | None -> (
      match ext with
      | Some ext_d when _is_force_liquidation ext_d.exit_trigger -> Fail
      | Some _ | None -> Not_applicable)

let _eval_r8 (e : TA.entry_decision) =
  match (e.side, e.macro_trend) with
  | Long, WT.Bullish -> Pass
  | Long, WT.Neutral -> Marginal
  | Long, WT.Bearish -> Fail
  | Short, WT.Bearish -> Pass
  | Short, WT.Neutral -> Marginal
  | Short, WT.Bullish -> Fail

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
