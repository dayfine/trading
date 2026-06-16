(** Compute the four README top-line numbers over one pinned full-history
    period, and render them as a Markdown block.

    The four numbers (all over the {e same} pinned window):
    + the pinned testing period — the {!Coverage.period_intersection} of the
      period-defining instruments' on-disk bar coverage;
    + SPY and BRK-B buy-and-hold total return (dividend-adjusted close);
    + SPY-only Weinstein stage-timing total return
      ({!Backtest.Strategy_choice.Spy_only_weinstein});
    + sector-ETF-only Weinstein total return
      ({!Backtest.Strategy_choice.Sector_rotation_weinstein}, k=3, 30-week
      investor MA, over the SPDR sector-ETF universe).

    The period is derived from actual coverage, never hardcoded; the two
    backtest numbers come from {!Backtest.Runner.run_backtest} (CSV mode), so
    they regenerate as the data store and strategy evolve. *)

open Core

type return_row = {
  label : string;  (** Human-readable row label, e.g. ["SPY buy-and-hold"]. *)
  total_return_pct : float;
  cagr_pct : float;
  note : string;
      (** Provenance note rendered in the table, e.g. dividend-adjusted vs
          price-only, or the strategy variant. *)
}
[@@deriving sexp]
(** A symbol's return over the pinned window: total return % and the annualised
    CAGR %/yr over the same inclusive calendar span. [Float.nan] when the figure
    could not be priced. *)

type report = {
  start_date : Date.t;  (** First trading day of the pinned period. *)
  end_date : Date.t;  (** Last trading day of the pinned period. *)
  period_instruments : Coverage.coverage list;
      (** The instruments whose coverage intersection pinned the period, with
          their first/last bar — rendered so the period is auditable. *)
  rows : return_row list;  (** The four return rows. *)
}
[@@deriving sexp]

val period_defining_symbols : string list
(** The instruments whose bar coverage pins the period: SPY, BRK-B, and the nine
    original (Dec-1998) SPDR sector ETFs. The late-inception ETFs (XLRE 2015,
    XLC 2018) are deliberately excluded here — they would collapse the window —
    but still participate in the sector backtest universe, joining mid-run on
    their first bar (the runner skips a symbol before its first bar via
    [Daily_price.active_through]). *)

val sector_etf_universe : (string * string) list
(** The SPDR sector-ETF universe (symbol, GICS sector) the sector-rotation
    Weinstein run trades over, plus the SPY relative-strength benchmark. All 11
    sector ETFs are included; the late-inception ones contribute only once their
    bars begin. *)

val read_coverage :
  data_dir:Fpath.t -> string -> (Coverage.coverage, string) Result.t
(** [read_coverage ~data_dir symbol] reads [symbol]'s first/last on-disk bar
    dates from the CSV store under [data_dir]. [Error msg] when the symbol is
    absent or has no bars. *)

val run : data_dir:Fpath.t -> report
(** [run ~data_dir] reads coverage for {!period_defining_symbols}, computes the
    pinned period, runs the buy-and-hold and Weinstein figures over it, and
    assembles the {!report}.

    @raise Failure
      if coverage cannot be read for a period-defining symbol, or the
      intersection is empty (these are environment errors the bin surfaces
      rather than silently fabricating a period). *)

val render_markdown : report -> string
(** [render_markdown report] is the inner body of the README block (without the
    {!Readme_block} markers): a header line naming the pinned period and a table
    of the four rows with total-return % and CAGR %/yr columns. *)
