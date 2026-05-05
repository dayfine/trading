(** Panel-shaped callback bundles for the Weinstein strategy callees.

    Stage 4 PR-A wedge: every callee in the Weinstein pipeline (Stage / Rs /
    Stock_analysis / Sector / Macro / Weinstein_stops support-floor) has a
    [callbacks_from_bars : Daily_price.t list -> callbacks] constructor today.
    The strategy currently calls those constructors via the bar-list wrapper
    [analyze ~bars:weekly], which materialises a {!Daily_price.t list} per call
    site per tick — the dominant allocator on the panel-mode hot path (see
    [dev/notes/panels-rss-spike-2026-04-25.md]).

    This module's constructors take
    {!Snapshot_runtime.Snapshot_bar_views.weekly_view} or
    {!Snapshot_runtime.Snapshot_bar_views.daily_view} (float-array views over
    snapshot rows) and return the same callback bundles, without ever
    materialising a {!Daily_price.t} record. The resulting bundles are
    bit-identical to those built by [callbacks_from_bars] for the same
    underlying bars, so the strategy can swap call sites one-for-one with no
    behavioural change.

    Stage 4 PR-B: {!Volume.analyze_breakout} and {!Resistance.analyze} now also
    consume callback bundles, so {!stock_analysis_callbacks_of_weekly_views}
    builds the full {!Stock_analysis.callbacks} record from a weekly view alone
    — no transitional [bars_for_volume_resistance] parameter remains. *)

val stage_callbacks_of_weekly_view :
  ?ma_cache:Weekly_ma_cache.t ->
  ?symbol:string ->
  config:Stage.config ->
  weekly:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  unit ->
  Stage.callbacks
