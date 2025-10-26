open Core
open Trading_base.Types

type market_data = {
  symbol : symbol;
  bid : price option;
  ask : price option;
  last : price option;
  timestamp : Time_ns_unix.t;
}
[@@deriving show, eq]

(* Market state is a hashtable mapping symbols to market data *)
type market_state = (symbol, market_data) Hashtbl.t
type fill_status = Filled | PartiallyFilled | Unfilled [@@deriving show, eq]

type execution_report = {
  order_id : string;
  status : fill_status;
  filled_quantity : quantity;
  remaining_quantity : quantity;
  average_price : price option;
  trades : trade list;
  timestamp : Time_ns_unix.t;
}
[@@deriving show, eq]

type commission_config = { per_share : float; minimum : float }
[@@deriving show, eq]

type engine_config = { commission : commission_config } [@@deriving show, eq]
