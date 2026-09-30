(** Per-trade ratings, behavioural metrics, and Weinstein-conformance scoring.

    See [trade_audit_ratings.mli] for the contract. *)

open Core
module TA = Backtest.Trade_audit
module WT = Weinstein_types
include Trade_audit_ratings_types

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

(** Max calendar-day gap tolerated when joining a [trades.csv] round-trip to its
    audit record (and back). The audit [entry_date] is the Friday decision date;
    the round-trip [entry_date] is the actual fill (next trading day), so the
    two differ by 1-3 days across a weekend. A week bridges that without
    cross-matching a distinct re-entry of the same symbol. Kept in sync with
    [Trade_audit_report]'s join tolerance. *)
let _join_tolerance_days = 7

(* From [candidates] sharing a symbol, return the one whose [date_of] is closest
   to [entry_date], within [_join_tolerance_days]. *)
let _nearest_within ~entry_date ~date_of candidates =
  List.filter_map candidates ~f:(fun c ->
      let gap = Int.abs (Date.diff (date_of c) entry_date) in
      if gap <= _join_tolerance_days then Some (gap, c) else None)
  |> List.min_elt ~compare:(fun (g1, _) (g2, _) -> Int.compare g1 g2)
  |> Option.map ~f:snd

let _audit_index audit =
  List.fold audit
    ~init:(Map.empty (module String))
    ~f:(fun acc (record : TA.audit_record) ->
      Map.add_multi acc ~key:record.entry.symbol ~data:record)

let rate_all ?(closes_lookup = _no_closes_lookup) ~config ~audit ~trades () =
  let idx = _audit_index audit in
  List.filter_map trades
    ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
      match Map.find idx t.symbol with
      | None -> None
      | Some records ->
          _nearest_within ~entry_date:t.entry_date
            ~date_of:(fun (r : TA.audit_record) -> r.entry.entry_date)
            records
          |> Option.map ~f:(fun record ->
              rate
                ~pre_entry_closes:(_closes_for closes_lookup record)
                ~config record t))

(* Behavioural metric (a) — over-trading ---------------------------------- *)

let _years_observed_of trades =
  let starts =
    List.map trades ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        t.entry_date)
  in
  let ends =
    List.map trades ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        t.exit_date)
  in
  match
    ( List.min_elt starts ~compare:Date.compare,
      List.max_elt ends ~compare:Date.compare )
  with
  | Some s, Some e ->
      let days = Date.diff e s in
      if days <= 0 then Float.nan else Float.of_int days /. 365.25
  | _ -> Float.nan

let _burst_outliers_of ~window_days trades =
  let by_symbol =
    List.fold trades
      ~init:(Map.empty (module String))
      ~f:(fun acc (t : Trading_simulation.Metrics.trade_metrics) ->
        Map.update acc t.symbol ~f:(function
          | None -> [ t ]
          | Some xs -> t :: xs))
  in
  Map.fold by_symbol ~init:[] ~f:(fun ~key:_ ~data:ts acc ->
      let sorted =
        List.sort ts ~compare:(fun a b ->
            Date.compare a.Trading_simulation.Metrics.entry_date b.entry_date)
      in
      let in_burst =
        List.filter sorted
          ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
            List.exists sorted
              ~f:(fun (other : Trading_simulation.Metrics.trade_metrics) ->
                (not (Date.equal other.entry_date t.entry_date))
                && Int.abs (Date.diff t.entry_date other.entry_date)
                   <= window_days))
      in
      List.map in_burst ~f:(fun t ->
          {
            symbol = t.Trading_simulation.Metrics.symbol;
            entry_date = t.entry_date;
            metric =
              sprintf "within %dd of another %s entry" window_days t.symbol;
          })
      @ acc)

