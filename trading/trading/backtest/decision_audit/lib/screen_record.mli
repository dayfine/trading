(** Per-screen decision-audit records — group a backtest's entry decisions by
    the weekly screen (Friday) they were taken on, and pair each screen's
    {b funded} entries against the {b cash-rejected near-misses} that scored at
    the same screen call.

    This is a {b faithfulness} lens, not an outcome grader (see
    [dev/plans/per-screen-decision-audit-2026-06-30.md]): it compares funded vs
    near-miss on the {b captured decision-time features} — score, grade, stage,
    [weeks_advancing], [rs_value], [volume_ratio], sector — to ask whether any
    signal the screener records separates the two sets. If none does, the tie is
    genuinely uninformative and selection is faithful; if one does and we do not
    fund on it, that is a candidate lever.

    Pure: same [audit_record] list in → same records out. *)

open Core

type funded_entry = {
  symbol : string;
  score : int;
  grade : Weinstein_types.grade;
  stage : Weinstein_types.stage;
  weeks_advancing : int option;
      (** [weeks_advancing] when [stage] is [Stage2], else [None]. *)
  rs_value : float option;
  volume_ratio : float option;
  sector_name : string;
}
[@@deriving sexp]
(** A candidate that was actually entered on a given screen date. Projected from
    {!Backtest.Trade_audit.entry_decision}. *)

type near_miss = {
  symbol : string;
  score : int;
  grade : Weinstein_types.grade;
  reason_skipped : Backtest.Trade_audit.skip_reason;
  stage : Weinstein_types.stage;
  weeks_advancing : int option;
  rs_value : float option;
  volume_ratio : float option;
  sector_name : string;
}
[@@deriving sexp]
(** A candidate that scored at the same screen call but was not entered.
    Projected from {!Backtest.Trade_audit.alternative_candidate}. *)

type summary = {
  n_funded : int;
  n_near_miss : int;
  min_funded_score : int option;
      (** Lowest score among the funded entries, or [None] when none were
          funded. *)
  max_nearmiss_score : int option;
      (** Highest score among the near-misses, or [None] when there were none.
      *)
  inversion : bool;
      (** [true] when some near-miss scored strictly higher than the lowest
          funded entry — i.e. a higher-scored name was skipped for a
          lower-scored one. Usually [false] (funding walks score-desc); an
          inversion flags a sizing / sector-cap quirk worth eyeballing. *)
}
[@@deriving sexp]
(** Per-screen roll-up counts + the inversion flag. *)

type t = {
  screen_date : Date.t;  (** The Friday the screen ran (the entry date). *)
  funded : funded_entry list;
      (** Entries taken this screen, in screener order (score-desc). *)
  near_misses : near_miss list;
      (** Union of [alternatives_considered] across this screen's entries,
          deduplicated by symbol (first occurrence wins), sorted score-desc. *)
  summary : summary;
}
[@@deriving sexp]
(** One record per weekly screen date. *)

val of_audit_records : Backtest.Trade_audit.audit_record list -> t list
(** Group the entry side of [audit_records] by [entry_date] into one {!t} per
    screen, sorted by [screen_date] ascending.

    For each screen: [funded] = the entries taken that date; [near_misses] = the
    union of every entry's [alternatives_considered], deduplicated by symbol
    (keeping the first, i.e. highest-scored, occurrence) and sorted score-desc;
    [summary] computes the counts + [inversion] flag. Exit records are ignored —
    this lens is entry-side only. *)
