(** Shared helpers for e2e tests that load real cached market data.

    Wraps [Historical_source] with test-friendly defaults: uses the standard
    data directory, converts daily bars to weekly, and raises [Failure] with a
    clear message (including the [fetch_symbols.exe] command to fix it) when
    required data is missing.

    {b Data dependencies} — tests using this module require the following
    symbols cached locally via [fetch_symbols.exe]:

    - [AAPL] — daily bars from at least 2020-01-01
    - [GSPC.INDX] — daily bars from at least 2020-01-01

    If data is missing, run:
    {v   fetch_symbols.exe --symbols AAPL,GSPC.INDX --api-key <key> v}

    See also: [ops-data] agent for data inventory management. *)

open Core

val load_daily_bars :
  symbol:string ->
  start_date:Date.t ->
  end_date:Date.t ->
  Types.Daily_price.t list
(** Load cached daily bars for [symbol] in the given date range. Raises
    [Failure] if the data is not available. *)

val load_weekly_bars :
  symbol:string ->
  start_date:Date.t ->
  end_date:Date.t ->
  Types.Daily_price.t list
(** Load cached daily bars and convert to weekly (excluding partial weeks). *)
