(** Assembly of macro-analyzer and screener inputs from a per-symbol bar
    history. Isolates data plumbing from the {!Weinstein_strategy} orchestrator
    so the strategy module focuses on transitions, stops, and screening cadence.

    Stage 4 PR-A: the strategy's hot-path entry points
    ({!build_global_index_views}, {!build_sector_map}) take and return
    {!Snapshot_runtime.Snapshot_bar_views.weekly_view} values rather than
    {!Daily_price.t list}, eliminating the per-tick list allocation. The legacy
    bar-list assembly {!build_global_index_bars} survives for callers that
    haven't switched.

    All functions are side-effectful only on their explicitly-passed state
    (notably [sector_prior_stages]). The underlying bar source is read-only. *)

open Core

val spdr_sector_etfs : (string * string) list
(** SPDR sector ETFs covering the 11 US GICS sectors. The list is stable since
    2018, when XLC was added following the GICS reclassification of
    Communication Services. Exposed so that callers of
    {!Weinstein_strategy.default_config} can opt into sector analysis without
    duplicating the list. *)

val default_global_indices : (string * string) list
(** Major non-US equity indices used by the macro global-consensus indicator.
    [GSPC.INDX] (the US benchmark) is intentionally omitted — it is already
    passed to {!Macro.analyze} as [~index_bars].

    Note: FTSE 100 is represented by [ISF.LSE] (iShares Core FTSE 100 UCITS ETF)
    because EODHD does not carry [FTSE.INDX] or [UKX.INDX]. The ETF is a
    physical-replication tracker with negligible tracking error at weekly
    cadence. *)

val ad_bars_at_or_before :
  ad_bars:Macro.ad_bar list -> as_of:Core.Date.t -> Macro.ad_bar list
(** [ad_bars_at_or_before ~ad_bars ~as_of] returns the prefix of [ad_bars] whose
    [date <= as_of]. Used by {!Weinstein_strategy._run_screen} to prevent the
    composer-loaded synthetic A-D series (which extends to its last
    [compute_synthetic_adl.exe] run, often well past the simulator's current
    tick) from leaking future breadth into the macro analyzer. Without this
    filter, [Macro.analyze_with_callbacks]'s [get_cumulative_ad ~week_offset:0]
    returns the cumulative as of the {b last loaded} A-D bar rather than the
    current simulation date — flipping the A-D / Momentum readings on real
    bear-market data and causing the [Bearish] composite to be misclassified as
    [Neutral] / [Bullish].

    Assumes [ad_bars] is sorted ascending by date, which {!Ad_bars.load}
    guarantees. Returns the input list unchanged when [as_of >= last bar.date]
    (the production-tail case). *)

val build_global_index_views :
  lookback_bars:int ->
  global_index_symbols:(string * string) list ->
  bar_reader:Bar_reader.t ->
  as_of:Date.t ->
  (string * Snapshot_runtime.Snapshot_bar_views.weekly_view) list
(** [build_global_index_views] returns the [(label, weekly_view)] list consumed
    by the macro callback bundle constructor for the global-consensus indicator.
    Each entry is the panel weekly view of the most recent [lookback_bars]
    weeks. Indices with no resident bars are silently dropped so that the macro
    callback sees only usable inputs.

    Stage 4 PR-A: production hot path. No [Daily_price.t list] is materialised.
*)

val build_global_index_bars :
  lookback_bars:int ->
  global_index_symbols:(string * string) list ->
  bar_reader:Bar_reader.t ->
  as_of:Date.t ->
  (string * Types.Daily_price.t list) list
(** [build_global_index_bars] is the bar-list shape of
    {!build_global_index_views}, retained for callers that build
    {!Macro.callbacks} via {!Macro.callbacks_from_bars}. The strategy's hot path
    uses {!build_global_index_views}; this is for tests and bar-list-shaped
    fixtures. *)

val build_sector_map :
  ?ma_cache:Weekly_ma_cache.t ->
  stage_config:Stage.config ->
  lookback_bars:int ->
  sector_etfs:(string * string) list ->
  bar_reader:Bar_reader.t ->
  as_of:Date.t ->
  sector_prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  ticker_sectors:(string, string) Hashtbl.t ->
  unit ->
  (string, Screener.sector_context) Hashtbl.t
