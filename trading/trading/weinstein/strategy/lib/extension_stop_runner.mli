(** Extension-stop exit runner — the strategy-side arm of the extension stop
    ({!Weinstein_stops.Extension_stop}).

    Each screening cycle, for every held LONG {!Position.t}, replays the weekly
    bars of its holding window (entry → [current_date]) on the 30-week WMA basis
    ([ma_period]) and emits a [TriggerExit] when the wide extension trail has
    fired — i.e. once the weekly close reached [config.trigger_ratio ×] the
    WMA30 and has since fallen [config.trail_pct] below the post-trigger running
    peak weekly close. The exit fires at the current bar's close (weekly-close
    semantics, L3).

    {1 Tail-insurance, not alpha}

    A catastrophic-stop-class dial (#1695 precedent). Extension events are rare
    (~0.6-1% of episodes), so this is a left-tail insurance mechanism, not a
    fold-metric lever — see {!Weinstein_stops.Extension_stop} for the acceptance
    basis and the width evidence.

    {1 Tighten-only (L2)}

    The runner only ever ADDS an exit trigger; it never lowers or replaces the
    structural trailing stop. A position already exiting this tick via any other
    channel (stop / force-liq / Stage-3 / laggard / liquidity) is skipped via
    [skip_position_ids], so an earlier structural exit always wins.

    {1 Default-off}

    No-op when [not (Extension_stop.is_enabled config)] (the default
    [trigger_ratio = 0.0] / [trail_pct = 0.0]): returns [[]] so every existing
    golden/baseline replays bit-identically
    ([.claude/rules/experiment-flag-discipline.md] R1).

    {1 Cadence & side}

    Fires only on a screening day ([is_screening_day], i.e. Friday weekly
    cadence). LONG positions only — the extension blow-off is a long-side
    phenomenon. *)

open Core
open Trading_strategy

val update :
  config:Weinstein_stops.Extension_stop.config ->
  ma_period:int ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  bar_reader:Bar_reader.t ->
  get_price:Strategy_interface.get_price_fn ->
  skip_position_ids:String.Set.t ->
  current_date:Core.Date.t ->
  Position.transition list
(** [update] iterates over every held LONG {!Position.t} and emits a
    [TriggerExit] for each whose extension trail has fired.

    {2 Behaviour}

    - Returns [[]] when [not (Extension_stop.is_enabled config)] (the no-op
      default), when [is_screening_day = false] (weekly cadence only), or when
      [positions] is empty.
    - For each held LONG position (in a {!Position.Holding} state): 1. Reads its
      weekly bars entry → [current_date] via {!Bar_reader.weekly_bars_for}
      (enough weeks to also fill the trailing WMA window), computes the 30-week
      WMA ([ma_period]) with {!Sma.calculate_weighted_ma} — the same basis as
      the merged extension screen — and slices to the holding window. 2. When
      {!Weinstein_stops.Extension_stop.fired} is [true] on that series, emits a
      [TriggerExit] with
      [exit_reason = StrategySignal { label = "extension_stop"; detail = Some
       "trigger=<r>,trail=<t>" }] and [exit_price = bar.close_price] from
      [get_price]. 3. Skips the position (no emit) when its [position_id] is in
      [skip_position_ids] or [get_price] returns [None].
    - SHORT positions and non-[Holding] states are skipped without emitting.

    Pure aside from the bar reads; holds no per-symbol state (the trail decision
    is recomputed from the holding window each cycle, which is self-healing —
    each Friday's replay ends at that Friday, so a fire is detected on its own
    week). *)
