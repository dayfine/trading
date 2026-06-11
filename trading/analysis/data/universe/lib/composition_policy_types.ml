open Core

(* Default sector label that identifies a REIT in the GICS sector column. *)
let _default_reit_sector_label = "Real Estate"

type candidate = {
  symbol : string;
  asset_type : Eodhd.Asset_type.t;
  sector : string;
  avg_dollar_volume : float;
  rank : int;
}
[@@deriving sexp, eq, show]

type reit_policy = Include | Exclude [@@deriving sexp, eq, show]

type config = {
  reit_policy : reit_policy;
  reit_sector_label : string;
  adr_min_dollar_volume : float option;
  exclude_preferred : bool;
}
[@@deriving sexp, eq, show]

let default_config =
  {
    reit_policy = Include;
    reit_sector_label = _default_reit_sector_label;
    adr_min_dollar_volume = None;
    exclude_preferred = false;
  }

type drop_reason =
  | Dual_class_duplicate of { kept_symbol : string }
  | Reit_excluded
  | Adr_below_liquidity_floor of { floor : float; avg_dollar_volume : float }
  | Preferred_excluded
[@@deriving sexp, eq, show]

type drop = { symbol : string; reason : drop_reason }
[@@deriving sexp, eq, show]

type filter_report = { filter : string; dropped : drop list; kept_count : int }
[@@deriving sexp, eq, show]

type result = { kept : candidate list; reports : filter_report list }
[@@deriving sexp, eq, show]
