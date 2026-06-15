(** Build a {!Snapshot.t} as the set of {b all} current eligible US listings —
    no top-N size cap.

    Sibling of {!Build_from_individuals}, which selects a fixed top-N by
    dollar-volume {i rank} at an annual reconstitution date. This builder
    instead keeps {b every} common-stock-like symbol that clears a set of
    {b absolute eligibility gates}, equal-weighted, for a single current date.
    The output is the same on-disk {!Snapshot.t} shape the screener /
    scenario_runner consume, so it drops straight into the live / backtest
    pipeline.

    Use it to materialize a live, current-dated universe from freshly-fetched
    bars rather than a historical reconstitution.

    {1 Pipeline (per [date])}

    1. {b Active filter} — keep inventory entries with
    [data_start_date <= date - trailing_window_days] (enough trailing history to
    score) and [data_end_date >= date] (actively trading).

    2. {b Equity-like filter} — drop ETF / Mutual_fund / Fund / Bond / Index /
    Currency / Commodity via {!Eodhd.Asset_type.is_equity_like}; keeps
    Common_stock / Preferred_stock / ADR / GDR.

    3. {b Eligibility gates} (all configurable, see {!config}): drop symbols
    whose latest close is below [min_price], whose trailing-window average
    [close * volume] is below [min_avg_dollar_volume], or that have fewer than
    [min_window_bars] bars in the trailing window. A symbol with no on-disk bars
    is dropped.

    4. {b Composition policy} — run {!Composition_policy.apply} with
    [reit_policy = Exclude] and [exclude_preferred = true] (plus the always-on
    dual-class dedup), so REITs and preferred shares are removed and only one
    class per economic entity survives. Net survivors: Common_stock / ADR / GDR
    passing every gate.

    5. {b Emit} — every survivor becomes a {!Snapshot.entry} with uniform weight
    [1.0 /. K] for the [K] survivors (so [total_weight ≈ 1.0]), its real GICS
    sector, [synthetic = false], and [avg_dollar_volume = Some score]. The
    snapshot's [size = K] (the actual survivor count — {b not} a cap) and
    [method_ = Composition_from_individuals] (same consumer-facing tag).
    [aggregate_period_return = 0.0]: a live build has no realized forward
    window.

    {1 Defaults reproduce a keep-all no-op}

    {!default_config}'s gates are all no-ops ([min_price = 0.0],
    [min_avg_dollar_volume = 0.0], [reit_policy = Include],
    [exclude_preferred = false]) — per
    [.claude/rules/experiment-flag-discipline.md] R2, every gate is an explicit
    config field defaulting to the pre-gate behaviour. {!spec_config} is the
    live-universe spec: [min_price = 5.0],
    [min_avg_dollar_volume = 1_000_000.0], [reit_policy = Exclude],
    [exclude_preferred = true]. *)

open Core

type config = {
  min_price : float;
      (** Drop symbols whose latest close (on / before [date]) is strictly below
          this floor. No-op default [0.0]; the live-universe spec uses [5.0]. *)
  min_avg_dollar_volume : float;
      (** Drop symbols whose trailing-window average [close * volume] is
          strictly below this floor. No-op default [0.0]; the spec uses
          [1_000_000.0]. *)
  trailing_window_days : int;
      (** Calendar days of trailing data used for the dollar-volume score and
          activity gate. Default [60]. *)
  min_window_bars : int;
      (** Minimum bars that must fall in the trailing window for a symbol to be
          eligible — reuses {!Build_from_individuals}'s history gate. Default
          [30] (≈ 30 weeks via the active filter / data-coverage requirement),
          dropping sparse / fresh names. *)
  reit_policy : Composition_policy_types.reit_policy;
      (** Passed through to {!Composition_policy}. No-op default [Include]; spec
          uses [Exclude]. *)
  exclude_preferred : bool;
      (** Passed through to {!Composition_policy}. No-op default [false]; spec
          uses [true]. *)
  bars_root : string;
      (** Root of cached bars ([<L1>/<L2>/<symbol>/data.csv]). *)
  symbol_types_path : string;  (** Path to [symbol_types.sexp]. *)
  sectors_csv_path : string;
      (** Path to [sectors.csv] (header [symbol,sector]). *)
  inventory_path : string;  (** Path to [inventory.sexp]. *)
}
[@@deriving sexp]

val default_config :
  bars_root:string ->
  symbol_types_path:string ->
  sectors_csv_path:string ->
  inventory_path:string ->
  config
(** [default_config ...] is the keep-all no-op: [min_price = 0.0],
    [min_avg_dollar_volume = 0.0], [trailing_window_days = 60],
    [min_window_bars = 30], [reit_policy = Include],
    [exclude_preferred = false]. A build through this config keeps every active
    equity-like symbol (the only drop is the always-on dual-class dedup). *)

val spec_config :
  bars_root:string ->
  symbol_types_path:string ->
  sectors_csv_path:string ->
  inventory_path:string ->
  config
(** [spec_config ...] is {!default_config} with the live-universe gates flipped
    on: [min_price = 5.0], [min_avg_dollar_volume = 1_000_000.0],
    [reit_policy = Exclude], [exclude_preferred = true]. *)

val build : date:Date.t -> config:config -> Snapshot.t Status.status_or
(** [build ~date ~config] runs the pipeline in the module docstring and returns
    the equal-weighted snapshot of every eligible symbol at [date].

    Returns:
    - [Error Status.Internal] if [inventory_path], [symbol_types_path], or
      [sectors_csv_path] cannot be read or parsed.
    - [Error Status.Failed_precondition] if {b no} symbol survives every gate
      (an empty universe is a build failure, not a valid snapshot).
    - [Ok snapshot] otherwise, with [snapshot.size] equal to the survivor count
      ({b not} truncated) and uniform per-entry weights. Symbols whose
      per-symbol [data.csv] is missing / unreadable are silently dropped. *)
