(** Liquidity-degradation exit runner — the held-position arm of the
    liquidity-realism overlay.

    Each screening cycle, for every held {!Position.t}, computes the trailing
    dollar-ADV ({!Liquidity_metric.dollar_adv}) from bars available at [as_of]
    (no lookahead) and emits a [TriggerExit] when it has degraded below
    [config.min_hold_dollar_adv]. This catches, in real time, a name we already
    hold whose liquidity collapses (large-cap → thinly-traded micro-cap /
    delisting / exchange move) — letting the strategy exit BEFORE the name
    becomes untradeable and a spurious tick can trip a worst-case stop fill.

    {1 Faithfulness}

    This is a risk/realism overlay, not a spine change
    ([.claude/rules/weinstein-faithful-core.md] W1 intact — stage framework,
    buy-in-Stage-2, volume-confirmed entry all unchanged). Weinstein would never
    hold a name he could not trade out of.

    {1 Default-off}

    No-op when [config.min_hold_dollar_adv <= 0.0] (the default): returns [[]]
    so every existing golden/baseline replays bit-identically.

    {1 Cadence, side & ordering}

    Fires only on a screening day ([is_screening_day], i.e. Friday weekly
    cadence). Applies to BOTH long and short held positions — illiquidity is a
    tradeability problem on either side. Invoked alongside the other special
    exits ({!Stage3_force_exit_runner}, {!Laggard_rotation_runner}); a position
    already exiting via a stop / force-liq / other special exit this tick is
    skipped via [skip_position_ids]. *)

open Core
open Trading_strategy

val update :
  config:Liquidity_config.t ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  bar_reader:Bar_reader.t ->
  get_price:Strategy_interface.get_price_fn ->
  skip_position_ids:String.Set.t ->
  current_date:Core.Date.t ->
  Position.transition list
(** [update] iterates over every held {!Position.t} and emits a [TriggerExit]
    for each whose trailing dollar-ADV has degraded below
    [config.min_hold_dollar_adv].

    {2 Behaviour}

    - Returns [[]] when [config.min_hold_dollar_adv <= 0.0] (the no-op default).
    - Returns [[]] when [is_screening_day = false] (weekly cadence only).
    - Returns [[]] when [positions] is empty.
    - For each held position (long OR short) in a {!Position.Holding} state:
      1. Reads its trailing daily bars via
         {!Bar_reader.daily_bars_for} up to [current_date] and computes
         {!Liquidity_metric.dollar_adv} over [config.adv_lookback_days].
      2. When the dollar-ADV is [Some adv] with [adv < min_hold_dollar_adv],
         emits a [TriggerExit] with
         [exit_reason = StrategySignal { label = "liquidity_exit";
          detail = Some "dollar_adv=<x>" }] and [exit_price = bar.close_price]
         from [get_price]. The forensic [dollar_adv] detail surfaces in the
         [exit_trigger] column of [trades.csv].
      3. Skips the position (no emit) when: its [position_id] is in
         [skip_position_ids]; [get_price] returns [None]; or the dollar-ADV is
         [None] (no liquidity reading — a missing reading must never force a
         spurious exit) or [>= min_hold_dollar_adv].
    - Non-[Holding] states are skipped without emitting.

    Pure aside from the bar reads; holds no per-symbol state (the threshold
    decision is recomputed from scratch each cycle). *)
