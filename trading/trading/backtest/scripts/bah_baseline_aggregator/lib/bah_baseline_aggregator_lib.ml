open Core
module Wf_types = Walk_forward.Walk_forward_types
module Window_spec = Walk_forward.Window_spec
module Fold_gate = Walk_forward.Fold_gate

(* ---------- annualisation constants ---------- *)

let _trading_days_per_year = 252.0
let _days_per_year_calendar = 365.25
let _placeholder_worst_delta = 100.0

(* ---------- math helpers ---------- *)

let _mean xs =
  let n = List.length xs in
  if n = 0 then Float.nan
  else List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int n

let _stdev_sample xs =
  let n = List.length xs in
  if n < 2 then Float.nan
  else
    let m = _mean xs in
    let s = List.fold xs ~init:0.0 ~f:(fun acc x -> acc +. ((x -. m) ** 2.0)) in
    Float.sqrt (s /. Float.of_int (n - 1))

let _daily_returns = function
  | [] | [ _ ] -> []
  | first :: rest ->
      let pairs = List.zip_exn (first :: List.drop_last_exn rest) rest in
      List.map pairs ~f:(fun (prev, curr) -> (curr /. prev) -. 1.0)

let _dd_pct_against ~peak x =
  if Float.( <= ) peak 0.0 then 0.0 else (peak -. x) /. peak *. 100.0

let _step_drawdown (peak, worst) x =
  let new_peak = Float.max peak x in
  (new_peak, Float.max worst (_dd_pct_against ~peak:new_peak x))

let _max_drawdown_pct = function
  | [] -> Float.nan
  | first :: _ as adj_closes ->
      List.fold adj_closes ~init:(first, 0.0) ~f:_step_drawdown |> snd

let _cagr_pct_from_factor ~total_factor ~years =
  if Float.( <= ) total_factor 0.0 then Float.neg_infinity
  else ((total_factor ** (1.0 /. years)) -. 1.0) *. 100.0

let _cagr_pct ~total_return_pct ~test_days_calendar =
  let years = Float.of_int test_days_calendar /. _days_per_year_calendar in
  if Float.( <= ) years 0.0 then Float.nan
  else
    _cagr_pct_from_factor
      ~total_factor:(1.0 +. (total_return_pct /. 100.0))
      ~years

let _calmar ~cagr_pct ~max_drawdown_pct =
  if Float.( = ) max_drawdown_pct 0.0 then 0.0 else cagr_pct /. max_drawdown_pct

let _total_return_pct adj =
  match adj with
  | [] | [ _ ] -> Float.nan
  | first :: _ ->
      let last = List.last_exn adj in
      if Float.( <= ) first 0.0 then Float.nan
      else ((last /. first) -. 1.0) *. 100.0

let _sharpe_ratio returns =
  let m = _mean returns in
  let s = _stdev_sample returns in
  if Float.is_nan m || Float.is_nan s || Float.( = ) s 0.0 then Float.nan
  else m /. s *. Float.sqrt _trading_days_per_year

(* ---------- windowing ---------- *)

let _prices_in_window ~(start_date : Date.t) ~(end_date : Date.t)
    (prices : Types.Daily_price.t list) : Types.Daily_price.t list =
  List.filter prices ~f:(fun p ->
      Date.( >= ) p.date start_date && Date.( <= ) p.date end_date)

let _test_days_calendar (fold : Window_spec.fold) : int =
  Date.diff fold.test_period.end_date fold.test_period.start_date + 1

(* ---------- per-fold + aggregate ---------- *)

let compute_fold_actual ~(prices : Types.Daily_price.t list)
    ~(variant_label : string) ~(fold : Window_spec.fold) : Wf_types.fold_actual
    =
  let window =
    _prices_in_window ~start_date:fold.test_period.start_date
      ~end_date:fold.test_period.end_date prices
  in
  let adj = List.map window ~f:(fun p -> p.adjusted_close) in
  let test_days_calendar = _test_days_calendar fold in
  let total_return_pct = _total_return_pct adj in
  let sharpe_ratio = _sharpe_ratio (_daily_returns adj) in
  let max_drawdown_pct = _max_drawdown_pct adj in
  let cagr_pct = _cagr_pct ~total_return_pct ~test_days_calendar in
  let calmar_ratio = _calmar ~cagr_pct ~max_drawdown_pct in
  {
    fold_name = fold.name;
    variant_label;
    total_return_pct;
    sharpe_ratio;
    max_drawdown_pct;
    calmar_ratio;
    cagr_pct;
    avg_holding_days = Float.of_int test_days_calendar;
  }

(** Non-firing placeholder gate that mirrors the v7 fixture's shape
    ([metric=Sharpe, m=0, n=<fold_count>, worst_delta=100.0]). The BO scorer
    consults verdicts only for non-baseline variants, and our single-variant
    aggregate's verdicts list is empty after that filter — but
    {!Walk_forward.Walk_forward_report.compute} still expects a gate input. *)
let _placeholder_gate ~fold_count : Fold_gate.t =
  {
    metric = Sharpe;
    m = 0;
    n = fold_count;
    worst_delta = _placeholder_worst_delta;
  }

let compute_bah_aggregate ~(prices : Types.Daily_price.t list)
    ~(spec : Window_spec.t) ~(label : string) : Wf_types.aggregate =
  let folds = Window_spec.generate spec in
  if List.is_empty folds then
    failwith
      "bah_baseline_aggregator: spec yielded 0 folds (empty date range or no \
       fold fits)";
  let fold_actuals =
    List.map folds ~f:(fun fold ->
        compute_fold_actual ~prices ~variant_label:label ~fold)
  in
  let gate = _placeholder_gate ~fold_count:(List.length folds) in
  Walk_forward.Walk_forward_report.compute ~baseline_label:label ~gate
    ~fold_actuals
