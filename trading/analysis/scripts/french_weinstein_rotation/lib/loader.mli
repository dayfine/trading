(** Loader for the pinned Kenneth French 49-Industry daily fixture.

    The fixture under
    [trading/analysis/data/sources/kenneth_french/fixture/french-49ind-2026-05-20.csv.gz]
    is a *derived* CSV (not the raw Dartmouth two-block layout): rows are
    [block,date,ind1,ind2,...,ind49] where [block] is either ["VW"] (value-
    weighted) or ["EW"] (equal-weighted), [date] is [YYYY-MM-DD], and each
    industry cell is a percent return (e.g. [0.46] = 0.46%) or empty (missing
    data, common in the early years for industries that did not exist yet).

    Decompression shells out to the system [gunzip] binary to avoid pulling in
    [camlzip] as a new opam dep. *)

open Core

(** Which return block to extract. The Kenneth French source emits both; callers
    typically want VW for portfolio backtests and EW only for academic
    comparison. *)
type block = VW | EW [@@deriving show, eq]

type daily_row = {
  date : Date.t;
      (** Trading-day anchor. The fixture is ascending and skips non-trading
          days. *)
  industry_returns : float option array;
      (** Parallel-aligned with the {!parsed_series.industries} list. Each cell
          is the percent return for that industry on that day (e.g. [0.46] means
          0.46%, NOT 0.0046). [None] for missing-data cells. *)
}
[@@deriving show, eq]

type parsed_series = {
  block : block;
  industries : string list;
      (** Industry-name order, taken from the fixture header. Length is 49 for
          the canonical fixture. *)
  rows : daily_row array;  (** Trading days in ascending order. *)
}
[@@deriving show, eq]

val load_block : csv_gz_path:string -> block:block -> parsed_series
(** [load_block ~csv_gz_path ~block] decompresses the gzipped fixture, parses
    the header, and returns only rows whose [block] column matches [block].
    Raises [Failure] on any structural failure (missing header, unparseable
    date, wrong column count). *)
