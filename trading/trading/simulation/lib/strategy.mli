(** Strategy interface for pluggable trading algorithms

    This module defines the signature that all trading strategies must implement.
    Strategies are called once per day after market close to generate order
    intents based on market conditions and portfolio state.
*)

(** {1 Strategy Output} *)

type strategy_output = {
  intent_actions : Intent.intent_action list;
      (** Changes to intent state (create/update/cancel) *)
  orders_to_submit : Trading_orders.Types.order list;
      (** Orders ready to be submitted to engine *)
}
[@@deriving show, eq]

(** {1 Strategy Module Signature} *)

module type STRATEGY = sig
  type config
  (** Strategy-specific configuration (e.g., EMA periods, thresholds, risk params) *)

  type state
  (** Strategy-specific state (e.g., active intents, position tracking, cached indicators)

      State should include:
      - Active intents being managed
      - Entry prices and dates for open positions
      - Risk management parameters per position
      - Any cached calculations
  *)

  val name : string
  (** Strategy name for logging and identification *)

  val init : config:config -> state
  (** Initialize strategy state from configuration *)

  val on_market_close :
    market_data:(module Market_data.MARKET_DATA with type t = 'a) ->
    market_data_instance:'a ->
    portfolio:Trading_portfolio.Portfolio.t ->
    state:state ->
    (strategy_output * state) Status.status_or
  (** Called once per day after market close.

      Strategy evaluates:
      - Current market conditions (via market_data)
      - Current portfolio state (positions, cash, P&L)
      - Active intents from strategy state

      Strategy decisions:
      - Entry signals: Create new intents to enter positions
      - Exit signals: Cancel intents or create exit orders for:
        * Take profit (profit target reached)
        * Stop loss (loss threshold exceeded)
        * Signal reversal (entry signal invalidated)
        * Underperforming positions (free capital for better opportunities)
      - Intent management: Update status of active intents

      Returns:
      - Intent actions (create/update/cancel)
      - Orders ready to execute (converted from intents)
      - Updated strategy state (with updated intents and position tracking)

      Constraints:
      - All orders MUST be priced (Limit/Stop/StopLimit)
      - Market orders are NOT allowed
      - Only data up to current date is visible (no lookahead)
   *)
end
