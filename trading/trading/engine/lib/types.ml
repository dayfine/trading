open Trading_base.Types

type price_quote = {
  symbol : symbol;
  bid : price option;
  ask : price option;
  last : price option;
}
[@@deriving show, eq]

type fill_status = Filled | PartiallyFilled | Unfilled [@@deriving show, eq]

type execution_report = {
  order_id : string;
  status : fill_status;
  trades : trade list;
}
[@@deriving show, eq]

type commission_config = { per_share : float; minimum : float }
[@@deriving show, eq]

type engine_config = { commission : commission_config } [@@deriving show, eq]

type mini_bar = {
  time_fraction : float;
  open_price : float;
  close_price : float;
}
[@@deriving show, eq]
