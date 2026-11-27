(** The per-stock analysis config the weekly report screens with. *)

val of_strategy_config : Weinstein_strategy.config -> Stock_analysis.config
(** [of_strategy_config config] is the backtest's per-screen config,
    [Weinstein_strategy.stock_analysis_config_for ~config], so the report
    screens on every strategy knob the simulator threads: the continuation
    detector ([enable_continuation_buys] + [continuation_config]), the
    resistance [min_history_bars] floor ([resistance_min_history_bars]), the RS
    [Positive_declining] toggle ([enable_rs_positive_declining]),
    [overhead_supply], the virgin-crossing re-admission
    [virgin_crossing_readmission] and its price basis [virgin_supply_basis]
    (#3664), the replace anchor [entry_anchor_local_range_weeks], the
    stale-entry cap [entry_cap_local_range_weeks] ({!Stale_entry_cap}) and the
    F1 [entry_freshness_basis] (#3725, #3726).

    One deliberate divergence: [require_breakout_volume] stays at
    {!Stock_analysis.default_config}'s [true] even when F5
    ([Weinstein_strategy_config.volume_confirm_at_fill_armed]) is armed. The
    backtest waives the screen-time volume gate only because
    [Volume_eject_runner] checks volume in the fill week instead; the live path
    has no fill-week check, so copying the waiver alone would drop volume
    confirmation from the picks (weinstein-faithful-core spine item 3).

    Every threaded knob defaults to the no-op or to the strategy's own default,
    so the weekly report is unchanged when unarmed. *)
