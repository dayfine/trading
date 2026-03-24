type t = {
  symbol : string;
  name : string;
  sector : string;
  industry : string;
  market_cap : float;
  exchange : string;
}
[@@deriving show, eq]
