(** The split corpus: real split price windows as test fixtures (issue #2973).

    Split-basis defects kept resurfacing one consumer at a time (resistance
    basis, stop split-adjust, snapshot adjusted basis, review-pack trade
    extraction, the entry audit), each caught by a reader rather than a test,
    and each existing test built its own synthetic split. The corpus inverts
    that: a fixed set of {b real} split windows, cut verbatim from the bar
    store, that every basis consumer is run over.

    Layout, under [trading/test_data/split_corpus/]: one directory per entry,
    named [<SYMBOL>-<first ex-date>], holding

    - [bars.csv] — roughly 60 weeks of daily bars around the split(s), the bar
      store's own 7 columns ([date,open,high,low,close,adjusted_close,volume]).
      [close] is RAW (as printed that day); [adjusted_close] is back-adjusted
      for every later split and dividend in the data vintage, so it is
      continuous across the ex-date while [close] jumps by the split ratio.
    - [meta.sexp] — a {!meta}: the splits inside the window, each with its ratio
      and the expected raw-to-adjusted factor either side of the ex-date.

    Rule the suite in [split_corpus/test/] enforces: every consumer of a price
    basis is asserted to use ONE consistent basis, i.e. a relative quantity
    (close/MA, stop distance %, fill-vs-trigger %) is invariant across the
    split. Adding a new basis consumer to the codebase adds a column to that
    suite. *)

open Core

(** Why an entry is in the corpus. *)
type shape =
  | Forward  (** One forward split (4:1, 5:1, 7:1, 10:1). *)
  | Reverse  (** One reverse split (1:8): the raw close jumps UP. *)
  | Two_in_window
      (** Two splits inside one 30-week MA window, so an MA or a lookback scan
          straddles both. *)
[@@deriving sexp]

type split = {
  ex_date : Date.t;  (** First bar priced after the split. *)
  ratio : float;
      (** [new_shares /. old_shares]: [4.0] for a 4:1, [0.125] for a 1:8 — the
          convention of [Types.Split_detector.detect_split] and of
          [Weinstein_stops.Stop_split_adjust.scale]'s [factor]. *)
  factor_before : float;
      (** {!adjustment_factor} of the last bar before [ex_date]. *)
  factor_after : float;
      (** {!adjustment_factor} of the [ex_date] bar. On a clean split day
          [factor_after /. factor_before = ratio]. *)
}
[@@deriving sexp]

type meta = {
  symbol : string;
  shape : shape;
  splits : split list;  (** Chronological; every split inside the window. *)
  note : string;  (** One line: what this entry exercises. *)
}
[@@deriving sexp]

type entry = {
  name : string;  (** The directory name, [<SYMBOL>-<first ex-date>]. *)
  meta : meta;
  bars : Types.Daily_price.t list;  (** Chronological daily bars. *)
}

val adjustment_factor : Types.Daily_price.t -> float
(** [adjusted_close /. close_price] for one bar: the multiplier that maps that
    day's RAW price into the vintage's ADJUSTED basis. Constant between
    corporate actions, drifts slightly on dividends, and jumps by exactly the
    split ratio on an ex-date. *)

val find_root : unit -> string option
(** The corpus directory, found by walking up from the current directory to the
    first ancestor containing [trading/test_data/split_corpus] (at most 10
    levels; [dune runtest] runs from inside [_build/default/...]). [None] when
    no ancestor has it. *)

val entry_names : root:string -> string list
(** The entry directory names under [root], sorted. *)

val load : root:string -> string -> entry
(** [load ~root name] reads one entry. Raises on a missing or malformed
    [bars.csv] / [meta.sexp]: a corpus defect must fail the suite, never be
    skipped. *)

val load_all : root:string -> entry list
(** Every entry under [root], in {!entry_names} order. *)
