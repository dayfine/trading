(** Per-symbol accumulated daily bar buffer used by the Weinstein strategy
    closure. The buffer is read by the stage classifier, MA computation, and
    macro input builders. Writes are idempotent on repeated calls with the same
    bar date so the simulator can re-invoke the strategy on a replayed day
    without duplicating history. *)

open Core

type t = Types.Daily_price.t list Hashtbl.M(String).t
(** A mutable hashtable from symbol to its daily bar history, in chronological
    order (oldest first). *)

val create : unit -> t
(** Empty bar history. *)

val accumulate :
  t ->
  get_price:Trading_strategy.Strategy_interface.get_price_fn ->
  symbols:string list ->
  unit
(** For each symbol in [symbols], pull today's bar via [get_price] and append it
    to the buffer — but only if the bar's date is strictly later than the last
    recorded bar. Called on every strategy invocation; idempotent for replayed
    days. *)

val weekly_bars_for : t -> symbol:string -> n:int -> Types.Daily_price.t list
(** Return the most recent [n] weekly-aggregated bars for [symbol]. Daily bars
    are converted via {!Time_period.Conversion.daily_to_weekly} with
    [include_partial_week:true]. Returns the empty list if [symbol] has no
    accumulated bars, or all available weekly bars if fewer than [n] exist. *)

val daily_bars_for : t -> symbol:string -> Types.Daily_price.t list
(** Return the full accumulated daily bar history for [symbol] in chronological
    order (oldest first). Returns the empty list if [symbol] has no accumulated
    bars. Callers that need a bounded window should slice the result themselves
    — the support-floor primitive in [weinstein_stops] is one such caller. *)

val trim_before : t -> as_of:Date.t -> max_lookback_days:int -> unit
(** [trim_before t ~as_of ~max_lookback_days] drops, for every symbol in [t],
    bars whose date is strictly older than [as_of] minus [max_lookback_days]
    days. Bars whose date equals or exceeds the cutoff are retained.

    Idempotent: calling twice with the same [as_of] / [max_lookback_days] is
    equivalent to calling once. Calling with an [as_of] in the future relative
    to the held bars is a no-op (cutoff is older than every bar; nothing drops).
    Calling with [max_lookback_days = 0] drops every bar whose date is strictly
    less than [as_of] — i.e., keeps only [as_of]'s bar if present.

    Raises [Invalid_argument] if [max_lookback_days < 0].

    Motivation: per-symbol bar buffers grow monotonically via [accumulate] and
    [seed], but strategy readers (52-week RS line, 30-week MA, ATR) only need a
    bounded recent window. Periodically calling [trim_before] caps the buffer's
    working set at [max_lookback_days] days per symbol. See
    [dev/plans/bar-history-trim-2026-04-24.md] for the motivating measurement.
*)

val seed : t -> symbol:string -> bars:Types.Daily_price.t list -> unit
(** [seed t ~symbol ~bars] merges [bars] into [symbol]'s accumulated history.
    [bars] must already be in chronological order (oldest first) — the caller is
    responsible for ordering (typical sources like [Bar_loader.Full.t.bars] and
    CSV storage are ascending by date already).

    Merge semantics match {!accumulate}: bars whose date is strictly later than
    [symbol]'s current last-bar date are appended; older or equal-dated bars are
    silently dropped. When [symbol] has no prior history, [bars] becomes the
    whole history (duplicate-date entries inside [bars] are {b not} deduplicated
    — the caller must supply clean data).

    Idempotent: calling [seed] twice with the same [bars] is equivalent to
    calling it once.

    Motivating use case: the Tiered backtest path throttles [accumulate] so
    [Bar_history] doesn't grow for every universe symbol. When a symbol is
    promoted to [Bar_loader.Full_tier], the loader holds a bounded OHLCV tail
    for it; [seed] ingests that tail into the strategy's [Bar_history] so
    readers ([_screen_universe], [Stops_runner], [_make_entry_transition]) see
    bars without further change to the strategy code. *)
