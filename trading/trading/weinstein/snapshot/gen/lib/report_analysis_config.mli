(** The per-stock analysis config the weekly report screens with. *)

val of_strategy_config : Weinstein_strategy.config -> Stock_analysis.config
(** [of_strategy_config config] is {!Stock_analysis.default_config} with the
    strategy config's ticket-level knobs threaded in. Those are
    [overhead_supply], the virgin-crossing re-admission
    [virgin_crossing_readmission] and their price basis [virgin_supply_basis]
    (#3664; each carries the strategy default, which the report then shares with
    the backtest), the replace anchor [entry_anchor_local_range_weeks], the
    stale-entry cap [entry_cap_local_range_weeks] ({!Stale_entry_cap}) and the
    F1 [entry_freshness_basis]. Each defaults to the no-op or to the strategy's
    own default, so the weekly report stays bit-identical when unarmed. It is
    the weekly-report counterpart of the simulator's
    [Weinstein_strategy.stock_analysis_config_for] for these knobs. *)
