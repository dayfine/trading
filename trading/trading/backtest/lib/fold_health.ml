(** Degenerate-fold detector. See [fold_health.mli]. *)

open Core

type config = {
  min_steps_for_check : int;
  flat_equity_min_distinct_ratio : float;
  depleted_abs_return_threshold : float;
}
[@@deriving sexp, eq]

(* ≈ a quarter of trading days: below this, a window is short enough that a
   legitimately quiet fold can have zero round-trips, so the guard stays silent.
*)
let _default_min_steps_for_check = 60

(* ≤5% distinct NAV values across the curve = effectively frozen. *)
let _default_flat_equity_min_distinct_ratio = 0.05

(* ≥50% terminal move from the starting stake, paired with zero round-trips, is
   the warmup-leak signature. *)
let _default_depleted_abs_return_threshold = 0.5

let default_config =
  {
    min_steps_for_check = _default_min_steps_for_check;
    flat_equity_min_distinct_ratio = _default_flat_equity_min_distinct_ratio;
    depleted_abs_return_threshold = _default_depleted_abs_return_threshold;
  }

type finding =
  | Zero_round_trips_over_long_window of { n_steps : int }
  | Flat_equity_curve of { n_points : int; n_distinct : int }
  | Unexplained_terminal_move of { total_return_pct : float }
[@@deriving sexp, eq]

let _zero_round_trips_msg n_steps =
  sprintf
    "zero in-window round-trips across %d steps (positions likely opened \
     during warmup and never round-tripped in-window)"
    n_steps

let _flat_equity_msg n_points n_distinct =
  sprintf
    "flat equity curve: only %d distinct NAV value(s) across %d points (held \
     positions likely frozen on cached / avg-cost marks)"
    n_distinct n_points

let _terminal_move_msg total_return_pct =
  sprintf
    "terminal NAV moved %.2f%% from the starting stake with zero in-window \
     round-trips (likely warmup-window P&L leaked into the measurement window)"
    total_return_pct

let finding_to_string = function
  | Zero_round_trips_over_long_window { n_steps } ->
      _zero_round_trips_msg n_steps
  | Flat_equity_curve { n_points; n_distinct } ->
      _flat_equity_msg n_points n_distinct
  | Unexplained_terminal_move { total_return_pct } ->
      _terminal_move_msg total_return_pct

(* Distinct count of the equity-curve values, with a float epsilon so two marks
   that differ only by floating noise are treated as the same NAV. *)
let _n_distinct equity_curve =
  equity_curve
  |> List.dedup_and_sort ~compare:(fun a b -> Float.robustly_compare a b)
  |> List.length

let _zero_round_trips_finding ~config ~n_round_trips ~n_steps =
  if n_round_trips = 0 && n_steps >= config.min_steps_for_check then
    Some (Zero_round_trips_over_long_window { n_steps })
  else None

let _flat_equity_finding ~config ~equity_curve =
  match equity_curve with
  | [] -> None
  | _ ->
      let n_points = List.length equity_curve in
      let n_distinct = _n_distinct equity_curve in
      let ratio = Float.of_int n_distinct /. Float.of_int n_points in
      if Float.( <= ) ratio config.flat_equity_min_distinct_ratio then
        Some (Flat_equity_curve { n_points; n_distinct })
      else None

(* Terminal return as a fraction of the starting stake, signed. *)
let _terminal_return_fraction ~initial_cash ~final_portfolio_value =
  (final_portfolio_value -. initial_cash) /. initial_cash

let _terminal_move_finding ~config ~initial_cash ~final_portfolio_value
    ~n_round_trips =
  let undefined = n_round_trips <> 0 || Float.( <= ) initial_cash 0.0 in
  let fraction =
    if undefined then 0.0
    else _terminal_return_fraction ~initial_cash ~final_portfolio_value
  in
  if
    (not undefined)
    && Float.( >= ) (Float.abs fraction) config.depleted_abs_return_threshold
  then Some (Unexplained_terminal_move { total_return_pct = fraction *. 100.0 })
  else None

let check ~config ~initial_cash ~final_portfolio_value ~n_round_trips ~n_steps
    ~equity_curve =
  List.filter_opt
    [
      _zero_round_trips_finding ~config ~n_round_trips ~n_steps;
      _flat_equity_finding ~config ~equity_curve;
      _terminal_move_finding ~config ~initial_cash ~final_portfolio_value
        ~n_round_trips;
    ]

let has_findings ~config ~initial_cash ~final_portfolio_value ~n_round_trips
    ~n_steps ~equity_curve =
  not
    (List.is_empty
       (check ~config ~initial_cash ~final_portfolio_value ~n_round_trips
          ~n_steps ~equity_curve))
