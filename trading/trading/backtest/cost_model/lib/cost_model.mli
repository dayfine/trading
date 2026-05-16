(** Cost-model overlay for backtest pipelines.

    Canonical, scenario-facing cost-configuration record. Four orthogonal cost
    components, each parameterised so scenarios can sweep them independently:

    - {b Per-trade flat commission} — dollars per executed trade, independent of
      share count (typical of "flat-fee" retail brokers).
    - {b Per-share commission} — dollars per share traded (typical of
      institutional commissions). Composes with the existing
      {!Trading_engine.Types.commission_config.minimum} floor when converted via
      {!to_engine_costs}.
    - {b Bid-ask spread, basis points} — one-side spread paid at fill. Buys pay
      the offer (price up), sells take the bid (price down). Composes with the
      engine's existing intraday-path slippage.
    - {b Market impact, bps per 1% ADV} — additional bps charged per 1% of
      average daily volume the order represents. Shipped as a pure function for
      now; not auto-applied because ADV is not yet plumbed into the fill path.
      See {!market_impact_bps}.

    The four-component design isolates each cost so scenarios can sweep them
    independently and so unit tests can pin each in isolation.

    {1 Wiring}

    This module is intentionally separate from the engine. The
    {!Trading_engine.Types.engine_config} already exposes per-share commission +
    slippage_bps; rather than reshape that API, this module is the canonical
    scenario-facing config record and converts via {!to_engine_costs} into the
    engine's existing surface. The two extra knobs (flat per-trade, market
    impact) are exposed as pure functions over {!Trading_base.Types.trade} so
    callers can apply them as a post-fill {!Trading_base.Types.trade} adjustment
    layer.

    {1 Realistic defaults}

    - {!zero} — frictionless. The default; preserves byte-equal baselines.
    - {!retail_default} — flat-fee retail: $0/trade, $0/share, 5 bps spread, no
      impact. Approximates Robinhood / IBKR Lite circa 2026.
    - {!institutional_default} — institutional: $0/trade, $0.005/share, 2 bps
      spread, 1 bps per 1% ADV. Approximates IBKR Pro tiered + a conservative
      impact coefficient. *)

type t = {
  per_trade_commission : float;
      (** Dollars per executed trade, independent of share count. Must be
          {m \geq 0}. Default {m 0.0}. *)
  per_share_commission : float;
      (** Dollars per share traded. Must be {m \geq 0}. Default {m 0.0}. Maps to
          {!Trading_engine.Types.commission_config.per_share}. *)
  bid_ask_spread_bps : float;
      (** One-side spread in basis points. Must be {m \geq 0}. Default {m 0.0}.
          {m 5.0} bps = 0.05% one-side. Converted to the engine's [int]
          slippage_bps via {!to_engine_costs}. *)
  market_impact_bps_per_pct_adv : float;
      (** Impact bps per 1% of average daily volume. Must be {m \geq 0}. Default
          {m 0.0}. Used by {!market_impact_bps}. *)
}
[@@deriving sexp, show, eq]
(** Cost-model configuration record. Each field is non-negative and
    independently sweepable. Zero in every field reduces to the frictionless
    baseline. *)

val zero : t
(** Frictionless cost model — every component is {m 0.0}. Use as the back-compat
    default for scenarios that omit cost_model. *)

val retail_default : t
(** Approximate flat-fee retail broker: $0/trade, $0/share, 5 bps bid-ask, no
    market impact. *)

val institutional_default : t
(** Approximate institutional broker: $0/trade, $0.005/share, 2 bps bid-ask, 1
    bps per 1% ADV market impact. *)

val validate : t -> (unit, Status.t) result
(** [validate t] returns [Ok ()] iff every field is non-negative and finite.
    Negative or NaN/infinite values yield an [invalid_argument_error] explaining
    the offending field. *)

val to_engine_costs : t -> Trading_engine.Types.commission_config * int
(** [to_engine_costs t] converts the cost-model record into the engine's
    existing per-share commission record + integer slippage bps. Used to wire
    scenarios into {!Trading_simulation.Simulator.create_deps}.

    Mapping:
    - [commission_config.per_share = t.per_share_commission]
    - [commission_config.minimum   = 0.0] (the flat per-trade component is
      applied separately via {!apply_per_trade_commission}; the engine's
      [minimum] floor is a different concept that this module intentionally does
      not expose)
    - [slippage_bps = round(t.bid_ask_spread_bps)] (engine API is [int];
      rounding nearest-half-to-even).

    Per-trade flat commission and market-impact bps are NOT folded into the
    engine config — they require per-trade information (commission flat: trade
    count; impact: order size and ADV) and are applied via the helpers below. *)

val apply_per_trade_commission :
  t -> Trading_base.Types.trade -> Trading_base.Types.trade
(** [apply_per_trade_commission t trade] returns a trade whose [commission]
    field has been increased by [t.per_trade_commission]. When
    [t.per_trade_commission = 0.0] this is the identity function and the input
    is returned unchanged (byte-equal preservation of the zero-cost baseline).
*)

val market_impact_bps : t -> adv_pct:float -> float
(** [market_impact_bps t ~adv_pct] returns the bid-side impact in basis points
    for an order whose size is [adv_pct] percent of ADV. Linear in [adv_pct]:

    {[
    result = t.market_impact_bps_per_pct_adv *. adv_pct
    ]}

    Pure, side-effect-free. Negative [adv_pct] is clamped to zero so sell-side
    orders against a thin tape never produce a negative impact bonus. This
    function is currently NOT wired into the simulator (ADV plumbing pending);
    shipped pure-and-tested so callers can apply it from analysis scripts and so
    the future wiring change is a thin call-site edit. *)

val apply_market_impact :
  t ->
  adv_pct:float ->
  side:Trading_base.Types.side ->
  fill_price:float ->
  float
(** [apply_market_impact t ~adv_pct ~side ~fill_price] returns the fill price
    adjusted by the {!market_impact_bps} for the given [adv_pct]. Buys pay up,
    sells take down — symmetric one-side impact. When the coefficient is zero
    the input price is returned unchanged. *)
