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

val default_max_position_pct_long : float
(** Default per-position concentration cap for {b long} entries (0.30 = 30% of
    portfolio_value). Long positions compound best with concentration: on
    sp500-2019-2023 long-only, the looser cap (0.30 / no-cap) yields +45.9%
    return vs +28.2% under a tighter 0.20 cap. *)

val default_max_position_pct_short : float
(** Default per-position concentration cap for {b short} entries (0.20 = 20% of
    portfolio_value). Shorts benefit from diversification + reduced
    force-liquidation cascade depth: on sp500-2019-2023 with-shorts, tightening
    to 0.20 lifts return +37.2% → +47.3% and drops max DD 34.5% → 28.8%. *)

val default_max_position_pct : float
(** {b Deprecated as of 2026-05-01.} Single-cap field retained for sexp
    backwards compat with scenario fixtures pinned during PR #744. New code
    should use [default_max_position_pct_long] /
    [default_max_position_pct_short]. Value: 0.20 (matches the prior single cap
    so scenarios reading the legacy field don't drift). *)

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
  max_short_notional_fraction : float;
      (** G15 step 2: aggregate short-notional cap evaluated at entry-decision
          time. The strategy sums [|entry_price * quantity|] across all
          currently-open [Holding] shorts in the portfolio; if admitting the
          candidate would push the running total past
          [max_short_notional_fraction * portfolio_value], the short candidate
          is dropped with a [Short_notional_cap] skip reason.

          Differs from [max_short_exposure_pct] (which is consumed by
          {!check_limits} on a portfolio snapshot at proposal time) by sitting
          at the strategy's per-Friday entry walk: the gate fires before any
          cash deduction or [Position.CreateEntering] is emitted, so short-cash
          inflation of [portfolio_value] doesn't size around the cap. Default:
          0.30 (30% of portfolio_value). *)
  min_cash_pct : float;
      (** Minimum cash fraction to maintain (default: 0.10 = 10%).

          {b Deprecated as of 2026-05-01:} never wired into the entry walk's
          [check_cash_and_deduct]. Cash discipline is now handled by
          [max_position_pct × max_positions] + macro gating + force-liquidation
          thresholds. Field retained for sexp compat. *)
  max_position_pct_long : float; [@sexp.default default_max_position_pct_long]
      (** Per-position concentration cap for long entries. Caps EACH new long at
          [portfolio_value * max_position_pct_long] dollars of notional.
          Combined with [max_long_exposure_pct] via [min()] in
          {!compute_position_size}: the final share count is the minimum of
          (risk-based, side-exposure cap, per-position cap). Default 0.30. *)
  max_position_pct_short : float; [@sexp.default default_max_position_pct_short]
      (** Per-position concentration cap for short entries. Caps EACH new short
          at [portfolio_value * max_position_pct_short] dollars of notional.
          Default 0.20. *)
  max_position_pct : float; [@sexp.default default_max_position_pct]
      (** {b Deprecated as of 2026-05-01.} Sexp-compat field for fixtures pinned
          during PR #744. The strategy code does NOT read this field — sizing
          dispatches on [max_position_pct_long] / [max_position_pct_short]
          instead. Retained so existing scenario sexps that mention this name
          still parse. Will be removed once all callers migrate. *)
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
    - max_short_notional_fraction = 0.30 (30%)
    - min_cash_pct = 0.10 (10%, deprecated — see field doc)
    - max_position_pct = 0.20 (20% per position)
    - max_sector_concentration = 5
    - max_unknown_sector_positions = 2
    - big_winner_multiplier = 1.5
    - force_liquidation = {!Force_liquidation.default_config} *)

val compute_position_size :
  config:config ->
  portfolio_value:float ->
  side:[ `Long | `Short ] ->
  entry_price:float ->
  stop_price:float ->
  ?big_winner:bool ->
  unit ->
  sizing_result
(** Compute position size using fixed-risk sizing, capped by exposure limits.

    Two formulas applied in series:
    + Risk-based: shares_risk = floor((portfolio_value * risk_pct) / |entry -
      stop|)
    + Cap-bounded: shares_max = floor(min(side_exposure_cap, position_cap) /
      entry_price), where side_exposure_cap = portfolio_value *
      [max_long_exposure_pct] for [Long] (or [max_short_exposure_pct] for
      [Short]) and position_cap = portfolio_value * [max_position_pct].

    Final share count is the minimum of the two. The exposure cap prevents tight
    stops (small [|entry - stop|]) from producing positions whose notional
    exceeds the configured per-side budget — a sizing pathology observed in the
    sp500-2019-2023 rerun where shorts opened at 124% of portfolio value (ABBV
    2019-02-01). The per-position cap further bounds individual concentration —
    45-48% per-position concentration was observed in sp500-2019-2023 with no
    per-position cap (2026-05-01).

    Pass [entry_price] and [stop_price] in their natural sense — entry is the
    real entry price and stop is the real stop level. The function checks the
    direction against [side]:
    - [Long]: requires [stop_price < entry_price]
    - [Short]: requires [stop_price > entry_price]

    If the stop is on the wrong side or equal to entry, returns 0 shares.

    @param config Risk configuration
    @param portfolio_value Total portfolio value for risk + exposure calculation
    @param side
      [`Long] uses [max_long_exposure_pct]; [`Short] uses
      [max_short_exposure_pct]
    @param entry_price Price at which to enter the position
    @param stop_price Stop-loss price for the position
    @param big_winner
      If [true], scales the risk-based share count by
      [config.big_winner_multiplier]. The exposure cap still applies to the
      final result. Use for high-conviction setups — Stage 2 breakouts with
      strong volume and relative strength — where you want to commit more
      capital. (default: false) *)

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
