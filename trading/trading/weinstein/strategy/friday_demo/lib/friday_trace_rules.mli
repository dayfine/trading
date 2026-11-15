(** The "Does:" prose of each stage of the Friday trace, built from the config
    the run uses.

    The prose is the trace's contract with its reader, so every rule value is
    read from the config rather than written into the text, a rule the config
    can switch off or arm is described only as the config sets it, and a value
    the demo changed from the strategy default says so
    ({!Friday_trace_format.setting}). Each function returns one paragraph per
    element, for {!Friday_trace_format.header}; each comment names the code the
    sentence describes. Stages 1 and 4 quote no config value and keep their
    prose inline in the printer. *)

val stage_classification : Stage.config -> string list
(** Stage 2: the MA period, the rising-MA slope test and the weeks-above-MA test
    of [Stage.classify]. *)

val macro_gate :
  Weinstein_strategy.Weinstein_strategy_config.config -> string list
(** Stage 3: how [Macro] weighs its indicators, and which trend blocks which
    side ([Screener.longs_admitted_by_macro] / [shorts_admitted_by_macro] under
    the config's [neutral_blocks_longs] / [neutral_blocks_shorts]). *)

val breakout_cascade :
  Weinstein_strategy.Weinstein_strategy_config.config -> string list
(** Stage 5: the long buy rules in the screen's order, with every arm of the
    stage-setup rule the config arms ([virgin_crossing_readmission],
    [enable_continuation_buys]) and each optional gate marked off when unset. *)

val scoring : Screener.config -> string list
(** Stage 6: the grade thresholds and the lowest grade bought. *)

val ranking :
  Weinstein_strategy.Weinstein_strategy_config.config ->
  date:Core.Date.t ->
  string list
(** Stage 7: the order and tiebreak of [Screener.compare_rankable], and the
    per-side top-N caps. *)

val entry_walk :
  Weinstein_strategy.Weinstein_strategy_config.config ->
  initial_stop_buffer:float ->
  string list
(** Stage 8: the trigger, the initial stop (the support floor under the config's
    [support_floor_anchor_scope] and [support_floor_anchor_mode], the fallback
    at [initial_stop_buffer], the round-number nudge), the skip rules, and
    [Portfolio_risk.compute_position_size]'s sizing caps. *)

val orders : Weinstein_strategy.Weinstein_strategy_config.config -> string list
(** Stage 9: the entry order shape the simulator works (a stop-limit with the
    [entry_extension_max_pct] band when armed, else a market order). *)
