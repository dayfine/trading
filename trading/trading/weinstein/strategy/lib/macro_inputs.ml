open Core

let spdr_sector_etfs =
  [
    ("XLK", "Technology");
    ("XLF", "Financials");
    ("XLE", "Energy");
    ("XLV", "Health Care");
    ("XLI", "Industrials");
    ("XLP", "Consumer Staples");
    ("XLY", "Consumer Discretionary");
    ("XLU", "Utilities");
    ("XLB", "Materials");
    ("XLRE", "Real Estate");
    ("XLC", "Communication Services");
  ]

(* ISF.LSE (iShares Core FTSE UCITS ETF) proxies the UK large-cap index
   because EODHD does not carry FTSE.INDX or UKX.INDX. Physical-replication
   tracker with ~bps tracking error — functionally indistinguishable from the
   index at weekly cadence. See dev/ops/2026-04-10-data-fetch.md. *)
let default_global_indices =
  [ ("GDAXI.INDX", "DAX"); ("N225.INDX", "Nikkei"); ("ISF.LSE", "FTSE") ]

let build_global_index_bars ~lookback_bars ~global_index_symbols ~bar_history =
  List.filter_map global_index_symbols ~f:(fun (symbol, label) ->
      let bars =
        Bar_history.weekly_bars_for bar_history ~symbol ~n:lookback_bars
      in
      if List.is_empty bars then None else Some (label, bars))

(** Analyze one sector ETF and return its {!Screener.sector_context}, keyed by
    the ETF symbol. Returns [None] when not enough bars are accumulated yet for
    stage classification or when the benchmark index has no bars. *)
let _sector_context_for ~(stage_config : Stage.config) ~lookback_bars
    ~bar_history ~sector_prior_stages ~index_bars ~etf_symbol ~sector_name :
    (string * Screener.sector_context) option =
  let sector_bars =
    Bar_history.weekly_bars_for bar_history ~symbol:etf_symbol ~n:lookback_bars
  in
  if List.length sector_bars < stage_config.ma_period then None
  else if List.is_empty index_bars then None
  else
    let prior_stage = Hashtbl.find sector_prior_stages etf_symbol in
    let result =
      Sector.analyze ~config:Sector.default_config ~sector_name ~sector_bars
        ~benchmark_bars:index_bars ~constituent_analyses:[] ~prior_stage
    in
    Hashtbl.set sector_prior_stages ~key:etf_symbol ~data:result.stage.stage;
    Some (etf_symbol, Sector.sector_context_of result)

let build_sector_map ~stage_config ~lookback_bars ~sector_etfs ~bar_history
    ~sector_prior_stages ~index_bars ~ticker_sectors =
  (* Step 1: Analyze each sector ETF to get sector_name -> sector_context. *)
  let sector_ctx_by_name = Hashtbl.create (module String) in
  List.iter sector_etfs ~f:(fun (etf_symbol, sector_name) ->
      match
        _sector_context_for ~stage_config ~lookback_bars ~bar_history
          ~sector_prior_stages ~index_bars ~etf_symbol ~sector_name
      with
      | None -> ()
      | Some (_key, ctx) ->
          Hashtbl.set sector_ctx_by_name ~key:sector_name ~data:ctx);
  (* Step 2: Expand to ticker-level map using ticker_sectors. *)
  let map = Hashtbl.create (module String) in
  Hashtbl.iteri ticker_sectors ~f:(fun ~key:ticker ~data:sector_name ->
      match Hashtbl.find sector_ctx_by_name sector_name with
      | Some ctx -> Hashtbl.set map ~key:ticker ~data:ctx
      | None -> ());
  map
