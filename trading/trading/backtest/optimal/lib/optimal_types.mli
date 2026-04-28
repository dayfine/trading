(** Data model for the optimal-strategy counterfactual.

    Captures the shapes consumed and produced across the four phases of the
    counterfactual pipeline:

    - Phase A (PR-1): {!Stage_transition_scanner} emits one {!candidate_entry}
      per (symbol, week) where the system's structural breakout predicate fires.
    - Phase B (PR-2): the outcome scorer enriches each candidate with the
      realized exit week / price / R-multiple under the counterfactual exit
      rule, producing a {!scored_candidate}.
    - Phase C (PR-3): the greedy filler walks Fridays and produces
      {!optimal_round_trip}s, which roll up into an {!optimal_summary}.

    Every record derives [sexp_of] / [of_sexp] so that scenario-runner artefacts
    on disk round-trip across processes — the renderer binary (PR-4) reads its
    inputs from sibling sexp files alongside [trades.csv] and [summary.sexp].

    Pure data — no I/O, no mutable state. Mirrors the shape discipline of
    {!Backtest.Trade_audit}'s record types.

    See [dev/plans/optimal-strategy-counterfactual-2026-04-28.md]. *)

open Core

(** {1 Phase A: candidate enumeration} *)

type candidate_entry = {
  symbol : string;
  entry_week : Date.t;
      (** Friday on which the breakout predicate fired. The week's close is the
          counterfactual entry price. *)
  side : Trading_base.Types.position_side;
      (** [Long] for Stage 1 → 2 breakouts, [Short] for Stage 3 → 4 breakdowns.
          PR-1 only enumerates longs; the [side] field is recorded here for
          forward-compatibility with the short-side scanner. *)
  entry_price : float;
      (** Counterfactual entry price — the breakout-week close. Mirrors the
          price the live strategy would have used had it acted. *)
  suggested_stop : float;
      (** Initial stop level for the counterfactual. Sourced from the same
          {!Screener.scored_candidate.suggested_stop} computation the live
          cascade uses, so the counterfactual respects the strategy's stop
          discipline. *)
  risk_pct : float;
      (** [|entry_price - suggested_stop| /. entry_price]. Used by the sizing
          envelope (Phase C) and the R-multiple computation (Phase B). *)
  sector : string;
      (** GICS sector display name. Used by the greedy filler's sector
          concentration cap. *)
  cascade_grade : Weinstein_types.grade;
      (** Cascade grade the live screener would have assigned. Recorded for the
          per-Friday divergence report (PR-4) so the renderer can attribute
          missed entries to "filtered by grade threshold". *)
  passes_macro : bool;
      (** Whether the macro gate at [entry_week] would have admitted this
          candidate. The scanner records both passes and fails so the renderer
          can produce two report variants — constrained (macro gate kept) and
          relaxed (macro gate dropped). *)
}
[@@deriving sexp]
(** One row per (symbol, week) where the system's structural breakout condition
    fires. Drops the screener's macro gate / top-N cap / grade threshold — keeps
    only the breakout predicate plus the sizing-input fields. *)

(** {1 Phase B: scored candidate (forward-declared shape)}

    Filled in by PR-2's [Outcome_scorer]. Listed here because PR-3 / PR-4 need
    to round-trip these via sexp from a sibling artefact file, so the schema
    must be stable across PRs.

    The scorer walks forward from [entry.entry_week] applying the counterfactual
    exit rule (first Stage-3 transition, stop hit, or end-of-run, whichever
    comes first) and fills in the post-entry fields. *)

(** Why a counterfactual position closed. Mirrors the real strategy's exit
    triggers but limited to the three the counterfactual can detect from a
    forward walk over the panel. *)
type exit_trigger = Stage3_transition | Stop_hit | End_of_run
[@@deriving sexp]