(** [build_sector_map] returns a map keyed by stock ticker (e.g. ["AAPL"]). Each
    entry is the {!Screener.sector_context} produced by
    {!Sector.analyze_with_callbacks} via panel-shaped callbacks built from
    [bar_reader] (sector ETF view) and [index_view] (benchmark view).

    The expansion from ETF-level to ticker-level uses [ticker_sectors], a
    ticker→sector-name hashtable typically loaded from [sectors.csv] via
    {!Sector_map.load}. Tickers whose sector name does not match any ETF in
    [sector_etfs] are omitted (the screener defaults them to Neutral).

    ETFs with fewer than [stage_config.ma_period] weekly bars are skipped. An
    empty [index_view] also skips analysis.

    [sector_prior_stages] is read and updated in place so that Stage1->Stage2
    transitions are detected across screening days — the caller owns this
    hashtable as part of the strategy closure state.

    Stage 4 PR-D: when [ma_cache] is passed, sector ETF MA values are fetched
    from the cache rather than recomputed per Friday. *)

(** {1 Snapshot-views constructors (Phase F.3.d)}

    Parallel constructors that take a {!Snapshot_runtime.Snapshot_callbacks.t}
    and fetch the underlying bar views via
    {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for} /
    {!Snapshot_runtime.Snapshot_bar_views.weekly_bars_for} before delegating to
    the panel-shaped helpers above.

    The fetched view types are type-equal to
    {!Snapshot_runtime.Snapshot_bar_views.weekly_view} (declared via [type =] in
    [snapshot_bar_views.mli]), so the delegation requires no per-call adapter
    and the output is bit-identical to the [bar_reader]-backed path on the same
    underlying bar history (parity tests:
    [Test_macro_inputs.Test_snapshot_parity]).

    Phase F.3.d plan: callers migrate from [Macro_inputs.X ~bar_reader] to
    [Macro_inputs.X_of_snapshot_views ~cb], which folds the view fetch into the
    input-assembly. *)

val build_global_index_views_of_snapshot_views :
  lookback_bars:int ->
  global_index_symbols:(string * string) list ->
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  as_of:Date.t ->
  (string * Snapshot_runtime.Snapshot_bar_views.weekly_view) list
(** [build_global_index_views_of_snapshot_views ~lookback_bars
     ~global_index_symbols ~cb ~as_of] returns the [(label, weekly_view)] list
    consumed by the macro callback bundle constructor for the global-consensus
    indicator.

    Same semantics as {!build_global_index_views} but the view fetch goes
    through {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for} over [cb]
    instead of {!Bar_reader.weekly_view_for}. Indices with no resident bars
    (empty view) are silently dropped. *)

val build_global_index_bars_of_snapshot_views :
  lookback_bars:int ->
  global_index_symbols:(string * string) list ->
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  as_of:Date.t ->
  (string * Types.Daily_price.t list) list
(** [build_global_index_bars_of_snapshot_views ~lookback_bars
     ~global_index_symbols ~cb ~as_of] is the bar-list shape of
    {!build_global_index_views_of_snapshot_views}, retained for callers that
    build {!Macro.callbacks} via {!Macro.callbacks_from_bars}. The bar fetch
    goes through {!Snapshot_runtime.Snapshot_bar_views.weekly_bars_for}. *)

val build_sector_map_of_snapshot_views :
  ?ma_cache:Weekly_ma_cache.t ->
  stage_config:Stage.config ->
  lookback_bars:int ->
  sector_etfs:(string * string) list ->
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  as_of:Date.t ->
  sector_prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  ticker_sectors:(string, string) Hashtbl.t ->
  unit ->
  (string, Screener.sector_context) Hashtbl.t
(** [build_sector_map_of_snapshot_views ?ma_cache ~stage_config ~lookback_bars
     ~sector_etfs ~cb ~as_of ~sector_prior_stages ~index_view ~ticker_sectors
     ()] is the snapshot-views variant of {!build_sector_map}: same ETF-level
    analysis path through {!Panel_callbacks.sector_callbacks_of_weekly_views}
    + {!Sector.analyze_with_callbacks} and the same ticker-level expansion via
      [ticker_sectors], but the sector ETF weekly views are fetched via
      {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for} over [cb] instead
      of {!Bar_reader.weekly_view_for}.

    [index_view] is still passed as a {!Snapshot_runtime.Snapshot_bar_views.weekly_view}
    because the strategy keeps the benchmark view in scope across the per-tick
    screen and reuses it across both [build_sector_map_*] paths; callers that
    have only a [Snapshot_callbacks.t] should fetch the benchmark view via
    {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for} themselves.

    [sector_prior_stages] is read and updated in place identically to
    {!build_sector_map}. *)
