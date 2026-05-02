(** Phase C of the optimal-strategy counterfactual: greedy sizing-constrained
    fill.

    Walks Fridays in chronological order. For each Friday:
    - {b Exits first.} Any open round-trip whose [scored_candidate.exit_week]
      equals this Friday closes — its proceeds accrue to cash before new entries
      are sized.
    - {b Then entries.} Candidates with [entry.entry_week = this Friday] are
      ranked by the variant-specific key (R-multiple descending for
      [Constrained] / [Relaxed_macro]; pre-trade [cascade_score] descending with
      [symbol] tie-break for [Score_picked]). Each is admitted only if it passes
      the skip-already-held / concurrent-position-cap / sector-cap / cash
      checks. Sizing is dollar-based:
      [shares = risk_per_trade_dollars / initial_risk_per_share]. Cash is
      deducted at entry and accrued at exit.

    {1 Heuristic A — earliest-Friday + R-descending}

    Per plan §Phase C, this is the "earliest-Friday, R-multiple descending, with
    hindsight on R-multiple but live capital tracking" heuristic. Single forward
    pass; calendar-honest; cheap. The other two heuristics enumerated in the
    plan (B = globally-optimal knapsack, C = Monte-Carlo sample) are PR-5
    follow-ups.

    {1 End-of-run handling}

    Round-trips whose exit_week falls inside [run_end_date] (inclusive) are
    closed at the scorer-provided exit price / week. Round-trips whose exit_week
    extends beyond [run_end_date] are closed at the boundary in the
    {!fill_input.run_end_date} sense — but the scorer already encodes
    [End_of_run] for any candidate that didn't trigger an exit during the panel
    walk, so the filler simply trusts the scorer's exit fields.

    {1 Variant tagging}

    Every emitted round-trip carries the candidate's [passes_macro] flag
    forward. The caller picks one variant per fill — the renderer emits three
    summaries by invoking the filler three times:
    - [Constrained]: macro gate kept, sort by realised [r_multiple] DESC (full
      outcome foresight; ceiling).
    - [Score_picked]: macro gate kept, sort by pre-trade [cascade_score] DESC
      (no outcome foresight; the same signal the live strategy uses).
    - [Relaxed_macro]: macro gate dropped, sort by realised [r_multiple] DESC.

    {1 Purity}

    Pure function. Determines the same output for the same input — enables
    reproducible counterfactuals across tunings.

    See [dev/plans/optimal-strategy-counterfactual-2026-04-28.md] §Phase C. *)

type config = {
  starting_cash : float;
      (** Initial portfolio cash. The scenario's [starting_cash] is the
          canonical value; PR-4 binary forwards it from the run's [Portfolio.t].
          Must be strictly positive. *)
  risk_per_trade_pct : float;
      (** Fraction of starting capital risked per trade (e.g. [0.01] = 1%).
          Mirrors [Portfolio_risk.config.risk_per_trade_pct]. The dollar risk
          per trade is fixed at [starting_cash *. risk_per_trade_pct] for the
          duration of the fill — the counterfactual does not mark-to-market
          across positions. This deliberately matches the live strategy's
          fixed-dollar-risk discipline at entry time. *)
  max_positions : int;
      (** Concurrent open-position cap. Mirrors
          [Portfolio_risk.config.max_positions]. *)
  max_sector_concentration : int;
      (** Maximum concurrent open positions per named sector. Mirrors
          [Portfolio_risk.config.max_sector_concentration]. The
          empty-string-sector / "Unknown" bucket is treated like any named
          sector — the counterfactual does not split it out (the live strategy's
          [max_unknown_sector_positions] is a separate cap that this phase
          ignores; the counterfactual is one cap simpler). *)
}
[@@deriving sexp]
(** Sizing envelope for the greedy fill.

    Constructed via {!default_config} for tests; PR-4's binary builds it from
    the actual run's [Weinstein_strategy.config.portfolio_risk_config] so the
    counterfactual lives under the same envelope as the actual run. *)

val default_config : config
(** Defaults match the production live config: [starting_cash = 100_000.0],
    [risk_per_trade_pct = 0.01], [max_positions = 20],
    [max_sector_concentration = 5]. *)

type fill_input = {
  candidates : Optimal_types.scored_candidate list;
      (** All scored candidates produced by Phase B, in any order — the filler
          sorts internally. Empty list yields an empty round-trip list. *)
  variant : Optimal_types.variant_label;
      (** Which variant to fill. [Constrained] / [Score_picked] admit only
          candidates whose [entry.passes_macro] is [true]; [Relaxed_macro]
          admits all. The variant also determines the per-Friday entry sort key
          — see {!fill}. *)
}
(** Inputs to a single fill pass. The [variant] choice determines both which
    subset of candidates is admissible and the per-Friday entry sort key;
    everything else (sizing, caps) is identical across variants. *)

val fill : config:config -> fill_input -> Optimal_types.optimal_round_trip list
(** [fill ~config input] runs the greedy Friday-by-Friday fill described above
    and returns the closed round-trips in entry-week order, ties broken by
    descending R-multiple (the same order they were admitted).

    Algorithm:
    {ol
     {- Filter [input.candidates] by variant. For [Constrained] /
        [Score_picked], drop any candidate where [entry.passes_macro = false].
     }
     {- Group remaining candidates by [entry.entry_week] (Friday). }
     {- Walk Fridays in ascending date order. For each Friday:
        {ul
         {- {b Exit phase.} Close any open round-trip whose [exit_week] equals
            this Friday. Accrue [exit_price * shares] to cash. Open positions
            are tracked by symbol; sector counts and position counts decrement.
         }
         {- {b Entry phase.} Sort the day's admissible candidates by the
            variant's key — [r_multiple] DESC for [Constrained] /
            [Relaxed_macro], [cascade_score] DESC ([symbol] ASC tie-break) for
            [Score_picked]. For each candidate in order:
            + {b Skip if symbol already held.} The counterfactual mirrors the
              live strategy's "one position per symbol" rule.
            + {b Skip if at concurrent-position cap.}
              [open_count >= max_positions].
            + {b Skip if at sector cap.}
              [sector_count(c.sector) >= max_sector_concentration].
            + {b Compute size.}
              [shares = floor(risk_per_trade_dollars / initial_risk_per_share)].
              If [shares <= 0], skip.
            + {b Skip if insufficient cash.}
              [shares * entry_price > current_cash]. The cash check uses the
              {b current} cash balance — mark-to-market is never done; only
              entry / exit cashflows move it.
            + {b Admit.} Deduct [shares * entry_price] from cash, increment open
              counts, add an in-flight round-trip waiting on its [exit_week].
         }
        }
     }
     {- After the last Friday, close out any remaining open round-trips at their
        scorer-provided [exit_price] / [exit_week] (the scorer encodes
        [End_of_run] when needed, so the filler trusts those fields).
     }
    }

    Returns the closed round-trips in entry-week order, with ties broken by
    descending R-multiple of the input scored candidate.

    Pure function — for the same [config + input] always returns the same list.
    Returns [[]] when [input.candidates] is empty.

    Sanity rule (per plan §Acceptance criteria): any round-trip in the output
    has [shares > 0.0], [initial_risk_dollars > 0.0], and a sign-correct
    [pnl_dollars] given [side]. *)
