(** Phase B of the optimal-strategy counterfactual: realized-outcome scorer.

    Walks forward from a {!Optimal_types.candidate_entry}'s [entry_week]
    applying the counterfactual exit rule and emits a
    {!Optimal_types.scored_candidate} enriched with the realized exit week /
    price / R-multiple.

    {1 Counterfactual exit rule}

    Per the plan (§Phase B), the position closes at the earliest of:

    - {!Optimal_types.Stop_hit}: the trailing stop walker triggers on a weekly
      close ≤ stop level (long) — the same {!Weinstein_stops.update} logic the
      live strategy applies to every position.
    - {!Optimal_types.Stage3_transition}: the stage classifier reports a 2 → 3
      transition that has been sustained for [stage3_confirm_weeks] consecutive
      weeks (default 2 — tunable via {!config}). Mirrors Weinstein's "exit on
      Stage 3 with profits" rule from book §Sell Criteria.
    - {!Optimal_types.End_of_run}: the panel runs out before either of the above
      fires.

    {1 Initial stop seeding}

    The scorer seeds the stop state from
    {!Optimal_types.candidate_entry.suggested_stop} directly — the cleanest stop
    the screener already computed, matching the plan's design rationale ("the
    counterfactual uses the cleanest stop = [suggested_stop] from the screener",
    §What the counterfactual ignores).

    The trailing-stop walker {!Weinstein_stops.update} is then invoked once per
    weekly bar to evolve the stop forward.

    {1 Purity}

    Pure function. No I/O, no mutable state. The caller (PR-4 binary) is
    responsible for materialising the [weekly_outlook list] from the bar source
    — the scorer never touches the snapshot cache or any indicator cache.

    See [dev/plans/optimal-strategy-counterfactual-2026-04-28.md] §Phase B. *)

type weekly_outlook = {
  date : Core.Date.t;  (** Friday on which this snapshot was computed. *)
  bar : Types.Daily_price.t;
      (** The weekly-aggregated OHLC bar for the Friday — the same shape
          {!Weinstein_stops.update} consumes via its [current_bar] parameter.
          [low_price] / [close_price] drive the stop-hit and Stage-3 checks. *)
  stage_result : Stage.result;
      (** Result of {!Stage.classify} at this Friday — provides the stage,
          [ma_value], and [ma_direction] the trailing-stop walker needs. The
          caller pre-classifies because Stage classification depends on a
          history-lookback that's expensive to recompute per call from inside
          the scorer; PR-4's binary already materialises this from its panel
          walk. *)
}
(** One Friday's forward-looking inputs: bar + stage. The scorer consumes a
    chronological list starting on the Friday {b after} [candidate.entry_week].

    The [entry_week] Friday's bar is {b not} included — entry already happened
    at that week's close, and the stop walker advances on subsequent weeks.

    PR-4's binary materialises these from the same panel data the actual
    backtest uses, so the counterfactual sees the same MA / stage view the live
    strategy did. *)

type config = {
  stops_config : Weinstein_stops.config;
      (** Configuration for the trailing-stop walker. Same as the actual run's
          {!Weinstein_strategy.config.stops_config} so the counterfactual
          respects the strategy's stop discipline. *)
  stage3_confirm_weeks : int;
      (** Number of consecutive weeks of Stage-3 classification required to
          declare a Stage-3 transition. Default 2 (per plan §Risks item 1). The
          renderer (PR-4) runs sensitivity at 1, 2, 3, and 4 weeks to verify the
          report's verdict is robust to this hyperparameter. *)
}
(** Scorer configuration. Mirrors the relevant subset of the live strategy's
    config so the counterfactual is invoked with byte-identical settings to the
    backtest run it is comparing against, plus the one Phase-B-only
    hyperparameter ([stage3_confirm_weeks]).

    Constructed via {!default_config} for tests and ad-hoc usage; PR-4's binary
    builds it from the actual run's [Weinstein_strategy.config]. *)

val default_config : config
(** Defaults: [stops_config = Weinstein_stops.default_config],
    [stage3_confirm_weeks = 2]. *)

val score :
  config:config ->
  candidate:Optimal_types.candidate_entry ->
  forward:weekly_outlook list ->
  Optimal_types.scored_candidate option
(** [score ~config ~candidate ~forward] walks [forward] week by week and returns
    a {!Optimal_types.scored_candidate} describing the realised counterfactual
    outcome for [candidate].

    [forward] is the chronological sequence of weekly outlooks {b after}
    [candidate.entry_week] — one entry per Friday, oldest first. The scorer
    seeds the stop state from [candidate.suggested_stop] and then applies the
    trailing-stop walker / Stage-3 detector to each entry in order, stopping on
    the first exit trigger.

    Returns [None] when:
    - [forward] is empty (cannot determine any exit; the candidate spans only
      the entry week and the panel ends — degenerate case the caller drops),
    - [candidate.suggested_stop] is non-finite or [<= 0] (malformed candidate;
      the caller should never construct one but the scorer is defensive),
    - [candidate.entry_price] is non-positive (would yield a non-finite
      R-multiple).

    Returns [Some scored_candidate] otherwise. The scorer always picks {b one}
    exit trigger:
    - {!Optimal_types.Stop_hit} when the trailing-stop walker reports a
      [Stop_hit] event (long: weekly close ≤ stop level; the bar's [close_price]
      is the exit price, mirroring the live strategy's weekly close trigger);
    - {!Optimal_types.Stage3_transition} when [config.stage3_confirm_weeks]
      consecutive weeks of Stage-3 classification have elapsed (the exit week is
      the {b first} of those weeks — the earliest signal — and the exit price is
      that week's close);
    - {!Optimal_types.End_of_run} when [forward] is exhausted with neither
      trigger firing; the exit week / price are the last entry of [forward].

    Pure function. *)
