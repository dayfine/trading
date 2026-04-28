(** Strategy wrapper that injects a panel-backed [get_indicator_fn] in place of
    the simulator's market-data-adapter-backed one.

    The wrapper holds an [Ohlcv_panels.t], an [Indicator_panels.t] registry, and
    a date → column map (the universe trading calendar). On each
    [on_market_close] call, it:

    1. Reads today's date from [get_price] for the primary index symbol. 2.
    Resolves the date to a panel column [t]. 3. Calls
    [Indicator_panels.advance_all ~t] using the pre-populated OHLCV panel. 4.
    Builds a panel-backed [get_indicator_fn] via [Get_indicator_adapter.make]
    and substitutes it into the inner strategy's [on_market_close] call.

    The OHLCV panel is fully pre-populated at runner startup
    ([Panel_runner._build_ohlcv] -> [Ohlcv_panels.load_from_csv_calendar]). The
    wrapper does NOT write the simulator's per-tick [get_price] results back
    into the panel: the panel is the authoritative reference and the simulator's
    per-step output (potentially adjusted for splits/dividends — see #641's MtM
    fix) must not flow back into the screener's view of the market.

    Stage 1 invariant: [Bar_history] inside the inner Weinstein strategy stays
    alive and untouched. The Weinstein strategy does not consume [get_indicator]
    today, so injecting the panel-backed closure does not perturb behaviour —
    the integration parity gate ensures this. The point of this wrapper is to
    validate the panel infrastructure end-to-end before Stages 2-4 actually
    consume from it.

    On dates not present in the calendar (e.g., holidays where the simulator
    still calls the strategy with stale prices) or falling completely outside
    the calendar, the wrapper falls back to passing the simulator's original
    [get_indicator] through unchanged — the panel state is undefined for those
    dates. *)

open Trading_strategy

type config = {
  ohlcv : Data_panel.Ohlcv_panels.t;
  indicators : Data_panel.Indicator_panels.t;
  calendar : Core.Date.t array;
      (** [calendar.(t)] is the date at panel column [t]. Used both for date →
          column lookup and for bound checking. *)
  primary_index : string;
      (** Symbol whose [get_price] result drives the per-tick date detection;
          must be present in [Ohlcv_panels.symbol_index ohlcv]. *)
}

val wrap :
  config:config ->
  (module Strategy_interface.STRATEGY) ->
  (module Strategy_interface.STRATEGY)
(** [wrap ~config strategy] returns a new strategy module that drives panel
    advance per tick and supplies the inner [strategy] with a panel-backed
    [get_indicator_fn]. *)
