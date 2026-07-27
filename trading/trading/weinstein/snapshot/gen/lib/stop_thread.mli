(** Thread a held position's trailing stop from week to week (weekly-snapshot
    item 4c.b).

    {1 What this is, and is not}

    This module does {b not} implement a stop state machine. {!Weinstein_stops}
    already is one — [Initial → Trailing → Tightened], with the never-lower rule
    and the correction-cycle bookkeeping of weinstein-book-reference.md §5.2 —
    and it is the machine the live/backtest strategy runs. Writing a second one
    for the weekly report would fork the domain logic, which is exactly the
    divergence {!Stop_recompute} was created to close on the candidate side.

    What this module adds is {b continuity}: {!seed} derives the machine's
    starting state from real bar history, {!advance} folds
    {!Weinstein_stops.update} over the weeks that have elapsed since the state
    was last carried forward, and {!Stop_track} is the shape that state is
    carried in. The report can then say what the stop {e is}, and how many times
    it has ratcheted, rather than what a fresh recomputation {e would be}.

    {1 What is wired, and what is not}

    {!advance} is live: {!Held_position_row.enrich} calls it for every holding
    that carries a {!Stop_track.t}.

    {!seed} is {b not} wired — no production code calls it, only its tests.
    Nothing writes a track back to [portfolio.sexp] either, so a holding that
    has no track never acquires one on its own; it renders from
    {!Stop_recompute.for_held_long} as it did before 4c.b. Seeding un-threaded
    holdings and persisting the advanced track are both weekly-snapshot item
    4c.c. {!seed} lands here, tested, because it is the piece 4c.c calls; read
    it as a component with no caller yet, not as a step the weekly run performs.

    {1 Purity}

    Bar {b lists} in, no [Bar_reader], no filesystem — the caller owns loading
    (same division as {!Rename_detector}). Same inputs always give the same
    outputs, so a weekly run is reproducible.

    {1 Weekly close, not an intra-week touch}

    {!advance} runs the machine with [trigger_on_weekly_close = true],
    overriding whatever the passed config carries. The bars it is fed are
    {e weekly} bars, and the config's own default ([false] — an intra-bar
    low/high trigger, kept so backtest goldens replay unchanged) would fire the
    stop on an intra-{e week} wick. Weinstein's rule is a weekly {b close} below
    the stop (book §Stop-Loss Rules), so a week that dips through the stop and
    closes back above it does not exit. This is a selection of the documented
    trigger semantics for this cadence, not a new threshold.

    Long-only, as the live held book is. *)

open Core

(** What {!advance} found when it replayed the elapsed weeks. Exhaustive, so a
    caller cannot forget the exit case. *)
type outcome =
  | Holding of Stop_track.t
      (** The stop was not hit. Carries the advanced track. *)
  | Triggered of {
      track : Stop_track.t;
          (** State as of the triggering week; the stop level is the one that
              was hit. *)
      week : Date.t;  (** Week-ending date of the triggering bar. *)
      close : float;  (** That week's close, which fell through the stop. *)
      stop_level : float;  (** The stop level it closed below. *)
    }
      (** A weekly close fell through the stop. Replay stops at this week —
          later weeks are not applied, because the position would have been
          sold. The caller decides what to do about it; this module never
          mutates a portfolio. *)
[@@deriving show, eq]

val seed :
  stops_config:Weinstein_stops.config ->
  initial_stop_buffer:float ->
  entry_price:float ->
  working_stop:float ->
  daily_bars:Types.Daily_price.t list ->
  as_of:Date.t ->
  Stop_track.t
(** [seed ~stops_config ~initial_stop_buffer ~entry_price ~working_stop
     ~daily_bars ~as_of] builds the starting track for a holding that has none —
    a position recorded before item 4c.b, or a fresh {!Portfolio_edit.record}
    (which is bar-free by design, so seeding belongs here where the bars are).

    {b No production caller yet} (see "What is wired, and what is not" above):
    item 4c.c is what invokes this and saves the result. Calling it today
    produces a track that nothing would persist.

    The [Initial] stop comes from
    {!Weinstein_stops.compute_initial_stop_with_floor}: the prior correction low
    in [daily_bars], falling back to [entry_price *. initial_stop_buffer] only
    when no qualifying correction exists in the lookback window. That is book
    §5.1 — the stop sits below the base, not at an arbitrary percentage.

    The result is then ratcheted to [working_stop] if the trader's working stop
    is higher, via {!Stop_track.ratchet}. Seeding must never {e lower} the stop
    actually resting at the broker: a position that has been held for months may
    have a working stop well above any floor derivable from its base.

    [updated] is set to [as_of] and [raises] to zero — the track starts its
    ratchet history here, not retroactively. *)

val advance :
  stops_config:Weinstein_stops.config ->
  stage_config:Stage.config ->
  weekly_bars:Types.Daily_price.t list ->
  prior:Stop_track.t ->
  outcome
(** [advance ~stops_config ~stage_config ~weekly_bars ~prior] replays
    {!Weinstein_stops.update} over the bars in [weekly_bars] whose date is
    {b strictly after} [prior.updated], threading the state through each week.

    - [weekly_bars] are weekly-aggregated bars, oldest first, ending at the run
      date (the same shape {!Weekly_snapshot_generator} already builds via
      [Bar_reader.weekly_bars_for]). Bars at or before [prior.updated] are
      context for the MA and stage classification, not replayed.
    - The [ma_value], [ma_direction] and [stage] each week come from
      {!Stage.classify} on the weekly prefix ending at that week, with the
      previous week's stage threaded in as [prior_stage] — the same three values
      the strategy hands {!Weinstein_stops.update}, derived the way the
      generator already derives a chained stage.
    - [raises] accumulates one per {!Weinstein_stops.Stop_raised} event.
    - Replay stops at the first week whose close falls through the stop,
      returning {!Triggered}.

    Idempotent: replaying with a track already advanced through the last bar
    applies zero weeks and returns [Holding prior] unchanged, so re-running a
    weekly report cannot double-count ratchets. *)
