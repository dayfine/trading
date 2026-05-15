(** Rolling window specification for walk-forward cross-validation.

    A [WindowSpec.t] is a pure description of how to roll a fixed-shape
    train/test window forward across a calendar range. {!generate} expands the
    spec into a list of {!fold}s; each fold carries a name and the train + test
    {!Scenario_lib.Scenario.period}s the walk-forward runner will instantiate
    base scenarios over.

    Walk-forward CV (Phase 2 per
    [dev/notes/next-session-priorities-2026-05-15.md]) scales the existing
    hand-curated 8-fold experiment to ~30 rolling folds so per-fold variance is
    observable and a machine-checkable go/no-go gate becomes the verdict rather
    than an eyeballed table.

    All date arithmetic is in calendar days (not trading days). Conversion to
    trading-day windows is the backtest runner's job — the spec only constrains
    the wall-clock period each fold runs over. *)

open Core

type t = {
  start_date : Date.t;
      (** Inclusive earliest day for the first fold's train (or test, when
          [train_days = 0]) period. *)
  end_date : Date.t;
      (** Inclusive latest day any fold may extend to. Folds whose test period
          would end after [end_date] are dropped. *)
  train_days : int;
      (** Length of each fold's in-sample (train) period in calendar days. Zero
          means OOS-only folds — [train_period] in the generated fold is [None].
          Must be [>= 0]. *)
  test_days : int;
      (** Length of each fold's out-of-sample (test) period in calendar days.
          Must be [> 0]. *)
  step_days : int;
      (** How far each subsequent fold's anchor advances in calendar days. Must
          be [> 0]. When [step_days < test_days] the test windows overlap
          (classic rolling walk-forward); when [step_days = test_days] the test
          windows tile without overlap. *)
}
[@@deriving sexp]
(** Sexp shape (one record):
    [((start_date 2010-01-01) (end_date 2024-12-31) (train_days 730) (test_days
     365) (step_days 182))]. *)

type fold = {
  index : int;  (** Zero-based fold index in generation order. *)
  name : string;
      (** Human-readable fold name, shape ["fold-NNN"] where [NNN] is [index]
          zero-padded to width 3. Used as a suffix in generated scenario names.
      *)
  train_period : Scenario_lib.Scenario.period option;
      (** [Some] when [WindowSpec.train_days > 0], else [None]. The train period
          precedes the test period back-to-back. *)
  test_period : Scenario_lib.Scenario.period;
}
[@@deriving sexp]

val generate : t -> fold list
(** [generate spec] expands a spec into its sequence of folds.

    Algorithm: starting from [spec.start_date], the first fold's train_period
    runs [start_date .. start_date + train_days - 1] (inclusive) and its
    test_period runs
    [start_date + train_days .. start_date + train_days + test_days - 1]. Each
    subsequent fold's anchor advances by [step_days] calendar days. A fold is
    included iff its test_period ends on or before [spec.end_date]; the first
    fold whose test_period would extend past [end_date] is dropped along with
    all later folds.

    Returns an empty list when [start_date > end_date] or no fold fits the
    bounds. Raises [Failure] when [train_days < 0], [test_days <= 0], or
    [step_days <= 0]. *)
