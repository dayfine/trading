(** Phase A of the optimal-strategy counterfactual: enumerate breakout
    candidates from a sequence of per-Friday screener inputs.

    Walks the panel forward week by week. For each Friday and each symbol in the
    universe, asks the existing {!Stock_analysis.is_breakout_candidate}
    predicate the same question the live cascade asks today: *is this a breakout
    candidate this week?*

    Emits one {!Optimal_types.candidate_entry} per (symbol, week) where the
    predicate fires. Tags each with [passes_macro] so the downstream pipeline
    can split rows by report variant (constrained vs relaxed-macro) without
    re-running this phase.

    Drops the screener's macro gate, top-N cap, and grade threshold — keeps only
    the breakout-condition predicate plus the {!Screener.scored_candidate}
    sizing-input fields ([suggested_entry], [suggested_stop], [risk_pct]).

    Pure function. The caller owns panel iteration; this module is invoked once
    per (Friday, list-of-analyses) pair, accumulates candidates across weeks,
    and returns the full list at the end. The PR-4 binary will wire panel
    iteration on top.

    See [dev/plans/optimal-strategy-counterfactual-2026-04-28.md] §Phase A. *)

open Core

type week_input = {
  date : Date.t;  (** Friday on which the analyses below were computed. *)
  macro_trend : Weinstein_types.market_trend;
      (** Macro trend at [date]. Used to set [passes_macro] on each candidate
          emitted from this Friday — does not gate enumeration. *)
  analyses : Stock_analysis.t list;
      (** Per-symbol screener inputs at [date]. The scanner consults the
          breakout predicate ({!Stock_analysis.is_breakout_candidate}) and the
          screener's per-candidate price helpers — it does NOT score, grade, or
          rank these analyses. *)
  sector_map : (string, Screener.sector_context) Hashtbl.t;
      (** Symbol → sector context. The scanner attaches [sector.sector_name] to
          each emitted candidate so the greedy filler (Phase C) can apply its
          sector concentration cap. *)
}
(** One Friday's worth of input to the scanner.

    Mirrors the shape the live screener already consumes — a [week_input] can be
    constructed by the caller from the same panel-derived data the backtest
    runner already builds when it invokes {!Screener.screen}. The scanner only
    reads it; the panel-iteration machinery lives in PR-4's binary. *)

type config = {
  scoring_weights : Screener.scoring_weights;
      (** Weights used to grade each emitted candidate. The grade is recorded on
          {!Optimal_types.candidate_entry.cascade_grade} for the renderer (PR-4)
          and for sanity-check assertions; it does NOT gate enumeration — every
          breakout-passing candidate is emitted regardless of grade. *)
  grade_thresholds : Screener.grade_thresholds;
      (** Score → grade mapping. Same role as [scoring_weights] — used for the
          recorded [cascade_grade] field, not for filtering. *)
  candidate_params : Screener.candidate_params;
      (** Per-candidate price computation parameters. The scanner derives
          [entry_price], [suggested_stop], and [risk_pct] from these the same
          way the live screener does. *)
}
(** Scanner configuration. Mirrors the relevant subset of {!Screener.config} so
    the counterfactual can be invoked with byte-identical settings to the
    backtest run it is comparing against. The omitted fields ([min_grade],
    [max_buy_candidates], [max_short_candidates]) are precisely the cascade
    constraints the counterfactual relaxes by design.

    Constructed via {!config_of_screener_config} from a {!Screener.config}. *)

val config_of_screener_config : Screener.config -> config
(** [config_of_screener_config c] projects a {!Screener.config} down to the
    subset the scanner needs. Used by the PR-4 binary to build a scanner config
    from the same screener config the actual run used.

    Drops [min_grade], [max_buy_candidates], and [max_short_candidates] — those
    are the gates the counterfactual relaxes. *)

val scan_week :
  config:config -> week_input -> Optimal_types.candidate_entry list
(** [scan_week ~config week] returns one {!Optimal_types.candidate_entry} per
    analysis in [week.analyses] that satisfies
    {!Stock_analysis.is_breakout_candidate}, in the order [week.analyses]
    arrived.

    Each candidate is enriched with sector context (from [week.sector_map]) and
    with [passes_macro = (week.macro_trend <> Bearish)] for longs. The scanner
    does not currently emit short candidates; the [side] field is fixed to
    [Long]. (PR-1 covers the long-side scanner; the short-side variant is a
    follow-up.)

    Returns the empty list when [week.analyses] is empty. Pure function. *)

val scan_panel :
  config:config -> week_input list -> Optimal_types.candidate_entry list
(** [scan_panel ~config weeks] applies {!scan_week} to every week and
    concatenates the results in arrival order — equivalent to
    [List.concat_map weeks ~f:(fun w -> scan_week ~config w)] but reads cleaner
    at call sites. *)
