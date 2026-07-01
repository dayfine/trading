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
