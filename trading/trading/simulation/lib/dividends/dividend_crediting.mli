(** Cash dividends on held positions (issue #3137, part 2).

    The simulator marks positions at raw closes, so a run without this module
    is price-only: a held long never receives its dividends and a short never
    pays them. Armed, each simulated step credits (long) or charges (short) the
    cash dividends whose ex-date fell since the previous step.

    {b Source.} The vendor's recorded dividends, read per symbol from
    [<data_dir>/.../<SYM>/dividends.csv] ({!Corporate_actions.read_dividends}),
    not inferred from the adjusted/raw close ratio. Special dividends are
    ordinary rows and are credited like any other.

    {b Amount.} Only [unadjusted_amount] — the cash paid per share held on the
    ex-date — because positions are held at raw (unadjusted) prices and share
    counts. A row whose [unadjusted_amount] is [None] is {e skipped and
    counted}; it is never replaced by [adjusted_amount], which is restated for
    later splits and would mis-credit any position held across a split.

    {b Ex-date convention.} The pay date is not in the data, so cash moves on
    the ex-date. A position earns a dividend iff it is held when the step for
    the ex-date starts — i.e. it was held at the prior close, the economic
    record condition. A buy that fills on the ex-date itself gets nothing; a
    sale that fills on the ex-date still gets it. The credit for step [date]
    covers every ex-date in [(previous credited step, date]], so an ex-date on
    a day without a step (a skipped weekend or holiday) is credited on the next
    step.

    {b Sign.} Long: [cash += quantity * amount]. Short: [cash -= |quantity| *
    amount] (the borrower owes the lender the dividend).

    {b Window.} Only ex-dates on or after [start_date] (the measurement-window
    start) are credited; warmup earns and pays nothing, mirroring
    [Cash_yield.Accrual].

    {b Missing data.} A held symbol with no [dividends.csv] is treated as paying
    no dividends and counted once in [missing_files], so a coverage gap is
    visible rather than silent. A malformed file fails the step. *)

open Core

type loader = string -> Corporate_actions.dividend list Status.status_or
(** Reads one symbol's dividends; [NotFound] means "no file". *)

type t
(** Per-run state: the loader, a per-symbol cache, the last credited date and
    the running totals. One value per run; mutated by {!step}. *)

val create : load:loader -> start_date:Date.t -> t
(** Fresh state. [load] is called at most once per symbol (results, including
    [NotFound], are cached). *)

val of_data_dir : data_dir:Fpath.t -> start_date:Date.t -> t
(** {!create} with {!Corporate_actions.read_dividends} on [data_dir] (the
    [TRADING_DATA_DIR] store, not the snapshot warehouse). *)

val step :
  t option ->
  date:Date.t ->
  Trading_portfolio.Portfolio.t ->
  Trading_portfolio.Portfolio.t Status.status_or
(** Credit / charge every held position for the ex-dates in
    [(last credited date, date]] (never before [start_date]). [None], or a
    [date] already covered, returns the portfolio unchanged. [Error] when a
    dividend file cannot be read for a reason other than [NotFound]. *)

type totals = {
  long_income : float;  (** Dollars received by long positions. *)
  short_paid : float;  (** Dollars paid by short positions ([>= 0]). *)
  skipped_no_amount : int;
      (** Held-position dividend events skipped because [unadjusted_amount] was
          [None]. *)
  missing_files : int;  (** Distinct held symbols that had no [dividends.csv]. *)
}
[@@deriving show, eq]
(** Running totals of one run. *)

val totals : t -> totals
(** Totals credited so far. *)
