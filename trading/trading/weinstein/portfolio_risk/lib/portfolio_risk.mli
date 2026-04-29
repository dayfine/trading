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

module Force_liquidation = Force_liquidation
(** Force-liquidation policy. See {!Force_liquidation}. *)

(** {1 Portfolio Snapshot} *)

type portfolio_snapshot = {
  total_value : float;
      (** Total portfolio value: cash + long market value − short market value
      *)
  cash : float;  (** Current cash balance *)
  cash_pct : float;
      (** Cash as fraction of total value [0.0, 1.0]. Low values indicate high
          deployment; falling below [config.min_cash_pct] blocks new trades. *)
  long_exposure : float;  (** Total long position market value *)
  long_exposure_pct : float;
      (** Long exposure as fraction of total value [0.0, 1.0]. High values mean
          concentrated long-side risk; limited by
          [config.max_long_exposure_pct]. *)
  short_exposure : float;
      (** Total short position market value (absolute value) *)
  short_exposure_pct : float;
      (** Short exposure as fraction of total value [0.0, 1.0]. Limited by
          [config.max_short_exposure_pct] to cap downside from short squeezes.
      *)
  position_count : int;  (** Number of open positions (long + short) *)
  sector_counts : (string * int) list;
      (** Positions per sector, sorted by sector name. The empty-string sector
          represents positions whose sector metadata is missing — this bucket is
          limited separately by [config.max_unknown_sector_positions]. High
          counts in any named sector indicate concentration risk; limited by
          [config.max_sector_concentration]. *)
}
[@@deriving show, eq]
(** Point-in-time view of portfolio composition used for risk calculations.

    Build via [snapshot_of_portfolio] when a [Portfolio.t] is available, or via
    [snapshot] for custom data sources. *)

val snapshot_of_portfolio :
  portfolio:Trading_portfolio.Portfolio.t ->
  prices:(string * float) list ->
  ?sectors:(string * string) list ->
  unit ->
  portfolio_snapshot
(** Compute portfolio snapshot from an existing portfolio and current prices.

    @param portfolio Current portfolio (cash and positions)
    @param prices List of (symbol, current_price) pairs
    @param sectors Optional (symbol, sector_name) pairs for sector tracking
    @return Portfolio snapshot with exposure metrics *)

val snapshot :
  cash:float ->
  positions:(string * float * float) list ->
  ?sectors:(string * string) list ->
  unit ->
  portfolio_snapshot
(** Low-level snapshot builder from raw (symbol, quantity, price) triples.

    Prefer [snapshot_of_portfolio] when a [Portfolio.t] is available.

    @param cash Current cash balance
    @param positions
      (symbol, quantity, current_price) triples; negative quantity for short
      positions
    @param sectors Optional (symbol, sector_name) pairs for sector tracking *)

(** {1 Position Sizing} *)

type sizing_result = {
  shares : int;
      (** Number of shares to buy/sell — rounded down to avoid overcommit *)
  position_value : float;  (** Total position value = shares * entry_price *)
  position_pct : float;
      (** Position as fraction of portfolio value [0.0, 1.0] *)
  risk_amount : float;  (** Dollar risk: shares * (entry_price - stop_price) *)
}
[@@deriving show, eq]
(** Result of position size computation. *)

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
      (** Maximum positions in any single named sector (default: 5) *)
  max_unknown_sector_positions : int;
      (** Maximum positions whose sector is unknown — tracked under the
          empty-string sector key (default: 2). Prevents long-tail names with
          missing sector metadata from dominating the portfolio. *)
  big_winner_multiplier : float;
      (** Size multiplier for high-conviction trades (default: 1.5x) *)
  force_liquidation : Force_liquidation.config;
      [@sexp.default Force_liquidation.default_config]
      (** Force-liquidation thresholds — see {!Force_liquidation}. Default: 50%
          per-position loss, 40% portfolio-of-peak floor. *)
}
[@@deriving show, eq, sexp]
(** All risk management parameters — nothing hardcoded. *)

val default_config : config
(** Default configuration:
    - risk_per_trade_pct = 0.01 (1% per trade)
    - max_positions = 20
    - max_long_exposure_pct = 0.90 (90%)
    - max_short_exposure_pct = 0.30 (30%)
    - min_cash_pct = 0.10 (10%)
    - max_sector_concentration = 5
    - max_unknown_sector_positions = 2
    - big_winner_multiplier = 1.5
    - force_liquidation = {!Force_liquidation.default_config} *)

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
      If [true], scales position size by [config.big_winner_multiplier]. Use for
      high-conviction setups — Stage 2 breakouts with strong volume and relative
      strength — where you want to commit more capital. (default: false) *)

(** {1 Limit Checks} *)

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
  | Unknown_sector_exceeded of int
      (** Adding this position would push the unknown-sector (empty-string)
          bucket to [n] positions, over [config.max_unknown_sector_positions].
      *)
  | Risk_too_high of float
      (** Risk amount is [pct] of portfolio, over configured limit *)
[@@deriving show]

val check_limits :
  config:config ->
  snapshot:portfolio_snapshot ->
  proposed_side:[ `Long | `Short ] ->
  proposed_value:float ->
  proposed_sector:string ->
  (unit, limit_violation list) Result.t
(** Check whether a proposed position would violate any portfolio risk limits.

    Every limit is evaluated independently — returns [Ok ()] only if all pass,
    [Error violations] listing every limit that would be exceeded.

    @param config Risk configuration
    @param snapshot Current portfolio snapshot
    @param proposed_side Long or short for the proposed position
    @param proposed_value Dollar value of the proposed position
    @param proposed_sector Sector of the proposed ticker *)
