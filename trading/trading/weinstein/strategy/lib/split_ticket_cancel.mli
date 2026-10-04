(** #3075 — cancel a resting entry ticket whose symbol splits while it rests.

    {b The gap.} The simulator rescales {e held} positions on a split
    ([Split_handler.detect_for_held_positions]) and {!Stops_split_runner}
    rescales the stop state of every position in the strategy's map, resting
    tickets included. Nothing rescales the resting {b entry trigger}. So a
    ticket written on the pre-split chart fills on post-split prices at a level
    the screener never chose. Specimens from the 26y investor run: AAON-wein-951
    (3:2 split in 2023, trigger 83.42 left unscaled, filled 2024-02-15 at about
    125 on the decision's basis) and MU-wein-76 (2:1, trigger 88.44 unscaled).
    Diagnosis: [dev/notes/trades-csv-stop-columns-3075-2026-10-03.md] on PR
    #3100.

    {b What this module does.} On every tick, for each resting (wholly unfilled)
    [Entering] position, it asks the split detector whether the symbol split
    between the prior bar and today's. If so it emits a [CancelEntry] with
    reason {!cancel_reason} and releases the symbol's {!Entry_freeze} pin, so
    the next weekly screen re-decides on the adjusted chart at a fresh [E]. The
    simulator's existing [Cancel_handler.cancel_resting_entry_orders] retires
    the order, so the stale trigger can never fill.

    {b Why cancel and not rescale.} The base, the breakout level and the stop
    were all read on a chart that no longer exists. Book §5 and spine item 5
    ([.claude/rules/weinstein-faithful-core.md]): risk is defined at entry by
    the base and the MA of the chart the decision was taken on. Re-deciding on
    the adjusted chart is the faithful answer; rescaling the trigger would keep
    a decision whose inputs moved.

    {b Limits.} The strategy runs after the day's fills. A long buy-stop sits
    above a post-split price, so it does not fill on the split bar and is
    cancelled the same evening. A short sell-stop sits below the market and a
    forward split drops the price through it, so it can fill on the split bar
    itself, before this module sees it; such a ticket is partially or wholly
    filled and is skipped. Stashed tickets ({!Entry_ticket_suspend}) are not
    positions and are not checked.

    {b Default-off} (config [cancel_resting_entry_on_split], R1): {!run} with
    [enabled = false] returns no transitions and the portfolio unchanged
    (physically the same value), without reading a bar. *)

open Core
module Position = Trading_strategy.Position
module Portfolio_view = Trading_strategy.Portfolio_view

val cancel_reason : string
(** ["entry_ticket_split_while_resting"] — the reason token on every
    [CancelEntry] this module builds, persisted verbatim into
    [Ticket_lifecycle.cancel_reason] by the trade audit. *)

val cancellations :
  positions:Position.t String.Map.t ->
  split_factor:(symbol:string -> float option) ->
  current_date:Date.t ->
  Position.transition list
(** [cancellations ~positions ~split_factor ~current_date] returns one
    [CancelEntry] (reason {!cancel_reason}, dated [current_date]) per position
    that is [Entering] with [filled_quantity = 0.0] and whose symbol has
    [split_factor ~symbol = Some _], in [positions] key order. Partially filled
    entries are skipped (a [CancelEntry] would strand their booked shares), as
    are [Holding] / [Exiting] / [Closed] positions. [split_factor] is consulted
    only for qualifying positions. *)

val run :
  enabled:bool ->
  pending_entry_e:Entry_freeze.t ->
  bar_reader:Bar_reader.t ->
  portfolio:Portfolio_view.t ->
  current_date:Date.t ->
  Position.transition list * Portfolio_view.t
(** [run ~enabled ~pending_entry_e ~bar_reader ~portfolio ~current_date] is
    {!cancellations} with [split_factor] read from [bar_reader] via
    {!Stops_split_runner.detect_split}. It also releases each cancelled symbol's
    {!Entry_freeze} pin and returns the portfolio without the cancelled
    positions, so the rest of the tick sees them as gone: no second cancel from
    {!Entry_ticket_ttl}, no stash by {!Entry_ticket_suspend}.

    [enabled = false] returns [([], portfolio)] with no bar reads (R1). *)