let _over_trading ~config ~trades : over_trading =
  let total_trades = List.length trades in
  let years = _years_observed_of trades in
  let trades_per_year =
    if Float.is_nan years || Float.( <= ) years 0.0 then Float.nan
    else Float.of_int total_trades /. years
  in
  let exceeds =
    (not (Float.is_nan trades_per_year))
    && Float.( > ) trades_per_year (Float.of_int config.trades_per_year_warn)
  in
  let outliers =
    _burst_outliers_of ~window_days:config.concentrated_burst_window_days trades
  in
  let burst_pct =
    if total_trades = 0 then 0.0
    else
      Float.of_int (List.length outliers) /. Float.of_int total_trades *. 100.0
  in
  {
    total_trades;
    trades_per_year;
    exceeds_threshold = exceeds;
    concentrated_burst_pct = burst_pct;
    outliers;
  }

(* Behavioural metric (b) — exit winners too early ------------------------ *)

let _exit_winners ~config ~ratings ~trades : exit_winners_too_early =
  let trade_idx =
    List.fold trades
      ~init:(Map.empty (module String))
      ~f:(fun acc (t : Trading_simulation.Metrics.trade_metrics) ->
        Map.add_multi acc ~key:t.symbol ~data:t)
  in
  let winners = List.filter ratings ~f:(fun r -> equal_outcome r.outcome Win) in
  let realized_pct (r : rating) =
    match Map.find trade_idx r.symbol with
    | None -> 0.0
    | Some trades -> (
        match
          _nearest_within ~entry_date:r.entry_date
            ~date_of:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
              t.entry_date)
            trades
        with
        | Some (t : Trading_simulation.Metrics.trade_metrics) ->
            t.pnl_percent /. 100.0
        | None -> 0.0)
  in
  let gaps = List.map winners ~f:(fun r -> (r, r.mfe_pct -. realized_pct r)) in
  let flagged =
    List.filter gaps ~f:(fun (r, _) ->
        let realized_frac = realized_pct r in
        Float.( > ) r.mfe_pct 0.0
        && Float.( < ) realized_frac
             (config.exit_early_mfe_fraction *. r.mfe_pct))
  in
  let avg_gap =
    match gaps with
    | [] -> 0.0
    | _ ->
        let total = List.fold gaps ~init:0.0 ~f:(fun acc (_, g) -> acc +. g) in
        total /. Float.of_int (List.length gaps) *. 100.0
  in
  let outliers =
    List.map flagged ~f:(fun (r, gap) ->
        {
          symbol = r.symbol;
          entry_date = r.entry_date;
          metric = sprintf "left %.2fpp on the table" (gap *. 100.0);
        })
  in
  {
    winners_evaluated = List.length winners;
    flagged_count = List.length flagged;
    avg_left_on_table_pct = avg_gap;
    outliers;
  }

(* Behavioural metric (c) — exit losers too late -------------------------- *)

let _exit_losers ~config ~ratings : exit_losers_too_late =
  let losers = List.filter ratings ~f:(fun r -> equal_outcome r.outcome Loss) in
  let stop_disciplined =
    List.count losers ~f:(fun r ->
        (not (Float.is_nan r.r_multiple))
        && Float.( <= ) (Float.abs r.r_multiple) 1.0)
  in
  let flagged =
    List.filter losers ~f:(fun r ->
        Float.is_nan r.r_multiple
        || Float.( > ) (Float.abs r.r_multiple)
             config.loser_r_multiple_threshold
        ||
        let mae_r = Float.abs r.mae_pct in
        let realized_r = Float.abs r.r_multiple in
        Float.( > ) realized_r 0.0
        && Float.( >= ) mae_r (config.loser_mae_to_realized_ratio *. realized_r))
  in
  let outliers =
    List.map flagged ~f:(fun r ->
        {
          symbol = r.symbol;
          entry_date = r.entry_date;
          metric =
            sprintf "realized R=%.2f, MAE=%.2f%%" r.r_multiple
              (r.mae_pct *. 100.0);
        })
  in
  let stop_pct =
    if List.is_empty losers then 0.0
    else
      Float.of_int stop_disciplined
      /. Float.of_int (List.length losers)
      *. 100.0
  in
  {
    losers_evaluated = List.length losers;
    flagged_count = List.length flagged;
    stop_discipline_pct = stop_pct;
    outliers;
  }

