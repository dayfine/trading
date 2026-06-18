(** Post-exit continuation measurement — the counterfactual half of the
    decision-grading lens (plan [dev/plans/decision-grading-lens-2026-06-17.md]
    §Phase 1).

    The strategy's edge is drawdown-avoidance via Stage-3/4 exits, so the
    central question for grading any exit is:
    {b after we sold, did the stock keep moving in our direction (we left money
       on the table) or did it reverse (we dodged a drop)?} Existing MFE/MAE in
    [Exit_audit_capture] measure excursion {b up to} the exit; this module
    measures excursion {b forward} from the exit, relative to the exit price.

    Every function here is pure — no [Bar_reader], no I/O, no engine state. It
    operates on a caller-supplied list of weekly bars at/after the exit date, so
    it is unit-tested directly against hand-built synthetic series. Whoever has
    the bars (CLI, report) calls in; this module only does arithmetic. *)

type horizon_result = {
  horizon_weeks : int;  (** The horizon this result was computed over. *)
  continuation_pct : float;
      (** Signed return from [exit_price] to the close of the last bar within
          [horizon_weeks] of the exit. For a {b long} a positive value means
          price kept rising after we sold — we gave up gains (premature exit); a
          negative value means price fell — we dodged a drop (good exit). For a
          {b short} the sign is mirrored so the same interpretation holds (a
          positive value still means "the move continued in the direction we
          would have wanted to stay in"). [0.0] when no bar falls within the
          horizon or when [exit_price <= 0.0]. *)
  post_exit_max_favorable_pct : float;
      (** Best move {b in the trade's direction} over the window
          [[exit_date, exit_date + horizon_weeks * 7]], as a fraction of
          [exit_price]. Long: from the window's max high; short: from the
          window's min low, sign-mirrored. Always [>= 0.0] for a window that
          contains [exit_price]'s own bar. [0.0] when the window is empty or
          [exit_price <= 0.0]. *)
  post_exit_max_adverse_pct : float;
      (** Worst move {b against the trade} over the same window, as a fraction
          of [exit_price]. Long: from the window's min low; short: from the
          window's max high, sign-mirrored. Typically [<= 0.0]. [0.0] when the
          window is empty or [exit_price <= 0.0]. *)
}
[@@deriving show, eq, sexp]
(** Post-exit excursion summary for one horizon. The favourable/adverse fields
    use the {b same} sign convention as [Exit_audit_capture._excursions]:
    "favourable" is in the trade's direction, "adverse" against it, and the
    short side is mirrored around [exit_price]. *)

val post_exit_metrics :
  side:Trading_base.Types.position_side ->
  exit_price:float ->
  exit_date:Core.Date.t ->
  bars:Types.Daily_price.t list ->
  horizons_weeks:int list ->
  horizon_result list
(** [post_exit_metrics ~side ~exit_price ~exit_date ~bars ~horizons_weeks]
    computes one {!horizon_result} per entry in [horizons_weeks], measuring how
    the stock moved {b after} the exit relative to [exit_price].

    [bars] are weekly bars; only those with [date >= exit_date] are used (the
    bar exactly on [exit_date] {b is included}). They need not be sorted — they
    are sorted ascending internally. For each horizon [h], the window is every
    used bar with [date] within [h * 7] days of [exit_date] (inclusive of the
    [exit_date] bar). [continuation_pct] reads the {b close} of the last bar in
    that window; the excursion fields read the window's high/low extremes. All
    three are sign-adjusted for [side] exactly as
    [Exit_audit_capture._excursions] does for the hold-window case.

    Edge cases (all documented per field above):
    - [exit_price <= 0.0] -> every field of every result is [0.0] (no meaningful
      percentage against a non-positive base).
    - A horizon whose window contains no bar (e.g. a horizon beyond the data, or
      [bars] empty) -> that result's float fields are all [0.0].

    The output list is in the same order as [horizons_weeks] (one result each,
    duplicates preserved). Pure: same inputs -> same output. *)
