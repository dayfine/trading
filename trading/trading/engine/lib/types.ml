open Trading_base.Types

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
