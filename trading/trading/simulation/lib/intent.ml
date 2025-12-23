(** Trading intent types - represent trading goals that may span multiple days *)

open Core

(** {1 Position Goals} *)

type position_goal =
  | AbsoluteShares of float
  | TargetPosition of float
  | PercentOfPortfolio of float
[@@deriving show, eq]

(** {1 Execution Plans} *)

type staged_order = {
  fraction : float;
  price : float;
  order_type : Trading_base.Types.order_type;
}
[@@deriving show, eq]

type execution_plan =
  | SingleOrder of {
      price : float;
      order_type : Trading_base.Types.order_type;
    }
  | StagedEntry of staged_order list
[@@deriving show, eq]

(** {1 Reasoning} *)

type risk_reason =
  | StopLoss of {
      entry_price : float;
      current_price : float;
      loss_percent : float;
    }
  | TakeProfit of {
      entry_price : float;
      current_price : float;
      profit_percent : float;
    }
  | UnderperformingAsset of {
      days_held : int;
      total_return : float;
      benchmark_return : float option;
    }
[@@deriving show, eq]

type signal_type =
  | TechnicalIndicator of {
      indicator : string;
      value : float;
      threshold : float;
      condition : string;
    }
  | PriceAction of {
      pattern : string;
      description : string;
    }
  | RiskManagement of risk_reason
  | PortfolioRebalancing of {
      current_allocation : float;
      target_allocation : float;
    }
[@@deriving show, eq]

type reasoning = {
  signal : signal_type;
  confidence : float;
  description : string;
}
[@@deriving show, eq]

(** {1 Intent Status} *)

type intent_status =
  | Active
  | PartiallyFilled of {
      filled_quantity : float;
      remaining_quantity : float;
    }
  | Completed
  | Cancelled of string
[@@deriving show, eq]

(** {1 Order Intent} *)

type order_intent = {
  id : string;
  created_date : Date.t;
  symbol : string;
  side : Trading_base.Types.side;
  goal : position_goal;
  execution : execution_plan;
  reasoning : reasoning;
  status : intent_status;
  expires_date : Date.t option;
}
[@@deriving show, eq]

(** {1 Intent Actions} *)

type intent_action =
  | CreateIntent of order_intent
  | UpdateIntent of {
      id : string;
      new_status : intent_status;
    }
  | CancelIntent of {
      id : string;
      reason : string;
    }
[@@deriving show, eq]
