(** Warn-first packaging of {!Weinstein_snapshot.Snapshot_validator} findings
    for the [generate_weekly_snapshot] seam (issue #2122 slice a).

    The generator runs the validator over the snapshot it just wrote and hands
    the findings here. This module owns two decisions, kept pure so they are
    testable without running the generator:

    - {b what to print} — a delimited stderr block, one finding per line, with a
      count header and a one-line verdict; or a single quiet confirmation line
      when there are no findings, so silence is never ambiguous.
    - {b whether to fail} — warn-first: findings alone never fail the run
      ([exit_code = 0]). A [strict] run escalates {e any} finding (error or
      warning) to a non-zero exit, so a Friday run cannot emit a defective
      report silently once [-validate-strict] is passed. *)

type outcome = {
  report : string;
      (** Text to write to stderr — either the delimited finding block or the
          quiet "OK" line. Always ends in a newline. *)
  exit_code : int;
      (** [0] to continue, [1] when [strict] and there is at least one finding.
      *)
}
[@@deriving sexp, eq, show]

val evaluate :
  strict:bool -> Weinstein_snapshot.Snapshot_validator.finding list -> outcome
(** [evaluate ~strict findings] packages [findings] into the stderr report and
    the process exit code. With no findings the report is the quiet OK line and
    [exit_code] is [0] regardless of [strict]. With findings the report is the
    delimited block; [exit_code] is [1] iff [strict] (warn-first otherwise). *)