type scored_candidate = {
  entry : candidate_entry;  (** The Phase-A row for this candidate. *)
  exit_week : Date.t;
      (** Friday on which the position closes under the counterfactual exit
          rule. *)
  exit_price : float;
      (** Close on [exit_week]. The counterfactual exits at weekly closes
          (mirrors the live stop's weekly-close trigger). *)
  exit_trigger : exit_trigger;
      (** Which of the three exit conditions fired first. *)
  raw_return_pct : float;
      (** [(exit_price - entry.entry_price) / entry.entry_price] for longs,
          mirrored for shorts. Sign carries the direction. *)
  hold_weeks : int;
      (** Whole weeks between [entry.entry_week] and [exit_week]. *)
  initial_risk_per_share : float;
      (** [|entry.entry_price - entry.suggested_stop|]. Used to convert
          [raw_return_pct] into an R-multiple. *)
  r_multiple : float;
      (** [(exit_price - entry.entry_price) / initial_risk_per_share] for longs.
          Comparable across positions of different sizes / risk profiles — the
          sort key the greedy filler uses. *)
}
[@@deriving sexp]
(** A {!candidate_entry} enriched with realized counterfactual outcome. *)

(** {1 Phase C: round-trip + summary} *)

type optimal_round_trip = {
  symbol : string;
  side : Trading_base.Types.position_side;
  entry_week : Date.t;
  entry_price : float;
  exit_week : Date.t;
  exit_price : float;
  exit_trigger : exit_trigger;
  shares : float;
      (** Position size the greedy filler chose under the sizing envelope —
          [risk_per_trade_dollars / initial_risk_per_share], rounded down. *)
  initial_risk_dollars : float;
      (** [(entry_price - stop) * shares]. Sets the R-multiple denominator on a
          dollar basis so [pnl_dollars / initial_risk_dollars] is comparable
          across positions. *)
  pnl_dollars : float;  (** [(exit_price - entry_price) * shares] for longs. *)
  r_multiple : float;
      (** [pnl_dollars /. initial_risk_dollars]. Equal to the
          {!scored_candidate} R-multiple modulo rounding when [shares] is
          bounded by risk only; may differ when cash or sector caps clipped the
          position. *)
  cascade_grade : Weinstein_types.grade;
      (** Carried from the {!candidate_entry}. *)
  passes_macro : bool;  (** Carried from the {!candidate_entry}. *)
}
[@@deriving sexp]
(** A counterfactual round trip — a candidate that the greedy filler chose to
    enter and that subsequently closed (or ran to end-of-run). One per closed
    position in the counterfactual portfolio. *)

type optimal_summary = {
  total_round_trips : int;
  winners : int;
  losers : int;
  total_return_pct : float;
      (** Cumulative return on starting capital, expressed as a fraction (e.g.
          [0.42] = +42%). *)
  win_rate_pct : float;
      (** [winners / total_round_trips], 0.0 when there are no round trips. *)
  avg_r_multiple : float;
      (** Mean of [round_trip.r_multiple] across closed positions. *)
  profit_factor : float;
      (** [sum(positive pnl_dollars) /. sum(|negative pnl_dollars|)]; infinite
          when there are no losers (encoded as [Float.infinity]). *)
  max_drawdown_pct : float;
      (** Peak-to-trough drawdown of the counterfactual equity curve, as a
          fraction (positive = drawdown). *)
  variant : variant_label;
      (** Which variant this summary describes — see {!variant_label}. *)
}
[@@deriving sexp]
(** Aggregate metrics over an [optimal_round_trip list]. Renders into the
    headline comparison table in [optimal_strategy.md]. *)

(** Which variant of the counterfactual a summary / round-trip set describes.

    The renderer (PR-4) emits a comparison table with columns for both variants;
    the scanner (PR-1) tags each candidate with [passes_macro] so the downstream
    pipeline can split rows by variant without re-running Phase A. *)
and variant_label =
  | Constrained
      (** Macro gate honoured — counterfactual only enters candidates whose
          [passes_macro] flag was [true] at the breakout week. The honest
          comparison: "what's reachable if cascade ranking were perfect, all
          else equal?" *)
  | Relaxed_macro
      (** Macro gate dropped — every candidate is eligible regardless of regime.
          The upper bound: "what's reachable if we also relaxed the macro gate?"
      *)
[@@deriving sexp]
