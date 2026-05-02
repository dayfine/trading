(** Data model for the optimal-strategy counterfactual.

    See [optimal_types.mli] for the API contract. *)

open Core

type candidate_entry = {
  symbol : string;
  entry_week : Date.t;
  side : Trading_base.Types.position_side;
  entry_price : float;
  suggested_stop : float;
  risk_pct : float;
  sector : string;
  cascade_grade : Weinstein_types.grade;
  cascade_score : int;
  passes_macro : bool;
}
[@@deriving sexp]

type exit_trigger = Stage3_transition | Stop_hit | End_of_run
[@@deriving sexp]

type scored_candidate = {
  entry : candidate_entry;
  exit_week : Date.t;
  exit_price : float;
  exit_trigger : exit_trigger;
  raw_return_pct : float;
  hold_weeks : int;
  initial_risk_per_share : float;
  r_multiple : float;
}
[@@deriving sexp]

type optimal_round_trip = {
  symbol : string;
  side : Trading_base.Types.position_side;
  entry_week : Date.t;
  entry_price : float;
  exit_week : Date.t;
  exit_price : float;
  exit_trigger : exit_trigger;
  shares : float;
  initial_risk_dollars : float;
  pnl_dollars : float;
  r_multiple : float;
  cascade_grade : Weinstein_types.grade;
  passes_macro : bool;
}
[@@deriving sexp]

type optimal_summary = {
  total_round_trips : int;
  winners : int;
  losers : int;
  total_return_pct : float;
  win_rate_pct : float;
  avg_r_multiple : float;
  profit_factor : float;
  max_drawdown_pct : float;
  variant : variant_label;
}

and variant_label = Constrained | Score_picked | Relaxed_macro
[@@deriving sexp]
