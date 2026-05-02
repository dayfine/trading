(** Source-series loaders for the synthetic generator.

    The block-bootstrap algorithm needs a real-world series to resample from.
    For the first PR we expose two loaders:

    - [load_csv]: read a YYYY-MM-DD,o,h,l,c,adj_close,vol formatted CSV (the
      same shape produced by [Csv_storage] elsewhere in the repo).

    - [synthetic_spy_like]: generate a deterministic SPY-shaped synthetic source
      in memory. Useful as a fixture for tests and as a stand-in until real SPY
      data lands via Norgate (M5.3). The series has a mild upward drift,
      GBM-style returns, and constant volume. *)

val load_csv : path:string -> (Types.Daily_price.t list, Status.t) Result.t
(** [load_csv ~path] reads a daily-price CSV. The expected header is
    [date,open,high,low,close,adjusted_close,volume]. Returns
    [Error Status.Invalid_argument] on parse failure or [Error Status.NotFound]
    if the file does not exist. *)

val synthetic_spy_like :
  start_date:Core.Date.t -> n_days:int -> seed:int -> Types.Daily_price.t list
(** [synthetic_spy_like ~start_date ~n_days ~seed] generates a deterministic
    SPY-shaped daily series of [n_days] business days starting from
    [start_date]. Returns are i.i.d. normal with mean ≈ 0.0003/day (≈ 8%
    annualised) and stdev ≈ 0.012/day (≈ 19% annualised) — the rough shape of
    SPY 1993–2025. Volume is constant (10M). The series is not a faithful SPY
    proxy; it is a fixture for the bootstrap algorithm tests until real data
    lands. *)
