(** Per-trade ratings, behavioural metrics, and Weinstein-conformance scoring.

    See [trade_audit_ratings.mli] for the contract. *)

open Core
module TA = Backtest.Trade_audit
module WT = Weinstein_types

(* Configuration ---------------------------------------------------------- *)

type config = {
  trades_per_year_warn : int;
  concentrated_burst_window_days : int;
  exit_early_mfe_fraction : float;
  loser_r_multiple_threshold : float;
  loser_mae_to_realized_ratio : float;
  recent_plunge_lookback_days : int;
  recent_plunge_min_drop_pct : float;
  recent_plunge_proximity_days : int;
  volume_confirmation_min_ratio : float;
}
[@@deriving sexp]

let default_config =
  {
    trades_per_year_warn = 50;
    concentrated_burst_window_days = 30;
    exit_early_mfe_fraction = 0.5;
    loser_r_multiple_threshold = 1.5;
    loser_mae_to_realized_ratio = 1.5;
    recent_plunge_lookback_days = 30;
    recent_plunge_min_drop_pct = 0.10;
    recent_plunge_proximity_days = 5;
    volume_confirmation_min_ratio = 2.0;
  }

(* Core types ------------------------------------------------------------- *)

type hold_time_anomaly = Stopped_immediately | Held_indefinitely | Normal
[@@deriving sexp, eq]

type outcome = Win | Loss [@@deriving sexp, eq]

type rule_outcome = Pass | Fail | Marginal | Not_applicable
[@@deriving sexp, eq]

type rule_id =
  | R1_long_above_30w_ma_flat_or_rising
  | R2_long_breakout_volume_2x
  | R3_no_long_in_stage_4
  | R4_short_below_30w_ma_flat_or_falling
  | R5_short_stage_4_breakdown
  | R6_no_recent_plunge
  | R7_exit_on_stage_3_to_4
  | R8_macro_alignment
[@@deriving sexp, eq]

type rule_evaluation = { rule : rule_id; outcome : rule_outcome }
[@@deriving sexp]

type rating = {
  symbol : string;
  entry_date : Date.t;
  r_multiple : float;
  mfe_pct : float;
  mae_pct : float;
  hold_time_anomaly : hold_time_anomaly;
  outcome : outcome;
  weinstein_score : float;
}
[@@deriving sexp]

type outlier_trade = { symbol : string; entry_date : Date.t; metric : string }
[@@deriving sexp]

type over_trading = {
  total_trades : int;
  trades_per_year : float;
  exceeds_threshold : bool;
  concentrated_burst_pct : float;
  outliers : outlier_trade list;
}
[@@deriving sexp]

type exit_winners_too_early = {
  winners_evaluated : int;
  flagged_count : int;
  avg_left_on_table_pct : float;
  outliers : outlier_trade list;
}
[@@deriving sexp]

type exit_losers_too_late = {
  losers_evaluated : int;
  flagged_count : int;
  stop_discipline_pct : float;
  outliers : outlier_trade list;
}
[@@deriving sexp]

type cascade_quartile = Q1_top | Q2 | Q3 | Q4_bottom [@@deriving sexp, eq]

type cascade_quartile_stat = {
  quartile : cascade_quartile;
  trade_count : int;
  win_count : int;
  win_rate_pct : float;
}
[@@deriving sexp]

type entering_losers_often = {
  per_quartile : cascade_quartile_stat list;
  flagged_count : int;
  outliers : outlier_trade list;
}
[@@deriving sexp]

type behavioral_metrics = {
  over_trading : over_trading;
  exit_winners_too_early : exit_winners_too_early;
  exit_losers_too_late : exit_losers_too_late;
  entering_losers_often : entering_losers_often;
}
[@@deriving sexp]

type rule_violation_summary = {
  rule : rule_id;
  fail_count : int;
  marginal_count : int;
  applicable_count : int;
  pass_rate_pct : float;
}
[@@deriving sexp]

type weinstein_aggregate = {
  per_rule : rule_violation_summary list;
  spirit_score : float;
  trades_with_critical_violation : outlier_trade list;
}
[@@deriving sexp]

type decision_quality_matrix = {
  per_quartile : cascade_quartile_stat list;
  total_trades : int;
  overall_win_rate_pct : float;
}
[@@deriving sexp]

(* Rule metadata ---------------------------------------------------------- *)

let all_rules =
  [
    R1_long_above_30w_ma_flat_or_rising;
    R2_long_breakout_volume_2x;
    R3_no_long_in_stage_4;
    R4_short_below_30w_ma_flat_or_falling;
    R5_short_stage_4_breakdown;
    R6_no_recent_plunge;
    R7_exit_on_stage_3_to_4;
    R8_macro_alignment;
  ]

