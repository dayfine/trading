(** See {!Portfolio_summary} for documentation. *)

open Core

type position_summary = {
  symbol : string;
  quantity : float;
  cost_basis : float;
}
[@@deriving show, eq, sexp]

type t = {
  current_cash : float;
  positions : position_summary list;
  position_value_total : float;
}
[@@deriving show, eq, sexp]

let _project_position (p : Trading_portfolio.Types.portfolio_position) :
    position_summary =
  {
    symbol = p.symbol;
    quantity = Trading_portfolio.Calculations.position_quantity p;
    cost_basis = Trading_portfolio.Calculations.position_cost_basis p;
  }

let of_portfolio (portfolio : Trading_portfolio.Portfolio.t)
    ~position_value_total : t =
  {
    current_cash = portfolio.current_cash;
    positions = List.map portfolio.positions ~f:_project_position;
    position_value_total;
  }

let positions_count t = List.length t.positions

let find_position t ~symbol =
  List.find t.positions ~f:(fun p -> String.equal p.symbol symbol)

let position_cost_basis_total t =
  List.fold t.positions ~init:0.0 ~f:(fun acc p -> acc +. p.cost_basis)

let empty = { current_cash = 0.0; positions = []; position_value_total = 0.0 }

let with_cash cash =
  { current_cash = cash; positions = []; position_value_total = 0.0 }
