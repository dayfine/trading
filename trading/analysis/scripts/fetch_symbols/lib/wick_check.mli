(** Fetch-path diagnostic for suspicious vendor intraday highs and lows (#3028).

    A full vendor refresh can import intraday wicks that no other copy of the
    series carries: the 2026-09 SPY refresh brought in 2009-06-02 low 87.53
    against 94.23, 2009-12-14 low 105.476 against 111.13, and 2002-08-08 low
    80.54 against 87.80. Strategies that read intraday lows (stops) can then
    stop out on a bar that never traded there, while close-based checks stay
    green.

    This module only {b flags}. It never edits, drops or replaces a vendor row;
    the caller saves the fetched bars unchanged and prints the findings.

    {b Reference.} For a fetched bar whose date is also in the copy already on
    disk, the stored bar is the reference ([Stored]). Otherwise the bar is
    checked against itself and the prior fetched bar ([Neighbour]).

    {b Basis.} Raw OHLC is compared with raw OHLC on the same date; adjusted
    fields are never mixed in. When the stored and fetched {e closes} for a date
    also differ by more than the threshold, the whole series was re-based (a
    split or re-adjustment), so the date is reported as a {!basis_change} and
    not checked for wicks.

    {b Known legitimate flags.} The neighbour check also flags a genuine
    intraday flush, such as SPY on 2010-05-06 (the flash crash). That is
    intended: a flag asks for a look, not a correction.

    Pure: no I/O and no credentials in scope, so a report cannot leak the API
    token. *)

open Core

type config = {
  threshold_pct : float;
      (** Relative move that counts as suspicious, e.g. [0.05] = 5 %. *)
}

val default_config : config
(** [threshold_pct = 0.05], the issue's suggested 5 %. *)

type field = High | Low [@@deriving sexp, equal]
type reference = Stored | Neighbour [@@deriving sexp, equal]

type wick = {
  date : Date.t;
  field : field;
  observed : float;  (** The fetched high or low. *)
  reference_value : float;
      (** [Stored]: the stored bar's high or low. [Neighbour]: for a low, the
          lower of the fetched bar's body bottom ([min open close]) and the
          prior fetched close; for a high, the higher of its body top
          ([max open close]) and the prior close. *)
  reference : reference;
  deviation_pct : float;
      (** [|observed - reference_value| / reference_value]. *)
}
[@@deriving sexp, equal]

type basis_change = {
  date : Date.t;
  stored_close : float;
  fetched_close : float;
}
[@@deriving sexp, equal]

type report = { wicks : wick list; basis_changes : basis_change list }
[@@deriving sexp, equal]
(** Both lists are sorted by date. *)

val check :
  ?config:config ->
  stored:Types.Daily_price.t list ->
  Types.Daily_price.t list ->
  report
(** [check ~stored fetched] flags every fetched bar whose high or low looks
    wrong.

    - {b Stored reference} (the date is in [stored]): if the closes differ by
      more than [threshold_pct], the date is a {!basis_change} and is not
      checked further. Otherwise the low is flagged when it sits more than
      [threshold_pct] below the stored low, and the high when it sits more than
      [threshold_pct] above the stored high.
    - {b Neighbour reference} (no stored bar): the low is flagged when it sits
      more than [threshold_pct] below the lower of the bar's own
      [min open close] and the prior fetched close, i.e. below both; the high
      mirrors this against [max open close] and the prior close. A gap day,
      whose open is more than [threshold_pct] from the prior close, is exempt,
      and so is the first fetched bar (no prior close).

    Thresholds are strict: a move of exactly [threshold_pct] is not flagged.
    Bars with a non-positive reference price are skipped. *)

val render : symbol:string -> report -> string list
(** One line per finding, for the fetch log:
    [WICK <symbol> <date> <low|high> observed=<x> reference=<y>
     (<stored|neighbour>) deviation=<p>%] and
    [BASIS <symbol> <date> stored_close=<x> fetched_close=<y>]. Empty for a
    clean report. *)