(** [stage_callbacks_of_weekly_view ?ma_cache ?symbol ~config ~weekly ()] builds
    a {!Stage.callbacks} bundle backed by the float-array view's [closes] and
    [dates], using the same {!Sma.calculate_sma} / [Sma.calculate_weighted_ma] /
    {!Ema.calculate_ema} kernels as {!Stage.callbacks_from_bars}.

    Stage 4 PR-D: when both [ma_cache] and [symbol] are passed, the MA values
    array is fetched from the cache instead of recomputed per call. The cache
    stores Friday-aligned MA values; if the view's most-recent date matches a
    cached date, the call short-circuits to a panel-cell read. On cache miss
    (mid-week date / unknown symbol) the constructor falls back to inline MA
    computation — preserving bit-equality with the bar-list path on every call.

    Tests and bar-list-only callers pass [()] for the trailing positional arg
    without [?ma_cache] / [?symbol] to use the inline path. The trailing [unit]
    keeps the optional args unambiguous (otherwise OCaml warns "this optional
    argument cannot be erased"). *)

val rs_callbacks_of_weekly_views :
  stock:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  benchmark:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  Rs.callbacks
(** [rs_callbacks_of_weekly_views ~stock ~benchmark] builds a {!Rs.callbacks}
    bundle by date-aligning the two views (same join-on-date semantics as
    {!Rs.callbacks_from_bars}) and indexing the resulting aligned arrays. *)

val volume_callbacks_of_weekly_view :
  weekly:Snapshot_runtime.Snapshot_bar_views.weekly_view -> Volume.callbacks
(** [volume_callbacks_of_weekly_view ~weekly] builds a {!Volume.callbacks}
    bundle backed by the view's [volumes] array (the same encoding
    {!Volume.callbacks_from_bars} produces). [week_offset:0] is the newest
    weekly bar; offsets past the view's depth return [None]. *)

val resistance_callbacks_of_weekly_view :
  weekly:Snapshot_runtime.Snapshot_bar_views.weekly_view -> Resistance.callbacks
(** [resistance_callbacks_of_weekly_view ~weekly] builds a
    {!Resistance.callbacks} bundle backed by the view's [highs], [lows], and
    [dates] arrays. The bar-offset indexing matches
    {!Resistance.callbacks_from_bars}: offset 0 is the newest bar; offsets past
    [n_bars] return [None]. *)

val stock_analysis_callbacks_of_weekly_views :
  ?ma_cache:Weekly_ma_cache.t ->
  ?stock_symbol:string ->
  config:Stock_analysis.config ->
  stock:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  benchmark:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  unit ->
  Stock_analysis.callbacks
(** [stock_analysis_callbacks_of_weekly_views ~config ~stock ~benchmark] builds
    a {!Stock_analysis.callbacks} bundle indexing the stock's [highs] and
    [volumes] arrays for the breakout / peak-volume scans, and threading nested
    {!Stage.callbacks} (over [stock]), {!Rs.callbacks} (over [stock] +
    [benchmark]), {!Volume.callbacks} (over [stock]), and
    {!Resistance.callbacks} (over [stock]) through the bundle.

    As of Stage 4 PR-B, no {!Daily_price.t list} is materialised — every
    sub-callee consumes a callback bundle. *)

val sector_callbacks_of_weekly_views :
  ?ma_cache:Weekly_ma_cache.t ->
  ?sector_symbol:string ->
  config:Sector.config ->
  sector:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  benchmark:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  unit ->
  Sector.callbacks
(** [sector_callbacks_of_weekly_views ~config ~sector ~benchmark] builds a
    {!Sector.callbacks} bundle: nested {!Stage.callbacks} over the sector's own
    bars and {!Rs.callbacks} over the sector vs benchmark. *)

val macro_callbacks_of_weekly_views :
  ?ma_cache:Weekly_ma_cache.t ->
  ?index_symbol:string ->
  config:Macro.config ->
  index:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  globals:(string * Snapshot_runtime.Snapshot_bar_views.weekly_view) list ->
  ad_bars:Macro.ad_bar list ->
  unit ->
  Macro.callbacks
(** [macro_callbacks_of_weekly_views ~config ~index ~globals ~ad_bars] builds a
    {!Macro.callbacks} bundle:

    - [index_stage] over the primary-index weekly view.
    - [get_index_close] indexing the index view's [closes].
    - [get_cumulative_ad] over the precomputed cumulative A-D array (folded from
      [ad_bars] as int-then-float, matching {!Macro.callbacks_from_bars}
      bit-for-bit per the PR-F invariant).
    - [get_ad_momentum_ma] returns the precomputed momentum-MA scalar at offset
      0 only.
    - [global_index_stages] = each (name, view) -> Stage.callbacks. *)

val support_floor_callbacks_of_daily_view :
  Snapshot_runtime.Snapshot_bar_views.daily_view -> Weinstein_stops.callbacks
(** [support_floor_callbacks_of_daily_view view] builds a
    {!Weinstein_stops.callbacks} (= {!Support_floor.callbacks}) bundle keyed by
    day offset. The view is already pre-windowed (by the caller's chosen
    [lookback]); offset [0] is the most recent bar, [n_days - 1] is the oldest,
    mirroring the convention of {!Support_floor.callbacks_from_bars}.

    Returns [None]-yielding callbacks (with [n_days = 0]) for empty views. *)

(** {1 Snapshot-views constructors (Phase F.3.c)}

    Parallel constructors that take a {!Snapshot_runtime.Snapshot_callbacks.t}
    and the symbol / window the underlying bar view should cover, fetching the
    view via {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for} /
    {!Snapshot_runtime.Snapshot_bar_views.daily_view_for} before delegating to
    the panel-shaped constructors above.

    The fetched view types are type-equal to
    {!Snapshot_runtime.Snapshot_bar_views.weekly_view} / {!Snapshot_runtime.Snapshot_bar_views.daily_view}
    (declared via [type =] in [snapshot_bar_views.mli]), so the delegation
    requires no per-call adapter and the output is bit-identical to the
    panel-backed path on the same underlying bar history (parity test:
    [Test_panel_callbacks.Test_snapshot_parity]).

    Phase F.3 plan: callers migrate from
    [Bar_reader.weekly_view_for ... |> Panel_callbacks.X_of_weekly_view] to
    [Panel_callbacks.X_of_snapshot_views ~cb ~symbol ~n ~as_of], which folds the
    view fetch into the callback construction. *)

val stage_callbacks_of_snapshot_views :
  ?ma_cache:Weekly_ma_cache.t ->
  config:Stage.config ->
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  symbol:string ->
  n:int ->
  as_of:Core.Date.t ->
  unit ->
  Stage.callbacks
(** [stage_callbacks_of_snapshot_views ?ma_cache ~config ~cb ~symbol ~n ~as_of
     ()] fetches a weekly view for [symbol] over the most recent [n] weekly
    buckets ending on or before [as_of] via
    {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for}, then delegates to
    {!stage_callbacks_of_weekly_view}. [symbol] doubles as the cache key when
    [ma_cache] is supplied (matching the panel-backed
    [stage_callbacks_of_weekly_view ~symbol] convention). *)

val rs_callbacks_of_snapshot_views :
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  stock_symbol:string ->
  benchmark_symbol:string ->
  n:int ->
  as_of:Core.Date.t ->
  Rs.callbacks
(** [rs_callbacks_of_snapshot_views ~cb ~stock_symbol ~benchmark_symbol ~n
     ~as_of] fetches weekly views for both symbols (same [n] / [as_of] window
    via {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for}) and delegates to
    {!rs_callbacks_of_weekly_views}. The date-aligned join inside the delegate
    handles asymmetric calendar coverage between the two symbols. *)

val volume_callbacks_of_snapshot_views :
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  symbol:string ->
  n:int ->
  as_of:Core.Date.t ->
  Volume.callbacks
(** [volume_callbacks_of_snapshot_views ~cb ~symbol ~n ~as_of] fetches the
    weekly view for [symbol] and delegates to
    {!volume_callbacks_of_weekly_view}. *)

val resistance_callbacks_of_snapshot_views :
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  symbol:string ->
  n:int ->
  as_of:Core.Date.t ->
  Resistance.callbacks
(** [resistance_callbacks_of_snapshot_views ~cb ~symbol ~n ~as_of] fetches the
    weekly view for [symbol] and delegates to
    {!resistance_callbacks_of_weekly_view}. *)

val stock_analysis_callbacks_of_snapshot_views :
  ?ma_cache:Weekly_ma_cache.t ->
  config:Stock_analysis.config ->
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  stock_symbol:string ->
  benchmark_symbol:string ->
  n:int ->
  as_of:Core.Date.t ->
  unit ->
  Stock_analysis.callbacks
(** [stock_analysis_callbacks_of_snapshot_views ?ma_cache ~config ~cb
     ~stock_symbol ~benchmark_symbol ~n ~as_of ()] fetches both weekly views
    (same [n] / [as_of] window) and delegates to
    {!stock_analysis_callbacks_of_weekly_views}. [stock_symbol] doubles as the
    cache key when [ma_cache] is supplied. *)

val sector_callbacks_of_snapshot_views :
  ?ma_cache:Weekly_ma_cache.t ->
  config:Sector.config ->
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  sector_symbol:string ->
  benchmark_symbol:string ->
  n:int ->
  as_of:Core.Date.t ->
  unit ->
  Sector.callbacks
(** [sector_callbacks_of_snapshot_views ?ma_cache ~config ~cb ~sector_symbol
     ~benchmark_symbol ~n ~as_of ()] fetches both weekly views (same [n] /
    [as_of] window) and delegates to {!sector_callbacks_of_weekly_views}.
    [sector_symbol] doubles as the cache key when [ma_cache] is supplied. *)

val macro_callbacks_of_snapshot_views :
  ?ma_cache:Weekly_ma_cache.t ->
  config:Macro.config ->
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  index_symbol:string ->
  globals:(string * string) list ->
  ad_bars:Macro.ad_bar list ->
  n:int ->
  as_of:Core.Date.t ->
  unit ->
  Macro.callbacks
(** [macro_callbacks_of_snapshot_views ?ma_cache ~config ~cb ~index_symbol
     ~globals ~ad_bars ~n ~as_of ()] fetches the primary index weekly view plus
    one weekly view per [(label, symbol)] entry in [globals] (same [n] / [as_of]
    window), filters out empty global views (matching
    {!Macro_inputs.build_global_index_views}'s [view.n = 0] short-circuit), and
    delegates to {!macro_callbacks_of_weekly_views}. [index_symbol] doubles as
    the cache key for the index Stage callback when [ma_cache] is supplied;
    global Stage callbacks remain uncached (matching the panel-backed path). *)

val support_floor_callbacks_of_snapshot_views :
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  lookback:int ->
  calendar:Core.Date.t array ->
  Weinstein_stops.callbacks
(** [support_floor_callbacks_of_snapshot_views ~cb ~symbol ~as_of ~lookback
     ~calendar] fetches a daily view for [symbol] over the most recent
    [lookback] daily bars ending on or before [as_of] via
    {!Snapshot_runtime.Snapshot_bar_views.daily_view_for}, then delegates to
    {!support_floor_callbacks_of_daily_view}.

    The [~calendar] parameter is the trading-day calendar that the panel-backed
    reader uses internally; passing it makes the resulting daily view bit-equal
    to {!Snapshot_runtime.Snapshot_bar_views.daily_view_for}'s window (#848 forward fix). *)