let rule_label = function
  | R1_long_above_30w_ma_flat_or_rising -> "R1"
  | R2_long_breakout_volume_2x -> "R2"
  | R3_no_long_in_stage_4 -> "R3"
  | R4_short_below_30w_ma_flat_or_falling -> "R4"
  | R5_short_stage_4_breakdown -> "R5"
  | R6_no_recent_plunge -> "R6"
  | R7_exit_on_stage_3_to_4 -> "R7"
  | R8_macro_alignment -> "R8"

let rule_description = function
  | R1_long_above_30w_ma_flat_or_rising ->
      "Long entry above 30w MA AND MA flat-or-rising (Ch.2, \xc2\xa74.1)"
  | R2_long_breakout_volume_2x ->
      "Long entry breakout with volume \xe2\x89\xa52x avg (Ch.4)"
  | R3_no_long_in_stage_4 -> "Never long in Stage 4 (Ch.2, CRITICAL)"
  | R4_short_below_30w_ma_flat_or_falling ->
      "Short entry below 30w MA AND MA flat-or-falling (Ch.7, \xc2\xa76.1)"
  | R5_short_stage_4_breakdown -> "Short entry is a Stage-4 breakdown (Ch.7)"
  | R6_no_recent_plunge ->
      "No entry within 5d of a 10% drop in last 30d (Ch.4 \xe2\x80\x94 \
       plunge-buy avoidance)"
  | R7_exit_on_stage_3_to_4 ->
      "Exit on Stage3 \xe2\x86\x92 Stage4 transition (Ch.6)"
  | R8_macro_alignment ->
      "Macro alignment: Bullish for longs, Bearish for shorts (Ch.3, Ch.8)"

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

(** R6 needs pre-entry bar history that the audit record does not currently
    capture (the audit's MAE/MFE fields are hold-period only). Until per-bar
    pre-entry context is wired in, the rule is reported as N/A; this is honest
    about the data gap rather than synthesising a verdict. *)
let _eval_r6 ~config:_ (_ : TA.entry_decision) = Not_applicable

(** R7 requires comparing entry-stage to exit-stage. A trade entered in Stage 2
    and exited in Stage 4 without an explicit exit_trigger of Stop_loss /
    Signal_reversal indicates the strategy held through a Stage3 \xe2\x86\x92
    Stage4 transition without exiting on signal. *)
let _eval_r7 (e : TA.entry_decision) (x : TA.exit_decision option) =
  match x with
  | None -> Not_applicable
  | Some exit_d ->
      let entered_long = _is_long e in
      let exited_in_stage_4 = _is_stage4 exit_d.stage_at_exit in
      let entered_stage_2_or_3 = _is_stage2 e.stage || _is_stage3 e.stage in
      if entered_long && entered_stage_2_or_3 && exited_in_stage_4 then
        match exit_d.exit_trigger with
        | Stop_loss _ | Signal_reversal _ -> Pass
        | _ -> Fail
      else Pass

let _eval_r8 (e : TA.entry_decision) =
  match (e.side, e.macro_trend) with
  | Long, WT.Bullish -> Pass
  | Long, WT.Neutral -> Marginal
  | Long, WT.Bearish -> Fail
  | Short, WT.Bearish -> Pass
  | Short, WT.Neutral -> Marginal
  | Short, WT.Bullish -> Fail

let evaluate_rules ~config (record : TA.audit_record) : rule_evaluation list =
  let e = record.entry in
  let x = record.exit_ in
  [
    { rule = R1_long_above_30w_ma_flat_or_rising; outcome = _eval_r1 e };
    { rule = R2_long_breakout_volume_2x; outcome = _eval_r2 ~config e };
    { rule = R3_no_long_in_stage_4; outcome = _eval_r3 e };
    { rule = R4_short_below_30w_ma_flat_or_falling; outcome = _eval_r4 e };
    { rule = R5_short_stage_4_breakdown; outcome = _eval_r5 e };
    { rule = R6_no_recent_plunge; outcome = _eval_r6 ~config e };
    { rule = R7_exit_on_stage_3_to_4; outcome = _eval_r7 e x };
    { rule = R8_macro_alignment; outcome = _eval_r8 e };
  ]

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

let rate ~config (record : TA.audit_record)
    (trade : Trading_simulation.Metrics.trade_metrics) : rating =
  let evals = evaluate_rules ~config record in
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

let _audit_index audit =
  List.fold audit
    ~init:(Map.empty (module String))
    ~f:(fun acc (record : TA.audit_record) ->
      let key =
        record.entry.symbol ^ "|" ^ Date.to_string record.entry.entry_date
      in
      Map.set acc ~key ~data:record)

let rate_all ~config ~audit ~trades =
  let idx = _audit_index audit in
  List.filter_map trades
    ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
      let key = t.symbol ^ "|" ^ Date.to_string t.entry_date in
      Option.map (Map.find idx key) ~f:(fun record -> rate ~config record t))

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
        Map.set acc ~key:(t.symbol ^ "|" ^ Date.to_string t.entry_date) ~data:t)
  in
  let winners = List.filter ratings ~f:(fun r -> equal_outcome r.outcome Win) in
  let realized_pct (r : rating) =
    let key = r.symbol ^ "|" ^ Date.to_string r.entry_date in
    match Map.find trade_idx key with
    | Some (t : Trading_simulation.Metrics.trade_metrics) ->
        t.pnl_percent /. 100.0
    | None -> 0.0
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
        let key = r.symbol ^ "|" ^ Date.to_string r.entry_date in
        Option.map (Map.find idx key) ~f:(fun a -> (r, a.entry.cascade_score)))
  in
  let sorted_desc =
    List.sort with_score ~compare:(fun (_, sa) (_, sb) -> Int.compare sb sa)
  in
  let total = List.length sorted_desc in
  List.mapi sorted_desc ~f:(fun i (r, _) -> (r, _quartile_of_index ~total i))

