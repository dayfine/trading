(** Panel-shaped callback bundles for the Weinstein strategy callees.

    Stage 4 PR-A wedge: every callee in the Weinstein pipeline (Stage / Rs /
    Stock_analysis / Sector / Macro / Weinstein_stops support-floor) has a
    [callbacks_from_bars : Daily_price.t list -> callbacks] constructor today.
    The strategy currently calls those constructors via the bar-list wrapper
    [analyze ~bars:weekly], which materialises a {!Daily_price.t list} per call
    site per tick — the dominant allocator on the panel-mode hot path (see
    [dev/notes/panels-rss-spike-2026-04-25.md]).

    This module's constructors take {!Bar_panels.weekly_view} or
    {!Bar_panels.daily_view} (float-array views over panel cells) and return the
    same callback bundles, without ever materialising a {!Daily_price.t} record.
    The resulting bundles are bit-identical to those built by
    [callbacks_from_bars] for the same underlying bars, so the strategy can swap
    call sites one-for-one with no behavioural change.

    Stage 4 PR-B: {!Volume.analyze_breakout} and {!Resistance.analyze} now also
    consume callback bundles, so {!stock_analysis_callbacks_of_weekly_views}
    builds the full {!Stock_analysis.callbacks} record from a weekly view alone
    — no transitional [bars_for_volume_resistance] parameter remains. *)

val stage_callbacks_of_weekly_view :
  ?ma_cache:Weekly_ma_cache.t ->
  ?symbol:string ->
  config:Stage.config ->
  weekly:Data_panel.Bar_panels.weekly_view ->
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
  stock:Data_panel.Bar_panels.weekly_view ->
  benchmark:Data_panel.Bar_panels.weekly_view ->
  Rs.callbacks
(** [rs_callbacks_of_weekly_views ~stock ~benchmark] builds a {!Rs.callbacks}
    bundle by date-aligning the two views (same join-on-date semantics as
    {!Rs.callbacks_from_bars}) and indexing the resulting aligned arrays. *)

val volume_callbacks_of_weekly_view :
  weekly:Data_panel.Bar_panels.weekly_view -> Volume.callbacks
(** [volume_callbacks_of_weekly_view ~weekly] builds a {!Volume.callbacks}
    bundle backed by the view's [volumes] array (the same encoding
    {!Volume.callbacks_from_bars} produces). [week_offset:0] is the newest
    weekly bar; offsets past the view's depth return [None]. *)

val resistance_callbacks_of_weekly_view :
  weekly:Data_panel.Bar_panels.weekly_view -> Resistance.callbacks
(** [resistance_callbacks_of_weekly_view ~weekly] builds a
    {!Resistance.callbacks} bundle backed by the view's [highs], [lows], and
    [dates] arrays. The bar-offset indexing matches
    {!Resistance.callbacks_from_bars}: offset 0 is the newest bar; offsets past
    [n_bars] return [None]. *)

val stock_analysis_callbacks_of_weekly_views :
  ?ma_cache:Weekly_ma_cache.t ->
  ?stock_symbol:string ->
  config:Stock_analysis.config ->
  stock:Data_panel.Bar_panels.weekly_view ->
  benchmark:Data_panel.Bar_panels.weekly_view ->
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
  sector:Data_panel.Bar_panels.weekly_view ->
  benchmark:Data_panel.Bar_panels.weekly_view ->
  unit ->
  Sector.callbacks
(** [sector_callbacks_of_weekly_views ~config ~sector ~benchmark] builds a
    {!Sector.callbacks} bundle: nested {!Stage.callbacks} over the sector's own
    bars and {!Rs.callbacks} over the sector vs benchmark. *)

val macro_callbacks_of_weekly_views :
  ?ma_cache:Weekly_ma_cache.t ->
  ?index_symbol:string ->
  config:Macro.config ->
  index:Data_panel.Bar_panels.weekly_view ->
  globals:(string * Data_panel.Bar_panels.weekly_view) list ->
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
  Data_panel.Bar_panels.daily_view -> Weinstein_stops.callbacks
(** [support_floor_callbacks_of_daily_view view] builds a
    {!Weinstein_stops.callbacks} (= {!Support_floor.callbacks}) bundle keyed by
    day offset. The view is already pre-windowed (by the caller's chosen
    [lookback]); offset [0] is the most recent bar, [n_days - 1] is the oldest,
    mirroring the convention of {!Support_floor.callbacks_from_bars}.

    Returns [None]-yielding callbacks (with [n_days = 0]) for empty views. *)
