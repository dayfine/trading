open Trading_base.Types

type price_bar = {
  symbol : symbol;
  open_price : price;
  high_price : price;
  low_price : price;
  close_price : price;
}
[@@deriving show, eq]

let default_bar_resolution = 390

type path_point = { price : price } [@@deriving show, eq]

type intraday_path = path_point list [@@deriving show, eq]

type fill_result = { price : price } [@@deriving show, eq]

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
