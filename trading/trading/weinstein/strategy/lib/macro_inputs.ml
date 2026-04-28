open Core

let spdr_sector_etfs =
  [
    ("XLK", "Information Technology");
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

(* AD bars are loaded once at strategy [make] time from disk (via
   [Ad_bars.load], which composes Unicorn + Synthetic). The synthetic CSV
   typically extends to the most recent [compute_synthetic_adl.exe] run,
   often well past the simulator's current tick. Without filtering, the
   panel-callbacks [get_cumulative_ad ~week_offset:0] returns the
   cumulative as of the {b last loaded} A-D bar (e.g., April 2026) while
   [get_index_close ~week_offset:0] correctly returns the {b current
   simulator tick}'s close (e.g., October 2022) — the macro indicator
   readings then disagree across an ~3-year date misalignment, breaking
   the [trend = Bearish] composite during real bear-market periods. The
   filter trims [ad_bars] to dates [<= current_date] before they reach
   {!Panel_callbacks.macro_callbacks_of_weekly_views}. *)

(** Production-tail fast path: when [ad_bars] is empty, or its last bar's date
    already lies on or before [as_of], the input list satisfies the contract
    verbatim. Returns [None] when a [List.filter] pass is required. *)
let _passthrough_if_in_range ~(ad_bars : Macro.ad_bar list) ~(as_of : Date.t) :
    Macro.ad_bar list option =
  match List.last ad_bars with
  | None -> Some []
  | Some last_bar when Date.( <= ) last_bar.Macro.date as_of -> Some ad_bars
  | _ -> None

let ad_bars_at_or_before ~(ad_bars : Macro.ad_bar list) ~(as_of : Date.t) :
    Macro.ad_bar list =
  match _passthrough_if_in_range ~ad_bars ~as_of with
  | Some bars -> bars
  | None ->
      List.filter ad_bars ~f:(fun (b : Macro.ad_bar) ->
          Date.( <= ) b.date as_of)

(* Stage 4 PR-A: build_global_index_views returns weekly views (panel-shaped).
   Each entry is consumed by the macro callback bundle constructor; no
   [Daily_price.t list] is ever materialised. The strategy's hot path uses
   this; bar-list callers can use the legacy [build_global_index_bars]. *)
let build_global_index_views ~lookback_bars ~global_index_symbols ~bar_reader
    ~as_of =
  List.filter_map global_index_symbols ~f:(fun (symbol, label) ->
      let view =
        Bar_reader.weekly_view_for bar_reader ~symbol ~n:lookback_bars ~as_of
      in
      if view.n = 0 then None else Some (label, view))

let build_global_index_bars ~lookback_bars ~global_index_symbols ~bar_reader
    ~as_of =
  List.filter_map global_index_symbols ~f:(fun (symbol, label) ->
      let bars =
        Bar_reader.weekly_bars_for bar_reader ~symbol ~n:lookback_bars ~as_of
      in
      if List.is_empty bars then None else Some (label, bars))

(** Analyze one sector ETF via panel-shaped callbacks and return its
    {!Screener.sector_context}. Returns [None] when not enough bars are
    accumulated yet for stage classification or when the benchmark index view is
    empty.

    Stage 4 PR-D: an optional [ma_cache] threads through to
    {!Panel_callbacks.sector_callbacks_of_weekly_views} so sector ETFs hit the
    per-symbol cached MA values rather than recomputing per Friday tick. *)
let _sector_context_from_views ?ma_cache ~(stage_config : Stage.config)
    ~lookback_bars ~bar_reader ~as_of ~sector_prior_stages
    ~(index_view : Data_panel.Bar_panels.weekly_view) ~etf_symbol ~sector_name
    () : (string * Screener.sector_context) option =
  let sector_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:etf_symbol ~n:lookback_bars
      ~as_of
  in
  if sector_view.n < stage_config.ma_period then None
  else if index_view.n = 0 then None
  else
    let prior_stage = Hashtbl.find sector_prior_stages etf_symbol in
    let callbacks =
      Panel_callbacks.sector_callbacks_of_weekly_views ?ma_cache
        ~sector_symbol:etf_symbol ~config:Sector.default_config
        ~sector:sector_view ~benchmark:index_view ()
    in
    let result =
      Sector.analyze_with_callbacks ~config:Sector.default_config ~sector_name
        ~callbacks ~constituent_analyses:[] ~prior_stage
    in
    Hashtbl.set sector_prior_stages ~key:etf_symbol ~data:result.stage.stage;
    Some (etf_symbol, Sector.sector_context_of result)

let build_sector_map ?ma_cache ~stage_config ~lookback_bars ~sector_etfs
    ~bar_reader ~as_of ~sector_prior_stages ~index_view ~ticker_sectors () =
  (* Step 1: Analyze each sector ETF to get sector_name -> sector_context. *)
  let sector_ctx_by_name = Hashtbl.create (module String) in
  List.iter sector_etfs ~f:(fun (etf_symbol, sector_name) ->
      match
        _sector_context_from_views ?ma_cache ~stage_config ~lookback_bars
          ~bar_reader ~as_of ~sector_prior_stages ~index_view ~etf_symbol
          ~sector_name ()
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
