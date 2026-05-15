(** Window specification for walk-forward cross-validation.

    A [WindowSpec.t] is a pure description of how to lay out a sequence of
    train/test windows across a calendar range. {!generate} expands the spec
    into a list of {!fold}s; each fold carries a name and the train + test
    {!Scenario_lib.Scenario.period}s the walk-forward runner will instantiate
    base scenarios over.

    Walk-forward CV (Phase 2 per
    [dev/notes/next-session-priorities-2026-05-15.md]) scales the existing
    hand-curated 8-fold experiment to ~30 rolling folds so per-fold variance is
    observable and a machine-checkable go/no-go gate becomes the verdict rather
    than an eyeballed table.

    Two construction modes:

    - [Rolling] — start_date/train_days/test_days/step_days expansion; the
      generator emits the fold sequence and stops dropping folds whose
      test_period extends past [end_date].
    - [Explicit] — hand-curated list of fold periods, used to migrate the
      2026-05-08 8-fold experiment as a regression fixture (its windows are not
      a rolling pattern). Folds pass through verbatim with their input-order
      indexes and operator-supplied names.

    All date arithmetic is in calendar days (not trading days). Conversion to
    trading-day windows is the backtest runner's job — the spec only constrains
    the wall-clock period each fold runs over. *)

open Core

type rolling_spec = {
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

type explicit_fold = {
  name : string;
      (** Human-readable fold name used verbatim as [fold.name] in the generated
          fold record. Must be unique within the [Explicit] list. *)
  train_period : Scenario_lib.Scenario.period option;
      (** Optional in-sample period, same semantics as the rolling case. *)
  test_period : Scenario_lib.Scenario.period;
}
[@@deriving sexp]
(** One hand-curated fold for the [Explicit] mode. *)

(** Sexp shape: [(Rolling ((start_date ...) (end_date ...) ...))] or
    [(Explicit (((name "...") (train_period ...) (test_period ...)) ...))].

    {b Legacy flat-shape compatibility:} the [t_of_sexp] override below accepts
    the pre-variant shape
    [((start_date ...) (end_date ...) (train_days ...) (test_days ...)
     (step_days ...))] and parses it as [Rolling]. The plan tracks this
    temporarily; new spec files should use the variant shape. *)
type t = Rolling of rolling_spec | Explicit of explicit_fold list
[@@deriving sexp]

val t_of_sexp : Sexp.t -> t
(** [t_of_sexp sexp] parses both the variant shape ([Rolling]/[Explicit]) and
    the legacy flat-record shape (silently promoted to [Rolling]). Raises
    [Failure] on shapes matching neither. *)

type fold = {
  index : int;  (** Zero-based fold index in generation order. *)
  name : string;
      (** Human-readable fold name. For [Rolling] folds shape is ["fold-NNN"]
          where [NNN] is [index] zero-padded to width 3. For [Explicit] folds
          the name is the operator-supplied {!explicit_fold.name} verbatim. *)
  train_period : Scenario_lib.Scenario.period option;
      (** [Some] when there is an in-sample period, else [None]. The train
          period precedes the test period back-to-back in [Rolling] mode; the
          [Explicit] case passes through whatever the operator supplied. *)
  test_period : Scenario_lib.Scenario.period;
}
[@@deriving sexp]

val generate : t -> fold list
(** [generate spec] expands a spec into its sequence of folds.

    [Rolling]: starting from [spec.start_date], the first fold's train_period
    runs [start_date .. start_date + train_days - 1] (inclusive) and its
    test_period runs
    [start_date + train_days .. start_date + train_days + test_days - 1]. Each
    subsequent fold's anchor advances by [step_days] calendar days. A fold is
    included iff its test_period ends on or before [spec.end_date]; the first
    fold whose test_period would extend past [end_date] is dropped along with
    all later folds.

    [Explicit]: passes the list through verbatim, assigning [index] in input
    order. Raises [Failure] on an empty list or on duplicate names.

    Returns an empty list when [Rolling]'s [start_date > end_date] or no fold
    fits the bounds. Raises [Failure] when [Rolling.train_days < 0],
    [Rolling.test_days <= 0], or [Rolling.step_days <= 0]. *)
