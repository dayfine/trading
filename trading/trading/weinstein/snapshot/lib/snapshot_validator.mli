(** Mechanical invariant checks over a weekly pick snapshot — issue #2122 v1.

    The weekly report is an artifact the user acts on with real money; three
    defects in one week (#2083, #2084, #2103) plus two more found by hand
    inspection (#2122) were all caught by eyeball. This module makes the obvious
    checks mechanical: every check is a pure function of the snapshot record
    (plus an optional bar source), producing typed findings rather than
    opinions.

    Checks (per candidate, side-aware):
    - [positive_prices] / [stop_side] — entry/stop finite and positive; the stop
      sits on the protective side of {!Weekly_snapshot.expected_fill_price}.
    - [reconciliation_overshoot] / [reconciliation_class] — the stored overshoot
      agrees with (close vs entry), and the class matches the thresholds
      ([through_band_pct] / [extension_max_pct] — pass the armed live values;
      defaults mirror dev/weekly-picks/live-config-overrides.sexp as of
      2026-07-27: 1.0 / 15.0). Both boundaries fall to the LOWER class,
      mirroring {!Entry_reconciliation}: an overshoot exactly at
      [through_band_pct] is still [Valid_stop], and one exactly at
      [extension_max_pct] is still [Through_entry]. The conventions must stay in
      lockstep — a stricter comparison here would flag a legitimate boundary
      artifact as a [reconciliation_class] error. (There is no
      [extended_not_suppressed] check: issue #2404 stopped the report
      suppressing past-cap tickets, so an EXTENDED candidate carries a
      normally-sized ticket and is covered by [risk_consistency] like any
      other.)
    - [risk_consistency] — [sized_risk_amount = shares x |expected fill - stop|]
      for sized candidates; [risk_budget] (optional) upper-bounds it.
    - With [bars_for]: [chart_coverage] (>= 2 bars or the chart cell degrades)
      and [split_in_window] (a step in the raw/adjusted ratio marks the
      candidate's resistance grade + structural floor basis-suspect, #2133).

    Snapshot-level: non-empty macro regime; no duplicate symbols per list.

    Everything is a warning or an error: errors are internal inconsistencies of
    the artifact (wrong class, wrong risk arithmetic); warnings are
    quality/coverage signals a human should read. Pure; never raises on any
    parseable snapshot. *)

type level = Error | Warning [@@deriving sexp, eq, show]

type finding = {
  level : level;
  symbol : string option;  (** [None] for snapshot-level findings. *)
  check : string;  (** Stable machine-readable check name (see above). *)
  detail : string;  (** Human-readable specifics with the numbers inline. *)
}
[@@deriving sexp, eq, show]

val validate :
  ?through_band_pct:float ->
  ?extension_max_pct:float ->
  ?risk_budget:float ->
  ?bars_for:(symbol:string -> Types.Daily_price.t list) ->
  Weekly_snapshot.t ->
  finding list
(** [validate t] runs every check and returns the findings, candidate order
    preserved within each list. Bar-dependent checks run only when [bars_for] is
    given; the budget check only when [risk_budget] is given. *)

val has_errors : finding list -> bool
(** [has_errors fs] is [true] when any finding is [Error]-level — the exe's
    exit-code predicate. *)

val to_report : finding list -> string
(** [to_report fs] renders findings one per line ("ERROR SYM check: detail"), or
    an explicit ["OK: no findings"] so silence is never ambiguous. *)