let _quartile_assignments_by_r (ratings : rating list) :
    (rating * cascade_quartile) list =
  let sorted_desc =
    List.sort ratings ~compare:(fun (a : rating) (b : rating) ->
        Float.compare b.r_multiple a.r_multiple)
  in
  let total = List.length sorted_desc in
  List.mapi sorted_desc ~f:(fun i r -> (r, _quartile_of_index ~total i))

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

let weinstein_aggregate_of ~config ~ratings ~audit : weinstein_aggregate =
  let evals_per_trade = List.map audit ~f:(evaluate_rules ~config) in
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

let decision_quality_matrix_of ~ratings : decision_quality_matrix =
  let assignments = _quartile_assignments_by_r ratings in
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

(* Markdown formatting ---------------------------------------------------- *)

let _outcome_label = function Win -> "W" | Loss -> "L"

let _quartile_label = function
  | Q1_top -> "Q1 (top)"
  | Q2 -> "Q2"
  | Q3 -> "Q3"
  | Q4_bottom -> "Q4 (bottom)"

let _fmt_pct_signed v = if Float.is_nan v then "—" else sprintf "%+.2f%%" v
let _fmt_pct_unsigned v = if Float.is_nan v then "—" else sprintf "%.2f%%" v
let _fmt_r_multiple v = if Float.is_nan v then "—" else sprintf "%+.2fR" v
let _fmt_score v = if Float.is_nan v then "—" else sprintf "%.2f" v

let _outlier_lines ~max_n outliers =
  let head = List.take outliers max_n in
  if List.is_empty head then [ "  _none_" ]
  else
    List.map head ~f:(fun o ->
        sprintf "  - %s %s — %s" o.symbol (Date.to_string o.entry_date) o.metric)

let _hold_anomaly_label = function
  | Stopped_immediately -> "stopped_imm"
  | Held_indefinitely -> "held_indef"
  | Normal -> "normal"

let _format_rating_row (r : rating) =
  sprintf "| %s | %s | %s | %s | %s | %s | %s | %s |" r.symbol
    (Date.to_string r.entry_date)
    (_outcome_label r.outcome)
    (_fmt_r_multiple r.r_multiple)
    (_fmt_pct_signed (r.mfe_pct *. 100.0))
    (_fmt_pct_signed (r.mae_pct *. 100.0))
    (_hold_anomaly_label r.hold_time_anomaly)
    (_fmt_score r.weinstein_score)

let format_per_trade_extras ~ratings : string list =
  let header =
    [
      "## Per-trade ratings";
      "";
      "| symbol | entry_date | outcome | r_multiple | mfe_% | mae_% | \
       hold_anomaly | weinstein_score |";
      "|---|---|---|---:|---:|---:|---|---:|";
    ]
  in
  let body =
    if List.is_empty ratings then [ "_No ratings._" ]
    else List.map ratings ~f:_format_rating_row
  in
  header @ body @ [ "" ]

