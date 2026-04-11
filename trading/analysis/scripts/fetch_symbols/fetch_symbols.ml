(** Fetch price data for named symbols from EODHD and cache them locally.

    Downloads historical daily OHLCV bars for each requested symbol and writes
    them to [data_dir/<first>/<last>/<symbol>/data.csv], alongside a
    [data.metadata.sexp] file recording the covered date range.

    Motivation: golden-scenario tests and backtests require local price data.
    This script is how that data gets into the cache. Run it once per symbol (or
    to refresh stale data), then run {!build_inventory} to update the manifest.

    Authentication: pass the EODHD API key via [--api-key]. The key is not read
    from the environment — use the flag directly or wrap the call in a shell
    script that reads from a secrets file.

    When to run:
    - Before writing a new golden-scenario test, to ensure the required symbol
      and date range are cached.
    - When adding new symbols to the trading universe.
    - Not on a schedule — data is cached indefinitely and re-fetching is only
      needed when extending the date range.

    Typical usage:
    {v
      fetch_symbols.exe --symbols AAPL,MSFT,SPY --api-key <key>
      fetch_symbols.exe --symbols GSPC.INDX --api-key <key> -data-dir /my/data
    v} *)

open Async

let _summary =
  "Fetch symbols from EODHD and cache them locally. If --symbols is omitted, \
   fetches all symbols from universe.sexp."

let _symbols_doc =
  "SYM1,SYM2,... Comma-separated list of symbols (default: all from \
   universe.sexp)"

let _data_dir_default () = Data_path.default_data_dir () |> Fpath.to_string

let command =
  Command.async ~summary:_summary
    (let%map_open.Command symbols_flag =
       flag "symbols" (optional string) ~doc:_symbols_doc
     and data_dir_str =
       flag "data-dir"
         (optional_with_default (_data_dir_default ()) string)
         ~doc:"PATH Directory to write cached data"
     and api_key_flag =
       flag "api-key" (optional string) ~doc:"KEY EODHD API key"
     in
     Fetch_symbols_lib.run ~symbols_flag ~data_dir_str ~api_key_flag)

let () = Command_unix.run command
