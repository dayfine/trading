(** Returns-block metric computer (M5.2b). See .mli for spec. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** Number of trading days per year used for volatility annualization. The
    Sharpe computer uses the same convention via
    [Metric_computer_utils.trading_days_per_year]; kept consistent here. *)
let _trading_days_per_year = Metric_computer_utils.trading_days_per_year

type sample = { date : Date.t; value : float }

type state = {
  samples : sample list;  (** Reversed: head is most recent. *)
  initial_value : float option;
}

(* ---- Daily returns helpers ---- *)

let _step_values samples = List.map samples ~f:(fun s -> s.value)

let _step_returns_pct_from_values values =
  let rec loop prev rest acc =
    match rest with
    | [] -> List.rev acc
    | curr :: rest' ->
        let r =
          if Float.(prev <= 0.0) then 0.0 else (curr -. prev) /. prev *. 100.0
        in
        loop curr rest' (r :: acc)
  in
  match values with [] | [ _ ] -> [] | first :: rest -> loop first rest []

(* ---- Volatility helpers ---- *)

let _mean = function
  | [] -> 0.0
  | xs ->
      let sum = List.fold xs ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length xs)

let _stdev xs =
  match xs with
  | [] | [ _ ] -> 0.0
  | _ ->
      let mu = _mean xs in
      let n = List.length xs in
      let sum_sq =
        List.fold xs ~init:0.0 ~f:(fun acc x ->
            let d = x -. mu in
            acc +. (d *. d))
      in
      Float.sqrt (sum_sq /. Float.of_int n)

let _annualize_pct stdev_pct = stdev_pct *. Float.sqrt _trading_days_per_year

let _downside_returns step_returns =
  List.map step_returns ~f:(fun r -> if Float.(r < 0.0) then r else 0.0)

(* ---- Calendar bucketing ----

   The grouping scheme: bucket steps by a derived [bucket_key]; within each
   bucket take the last sample (chronological max). Pair adjacent buckets
   (prev_end, this_end) and compute compounded return. The first bucket
   uses [initial_value] as its predecessor-end. *)

let _week_key (d : Date.t) =
  (* ISO 8601 calendar week (Mon–Sun). Returns (week_numbering_year,
     week_number); the week-numbering year may differ from the calendar year
     near year boundaries (e.g. 2024-12-30 belongs to 2025-W01 by ISO). Equal
     keys correspond to dates in the same ISO week, which is what the bucketing
     logic requires. *)
  let week, week_year = Date.week_number_and_year d in
  (week_year, week)

let _month_key (d : Date.t) = (Date.year d, Month.to_int (Date.month d))

let _quarter_key (d : Date.t) =
  (Date.year d, ((Month.to_int (Date.month d) - 1) / 3) + 1)

let _year_key (d : Date.t) = Date.year d

(** Bucket [samples] (chronological) by [key_of], emitting one entry per bucket
    in order. The entry's value is the last sample within the bucket. Bucket
    order is preserved by left-to-right scanning. *)
let _bucket_last_values (samples : sample list) ~key_of =
  let rec loop acc current rest =
    match rest with
    | [] -> (
        match current with
        | None -> List.rev acc
        | Some (_, v) -> List.rev (v :: acc))
    | s :: rest' -> (
        let k = key_of s.date in
        match current with
        | None -> loop acc (Some (k, s.value)) rest'
        | Some (cur_k, _) when Poly.equal cur_k k ->
            loop acc (Some (cur_k, s.value)) rest'
        | Some (_, prev_v) -> loop (prev_v :: acc) (Some (k, s.value)) rest')
  in
  loop [] None samples

let _bucket_returns_pct values ~initial =
  let rec loop prev rest acc =
    match rest with
    | [] -> List.rev acc
    | curr :: rest' ->
        let r =
          if Float.(prev <= 0.0) then 0.0 else (curr -. prev) /. prev *. 100.0
        in
        loop curr rest' (r :: acc)
  in
  match values with [] -> [] | _ :: _ -> loop initial values []

