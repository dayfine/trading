(** Cross-version pick diff — pure function comparing two {!Weekly_snapshot.t}
    values produced by different system versions on the {b same} date.

    Catches silent screener drift across system revisions: when [v1] and [v2]
    differ in their long-candidate set, scores, ranks, or macro regime, the diff
    surfaces exactly what changed.

    {1 Model}

    The diff considers [long_candidates] only — that is the canonical pick list.
    Held positions, sectors, and short candidates are out of scope for M6.3.

    For overlapping symbols (in both [v1] and [v2]):

    - {b score_changes} reports [v2_score - v1_score] when nonzero.
    - {b rank_changes} reports [v2_rank - v1_rank] when nonzero. Rank is 1-based
      positional index in [long_candidates] (which is already score-descending
      per the screener contract).

    For non-overlapping symbols:

    - {b added_in_v2} lists symbols present in [v2] but not [v1].
    - {b removed_in_v2} lists symbols present in [v1] but not [v2].

    For the macro regime:

    - {b macro_change} is [Some {v1_regime; v2_regime}] iff the regime label
      differs; [None] if it matches. Macro score deltas are not reported by this
      module — the regime label is the gate-relevant signal.

    {1 Determinism}

    Pure function. Same inputs → same outputs. No I/O, no clock, no global
    state. Suitable for fixture-pinned tests.

    {1 Date safety}

    [diff] requires [v1.date = v2.date]. Comparing snapshots from different
    dates is not meaningful (the universe and macro context differ for reasons
    unrelated to the system version under test) and is rejected with
    [Status.Invalid_argument]. *)

open Core

type score_change = {
  symbol : string;  (** Ticker present in both [v1] and [v2]. *)
  v1_score : float;  (** Score in [v1]. *)
  v2_score : float;  (** Score in [v2]. *)
  delta : float;  (** [v2_score -. v1_score]. *)
}
[@@deriving sexp, eq, show]
(** Score change for a symbol present in both snapshots. *)

type rank_change = {
  symbol : string;  (** Ticker present in both [v1] and [v2]. *)
  v1_rank : int;  (** 1-based rank in [v1.long_candidates]. *)
  v2_rank : int;  (** 1-based rank in [v2.long_candidates]. *)
  delta : int;
      (** [v2_rank - v1_rank]. Negative means the symbol moved up (better rank)
          in [v2]; positive means it moved down. *)
}
[@@deriving sexp, eq, show]
(** Rank change for a symbol present in both snapshots. *)

type macro_change = {
  v1_regime : string;  (** Macro regime label in [v1]. *)
  v2_regime : string;  (** Macro regime label in [v2]. *)
}
[@@deriving sexp, eq, show]
(** Macro regime change. Only reported when [v1.regime <> v2.regime]. *)

type t = {
  date : Date.t;  (** Common snapshot date (equal across [v1] and [v2]). *)
  v1_version : string;  (** [v1.system_version]. *)
  v2_version : string;  (** [v2.system_version]. *)
  added_in_v2 : string list;
      (** Symbols in [v2.long_candidates] but not [v1.long_candidates], sorted
          ascending. *)
  removed_in_v2 : string list;
      (** Symbols in [v1.long_candidates] but not [v2.long_candidates], sorted
          ascending. *)
  score_changes : score_change list;
      (** Score deltas for overlapping symbols, only entries with nonzero delta.
          Sorted by symbol ascending. *)
  rank_changes : rank_change list;
      (** Rank deltas for overlapping symbols, only entries with nonzero delta.
          Sorted by symbol ascending. *)
  macro_change : macro_change option;
      (** [Some _] iff [v1.macro.regime <> v2.macro.regime], else [None]. *)
}
[@@deriving sexp, eq, show]
(** Cross-version pick diff. An empty diff (identical inputs) has empty lists
    and [macro_change = None]. *)

val diff : v1:Weekly_snapshot.t -> v2:Weekly_snapshot.t -> t Status.status_or
(** [diff ~v1 ~v2] computes the cross-version pick diff between [v1] and [v2].

    Returns:
    - [Ok t] on success.
    - [Error Invalid_argument] if [v1.date <> v2.date]. The error message names
      both dates. *)
