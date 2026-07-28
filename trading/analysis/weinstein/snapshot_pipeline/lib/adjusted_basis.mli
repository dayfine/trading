(** Rescale a raw-OHLC daily bar onto its split/dividend-adjusted price basis.

    Warehouses store raw OHLC alongside a separate [adjusted_close]; the
    resistance-supply machinery (weekly side-tables, the histogram sketch)
    measures overhead supply on the price series. Measuring on RAW prices
    mis-scales any symbol with a split inside the lookback window — a forward
    split hides real supply, a reverse split fabricates phantom supply (issue
    #2133). This helper pins the measurement to the adjusted basis. Its
    semantics match {!Weinstein_snapshot.Svg_series}'s chart-side rescale so the
    report charts and the supply sketch agree on the same continuous scale. *)

val to_adjusted_basis : Types.Daily_price.t -> Types.Daily_price.t
(** [to_adjusted_basis b] scales [b]'s open/high/low by the split/dividend
    factor [f = adjusted_close /. close_price] and sets
    [close_price := adjusted_close], so the whole bar lies on the same
    continuous scale as [adjusted_close]. The [adjusted_close], [volume], [date]
    and [active_through] fields are preserved.

    A non-positive or NaN raw [close_price] admits no factor ([f = 1.0]): the
    O/H/L keep their raw values and [close_price] takes [adjusted_close] — a
    corrupt bar must not blow up the rescale. Idempotent: on an already-adjusted
    bar ([close_price = adjusted_close]) the factor is [1.0], so re-applying is
    a no-op. Pure function. *)
