(** Forward-return counterfactual — the honest "usable signal left on the table"
    half of the per-screen decision audit (plan
    [dev/plans/per-screen-decision-audit-2026-06-30.md] §Phase 2).

    Phase 1 answered the faithfulness question on {b captured features}: do the
    funded entries differ from the cash-rejected near-misses on any signal the
    screener records? This module adds the one place {b outcome} legitimately
    enters: does the forward return of the cash-rejected near-misses differ
    systematically from the funded names? If not, there is no usable captured
    signal being left on the table (selection is faithful — the expected/WAI
    case, per [project_edge_is_the_fat_tail] / [accuracy_is_unreachable]); if
    the near-misses systematically out/under-perform on some captured axis, that
    is a real lever to dig into.

    The forward return reuses {!Decision_grading.Post_exit.post_exit_metrics}'s
    [continuation_pct] (the signed, side-adjusted return over one horizon),
    treating the screen date as the "exit" and the close of the first bar
    at/after the screen date as the base price. Reusing [post_exit] keeps the
    excursion arithmetic in one place rather than re-deriving it.

    The arithmetic is pure; the only impurity is the caller-supplied
    {!Weinstein_strategy.Bar_reader.t}, which reads bars from a snapshot
    warehouse (or an in-memory fixture in tests). *)

open Core

type candidate_forward = {
  symbol : string;
  side : Trading_base.Types.position_side;
  is_funded : bool;
      (** [true] when this candidate was funded on its screen; [false] for a
          cash-rejected (or otherwise skipped) near-miss. *)
  screen_date : Date.t;  (** The Friday the screen ran. *)
  reason_skipped : Backtest.Trade_audit.skip_reason option;
      (** The skip reason for a near-miss; [None] for a funded entry. *)
  forward_return_pct : float option;
      (** Signed forward return from [screen_date] over the report's horizon,
          side-adjusted (positive = the move continued in the candidate's
          direction). [None] when the symbol has no bar at/after [screen_date]
          in the warehouse — such candidates are dropped from the distributional
          stats but still counted. *)
  score : int;
  rs_value : float option;
  volume_ratio : float option;
  weeks_advancing : int option;
}
[@@deriving sexp]
(** One forward-return record per (screen, candidate). Carries the captured
    decision-time features alongside the outcome so the report can optionally
    split the funded-vs-near-miss forward return by a captured-feature bucket.
*)

val compute :
  Screen_record.t list ->
  bar_reader:Weinstein_strategy.Bar_reader.t ->
  horizon_weeks:int ->
  candidate_forward list
(** [compute records ~bar_reader ~horizon_weeks] produces one
    {!candidate_forward} per candidate across all screens.

    For each screen in [records], the candidate set is the {b union} of that
    screen's funded entries and near-misses; a symbol that appears as both a
    funded entry and a near-miss is deduplicated {b toward the funded entry}
    (counted once, as funded). For each candidate:

    - [bars] = [Bar_reader.weekly_bars_for bar_reader ~symbol] as of a few weeks
      past the horizon;
    - the base price is the close of the first bar with [date >= screen_date];
      when no such bar exists, [forward_return_pct] is [None];
    - otherwise [forward_return_pct] is the [continuation_pct] from
      {!Decision_grading.Post_exit.post_exit_metrics} at [horizon_weeks], with
      the base price as the exit price and [screen_date] as the exit date,
      side-adjusted per the candidate's [side].

    Pure given a fixed [bar_reader]: same inputs → same output. *)
