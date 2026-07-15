(** Composite per-trade quality score — "how good was this trade?" rolled into
    one 0-100 number + letter grade for the audit report.

    Inputs are the already-derived {!Trade_audit_ratings.rating} metrics plus
    the trade's realized P&L percent. Four weighted components, each in
    [[0, 1]]:

    - {b capture} — realized gain as a fraction of the max favourable excursion
      ([pnl / mfe]): did the exit keep what the trade offered? Losing trades
      score 0; trades with no favourable excursion score 0.
    - {b risk_reward} — the R-multiple squashed to [[0, 1]] via
      [r / (r + r_scale)] for winners (diminishing credit above [r_scale]);
      losers score a partial credit [1 - min(1, |r|)] scaled by [loss_credit] (a
      disciplined small loss beats a full-stop loss).
    - {b pain} — [1 - min(1, |mae| / initial risk)]: how far the trade sank
      toward its stop before resolving. NaN-risk (degenerate stop) scores 0.5.
    - {b conformance} — the Weinstein rule score
      ({!Trade_audit_ratings.rating.weinstein_score}) verbatim; NaN (no
      applicable rules) re-weights onto the other components.

    The composite is the weight-normalized sum, scaled to 0-100. Letter grades
    cut at fixed thresholds (A+ >= 85, A >= 70, B >= 55, C >= 40, D >= 25, F
    below). All weights and scales live in {!type:config} — nothing hardcoded at
    call sites. *)

type config = {
  capture_weight : float;  (** Default [0.30]. *)
  risk_reward_weight : float;  (** Default [0.30]. *)
  pain_weight : float;  (** Default [0.15]. *)
  conformance_weight : float;  (** Default [0.25]. *)
  r_scale : float;
      (** R-multiple at which a winner earns half the risk_reward component.
          Default [2.0] (a 2R win = 0.5; 6R ~= 0.75). *)
  loss_credit : float;
      (** Ceiling on the risk_reward component for losing trades. Default
          [0.25]: a scratch loss (|r| ~ 0) earns up to 0.25; a full 1R stop loss
          earns 0. *)
}
[@@deriving sexp]

val default_config : config

type t = {
  score : float;  (** Composite in [[0, 100]]. *)
  grade : string;  (** ["A+"], ["A"], ["B"], ["C"], ["D"], or ["F"]. *)
  capture : float;  (** Component in [[0, 1]]. *)
  risk_reward : float;
  pain : float;
  conformance : float;  (** [Float.nan] when no rules were applicable. *)
}
[@@deriving sexp]

val compute :
  ?config:config ->
  rating:Trade_audit_ratings.rating ->
  pnl_percent:float ->
  unit ->
  t
(** [compute ~rating ~pnl_percent ()] derives the composite. [pnl_percent] is
    the round-trip realized percent from trades.csv (sign per side, e.g. [-9.17]
    for a 9.17% loss). Deterministic and total: every input NaN case maps to a
    documented fallback rather than propagating. *)

val grade_of_score : float -> string
(** Fixed thresholds; exposed for tests and for rendering legends. *)
