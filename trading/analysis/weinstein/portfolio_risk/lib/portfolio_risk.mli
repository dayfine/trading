(** Weinstein portfolio risk management.

    Implements position sizing using fixed-risk sizing (Weinstein Ch. 7) and
    portfolio-level exposure limits.

    {1 Overview}

    The core formula: risk a fixed percentage of portfolio value per trade.
    Position size = (portfolio_value * risk_pct) / (entry - stop).

    This ensures that if the stop is hit, total loss equals exactly
    [risk_per_trade_pct * portfolio_value], regardless of position size.

    {1 Design}

    Pure functions — no state. Takes a portfolio snapshot and config, returns
    sizing results and limit checks. The caller (strategy) decides what to do
    with the results.

    Does NOT modify the existing Portfolio module. Works alongside it by taking
    a snapshot of the portfolio state. *)

(** {1 Portfolio Snapshot} *)

type portfolio_snapshot = {
  total_value : float;
      (** Total portfolio value: cash + market value of all positions *)
  cash : float;  (** Current cash balance *)
  cash_pct : float;  (** Cash as percentage of total value [0.0, 1.0] *)
  long_exposure : float;  (** Total long position market value *)
  long_exposure_pct : float;
      (** Long exposure as percentage of total value [0.0, 1.0] *)
  short_exposure : float;
      (** Total short position market value (absolute value) *)
  short_exposure_pct : float;
      (** Short exposure as percentage of total value [0.0, 1.0] *)
  position_count : int;  (** Number of open positions (long + short) *)
  sector_counts : (string * int) list;
      (** Sector -> position count mapping, sorted by sector name *)
}
[@@deriving show, eq]
(** Point-in-time view of portfolio composition used for risk calculations.

    Computed from the existing Portfolio.t plus current market prices. *)

(** {1 Sizing Result} *)

type sizing_result = {
  shares : int;
      (** Number of shares to buy/sell -- rounded down to avoid overcommit *)
  position_value : float;  (** Total position value = shares * entry_price *)
  position_pct : float;
      (** Position as percentage of portfolio value [0.0, 1.0] *)
  risk_amount : float;  (** Dollar risk: shares * (entry_price - stop_price) *)
}
[@@deriving show, eq]
(** Result of position size computation. *)

(** {1 Limit Violations} *)

(** Reasons a proposed position would violate portfolio risk limits. *)
type limit_violation =
  | Max_positions_exceeded of int
      (** Portfolio already has [n] positions, at maximum *)
  | Long_exposure_exceeded of float
      (** Adding this position would push long exposure to [pct] *)
  | Short_exposure_exceeded of float
      (** Adding this position would push short exposure to [pct] *)
  | Cash_below_minimum of float
      (** After this trade, cash would fall to [pct] of portfolio *)
  | Sector_concentration of string * int
      (** Sector [name] would have [n] positions, over limit *)
  | Risk_too_high of float
      (** Risk amount is [pct] of portfolio, over configured limit *)
[@@deriving show]

(** {1 Configuration} *)

type config = {
  risk_per_trade_pct : float;
      (** Fraction of portfolio to risk per trade (default: 0.01 = 1%) *)
  max_positions : int;  (** Maximum total open positions (default: 20) *)
  max_long_exposure_pct : float;
      (** Maximum long exposure as fraction of portfolio (default: 0.90 = 90%)
      *)
  max_short_exposure_pct : float;
      (** Maximum short exposure as fraction of portfolio (default: 0.30 = 30%)
      *)
  min_cash_pct : float;
      (** Minimum cash fraction to maintain (default: 0.10 = 10%) *)
  max_sector_concentration : int;
      (** Maximum positions in any single sector (default: 5) *)
  big_winner_multiplier : float;
      (** Scale up sizing for high-conviction trades (default: 1.5x) *)
}
[@@deriving show, eq]
(** All risk management parameters -- nothing hardcoded. *)

val default_config : config
(** Default configuration:
    - risk_per_trade_pct = 0.01 (1% per trade)
    - max_positions = 20
    - max_long_exposure_pct = 0.90 (90%)
    - max_short_exposure_pct = 0.30 (30%)
    - min_cash_pct = 0.10 (10%)
    - max_sector_concentration = 5
    - big_winner_multiplier = 1.5 *)

(** {1 Core Functions} *)

val snapshot :
  cash:float -> positions:(string * float * float) list -> portfolio_snapshot
(** Compute portfolio snapshot for risk calculations.

    @param cash Current cash balance
    @param positions
      List of (symbol, quantity, current_price) triples. Quantity is positive
      for long, negative for short.
    @return Portfolio snapshot with exposure metrics

    Note: sector_counts is always empty in this function -- use
    [snapshot_with_sectors] when sector tracking is needed. *)

val snapshot_with_sectors :
  cash:float ->
  positions:(string * float * float) list ->
  sectors:(string * string) list ->
  portfolio_snapshot
(** Compute portfolio snapshot including sector concentration tracking.

    @param cash Current cash balance
    @param positions List of (symbol, quantity, current_price) triples
    @param sectors List of (symbol, sector_name) pairs
    @return Portfolio snapshot with sector_counts populated *)

val compute_position_size :
  config:config ->
  portfolio_value:float ->
  entry_price:float ->
  stop_price:float ->
  ?big_winner:bool ->
  unit ->
  sizing_result
(** Compute position size using fixed-risk sizing.

    Formula: shares = floor((portfolio_value * risk_pct) / (entry - stop))

    The stop must be strictly below the entry price (long) or above (short). If
    stop >= entry (which would be invalid), returns 0 shares.

    @param config Risk configuration
    @param portfolio_value Total portfolio value for risk calculation
    @param entry_price Price at which to enter the position
    @param stop_price Stop-loss price for the position
    @param big_winner
      If true, applies big_winner_multiplier to sizing (default: false)
    @return Sizing result with shares, position_value, position_pct, risk_amount
*)

val check_limits :
  config:config ->
  snapshot:portfolio_snapshot ->
  proposed_side:[ `Long | `Short ] ->
  proposed_value:float ->
  proposed_sector:string ->
  (unit, limit_violation list) Result.t
(** Check if a proposed position would violate any portfolio risk limits.

    Checks in order: 1. Max positions 2. Exposure limits (long or short
    depending on side) 3. Minimum cash 4. Sector concentration (Risk_too_high is
    checked separately via [compute_position_size])

    Returns [Ok ()] if all limits pass, [Error violations] with all violations
    found (not just the first).

    @param config Risk configuration
    @param snapshot Current portfolio snapshot
    @param proposed_side Long or short for the proposed position
    @param proposed_value Dollar value of the proposed position
    @param proposed_sector Sector of the proposed ticker
    @return Ok if all limits pass, Error with all violations *)