let _format_over_trading (ot : over_trading) =
  let tpy =
    if Float.is_nan ot.trades_per_year then "—"
    else sprintf "%.1f" ot.trades_per_year
  in
  let warn = if ot.exceeds_threshold then " (ABOVE threshold)" else "" in
  [
    "### (a) Over-trading";
    sprintf "- Total trades: %d" ot.total_trades;
    sprintf "- Trades / year: %s%s" tpy warn;
    sprintf "- Concentrated-burst share: %.1f%%" ot.concentrated_burst_pct;
    "- Outliers (top 5):";
  ]
  @ _outlier_lines ~max_n:5 ot.outliers
  @ [ "" ]

let _format_exit_winners (ew : exit_winners_too_early) =
  [
    "### (b) Exit-winners-too-early";
    sprintf "- Winners evaluated: %d" ew.winners_evaluated;
    sprintf "- Flagged (realized < %.0f%% of MFE): %d" 50.0 ew.flagged_count;
    sprintf "- Avg pp left on the table: %.2f" ew.avg_left_on_table_pct;
    "- Outliers (top 5):";
  ]
  @ _outlier_lines ~max_n:5 ew.outliers
  @ [ "" ]

let _format_exit_losers (el : exit_losers_too_late) =
  [
    "### (c) Exit-losers-too-late";
    sprintf "- Losers evaluated: %d" el.losers_evaluated;
    sprintf "- Flagged (|R|>1.5 or MAE\xe2\x89\xa51.5\xc3\x97realized): %d"
      el.flagged_count;
    sprintf "- Stop discipline (|R|\xe2\x89\xa41.0): %.1f%%"
      el.stop_discipline_pct;
    "- Outliers (top 5):";
  ]
  @ _outlier_lines ~max_n:5 el.outliers
  @ [ "" ]

let _format_entering_losers (lo : entering_losers_often) =
  let rows =
    List.map lo.per_quartile ~f:(fun s ->
        sprintf "| %s | %d | %d | %.1f%% |"
          (_quartile_label s.quartile)
          s.trade_count s.win_count s.win_rate_pct)
  in
  [
    "### (d) Entering-losers-too-often (cascade quartile vs outcome)";
    "";
    "| quartile | trades | wins | win_rate |";
    "|---|---:|---:|---:|";
  ]
  @ rows
  @ [
      "";
      sprintf "- Flagged outliers: %d" lo.flagged_count;
      "- Outliers (top 5):";
    ]
  @ _outlier_lines ~max_n:5 lo.outliers
  @ [ "" ]

let format_behavioral_section (m : behavioral_metrics) : string list =
  [ "## Behavioural metrics"; "" ]
  @ _format_over_trading m.over_trading
  @ _format_exit_winners m.exit_winners_too_early
  @ _format_exit_losers m.exit_losers_too_late
  @ _format_entering_losers m.entering_losers_often

let _format_rule_row (s : rule_violation_summary) =
  let passes = s.applicable_count - s.fail_count - s.marginal_count in
  sprintf "| %s | %s | %d / %d | %.1f%% | %d |" (rule_label s.rule)
    (rule_description s.rule) passes s.applicable_count s.pass_rate_pct
    s.fail_count

let format_weinstein_section (w : weinstein_aggregate) : string list =
  let header =
    [
      "## Weinstein conformance";
      "";
      sprintf "- Spirit score (avg per-trade): %s" (_fmt_score w.spirit_score);
      "";
      "| rule | description | passed/applicable | pass_rate | fails |";
      "|---|---|---:|---:|---:|";
    ]
  in
  let rows = List.map w.per_rule ~f:_format_rule_row in
  let critical =
    if List.is_empty w.trades_with_critical_violation then
      [ ""; "- No critical (R3) violations." ]
    else
      "" :: "- Critical R3 violations:"
      :: _outlier_lines ~max_n:10 w.trades_with_critical_violation
  in
  header @ rows @ critical @ [ "" ]

let format_decision_quality_section (m : decision_quality_matrix) : string list
    =
  let row (s : cascade_quartile_stat) =
    sprintf "| %s | %d | %d | %.1f%% |"
      (_quartile_label s.quartile)
      s.trade_count s.win_count s.win_rate_pct
  in
  [
    "## Decision quality (cascade quartile vs outcome)";
    "";
    sprintf "- Total trades: %d" m.total_trades;
    sprintf "- Overall win rate: %s" (_fmt_pct_unsigned m.overall_win_rate_pct);
    "";
    "| quartile | trades | wins | win_rate |";
    "|---|---:|---:|---:|";
  ]
  @ List.map m.per_quartile ~f:row
  @ [ "" ]
