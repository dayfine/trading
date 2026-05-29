(** Price-lookup helpers along a chronological weekly-bar series.

    Used by {!Trade_autopsy} to compute the "missed-gain" magnitude of each
    closed trade: how much price moved between the exit and the next re-entry,
    or between the exit and the end of the test window if no re-entry occurs.

    All functions are pure. Inputs are assumed to be sorted in chronological
    order (oldest first) — the same order returned by the per-symbol stage
    strategy module. Date ties are not expected. *)

open Core

type weekly_bar = Types.Daily_price.t

val close_at : bars:weekly_bar list -> date:Date.t -> float option
(** [close_at ~bars ~date] returns the close price of the bar whose [date] is
    exactly [date]. Returns [None] if no bar has that exact date — note this
    means the caller should supply weekly-aligned dates (entry/exit dates coming
    back from [Walk_step.trade], which were the bar dates the strategy saw). *)

val close_at_offset :
  bars:weekly_bar list -> anchor_date:Date.t -> weeks:int -> float option
(** [close_at_offset ~bars ~anchor_date ~weeks] returns the close price at
    [weeks] weekly bars forward of the bar whose date equals [anchor_date].
    [weeks = 0] returns the anchor bar's close. [weeks > 0] walks forward.

    Returns [None] if [anchor_date] is not in [bars] or if walking forward
    [weeks] bars runs off the end of the series. *)

val close_at_end : bars:weekly_bar list -> float option
(** [close_at_end ~bars] is the last bar's close. [None] for an empty list. *)

val next_entry_after :
  trades:'a list ->
  trade_entry_date:('a -> Date.t) ->
  after_date:Date.t ->
  'a option
(** [next_entry_after ~trades ~trade_entry_date ~after_date] finds the next
    trade whose [entry_date] is strictly after [after_date], scanning [trades]
    in chronological order (assumed to be sorted by entry date already). Returns
    [None] if no such trade exists. *)

val cyclical_low_close_before :
  bars:weekly_bar list ->
  entry_date:Date.t ->
  lookback_weeks:int ->
  (Date.t * float) option
(** [cyclical_low_close_before ~bars ~entry_date ~lookback_weeks] returns the
    [(date, close)] of the lowest-close weekly bar in the window
    [(entry_date - lookback_weeks, entry_date)] (exclusive of [entry_date]
    itself; the entry bar is not a candidate). The window is bounded above by
    [lookback_weeks] bars walking backward from the bar matching [entry_date].

    Returns [None] if [entry_date] is not in [bars] or the lookback window is
    empty. *)
