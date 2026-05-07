(** Laggard-rotation runner — wires {!Laggard_rotation} into the Weinstein
    strategy.

    Capital-recycling exit per Weinstein Ch. 4 §portfolio sizing (~lines
    4929–4933), surfaced as [docs/design/weinstein-book-reference.md] §5.6 (PR
    #891). Issue #887, framing note
    [dev/notes/capital-recycling-framing-2026-05-06.md].

    {1 Cadence}

    Fires only on Friday (weekly cadence). The detector computes
    relative-strength-vs-benchmark over a rolling 13-week window using the
    {!Bar_reader} primitives — meaningful only at the week-bucket boundary. On
    non-Friday calls the runner is a no-op.

    {1 Side & ordering}

    Long positions only. Short positions never trigger this exit; their
    relative-strength semantics are inverted (a short profits when the
    underlying lags the market — exactly the laggard signal here would mean the
    short is winning), so the runner skips shorts. The book authority (§5.6)
    only mentions long-side rotation.

    Invoked AFTER {!Stops_runner.update}, AFTER
    {!Force_liquidation_runner.update}, AND AFTER
    {!Stage3_force_exit_runner.update}, and BEFORE the entry walk on the same
    tick (so freed cash is visible to the entry walk).

    Single-exit invariant — at most one [TriggerExit] per position per tick — is
    enforced two ways depending on which earlier channel fired:

    - {b Stops + Stage-3}: the laggard runner sees their position_ids in
      [skip_position_ids] and emits no laggard transition for them. The stop /
      Stage-3 label is the surviving exit reason.
    - {b Force-liquidation}: NOT included in [skip_position_ids]. Instead, the
      caller post-strips colliding force-liq transitions after the laggard
      runner returns — see [weinstein_strategy.ml] around line 691. When both
      channels fire for the same position on the same tick, the surviving label
      is [laggard_rotation], not [force_liquidation_*]. The single-exit
      invariant still holds; only the reason attribution differs from a strict
      "earlier-wins" reading. This was a deliberate choice when laggard rotation
      landed (PR #909) — the laggard signal is strategy-driven, the force-liq is
      defense-in-depth, so attributing the exit to the strategy signal carries
      more diagnostic value.

    {1 RS computation}

    For each held long position on each Friday close: 1. Read the most recent
    [config.rs_window_weeks + 1] weekly bars (default 14) for the position
    symbol via {!Bar_reader.weekly_bars_for}. 2. Read the same for the benchmark
    symbol (typically [config.indices.primary]). 3. Compute
    [position_13w_return = close[latest] / close[oldest] - 1.0] and likewise for
    the benchmark. 4. Pass both into {!Laggard_rotation.observe_position}, which
    advances the consecutive- negative-RS streak counter and decides whether to
    fire.

    A position whose history is shorter than [rs_window_weeks + 1] weekly bars
    is skipped (no observation, no streak advancement) — the streak table only
    records meaningful comparisons. Likewise when the benchmark's weekly history
    is too short. *)

open Core
open Trading_strategy

val update :
  config:Laggard_rotation.config ->
  benchmark_symbol:string ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  bar_reader:Bar_reader.t ->
  get_price:Strategy_interface.get_price_fn ->
  laggard_streaks:int Hashtbl.M(String).t ->
  skip_position_ids:String.Set.t ->
  current_date:Core.Date.t ->
  Position.transition list
(** [update] iterates over every held long {!Position.t} and runs the
    laggard-rotation detector, returning a list of [TriggerExit] transitions for
    positions whose detector decision is [Laggard_exit].

    {2 Behaviour}

    - Returns [[]] when [is_screening_day = false]. The detector runs at weekly
      cadence only.
    - Returns [[]] when [positions] is empty.
    - Returns [[]] when the benchmark's weekly history is shorter than
      [config.rs_window_weeks + 1] bars — without a comparable RS signal, no
      position can be classified as a laggard. Streak counts are NOT reset in
      that case (the missing benchmark is a data gap, not a stage-recovery
      signal).
    - For each held long position with a {!Position.Holding} state: 1. Reads
      [config.rs_window_weeks + 1] weekly bars via [bar_reader]. If the
      position's history is shorter than that, the position is skipped (no
      observation, no streak advance — the symbol's history hasn't covered the
      window yet, parallel to {!Stops_runner}'s warmup-skip). 2. Computes the
      13-week returns for the position and the benchmark. 3. Calls
      {!Laggard_rotation.observe_position} — the detector mutates
      [laggard_streaks] in place to maintain the consecutive-negative-RS count.
      4. On [Laggard_exit { rs_13w_neg_weeks }]:
    - Skips the position if its [position_id] is in [skip_position_ids] — a stop
      or Stage-3 force-exit already exited it this tick. Force-liquidation is
      intentionally NOT in this set; collisions there are resolved by the
      caller's post-strip path documented in the module-level "Side & ordering"
      section.
    - Otherwise emits a [TriggerExit] transition with
      [exit_reason = StrategySignal { label = "laggard_rotation"; detail = Some
       "rs_13w_neg_weeks=N" }] and [exit_price = bar.close_price] from
      [get_price]. When [get_price] returns [None] the position is silently
      skipped (no transition emitted).
    - {b Exit semantics}: the emitted [TriggerExit] closes the {e entire}
      position, not a partial slice. The book authority §5.6 ("lighten up") is
      ambiguous between full and partial exits; the framing note (#896) flagged
      partial-exit as an open question. PR #909 took the simpler full-exit
      interpretation as the chosen semantics. Partial-exit ("lighten up by N%")
      is future scope — would require a [TriggerPartialExit] transition kind
      that the position state machine does not currently support.
    - Short positions and non-Holding states are skipped without emitting, and
      their entry in [laggard_streaks] is left untouched.

    {2 Mutates}

    - [laggard_streaks] — the per-symbol consecutive-negative-RS count is
      updated in place via {!Laggard_rotation.observe_position}. Each call
      advances the count by one on a negative-RS read or resets it to zero on
      any non-negative read. *)
