(** Pure detection of {b ticker-reuse splices} inside a single price series.

    A splice is a day on which the series stops describing one security and
    starts describing another under the same ticker — a vendor feed joining two
    issues, or an exchange recycling a delisted symbol. The tell is a
    day-over-day jump in the {b adjusted} close far outside anything a real
    session produces, with no corporate action behind it.

    {b Why the adjusted series, not the raw one.} Splits move the raw close and
    are back-rolled {e out} of the adjusted close, so a 4:1 split shows as a 4x
    raw jump and a continuous adjusted one. Scanning raw closes would therefore
    flag every split in the warehouse; scanning adjusted closes flags only
    discontinuities the adjustment does not explain.

    {b Relationship to {!Twin_detector}.} That module is the same pipeline's
    other data-integrity pass, and the two are complementary rather than
    overlapping: [Twin_detector] compares {e whole series across symbols} to
    find one company listed twice, this one compares
    {e consecutive bars within one symbol} to find two companies listed once.
    Neither can see the other's defect — the CHS splice below sat in a warehouse
    the twin pass had already cleaned.

    Motivating defect: issue #2646. [CHS] 2004-12-17 -> 2004-12-20 stepped from
    an adjusted close of 4.0693 to 15.8803 (x3.9) with daily volume falling from
    ~5M to ~1M; the raw close moved 11.2875 -> 45.16 (x4.0), so the adjustment
    factor barely changed and no split is detectable. A backtest bought the
    Friday bar and "sold" the Monday one for +$513,550 on a three-day hold — 70%
    of that cell's realised P&L. The committed full scan of the same warehouse
    is [dev/experiments/arc-rerun-2026-09-01/results/splice-scan.csv] (11,028
    candidate bars across 2,908 snapshots; 184 of them tradeable).

    The detector is a pure function of {!Config.t} + a list of {!series} — no
    filesystem, no bar loading. {!Build_scenario_snapshots} owns the loading,
    the wiring, and the sidecar file. *)

open Core

module Config : sig
  type t = {
    enabled : bool;
        (** Master switch. Defaults to [false] so the detector is a no-op (empty
            report, nothing written, no bar touched) unless a build explicitly
            arms it. *)
    min_ratio : float;
        (** Lower bound of the acceptable day-over-day adjusted-close ratio.
            Default [0.4]. *)
    max_ratio : float;
        (** Upper bound of the same ratio. Default [2.5] — the CHS splice was
            3.9x. A ratio {i strictly} outside [[min_ratio, max_ratio]] is a
            candidate; the bounds themselves are clean. *)
    skip_split_days : bool;
        (** When [true] (the default), a candidate day on which
            {!Types.Split_detector.detect_split} recovers a split factor is
            {b not} reported. This only fires on a feed whose adjusted series is
            itself carrying an un-back-rolled (or off-by-one) corporate action:
            a correctly adjusted split leaves the adjusted ratio near 1.0 and
            never becomes a candidate in the first place. Set [false] to report
            every out-of-band day regardless. *)
  }
  [@@deriving sexp, equal]

  val default : t
  (** [enabled = false], [min_ratio = 0.4], [max_ratio = 2.5],
      [skip_split_days = true] — the band the #2646 scan used. *)
end

type series = {
  symbol : string;
  bars : Types.Daily_price.t array;
      (** The symbol's daily bars, {b sorted ascending by date}. Both the raw
          [close_price] and the [adjusted_close] are read: the former only to
          let {!Config.skip_split_days} recognise a split. *)
}

type finding = {
  symbol : string;
  date : Date.t;  (** The bar the series jumps {e onto}. *)
  prev_adj_close : float;
  adj_close : float;
  ratio : float;  (** [adj_close /. prev_adj_close]. *)
  prev_volume : int;
  volume : int;
      (** Volume is carried because a ticker reuse usually changes the traded
          size by an order of magnitude (CHS: ~5M -> ~1M), which is how a
          reviewer tells a reuse from a genuine one-day repricing. *)
}
[@@deriving sexp_of, equal]

type report = {
  config : Config.t;
  findings : finding list;
      (** Every detected splice, sorted by [(symbol, date)]. *)
}
[@@deriving sexp_of]

val detect : Config.t -> series list -> report
(** [detect config series] scans each series' consecutive bar pairs. With
    [config.enabled = false] it returns an empty report without reading a bar.

    A pair is skipped silently — neither clean nor reported — when
    [prev_adj_close] is not positive: a zero or negative adjusted close has no
    meaningful ratio, and is a separate data defect from the one this module
    names. The first bar of a series has no predecessor and is likewise never a
    finding. *)

val to_csv : report -> string
(** [to_csv report] renders the findings as CSV with the header
    [symbol,date,prev_adj_close,adj_close,ratio,prev_volume,volume] — the same
    columns and precision as the committed
    [dev/experiments/arc-rerun-2026-09-01/results/splice-scan.csv], so a build's
    sidecar can be diffed against that scan directly. A report with no findings
    renders as the header alone. Ends with a newline. *)

val summary : report -> string
(** [summary report] is a one-line human summary — the count of findings and the
    distinct symbols they span — for the builder's stderr. The findings
    themselves go to the CSV. *)
