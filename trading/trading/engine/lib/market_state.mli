(** Per-symbol market state for the execution engine: the most-recent bar for
    every symbol, the reusable [Price_path] scratch pool, and a per-tick memo of
    already-generated intraday paths.

    Memory note: [update] stores only the per-symbol
    {!Trading_engine.Types.price_bar} (a handful of floats). The intraday
    [Price_path] — a boxed [intraday_path] list of ~390 points, ~19 KB each — is
    generated lazily in {!path_for}, and only for the handful of symbols an
    order actually references each tick. The prior design generated one path per
    symbol with a bar every tick, allocating ~N (universe-size) of these per day
    even though >99% were never read. At broad-N (3000-symbol PIT universes)
    that per-tick churn dominated the major heap and OOM'd the container;
    deferring it flattens the heap with no change to fill prices (same bar +
    scratch + config -> same path). *)

type t

val create : unit -> t
(** Empty market state: no bars observed, empty scratch pool and memo. *)

val update :
  t -> path_config:Price_path.path_config -> Types.price_bar list -> unit
(** Record [bars] as the most-recent bar for each symbol and retain
    [path_config] for later lazy path generation. Clears the per-tick path memo
    so the next {!path_for} for any symbol regenerates from the new bar. *)

val path_for :
  t -> symbol:Trading_base.Types.symbol -> Types.intraday_path option
(** Intraday path for [symbol], generated from its most-recent stored bar and
    memoized for the current tick. [None] when no bar has been observed for
    [symbol]. Repeated calls within one tick return the {e same} path, matching
    the prior eager design where each symbol's path was generated exactly once
    per tick (so sibling orders on one symbol see one path, not independent
    random draws). *)