let _best_worst returns =
  match returns with
  | [] -> (0.0, 0.0)
  | _ ->
      let best = List.fold returns ~init:Float.neg_infinity ~f:Float.max in
      let worst = List.fold returns ~init:Float.infinity ~f:Float.min in
      (best, worst)

(* ---- update / finalize ---- *)

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    let value = step.Simulator_types.portfolio_value in
    let initial_value =
      match state.initial_value with None -> Some value | some -> some
    in
    { samples = { date = step.date; value } :: state.samples; initial_value }

let _bucket_extremes_for ~initial_value samples ~key_of =
  let bucket_values = _bucket_last_values samples ~key_of in
  _best_worst (_bucket_returns_pct bucket_values ~initial:initial_value)

let _bucket_extremes ~initial_value chrono =
  let best_week, worst_week =
    _bucket_extremes_for ~initial_value chrono ~key_of:_week_key
  in
  let best_month, worst_month =
    _bucket_extremes_for ~initial_value chrono ~key_of:_month_key
  in
  let best_quarter, worst_quarter =
    _bucket_extremes_for ~initial_value chrono ~key_of:_quarter_key
  in
  let best_year, worst_year =
    _bucket_extremes_for ~initial_value chrono ~key_of:_year_key
  in
  ( best_week,
    worst_week,
    best_month,
    worst_month,
    best_quarter,
    worst_quarter,
    best_year,
    worst_year )

let _total_return_pct ~initial_value ~last_value =
  if Float.(initial_value <= 0.0) then 0.0
  else (last_value -. initial_value) /. initial_value *. 100.0

let _metrics ~initial_value samples =
  let chrono = List.rev samples in
  let values = _step_values chrono in
  let step_returns = _step_returns_pct_from_values values in
  let last_value =
    match List.last chrono with None -> initial_value | Some s -> s.value
  in
  let vol_annualized = _annualize_pct (_stdev step_returns) in
  let downside_annualized =
    _annualize_pct (_stdev (_downside_returns step_returns))
  in
  let best_day, worst_day = _best_worst step_returns in
  let ( best_week,
        worst_week,
        best_month,
        worst_month,
        best_quarter,
        worst_quarter,
        best_year,
        worst_year ) =
    _bucket_extremes ~initial_value chrono
  in
  Metric_types.of_alist_exn
    [
      (TotalReturnPct, _total_return_pct ~initial_value ~last_value);
      (VolatilityPctAnnualized, vol_annualized);
      (DownsideDeviationPctAnnualized, downside_annualized);
      (BestDayPct, best_day);
      (WorstDayPct, worst_day);
      (BestWeekPct, best_week);
      (WorstWeekPct, worst_week);
      (BestMonthPct, best_month);
      (WorstMonthPct, worst_month);
      (BestQuarterPct, best_quarter);
      (WorstQuarterPct, worst_quarter);
      (BestYearPct, best_year);
      (WorstYearPct, worst_year);
    ]

let _empty_metric_set () =
  Metric_types.of_alist_exn
    [
      (TotalReturnPct, 0.0);
      (VolatilityPctAnnualized, 0.0);
      (DownsideDeviationPctAnnualized, 0.0);
      (BestDayPct, 0.0);
      (WorstDayPct, 0.0);
      (BestWeekPct, 0.0);
      (WorstWeekPct, 0.0);
      (BestMonthPct, 0.0);
      (WorstMonthPct, 0.0);
      (BestQuarterPct, 0.0);
      (WorstQuarterPct, 0.0);
      (BestYearPct, 0.0);
      (WorstYearPct, 0.0);
    ]

let _finalize ~state ~config:_ =
  match state.initial_value with
  | None -> _empty_metric_set ()
  | Some initial_value -> _metrics ~initial_value state.samples

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "return_basics";
      init = (fun ~config:_ -> { samples = []; initial_value = None });
      update = _update;
      finalize = _finalize;
    }
