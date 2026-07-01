(** Markdown rendering for the per-screen decision-audit — the faithfulness
    lens.

    Two parts:
    - a {b roll-up header} answering the faithfulness question: across all
      screens, does any captured feature (score / rs_value / volume_ratio /
      weeks_advancing / stage / sector) separate the {b funded} entries from the
      {b cash-rejected near-misses}? If none does, the tie is uninformative and
      selection is faithful.
    - a {b per-screen section} listing each screen's funded entries, its
      near-misses (emphasising [Insufficient_cash] — the binding constraint),
      and the inversion flag.

    Pure: same {!Screen_record.t} list in → same markdown out. *)

type feature_stat = {
  feature : string;  (** Human-readable feature name, e.g. ["rs_value"]. *)
  funded_n : int;  (** Count of funded entries with the feature present. *)
  funded_mean : float option;
      (** Mean of the feature over funded entries, or [None] when
          [funded_n = 0]. *)
  near_miss_n : int;
  near_miss_mean : float option;
}
[@@deriving sexp]
(** Funded-vs-near-miss central-tendency comparison for one numeric captured
    feature. A feature whose funded and near-miss means overlap does not
    separate the two sets — the faithful/expected case. *)

val feature_stats : Screen_record.t list -> feature_stat list
(** Compute the funded-vs-near-miss {!feature_stat} for each numeric captured
    feature (score, rs_value, volume_ratio, weeks_advancing) pooled across all
    screens. [None]-valued features contribute to neither count nor mean. *)

val to_markdown : Screen_record.t list -> string
(** Render the full report: roll-up header (screen/entry/near-miss totals,
    inversion count, the funded-vs-near-miss {!feature_stats} table, and a
    near-miss [skip_reason] breakdown) followed by one section per screen date.
    Emits a graceful "no entry decisions" note when the input is empty. *)

type forward_stat = {
  n : int;  (** Count of candidates with a forward return present. *)
  mean : float option;  (** Mean forward return, or [None] when [n = 0]. *)
  median : float option;  (** Median forward return, or [None] when [n = 0]. *)
}
[@@deriving sexp]
(** Central-tendency summary of forward returns for one group of candidates.
    Both mean and median are reported so the reader sees the distribution shape,
    not just a point estimate (per
    [.claude/rules/mechanism-validation-rigor.md]). [None]-valued forward
    returns contribute to neither [n] nor the statistics. *)

val forward_stat : Counterfactual.candidate_forward list -> forward_stat
(** [forward_stat cs] pools the [forward_return_pct] over [cs], dropping
    [None]s, and returns its count / mean / median. *)

val counterfactual_to_markdown : Counterfactual.candidate_forward list -> string
(** Render the Phase-2 forward-return counterfactual section: the honest "usable
    signal left on the table" test.

    Emits the headline {b funded-vs-near-miss} forward-return mean, median, and
    n (overlapping distributions = no exploitable signal = faithful), then the
    near-miss group broken out by [skip_reason] (emphasising
    [Insufficient_cash], the binding constraint). Labels the section as the
    outcome test and states that a null (overlapping) result means selection is
    faithful. Emits a graceful "no candidates" note when the input is empty. *)
