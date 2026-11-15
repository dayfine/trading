(** The synthetic market the Friday demo runs on.

    Every symbol is made up ([DEMO_*]) and every price is generated here, so no
    vendor data enters the repo. Nine stocks, one index and three sector ETFs,
    with about two years of weekday bars. Each stock is shaped to stop at a
    different point of the pipeline; the README lists which is which.

    The weekly closes are spelled out as legs (ramp to this close over that many
    weeks) and turned into daily bars by straight-line interpolation between
    Friday closes, with a fixed 1 % intraday range, so a reader can follow a
    shape from its definition to the stage it lands in. The shared
    [Synthetic_source] patterns (trend, base, breakout, decline) cannot place a
    pullback low or a single breakout week, which is what the stop gates and the
    stage transition key on, hence the small generator here. *)

val demo_friday : Core.Date.t
(** The screening Friday the demo prints. *)

val warmup_fridays : Core.Date.t list
(** The Fridays the strategy runs on before {!demo_friday} to build its carried
    state (last week's stage per ticker), oldest first. *)

val config : Weinstein_strategy.Weinstein_strategy_config.config
(** The strategy's default config with the demo's universe, index and sector
    ETFs, a top-N of 4 so the cut is visible, a fixed seeded tiebreak, and the
    investor preset's [require_structural_stop]. *)

val inputs : unit -> Friday_pipeline.inputs
(** The bar reader over the fixture's bars (materialised in a temp directory),
    the ticker-to-sector map, and a $100,000 all-cash account. *)

val trace : unit -> Friday_trace.t
(** Warm the strategy up over {!warmup_fridays}, then run {!demo_friday}. *)
