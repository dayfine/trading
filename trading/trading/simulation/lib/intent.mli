(** Trading intent types - represent trading goals that may span multiple days *)

open Core

(** {1 Position Goals} *)

type position_goal =
  | AbsoluteShares of float
      (** Buy/sell exactly N shares (e.g., "buy 100 shares") *)
  | TargetPosition of float
      (** Reach a target position size (e.g., "hold 200 shares total")
          - If currently at 150, buy 50
          - If currently at 250, sell 50 *)
  | PercentOfPortfolio of float
      (** Position worth X% of portfolio value (0.0 to 1.0)
          Dynamically calculated based on current portfolio value *)
[@@deriving show, eq]

(** {1 Execution Plans} *)

type staged_order = {
  fraction : float;  (** Fraction of total intent (0.0 to 1.0) *)
  price : float;  (** Target price *)
  order_type : Trading_base.Types.order_type;
      (** Order type (Limit/Stop/StopLimit) *)
}
[@@deriving show, eq]

type execution_plan =
  | SingleOrder of {
      price : float;
      order_type : Trading_base.Types.order_type;
    }
      (** Single order at a specific price *)
  | StagedEntry of staged_order list
      (** Multiple orders at different price levels
          Example: "Buy 50 shares at $100, 50 more at $95" *)
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
      indicator : string;  (** "EMA", "RSI", etc. *)
      value : float;  (** Current value *)
      threshold : float;  (** Threshold crossed *)
      condition : string;  (** "crossed above", "below", etc. *)
    }
  | PriceAction of {
      pattern : string;  (** "breakout", "support", "resistance" *)
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
  confidence : float;  (** 0.0 to 1.0 *)
  description : string;  (** Human-readable explanation *)
}
[@@deriving show, eq]

(** {1 Intent Status} *)

type intent_status =
  | Active  (** Intent is being worked on, orders may be pending *)
  | PartiallyFilled of {
      filled_quantity : float;
      remaining_quantity : float;
    }  (** Some orders have executed, more to go *)
  | Completed  (** All orders executed or goal achieved *)
  | Cancelled of string  (** Intent cancelled (reason provided) *)
[@@deriving show, eq]

(** {1 Order Intent} *)

type order_intent = {
  id : string;  (** Unique identifier *)
  created_date : Date.t;  (** When intent was created *)
  symbol : string;
  side : Trading_base.Types.side;  (** Buy or Sell *)
  goal : position_goal;  (** What to achieve *)
  execution : execution_plan;  (** How to achieve it *)
  reasoning : reasoning;  (** Why *)
  status : intent_status;  (** Current state *)
  expires_date : Date.t option;  (** Optional expiration *)
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
