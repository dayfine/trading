(** Forward-trace renderer — pure function that rolls a {!Weekly_snapshot.t}'s
    long candidates forward over a fixed horizon of daily bars and reports the
    per-pick outcome.

    Lets us answer "would these picks have worked?" without re-running the full
    simulator. Adjusted-close prices are used throughout, so split-day round-
    trips do not produce phantom returns.

    {1 Model}

    For each long candidate we model a buy-stop entry: scan forward in time
    until a bar's high reaches the suggested entry price, mark the entry at that
    bar's date and price (clipped to the high if the open gapped past), then
    continue rolling forward up to [horizon_days] from the pick date. Over that
    window we track:

    - [max_favorable]: highest high observed after entry
    - [max_adverse]: lowest low observed after entry
    - [final_price]: adjusted close on the last bar within the horizon
    - [stop_triggered]: true iff any post-entry bar's low pierced the suggested
      stop
    - [pct_return_horizon]: ([final_price] - [entry_filled_at]) /
      [entry_filled_at]
    - [winner]: [pct_return_horizon] > 0

    The horizon is measured in {b calendar} days from the pick date — bars that
    fall on weekends/holidays simply aren't there. If the horizon ends before
    enough trading days exist, we use the last available bar.

    Picks whose entry is never filled within the horizon are reported with
    [entry_filled_at = nan] and [winner = false] (a sentinel — they don't count
    toward winner / loser averages).

    Short candidates are not currently traced (entry/stop semantics differ).
    [trace_picks] currently consumes only [picks.long_candidates].

    {1 Split safety}

    All prices read from bars use [adjusted_close] for closes and apply a
    bar-relative scaling for highs / lows derived from
    [(high_price / close_price) * adjusted_close] etc. This keeps split-day
    round-trips numerically clean: a 4:1 split between pick date and horizon end
    produces no phantom 4× return because both entry and exit are in adjusted
    terms.

    {1 Determinism}

    Pure function. Same inputs → same outputs. No I/O, no clock, no global
    state. Suitable for fixture-pinned tests. *)

open Core
open Types

type per_pick_outcome = {
  symbol : string;  (** Ticker. *)
  pick_date : Date.t;  (** Snapshot date the candidate was emitted on. *)
  suggested_entry : float;
      (** Suggested buy-stop entry from the snapshot, in adjusted terms. *)
  suggested_stop : float;
      (** Suggested initial stop from the snapshot, in adjusted terms. *)
  entry_filled_at : float;
      (** Adjusted price the entry was filled at, or [Float.nan] if never filled
          within the horizon. *)
  entry_filled_date : Date.t;
      (** Date the entry was filled. Equal to [pick_date] if never filled
          (sentinel — disambiguated by [Float.is_nan entry_filled_at]). *)
  max_favorable : float;
      (** Maximum adjusted high observed in the post-entry window. *)
  max_adverse : float;
      (** Minimum adjusted low observed in the post-entry window. *)
  final_price : float;
      (** Adjusted close on the final bar in the horizon (or last available bar
          before the horizon ends). *)
  final_date : Date.t;  (** Date of the [final_price] bar. *)
  pct_return_horizon : float;
      (** [(final_price - entry_filled_at) / entry_filled_at]. [Float.nan] if
          the entry was never filled. *)
  stop_triggered : bool;
      (** True iff any post-entry bar's adjusted low ≤ [suggested_stop]. *)
  max_drawdown_within_horizon : float;
      (** Maximum drawdown from the highest post-entry close, expressed as a
          negative fraction (e.g. [-0.0221] for -2.21%). [0.0] if no drawdown
          occurred. *)
  winner : bool;
      (** [pct_return_horizon > 0]. Always false if entry never filled. *)
}
[@@deriving sexp, eq, show]
(** Per-candidate outcome over the horizon. *)

type aggregate = {
  horizon_days : int;  (** Horizon used for the trace, in calendar days. *)
  total_picks : int;  (** Number of long candidates traced. *)
  winners : int;  (** Picks with [pct_return_horizon > 0]. *)
  losers : int;
      (** Filled picks with [pct_return_horizon ≤ 0]. Excludes never-filled
          picks. *)
  stopped_out : int;
      (** Picks whose post-entry low pierced [suggested_stop]. *)
  avg_return_pct : float;
      (** Mean [pct_return_horizon] across all filled picks. [Float.nan] if no
          picks were filled. *)
  avg_winner_return_pct : float;
      (** Mean [pct_return_horizon] among winners only. [Float.nan] if no
          winners. *)
  avg_loser_return_pct : float;
      (** Mean [pct_return_horizon] among losers only. [Float.nan] if no losers.
      *)
  best_pick : string;
      (** Symbol of the highest-return filled pick. Empty string if no picks
          were filled. *)
  worst_pick : string;
      (** Symbol of the lowest-return filled pick. Empty string if no picks were
          filled. *)
}
[@@deriving sexp, eq, show]
(** Cross-pick summary for the whole snapshot. *)

val trace_picks :
  picks:Weekly_snapshot.t ->
  bars:Daily_price.t list String.Map.t ->
  horizon_days:int ->
  per_pick_outcome list * aggregate
(** [trace_picks ~picks ~bars ~horizon_days] traces each long candidate in
    [picks] forward over [horizon_days] calendar days using the bar series for
    that symbol from [bars].

    Bars for each symbol are expected ascending by date. They are sorted
    defensively. Bars outside the half-open window
    [pick_date < bar_date <= pick_date + horizon_days] are ignored.

    A symbol that has no entry in [bars], or whose bars are entirely outside the
    window, produces an unfilled outcome (see [per_pick_outcome]).

    [horizon_days] must be ≥ 1; if less than 1 the function still returns a
    well-formed result — every pick is unfilled and the aggregate counts are
    zero. This permits using the function as a no-op probe. *)