(* Cascade quartile bucketing --------------------------------------------- *)

(** Rank-based quartile: sort scores ascending, split by index into 4 equal
    chunks. Q1_top = top quartile (highest scores), Q4_bottom = lowest. Ties
    handled by sort stability (input order preserved). *)
let _quartile_of_index ~total i =
  if total <= 0 then Q4_bottom
  else
    let q1_cutoff = total / 4 in
    let q2_cutoff = total / 2 in
    let q3_cutoff = 3 * total / 4 in
    if i < q1_cutoff then Q1_top
    else if i < q2_cutoff then Q2
    else if i < q3_cutoff then Q3
    else Q4_bottom

let _quartile_assignments_by_score ~audit (ratings : rating list) :
    (rating * cascade_quartile) list =
  let idx = _audit_index audit in
  let with_score =
    List.filter_map ratings ~f:(fun (r : rating) ->
        match Map.find idx r.symbol with
        | None -> None
        | Some records ->
            _nearest_within ~entry_date:r.entry_date
              ~date_of:(fun (a : TA.audit_record) -> a.entry.entry_date)
              records
            |> Option.map ~f:(fun (a : TA.audit_record) ->
                (r, a.entry.cascade_score)))
  in
  let sorted_desc =
    List.sort with_score ~compare:(fun (_, sa) (_, sb) -> Int.compare sb sa)
  in
  let total = List.length sorted_desc in
  List.mapi sorted_desc ~f:(fun i (r, _) -> (r, _quartile_of_index ~total i))

let _quartile_stats (assignments : (rating * cascade_quartile) list) =
  let bucket_of q (rs : rating list) =
    let n = List.length rs in
    let wins = List.count rs ~f:(fun r -> equal_outcome r.outcome Win) in
    let pct =
      if n = 0 then 0.0 else Float.of_int wins /. Float.of_int n *. 100.0
    in
    { quartile = q; trade_count = n; win_count = wins; win_rate_pct = pct }
  in
  let pick q =
    List.filter_map assignments ~f:(fun (r, q') ->
        if equal_cascade_quartile q q' then Some r else None)
  in
  List.map [ Q1_top; Q2; Q3; Q4_bottom ] ~f:(fun q -> bucket_of q (pick q))

(* Behavioural metric (d) — entering losers too often --------------------- *)

let _entering_losers ~audit ~ratings : entering_losers_often =
  let assignments = _quartile_assignments_by_score ~audit ratings in
  let per_quartile = _quartile_stats assignments in
  let bottom_losers =
    List.filter assignments ~f:(fun (r, q) ->
        equal_cascade_quartile q Q4_bottom && equal_outcome r.outcome Loss)
  in
  let top_losers =
    List.filter assignments ~f:(fun (r, q) ->
        equal_cascade_quartile q Q1_top && equal_outcome r.outcome Loss)
  in
  let outliers =
    List.map bottom_losers ~f:(fun (r, _) ->
        {
          symbol = r.symbol;
          entry_date = r.entry_date;
          metric = "bottom-quartile entry became loser (cascade mis-scoring)";
        })
    @ List.map top_losers ~f:(fun (r, _) ->
        {
          symbol = r.symbol;
          entry_date = r.entry_date;
          metric = "top-quartile entry became loser (blind spot)";
        })
  in
  { per_quartile; flagged_count = List.length outliers; outliers }

let behavioral_metrics_of ~config ~ratings ~audit ~trades : behavioral_metrics =
  {
    over_trading = _over_trading ~config ~trades;
    exit_winners_too_early = _exit_winners ~config ~ratings ~trades;
    exit_losers_too_late = _exit_losers ~config ~ratings;
    entering_losers_often = _entering_losers ~audit ~ratings;
  }

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
  let assignments = _quartile_assignments_by_score ~audit ratings in
  let per_quartile = _quartile_stats assignments in
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
