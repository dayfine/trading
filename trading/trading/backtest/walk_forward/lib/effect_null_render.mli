(** Presentation for {!Effect_null_report} — the markdown an experiment writeup
    pastes verbatim.

    Split from the computation so the verdict logic can be read and tested
    without the table formatting, and so the table's column set can change
    without touching the statistics. *)

val verdict_label : Effect_null_report.verdict -> string
(** Short display string for a verdict: ["PASS"], ["INSIDE-NOISE"],
    ["not judged (directionless)"], ["NO-BAND"]. *)

val markdown :
  arm_label:string -> null_label:string -> Effect_null_report.report -> string
(** [markdown ~arm_label ~null_label report] renders the Rule-4 table: a header
    naming both sides and the pair count, the report's [notes] (plus, for a
    single-pair report, an explicit statement that no noise claim is possible)
    as blockquotes, then one row per metric carrying the mean paired gap, every
    per-pair gap (so a sign flip is visible in the table itself), the null band,
    the ratio, and the verdict.

    A non-finite cell prints as ["n/a"], never as ["0.0000"] — an unmeasured
    band and a measured band of zero must not read the same. Deterministic: the
    same report renders byte-identically. *)
