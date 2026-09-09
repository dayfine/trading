(** Cross-arm comparison gate over post-run validator reports.

    The post-run validator ({!Validator_report}) is report-only: it tells you
    how many invariant violations one run carries, and every experiment chain
    writes one report per arm. Nothing, until now, compared those counts to each
    other — so on 2026-09-08 the item-3 stop-width surface ran a null arm with
    [V6 = 0] against a map arm with [V6 = 6] twin-position violations, and
    ~$764k of that arm's "edge" was one instrument held twice under two tickers.
    QC caught it by reading the two [.md] files side by side (issue #2730, ask
    2, off PR #2728).

    That is the rule this module mechanises:
    {b a cell whose invariant counts differ from its comparator's is not a
       paired read.} The two arms hold different instrument sets, so their P&L
    delta measures the data defect as much as it measures the mechanism, and its
    size scales with the lever. See
    [.claude/rules/mechanism-validation-rigor.md] check 8.

    Everything here is pure over already-parsed {!Validator_types.report}
    values; [bin/validator_diff.ml] is the thin CLI that loads the sexps and
    turns {!agreed} into an exit code. Incantation:

    {v
      dune exec trading/backtest/validation/bin/validator_diff.exe -- \
        -report null=<dir>/a0-...-validator.sexp.sexp \
        -report map=<dir>/a1-...-validator.sexp.sexp
    v}

    Exit 0 = every selected check agrees; exit 1 = they differ (the arms are not
    comparable). Add [-check V6] to gate on one check, or [-severity all] to
    include {!Validator_types.Expectation} checks too. *)

(** Which checks are compared when no explicit [-check] list is given. *)
type severity_filter =
  | Invariant_only
      (** Only checks some report marks {!Validator_types.Invariant} — the
          default, because an {!Validator_types.Expectation} count legitimately
          moves with the lever under test (a wider stop holds different trades,
          so its V9 overhead count differs without anything being wrong). An
          {!Validator_types.Invariant} count moving means the two runs disagree
          about the data itself. *)
  | All_checks  (** Every check id present in any report. *)

type labeled_report = { label : string; report : Validator_types.report }
(** One arm's report plus the short name it is printed under (["null"], ["map"],
    ...). *)

type check_row = {
  id : string;  (** e.g. ["V6"]. *)
  counts : (string * int) list;
      (** [(label, n_violations)] for every report, in the order the reports
          were given. *)
  agreed : bool;  (** All the [counts] are equal. *)
}
(** One row of the comparison table: a check id and its violation count in each
    arm. *)

type specimen_delta = {
  check_id : string;
  specimen : Validator_types.specimen;
  present_in : string list;
      (** The labels whose report lists this exact specimen. Strictly a subset
          of all labels — a specimen present everywhere is not a delta. *)
}
(** A violating trade that one arm reports and another does not — the "WHICH
    twin pair appeared" detail. Note the validator caps [specimens] at 10 per
    check, so on a check with many violations this list is a sample of the
    difference, not its entirety; {!check_row.counts} is the authority on size.
*)

type t = { rows : check_row list; specimen_deltas : specimen_delta list }
(** A computed comparison: one {!check_row} per selected check, plus the
    specimen deltas of the checks that disagreed (none are collected for checks
    that agreed). *)

val compute :
  ?check_ids:string list ->
  ?severity:severity_filter ->
  labeled_report list ->
  t Status.status_or
(** [compute ?check_ids ?severity reports] compares [reports] check by check.

    Selection: a non-empty [check_ids] names exactly the checks to compare and
    overrides [severity]; otherwise every check id appearing in any report is
    taken, in first-appearance order, filtered by [severity] (default
    {!Invariant_only}).

    Errors — never a silent pass, since the whole point is to refuse to certify
    an unverifiable pairing:
    - fewer than two reports (nothing to compare);
    - the selection is empty (e.g. [-check] named nothing that exists);
    - a selected check id is missing from any one report ([Not_found]) — two
      runs whose validators ran different check sets cannot be diffed. *)

val agreed : t -> bool
(** [true] when every row in [t] agreed, i.e. the arms are a paired read on the
    selected checks. This is the gate: the CLI exits 0 on [true], 1 on [false].
*)

val render : t -> string
(** The human table — [check | label1 | label2 | ... | verdict], one row per
    selected check with [agree] / [DIFFER] — followed, when there are any, by
    the {!specimen_delta} lines naming the trades that appear in some arms and
    not others. No trailing newline. *)
