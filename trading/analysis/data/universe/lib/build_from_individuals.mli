(** Build a {!Snapshot.t} from cached EODHD bars via dollar-volume rank.

    Pivoted from the original shares-outstanding ranker (blocked on EODHD
    Fundamentals tier 403). Dollar-volume is a defensible proxy for "tradeable
    size" and arguably superior to market cap for Weinstein universe
    construction (it weights liquidity rather than total cap).

    See [dev/plans/custom-universe-bidirectional-2026-05-17.md] §Q2-A.

    {1 Algorithm}

    For each annual reconstitution date [YYYY-05-31]:

    1. Filter [inventory] to symbols where [data_start_date <= YYYY - 04-01]
    (need [trailing_window_days] of data) and [data_end_date >= YYYY-05-31]
    (actively trading).

    2. Pass the survivors through
    [Asset_type_enrichment_lib.filter_equity_like_symbols] to drop funds, ETFs,
    bonds, etc.

    3. For each remaining symbol, read its bars CSV at
    [{bars_root}/<L1>/<L2>/<symbol>/data.csv], window to
    [[YYYY-03-01, YYYY-05-31]], compute [avg(close * volume)] across the window.
    Symbols with fewer than [min_window_bars] bars in window (e.g. fresh
    listings or sparse OTC names) are dropped.

    4. Rank descending by avg dollar volume; take top [size].

    5. Look up each kept symbol's sector from [sectors.csv]; default to empty
    string when missing.

    6. Compute a 1-year forward [aggregate_period_return]: for each entry, find
    the first [adjusted_close] on / after [date] and the last [adjusted_close]
    on / before [date + 365 days]; per-symbol return is
    [(p_end / p_start) - 1.0]; aggregate is the simple average (equal-weight).
    Symbols missing either endpoint are skipped from the aggregate.

    Weights are uniform [1.0 /. size]. Dollar-volume is used purely for ranking;
    we do not propagate the score into the snapshot.

    {1 Why dollar-volume instead of market cap}

    - Vendor-blocked: [/api/fundamentals/] returns 403 on our token.
    - Better Weinstein proxy: liquidity rather than total cap controls whether a
      name is tradeable at backtest-realistic position sizes.
    - Pure: rank is computed deterministically from cached bars; no vendor
      calls. *)

open Core

type config = {
  size : int;  (** Top-N cutoff: typically 500, 1000, or 3000. *)
  trailing_window_days : int;
      (** Calendar days of trailing data needed to score a symbol. Default [60].
      *)
  min_window_bars : int;
      (** Minimum bars that must fall in [[date - trailing_window_days, date]]
          for a symbol to be eligible. Default [30]. Drops sparse / fresh names.
      *)
  bars_root : string;
      (** Filesystem root containing [<L1>/<L2>/<symbol>/data.csv]. *)
  symbol_types_path : string;
      (** Path to [symbol_types.sexp] (see [Asset_type_enrichment_lib]). *)
  sectors_csv_path : string;
      (** Path to [sectors.csv] — header [symbol,sector]. Missing symbols
          default to empty sector. *)
  inventory_path : string;
      (** Path to [inventory.sexp] (see [weinstein.data_source]). *)
}
[@@deriving sexp]

val default_config :
  size:int ->
  bars_root:string ->
  symbol_types_path:string ->
  sectors_csv_path:string ->
  inventory_path:string ->
  config
(** [default_config ~size ~bars_root ~symbol_types_path ~sectors_csv_path
     ~inventory_path] sets [trailing_window_days = 60] and
    [min_window_bars = 30]. *)

val avg_dollar_volume_for_bars :
  date:Date.t ->
  trailing_window_days:int ->
  min_window_bars:int ->
  Composition_bar_reader.bar list ->
  float option
(** [avg_dollar_volume_for_bars ~date ~trailing_window_days ~min_window_bars
     bars] is the trailing-window dollar-volume score over [bars]: it windows to
    [[date - trailing_window_days, date]] and returns
    [Some (avg (close * volume))] across that window when at least
    [min_window_bars] bars fall inside it, else [None] (the same condition under
    which {!build} drops a symbol). Pure helper over an already-read [bar list]
    so a caller that needs both this score and {!latest_close_for_bars} reads
    the CSV once. This is the exact scoring {!avg_dollar_volume_for_symbol} and
    {!build}'s ranker apply. *)

val latest_close_for_bars :
  date:Date.t -> Composition_bar_reader.bar list -> float option
(** [latest_close_for_bars ~date bars] is the [close] of the most recent bar on
    or before [date], or [None] when no bar falls on / before [date]. Used by
    the eligibility builder's [min_price] gate. Pure helper over an already-read
    [bar list]. *)

val avg_dollar_volume_for_symbol :
  date:Date.t -> config:config -> string -> float option
(** [avg_dollar_volume_for_symbol ~date ~config symbol] computes the single
    symbol's trailing dollar-volume score using the *exact* same logic {!build}
    applies when ranking the universe: read the symbol's bars from
    [config.bars_root], window to [[date - config.trailing_window_days, date]],
    and return [Some (avg (close * volume))] over the window when at least
    [config.min_window_bars] bars fall inside it, else [None].

    Exposed so a snapshot-enrichment pass can backfill the per-entry
    [avg_dollar_volume] field for an *existing* symbol set without re-ranking
    the universe (which would drift composition). [None] when the symbol's
    [data.csv] is missing / unreadable or the window has too few bars — the same
    conditions under which {!build} would have dropped the symbol. Only
    [config.bars_root], [config.trailing_window_days], and
    [config.min_window_bars] are consulted; the inventory / sector / size fields
    are unused. *)

val build : date:Date.t -> config:config -> Snapshot.t Status.status_or
(** [build ~date ~config] runs the algorithm described in the module docstring
    and returns a composition snapshot anchored at [date].

    Returns:
    - [Error Status.Invalid_argument] if [config.size <= 0].
    - [Error Status.Internal] if [inventory_path], [symbol_types_path], or
      [sectors_csv_path] cannot be read or parsed.
    - [Error Status.Failed_precondition] if fewer than [config.size] symbols
      survive the activity + equity-like + min-bars filters (insufficient signal
      to rank).
    - [Ok snapshot] otherwise. Symbols whose per-symbol [data.csv] is missing or
      unreadable are silently dropped (per spec: not every inventory entry has
      on-disk bars). *)
