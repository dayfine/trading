(** Fundamental metadata for a tradeable instrument (stock, ETF, or index). *)
type t = {
  symbol : string;
  name : string;
  sector : string;
  industry : string;
  market_cap : float;
  exchange : string;
}
[@@deriving show, eq, sexp]
