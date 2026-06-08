(** Detects positions still held after their underlying bars stop arriving —
    typical cause is a corporate-action (cash merger, stock merger, bankruptcy
    delisting, suspension) the strategy did not anticipate, so the position
    remains in [Holding] state without any further price signal. The simulator
    records each such {b held} symbol per step into a {!Log}, callers persist
    the log alongside other run artefacts.

    By default {b this module does not force-close the position} — it is a pure
    detector + recorder, and the position continues to be valued via
    forward-fill (last-known close from
    {!Market_data_adapter.get_previous_bar}). When
    [config.stale_exit_after_days] is set, {!force_exit_candidates} additionally
    selects held positions whose bar gap has reached the configured threshold so
    the simulator can force-sell them at the last available close — closing the
    gap where a delisted/halted position is otherwise carried open indefinitely
    and counted in terminal NAV (issue #1484). A future M&A track will add
    explicit force-close on cash mergers and symbol-swap on stock mergers — see
    [dev/notes/next-session-priorities-2026-05-07.md] §"Long-term M&A track". *)

open Core

(** {1 Configuration} *)

type config = {
  enabled : bool;
      (** Detection enabled. Default [true]; set [false] to suppress the
          per-step check entirely (useful in unit tests that want strict
          reproducibility without the get_previous_bar query overhead). *)
  stale_after_days : int;
      (** Calendar days since [last_bar_date] beyond which a held position is
          flagged as stale. Default [5] — covers typical weekend + long-weekend
          gaps without false-positives, fires within a week of a corporate
          action. *)
  stale_exit_after_days : int option;
      (** When [Some n], a held position whose bar gap has reached [n] calendar
          days is force-exited at its last available close (see
          {!force_exit_candidates}) — so a delisted/halted position is realised
          out instead of carried open at a stale mark indefinitely (issue
          #1484). When [None] (the default) no force-exit happens: the detector
          still records events but the position is only forward-filled, which is
          the pre-#1484 behaviour. Default [None] keeps every existing run
          byte-identical. *)
}
[@@deriving show, eq, sexp]

val default_config : config
(** [{ enabled = true; stale_after_days = 5; stale_exit_after_days = None }] —
    detector on, force-exit off (pre-#1484 behaviour). *)

(** {1 Event} *)

type event = {
  symbol : string;
  date : Date.t;  (** Step date when the staleness was detected. *)
  last_bar_date : Date.t;
      (** Date of the most recent bar the adapter returned for [symbol].
          [Date.diff date last_bar_date] equals [days_since_last_bar]. *)
  last_close : float;
      (** Close price on [last_bar_date] — the last meaningful market price for
          valuation purposes. *)
  days_since_last_bar : int;
      (** Calendar gap [Date.diff date last_bar_date], guaranteed
          [>= stale_after_days]. *)
  quantity : float;
      (** Position size at detection time (always positive; side carried by the
          broker portfolio). *)
  cost_basis : float;
      (** [avg_entry_price * quantity]. Reported alongside [last_close] so
          consumers can compute unrealized P&L without re-deriving from lots. *)
}
[@@deriving show, eq, sexp]
(** One emit per (held position, step) pair where the position is stale. Note
    this means the same position emits one event per subsequent step while it
    remains stale — consumers typically
    [List.dedup_and_sort ~compare:(fun a b -> String.compare a.symbol b.symbol)]
    to extract the distinct symbol list, or [List.last] to find the most recent
    state. *)

(** {1 Detector} *)

val detect_stale :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  date:Date.t ->
  portfolio:Trading_portfolio.Portfolio.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  config:config ->
  event list
(** Walk [portfolio.positions]. For each held symbol with no entry in
    [today_bars], query [adapter.get_previous_bar] for the most recent prior
    bar; if none exists or the gap
    [date - last_bar_date >= config.stale_after_days], emit one event. Returns
    [[]] when [config.enabled = false], when no positions are held, or when no
    held position is stale. Pure with respect to the adapter's cache. *)

(** {1 Force-exit} *)

type force_exit = {
  symbol : string;  (** Symbol of the held position to force-exit. *)
  signed_quantity : float;
      (** Held quantity, {b signed} — positive for a long position, negative for
          a short. The simulator sells [signed_quantity] (Sell for a long, Buy
          for a short) at [last_close] to flatten the position. *)
  last_close : float;
      (** Close on the most recent bar — the price the synthetic exit fills at.
      *)
  last_bar_date : Date.t;  (** Date of [last_close]'s bar. *)
  days_since_last_bar : int;
      (** Calendar gap [Date.diff date last_bar_date];
          [>= stale_exit_after_days]. *)
}
[@@deriving show, eq, sexp]
(** One force-exit instruction per held position whose bar gap has reached
    [config.stale_exit_after_days]. The simulator turns each into a realised
    market trade at [last_close]. *)

val force_exit_candidates :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  date:Date.t ->
  portfolio:Trading_portfolio.Portfolio.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  config:config ->
  force_exit list
(** Select held positions to force-exit at [date]. For each held symbol with no
    bar in [today_bars], query [adapter.get_previous_bar]; emit a {!force_exit}
    when a prior bar exists and the gap [date - last_bar_date] is at least
    [config.stale_exit_after_days].

    Returns [[]] when [config.stale_exit_after_days = None] (force-exit
    disabled), when [config.enabled = false], when no positions are held, or
    when no held position has reached the exit threshold. Pure with respect to
    the adapter's cache; the simulator owns the trade construction + portfolio /
    position mutation. *)

(** {1 Log} *)

module Log : sig
  type t
  (** Mutable per-run collector. Not thread-safe. *)

  val create : unit -> t
  val record : t -> event -> unit

  val events : t -> event list
  (** All events in chronological order, broken ties by symbol. *)

  val count : t -> int

  val distinct_symbols : t -> string list
  (** Distinct symbols across all events, sorted ascending. Useful for summary
      surfacing where the per-step granularity would be overwhelming. *)
end

(** {1 Sexp persistence} *)

type artefact = { events : event list } [@@deriving sexp]
(** On-disk envelope for [stale_holds.sexp]. Wraps a record (rather than a bare
    list) for forward-compatibility with future fields (e.g. config snapshot).
*)

val save_sexp : path:string -> Log.t -> unit
(** Save [Log.events log] to [path] as [stale_holds.sexp]. No-op when the log is
    empty — empty-log scenarios produce no file. *)

val load_sexp : string -> event list
(** Inverse of {!save_sexp}. Raises if the file does not exist or fails to
    parse. *)
