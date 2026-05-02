(** Drawdown analytics computer (M5.2c). See .mli for spec. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type sample = { date : Date.t; value : float }
type state = { samples : sample list  (** Reversed: head is most recent. *) }

(* ---- Episode detection ---- *)

type episode = {
  peak_date : Date.t;
  end_date : Date.t;
  max_depth_pct : float;  (** Maximum trough depth observed, in percent. *)
}
(** A drawdown episode: contiguous run of days where portfolio_value is below
    the running peak that started the episode, plus the recovery day (or the
    end-of-run day if the episode has not recovered). *)

(** Per-day drawdown percent against [peak]. Defensive guard against a
    non-positive peak (which shouldn't happen with portfolio_value > 0 but is
    handled to avoid NaN). *)
let _drawdown_pct ~peak ~value =
  if Float.(peak <= 0.0) then 0.0
  else Float.max 0.0 ((peak -. value) /. peak *. 100.0)

type sweep_state = {
  peak : float;
  peak_date : Date.t;
  current_max_depth : float;
  current_end_date : Date.t;
  in_drawdown : bool;
  episodes : episode list;
  per_day_dd : float list;  (** Per-day drawdown pct, reverse-chronological. *)
}
(** Tracks the per-day drawdown series + the in-progress episode. The episode
    list grows when we recover to a new peak. *)

let _initial_sweep (s : sample) =
  {
    peak = s.value;
    peak_date = s.date;
    current_max_depth = 0.0;
    current_end_date = s.date;
    in_drawdown = false;
    episodes = [];
    per_day_dd = [ 0.0 ];
  }

(** Closes the current in-progress episode (if any), pegging the end date to
    [end_date] (the recovery date when called from [_on_new_peak], or the last
    sample's date when called from end-of-run). *)
let _close_episode_at sweep ~end_date =
  if not sweep.in_drawdown then sweep.episodes
  else
    {
      peak_date = sweep.peak_date;
      end_date;
      max_depth_pct = sweep.current_max_depth;
    }
    :: sweep.episodes

(** New peak (or first sample) — flush any in-progress episode whose recovery
    date is [s.date]. *)
let _on_new_peak sweep (s : sample) =
  let episodes = _close_episode_at sweep ~end_date:s.date in
  {
    peak = s.value;
    peak_date = s.date;
    current_max_depth = 0.0;
    current_end_date = s.date;
    in_drawdown = false;
    episodes;
    per_day_dd = 0.0 :: sweep.per_day_dd;
  }

(** Below the current peak — extend the in-progress episode. *)
let _on_underwater sweep (s : sample) ~dd =
  {
    sweep with
    current_max_depth = Float.max sweep.current_max_depth dd;
    current_end_date = s.date;
    in_drawdown = true;
    per_day_dd = dd :: sweep.per_day_dd;
  }

let _step_sweep sweep (s : sample) =
  if Float.(s.value >= sweep.peak) then _on_new_peak sweep s
  else
    let dd = _drawdown_pct ~peak:sweep.peak ~value:s.value in
    _on_underwater sweep s ~dd

(** Sweep the chronological samples, producing the closed-episode list (with the
    trailing in-progress episode flushed) and the per-day drawdown series in
    chronological order. *)
let _sweep samples =
  match samples with
  | [] -> ([], [])
  | first :: rest ->
      let initial = _initial_sweep first in
      let final = List.fold rest ~init:initial ~f:_step_sweep in
      let episodes = _close_episode_at final ~end_date:final.current_end_date in
      (List.rev episodes, List.rev final.per_day_dd)

(* ---- Episode-level statistics ---- *)

let _mean = function
  | [] -> 0.0
  | xs ->
      let sum = List.fold xs ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length xs)

let _median xs =
  match xs with
  | [] -> 0.0
  | _ ->
      let sorted = List.sort xs ~compare:Float.compare in
      let n = List.length sorted in
      let arr = Array.of_list sorted in
      if n mod 2 = 1 then arr.(n / 2)
      else (arr.((n / 2) - 1) +. arr.(n / 2)) /. 2.0

let _episode_duration_days (e : episode) =
  Float.of_int (Date.diff e.end_date e.peak_date)

let _episode_metrics episodes =
  let depths = List.map episodes ~f:(fun e -> e.max_depth_pct) in
  let durations = List.map episodes ~f:_episode_duration_days in
  let avg_depth = _mean depths in
  let median_depth = _median depths in
  let avg_duration = _mean durations in
  let max_duration = List.fold durations ~init:0.0 ~f:Float.max in
  (avg_depth, median_depth, avg_duration, max_duration)

(* ---- Per-day statistics ---- *)

let _per_day_metrics per_day_dd =
  let n = List.length per_day_dd in
  if n = 0 then (0.0, 0.0, 0.0, 0.0)
  else
    let n_f = Float.of_int n in
    let n_underwater = List.count per_day_dd ~f:(fun d -> Float.(d > 0.0)) in
    let time_in_dd_pct = Float.of_int n_underwater /. n_f *. 100.0 in
    let pain = _mean per_day_dd in
    let underwater_area = pain *. n_f in
    let mean_sq =
      List.fold per_day_dd ~init:0.0 ~f:(fun acc d -> acc +. (d *. d)) /. n_f
    in
    let ulcer = Float.sqrt mean_sq in
    (time_in_dd_pct, pain, underwater_area, ulcer)

(* ---- Output assembly ---- *)

let _empty_metric_set () =
  Metric_types.of_alist_exn
    [
      (AvgDrawdownPct, 0.0);
      (MedianDrawdownPct, 0.0);
      (MaxDrawdownDurationDays, 0.0);
      (AvgDrawdownDurationDays, 0.0);
      (TimeInDrawdownPct, 0.0);
      (UlcerIndex, 0.0);
      (PainIndex, 0.0);
      (UnderwaterCurveArea, 0.0);
    ]

let _build_metrics episodes per_day_dd =
  let avg_depth, median_depth, avg_duration, max_duration =
    _episode_metrics episodes
  in
  let time_in_dd, pain, underwater_area, ulcer = _per_day_metrics per_day_dd in
  Metric_types.of_alist_exn
    [
      (AvgDrawdownPct, avg_depth);
      (MedianDrawdownPct, median_depth);
      (MaxDrawdownDurationDays, max_duration);
      (AvgDrawdownDurationDays, avg_duration);
      (TimeInDrawdownPct, time_in_dd);
      (UlcerIndex, ulcer);
      (PainIndex, pain);
      (UnderwaterCurveArea, underwater_area);
    ]

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    {
      samples =
        { date = step.Simulator_types.date; value = step.portfolio_value }
        :: state.samples;
    }

let _finalize ~state ~config:_ =
  let chrono = List.rev state.samples in
  match chrono with
  | [] -> _empty_metric_set ()
  | _ ->
      let episodes, per_day_dd = _sweep chrono in
      _build_metrics episodes per_day_dd

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "drawdown_analytics";
      init = (fun ~config:_ -> { samples = [] });
      update = _update;
      finalize = _finalize;
    }
