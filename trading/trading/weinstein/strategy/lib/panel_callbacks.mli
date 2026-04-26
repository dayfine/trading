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

    {b Out of scope (PR-B)}: {!Volume.analyze_breakout} and
    {!Resistance.analyze} still consume {!Daily_price.t list}. The
    {!stock_analysis_callbacks_of_weekly_views} return value pairs with the
    bar-list still required by those callees as [bars_for_volume_resistance];
    PR-B reshapes Volume + Resistance and drops the parameter. *)

val stage_callbacks_of_weekly_view :
  config:Stage.config ->
  weekly:Data_panel.Bar_panels.weekly_view ->
  Stage.callbacks
(** [stage_callbacks_of_weekly_view ~config ~weekly] builds a {!Stage.callbacks}
    bundle backed by the float-array view's [closes] and [dates], using the same
    {!Sma.calculate_sma} / [Sma.calculate_weighted_ma] / {!Ema.calculate_ema}
    kernels as {!Stage.callbacks_from_bars}. *)

val rs_callbacks_of_weekly_views :
  stock:Data_panel.Bar_panels.weekly_view ->
  benchmark:Data_panel.Bar_panels.weekly_view ->
  Rs.callbacks
(** [rs_callbacks_of_weekly_views ~stock ~benchmark] builds a {!Rs.callbacks}
    bundle by date-aligning the two views (same join-on-date semantics as
    {!Rs.callbacks_from_bars}) and indexing the resulting aligned arrays. *)

val stock_analysis_callbacks_of_weekly_views :
  config:Stock_analysis.config ->
  stock:Data_panel.Bar_panels.weekly_view ->
  benchmark:Data_panel.Bar_panels.weekly_view ->
  Stock_analysis.callbacks
(** [stock_analysis_callbacks_of_weekly_views ~config ~stock ~benchmark] builds
    a {!Stock_analysis.callbacks} bundle indexing the stock's [highs] and
    [volumes] arrays for the breakout / peak-volume scans, and threading nested
    {!Stage.callbacks} (over [stock]) and {!Rs.callbacks} (over [stock]
    + [benchmark]) through the bundle.

    Note: {!Stock_analysis.analyze_with_callbacks} also takes
    [bars_for_volume_resistance : Types.Daily_price.t list] for the not-yet-
    reshaped Volume / Resistance callees. PR-A callers reconstruct that bar list
    via {!Bar_panels.weekly_bars_for}; PR-B reshapes those callees and drops the
    parameter. *)

val sector_callbacks_of_weekly_views :
  config:Sector.config ->
  sector:Data_panel.Bar_panels.weekly_view ->
  benchmark:Data_panel.Bar_panels.weekly_view ->
  Sector.callbacks
(** [sector_callbacks_of_weekly_views ~config ~sector ~benchmark] builds a
    {!Sector.callbacks} bundle: nested {!Stage.callbacks} over the sector's own
    bars and {!Rs.callbacks} over the sector vs benchmark. *)

val macro_callbacks_of_weekly_views :
  config:Macro.config ->
  index:Data_panel.Bar_panels.weekly_view ->
  globals:(string * Data_panel.Bar_panels.weekly_view) list ->
  ad_bars:Macro.ad_bar list ->
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
