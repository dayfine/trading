(** Sparse-tail eligibility gate for {!Weekly_snapshot_generator} (issue #2083
    fix 1).

    {1 What this closes}

    An engineering data-hygiene gate, {b not} a Weinstein book rule — the
    Weinstein spine (stage classification, breakout + volume confirmation,
    macro/sector gates) is untouched by this module; it simply refuses to screen
    a ticker whose recent price series is too sparse to trust.

    2026-07-17 incident (issue #2083): the weekly report's rank-1 pick "SNSE"
    did not exist at the broker — Sensei Biotherapeutics had renamed to Faeth
    Therapeutics (SNSE -> FTH) on 2026-06-16. The data feed kept serving
    occasional stale bars under the dead SNSE ticker (6 bars across ~15 trading
    days), including one anomalous spike bar the screener picked up as a
    breakout. The existing "too few bars -> drop" check
    ({!Weekly_snapshot_generator}'s degraded-input handling) did not fire
    because [data_end] equalled the as-of date — the series was current at the
    right-hand edge and merely sparse in the middle, which the old check never
    inspected.

    {1 What it does}

    {!check} counts how many daily bars are actually present in the trailing
    [window_trading_days] {b trading days} (not calendar days — weekends never
    count as "missing") ending at [as_of], using the bar reader's own
    trading-day calendar (the real holiday calendar in production; a synthesized
    Mon-Fri weekday calendar for tests / in-memory readers — see
    {!Weinstein_strategy.Bar_reader.of_snapshot_views}). A ticker with fewer
    than [min_bars] present in that window is {!Sparse_tail}; the caller drops
    it from candidate consideration and surfaces the warning from {!warning}
    instead of silently vanishing the pick.

    {1 Default-off}

    [window_trading_days <= 0] always returns {!Eligible} — the gate is
    disabled. {!Weekly_snapshot_generator} threads [config.sparse_tail_min_bars]
    / [config.sparse_tail_window_trading_days], both of which default to [0]
    (see {!Weinstein_strategy_config.sparse_tail_min_bars}), so an unarmed run
    is bit-identical to pre-#2083-fix1 behaviour: every ticker with any bars at
    all remains eligible regardless of tail density. *)

open Core

(** [Eligible] — the gate is disabled, or the ticker has enough bars in the
    window. [Sparse_tail { bars_present; min_bars; window_trading_days }] — the
    gate is armed and the ticker fell short; [bars_present] is the actual count
    (for the warning message and tests). *)
type verdict =
  | Eligible
  | Sparse_tail of {
      bars_present : int;
      min_bars : int;
      window_trading_days : int;
    }
[@@deriving eq, show]

val check :
  Weinstein_strategy.Bar_reader.t ->
  symbol:string ->
  as_of:Date.t ->
  min_bars:int ->
  window_trading_days:int ->
  verdict
(** [check bar_reader ~symbol ~as_of ~min_bars ~window_trading_days] is
    {!Eligible} when [window_trading_days <= 0] (gate disabled) or when [symbol]
    has at least [min_bars] daily bars present among the trailing
    [window_trading_days] trading days ending at (and including) [as_of].
    Otherwise {!Sparse_tail}, carrying the actual bar count.

    A symbol entirely absent from [bar_reader] (0 bars in the window) is
    {!Sparse_tail} whenever the gate is armed with [min_bars > 0] — this gate
    does not special-case "no data" as a separate outcome; it is the sparsest
    possible tail. Pure: same inputs -> same output ([bar_reader] is read-only).
*)

val partition :
  Weinstein_strategy.Bar_reader.t ->
  as_of:Date.t ->
  min_bars:int ->
  window_trading_days:int ->
  string list ->
  string list * string list
(** [partition bar_reader ~as_of ~min_bars ~window_trading_days tickers] applies
    {!check} to each ticker and returns [(eligible, warnings)]: the tickers that
    passed (order preserved) and one {!warning} line per ticker the gate
    dropped. With the gate disabled ([window_trading_days <= 0], the default)
    this returns [(tickers, [])]. Pure. *)

val warning : symbol:string -> verdict -> string option
(** [warning ~symbol verdict] is [None] for {!Eligible}. For {!Sparse_tail} it
    is [Some msg], a human-readable single line naming the symbol, the actual
    vs. required bar count, and the window — suitable for
    {!Weekly_snapshot.t.warnings} and the rendered report, so a dropped
    candidate is visible and explained rather than silently missing. *)
