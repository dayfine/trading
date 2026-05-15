(** Pure go/no-go gate for walk-forward fold results.

    The gate encodes the rule "variant wins on at least M of N folds AND no
    single fold is worse than baseline by more than Δ". This is the
    machine-checkable verdict that supersedes the eyeballed
    [dev/experiments/cell-e-walk-forward-2026-05-08/report.md] verdict — the
    M5.5 axis-2 and continuation-combined sweeps that ultimately failed 16y
    validation would have been rejected by an honest M-of-N gate set on
    short-window data alone.

    All thresholds are inputs. The harness chooses sensible defaults; the
    discipline is in the gate's shape, not in the specific numbers. *)

(** Which metric the gate compares variant vs baseline on. [MaxDrawdownPct]
    inverts the comparison direction (lower is better) — see {!evaluate}. *)
type metric_key = Sharpe | Calmar | TotalReturnPct | MaxDrawdownPct
[@@deriving sexp]

type t = {
  metric : metric_key;
      (** The per-fold score the gate compares variant vs baseline on. *)
  m : int;
      (** Minimum number of fold-wins required for [Pass]. Must satisfy
          [0 <= m <= n]. *)
  n : int;
      (** Expected total fold count. The evaluator raises [Failure] when the
          input fold list's length doesn't match [n] — a guard against
          accidentally fudging the gate by silently dropping folds. Must be
          [>= 1]. *)
  worst_delta : float;
      (** Maximum permitted shortfall on any single fold:
          [variant_score < baseline_score - worst_delta] is a hard fail
          regardless of total win count. For [MaxDrawdownPct] (lower is better)
          the shortfall direction is reversed:
          [variant_score > baseline_score + worst_delta] is the failure
          condition. Must be [>= 0.0]. *)
}
[@@deriving sexp]

type fold_result = {
  fold_name : string;
  variant_score : float;
  baseline_score : float;
}
[@@deriving sexp]
(** One per-fold measurement pair. The walk-forward report builder produces one
    [fold_result] per (fold, metric) pair. *)

type verdict =
  | Pass of { wins : int; n : int }
  | Fail of {
      wins : int;
      n : int;
      worst_fold : string;
      worst_gap : float;
          (** Signed shortfall in [variant - baseline] units for "higher is
              better" metrics, or in [baseline - variant] units for
              [MaxDrawdownPct]. Always nonnegative when [worst_gap > 0.0]
              triggered the failure; may be [0.0] when only the M-threshold
              tripped. *)
      reason : string;
    }
[@@deriving sexp]

val evaluate : t -> fold_result list -> verdict
(** [evaluate gate folds] returns [Pass _] iff:
    - [List.length folds = gate.n] (raises [Failure] otherwise),
    - the variant wins on at least [gate.m] folds (ties count as a win for the
      baseline — variant must strictly beat),
    - AND no single fold's variant trails the baseline by more than
      [gate.worst_delta] (direction inverted for [MaxDrawdownPct]).

    Otherwise returns [Fail _] with the diagnostic shape. The [worst_fold] /
    [worst_gap] / [reason] fields name the largest individual shortfall (even on
    a pure M-threshold miss) so the report renderer can surface a useful "why"
    sentence.

    For "higher is better" metrics (Sharpe, Calmar, TotalReturnPct), a "win"
    means [variant_score > baseline_score]. For [MaxDrawdownPct], a "win" means
    [variant_score < baseline_score] (less drawdown is better). *)

val higher_is_better : metric_key -> bool
(** Returns [true] for Sharpe / Calmar / TotalReturnPct; [false] for
    MaxDrawdownPct. Exposed so the report renderer's per-fold table can label
    wins consistently with the gate's interpretation. *)
