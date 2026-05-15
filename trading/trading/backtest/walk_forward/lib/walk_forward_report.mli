(** Pure markdown renderer for walk-forward CV results.

    Consumes a flat list of per-(fold, variant) measurements + a baseline label
    \+ a {!Fold_gate.t}, and emits a four-section markdown report:

    1. **Per-fold metrics table** — one row per fold × variant, columns: fold
    name, variant label, total return %, Sharpe, MaxDD %, Calmar. 2. **Stability
    table** — one row per variant: mean ± stdev of each metric across folds. 3.
    **Cross-fold parameter sensitivity** — variant win-count per metric. 4.
    **Go/no-go verdict block** — calls {!Fold_gate.evaluate} on the
    gate-selected metric and renders Pass/Fail with the diagnostic fields. *)

type fold_actual = {
  fold_name : string;
  variant_label : string;
  total_return_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  calmar_ratio : float;
}
[@@deriving sexp]

val render :
  baseline_label:string ->
  gate:Fold_gate.t ->
  fold_actuals:fold_actual list ->
  string
(** [render ~baseline_label ~gate ~fold_actuals] returns a markdown report
    string. The renderer is deterministic — same inputs produce byte-identical
    output (modulo timestamp, which is intentionally omitted).

    Raises [Failure] if [fold_actuals] is empty or if [baseline_label] is not
    present among the variant labels in [fold_actuals].

    The per-fold table preserves the input ordering of [fold_actuals]. The
    stability and sensitivity tables aggregate by variant label, in the order
    the labels first appear in [fold_actuals].

    The go/no-go verdict block pairs each non-baseline variant against the
    baseline on the gate's [metric] and renders a separate Pass/Fail line per
    variant. *)
