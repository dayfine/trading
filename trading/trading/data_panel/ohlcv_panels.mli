(** Six [N x T] Bigarray panels — one per OHLCV+adjusted_close field — stored in
    C-layout Float64. [N] is the universe size from a [Symbol_index]; [T] is the
    number of trading days in the backtest range. Volume is stored as a float
    for layout uniformity (volume × 8 B); precision is sufficient for any
    realistic share count.

    [adjusted_close] is carried as a separate panel because downstream
    indicators (Stage classifier MA, RS line, Macro analyzer) read
    [Daily_price.adjusted_close] rather than the raw close — for stocks with
    dividends or splits the two diverge, and using raw close in indicator math
    silently changes behaviour. Stage 1's spike landed without the adjusted
    panel because the EMA kernel parity test used a synthetic feed where
    adjclose = close; Stage 2 added it as a prerequisite for the bar
    reconstruction surface that the offline snapshot pipeline (Phase B) later
    inherited.

    Layout choice (separate panels per field) is deliberate: cross-section reads
    ("today's close for all symbols") become a single panel column (stride [N]),
    and per-symbol window reads ("last 90 lows for one symbol") become a single
    panel row slice (stride [1]). A combined [N x T x 6] layout would force one
    of the two patterns to be strided.

    All cells are initialized to [Float.nan]. Cells for missing bars (symbol
    didn't trade on a given day) remain NaN — downstream indicator kernels must
    handle NaN explicitly. *)

type t

val create : Symbol_index.t -> n_days:int -> t
(** [create idx ~n_days] allocates five [N x n_days] Float64 panels with all
    cells set to NaN. [n_days] must be non-negative. Allocates ~5 *
    [Symbol_index.n idx] * [n_days] * 8 bytes outside the OCaml heap (Bigarray
    backing buffers do not go through the GC). *)

val n : t -> int
(** [n t] returns the universe size (number of rows). *)

val n_days : t -> int
(** [n_days t] returns the day-axis length (number of columns). *)

val symbol_index : t -> Symbol_index.t
(** [symbol_index t] returns the index used to construct [t]. *)

val open_ :
  t -> (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t
(** Open-price panel. Shape [N x T]. *)

val high :
  t -> (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t
(** High-price panel. Shape [N x T]. *)

val low :
  t -> (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t
(** Low-price panel. Shape [N x T]. *)

val close :
  t -> (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t
(** Close-price panel. Shape [N x T]. *)

val volume :
  t -> (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t
(** Volume panel (float64). Shape [N x T]. *)

val adjusted_close :
  t -> (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t
(** Adjusted-close panel (float64). Shape [N x T]. Carries
    [Daily_price.adjusted_close] for indicators that read the dividend-and-
    split-adjusted close (Stage classifier MA, RS line, Macro). *)

val write_row : t -> symbol_index:int -> day:int -> Types.Daily_price.t -> unit
(** [write_row t ~symbol_index ~day price] writes the OHLCV+adjusted_close
    fields of [price] into row [symbol_index] / column [day] across all six
    panels. Bounds-checked (raises [Invalid_argument] if either index is out of
    range). *)

val load_from_csv :
  Symbol_index.t ->
  data_dir:Fpath.t ->
  start_date:Core.Date.t ->
  n_days:int ->
  (t, Status.t) Result.t
(** [load_from_csv idx ~data_dir ~start_date ~n_days] loads each universe
    symbol's CSV from [data_dir] (using the standard
    [Csv_storage.symbol_data_dir] layout) and writes its OHLCV bars into the
    panels.

    Bars are aligned by trading-day position relative to the symbol's first
    available bar at-or-after [start_date]. This was the simplest alignment the
    Stage 0 spike needed; symbols with different start dates will misalign.
    Stage 1+ callers should prefer {!load_from_csv_calendar} which aligns rows
    by date.

    Missing symbols (file not found) are tolerated: their rows stay NaN and a
    non-fatal note is silently skipped (the spike doesn't need to surface
    these). Other errors (parse failures, etc.) are returned. *)

val load_from_csv_calendar :
  Symbol_index.t ->
  data_dir:Fpath.t ->
  calendar:Core.Date.t array ->
  (t, Status.t) Result.t
(** [load_from_csv_calendar idx ~data_dir ~calendar] loads each universe
    symbol's CSV and aligns its bars to the supplied trading calendar.

    [calendar] is the universe's trading-day axis: [calendar.(t)] is the date at
    panel column [t]. [n_days] of the resulting panels equals
    [Array.length calendar].

    Alignment contract: for each bar in a symbol's CSV with date [D], the bar's
    OHLCV fields are written to column [t] iff [calendar.(t) = D]. Bars whose
    date is not in the calendar are ignored. Calendar dates with no matching bar
    leave the corresponding cells as NaN (the symbol either didn't trade that
    day, hadn't IPO'd, or was suspended).

    Missing symbol CSVs are tolerated (row stays all-NaN). Empty calendar is
    allowed (yields zero-column panels). Other errors (parse failures, etc.) are
    returned. *)
