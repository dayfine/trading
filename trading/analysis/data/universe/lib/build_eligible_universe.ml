open Core
module CI = Composition_inputs
module BR = Composition_bar_reader
module BFI = Build_from_individuals
module CP = Composition_policy
module CPT = Composition_policy_types

(* Defaults documented in [build_eligible_universe.mli]. *)
let _default_trailing_window_days = 60
let _default_min_window_bars = 30

(* No-op staleness tolerance: 0 trading days ⇒ a symbol is active only if its
   last bar is on / after [date] (exactly the pre-tolerance behaviour). *)
let _default_max_staleness_trading_days = 0

(* Tickers carried in a [staleness_report.sample] (a logging aid, not a gate). *)
let staleness_sample_size = 10

(* Live-universe spec gate values (the spec, not the no-op record default). *)
let _spec_min_price = 5.0
let _spec_min_avg_dollar_volume = 1_000_000.0

(* ------------------------------------------------------------------ *)
(* Config                                                              *)
(* ------------------------------------------------------------------ *)

type config = {
  min_price : float;
  min_avg_dollar_volume : float;
  max_staleness_trading_days : int;
  trailing_window_days : int;
  min_window_bars : int;
  reit_policy : CPT.reit_policy;
  exclude_preferred : bool;
  bars_root : string;
  symbol_types_path : string;
  sectors_csv_path : string;
  inventory_path : string;
}
[@@deriving sexp]

type staleness_report = { excluded_count : int; sample : string list }
[@@deriving sexp, show, eq]

let default_config ~bars_root ~symbol_types_path ~sectors_csv_path
    ~inventory_path =
  {
    min_price = 0.0;
    min_avg_dollar_volume = 0.0;
    max_staleness_trading_days = _default_max_staleness_trading_days;
    trailing_window_days = _default_trailing_window_days;
    min_window_bars = _default_min_window_bars;
    reit_policy = CPT.Include;
    exclude_preferred = false;
    bars_root;
    symbol_types_path;
    sectors_csv_path;
    inventory_path;
  }

let spec_config ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path
    =
  {
    (default_config ~bars_root ~symbol_types_path ~sectors_csv_path
       ~inventory_path)
    with
    min_price = _spec_min_price;
    min_avg_dollar_volume = _spec_min_avg_dollar_volume;
    reit_policy = CPT.Exclude;
    exclude_preferred = true;
  }

(* ------------------------------------------------------------------ *)
(* Active + equity-like filtering                                      *)
(* ------------------------------------------------------------------ *)

(* Whether [d] is a weekday (Mon–Fri). Holidays are not modelled, so a
   "trading day" here is a weekday — see the [.mli] freshness-gate docs. *)
let _is_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

(* Count weekdays strictly after [end_date] up to and including [date] — i.e.
   how many trading days the last bar ([end_date]) lags [date]. [0] when
   [end_date >= date] (the symbol is fresh, or ahead). *)
let _trading_days_late ~end_date ~date =
  if Date.( >= ) end_date date then 0
  else
    Date.dates_between ~min:(Date.add_days end_date 1) ~max:date
    |> List.count ~f:_is_weekday

(* A symbol clears the trailing-history start gate (enough lead-in to score). *)
let _has_enough_history ~required_start (entry : CI.inventory_entry) =
  Date.( <= ) entry.data_start_date required_start

(* The last bar is fresh enough: on / after [date], or stale by at most
   [max_staleness_trading_days] trading days. *)
let _is_fresh_enough ~date ~max_staleness_trading_days
    (entry : CI.inventory_entry) =
  _trading_days_late ~end_date:entry.data_end_date ~date
  <= max_staleness_trading_days

let _is_active ~date ~required_start ~max_staleness_trading_days
    (entry : CI.inventory_entry) =
  _has_enough_history ~required_start entry
  && _is_fresh_enough ~date ~max_staleness_trading_days entry

let _required_start ~date ~config =
  Date.add_days date (-config.trailing_window_days)

let _active_symbols ~date ~config (inventory : CI.inventory) =
  let required_start = _required_start ~date ~config in
  List.filter_map inventory.symbols ~f:(fun e ->
      if
        _is_active ~date ~required_start
          ~max_staleness_trading_days:config.max_staleness_trading_days e
      then Some e.symbol
      else None)

let _is_equity_like ~equity_like_lookup symbol =
  match Hashtbl.find equity_like_lookup symbol with
  | Some true -> true
  | _ -> false

(* Symbols dropped {b specifically} for staleness: they clear the history start
   gate and are equity-like, but their last bar is too old for the freshness
   gate ([data_end_date < date] and beyond [max_staleness_trading_days]). The
   observability counterpart to the active filter — a non-zero count means a
   partial data refresh shrank the universe. Inventory order is preserved so the
   report is deterministic. *)
let _staleness_excluded ~date ~config ~equity_like_lookup
    (inventory : CI.inventory) =
  let required_start = _required_start ~date ~config in
  List.filter_map inventory.symbols ~f:(fun (e : CI.inventory_entry) ->
      if
        _has_enough_history ~required_start e
        && (not
              (_is_fresh_enough ~date
                 ~max_staleness_trading_days:config.max_staleness_trading_days e))
        && _is_equity_like ~equity_like_lookup e.symbol
      then Some e.symbol
      else None)

let _staleness_report ~date ~config ~equity_like_lookup inventory =
  let excluded =
    _staleness_excluded ~date ~config ~equity_like_lookup inventory
  in
  {
    excluded_count = List.length excluded;
    sample = List.take excluded staleness_sample_size;
  }

(* ------------------------------------------------------------------ *)
(* Per-symbol scoring + eligibility gates                              *)
(* ------------------------------------------------------------------ *)

(* A symbol that passes the price / dollar-volume / min-bars gates, carrying
   the score needed downstream for the composition-policy ADR floor and the
   snapshot's [avg_dollar_volume] field. *)
type _eligible = { symbol : string; avg_dollar_volume : float }

let _passes_price_gate ~config ~date bars =
  match BFI.latest_close_for_bars ~date bars with
  | None -> false
  | Some close -> Float.( >= ) close config.min_price

(* The dollar-volume score, gated by [min_avg_dollar_volume] and the
   min-window-bars requirement (the latter enforced inside
   [avg_dollar_volume_for_bars]). [None] when either gate fails. *)
let _passing_dollar_volume ~config ~date bars =
  match
    BFI.avg_dollar_volume_for_bars ~date
      ~trailing_window_days:config.trailing_window_days
      ~min_window_bars:config.min_window_bars bars
  with
  | Some score when Float.( >= ) score config.min_avg_dollar_volume ->
      Some score
  | _ -> None

let _score_eligible_bars ~config ~date ~symbol bars : _eligible option =
  if not (_passes_price_gate ~config ~date bars) then None
  else
    Option.map (_passing_dollar_volume ~config ~date bars) ~f:(fun score ->
        { symbol; avg_dollar_volume = score })

let _score_if_eligible ~date ~config symbol : _eligible option =
  match BR.read_bars ~bars_root:config.bars_root symbol with
  | None -> None
  | Some bars -> _score_eligible_bars ~config ~date ~symbol bars

let _score_all ~date ~config symbols : _eligible list =
  List.filter_map symbols ~f:(_score_if_eligible ~date ~config)

(* ------------------------------------------------------------------ *)
(* Composition policy (REIT / preferred / dual-class)                  *)
(* ------------------------------------------------------------------ *)

let _asset_type_for ~asset_type_lookup symbol =
  (* Symbols absent from the lookup default to Common_stock (per
     [Composition_inputs.load_asset_type_lookup] semantics). *)
  match Hashtbl.find asset_type_lookup symbol with
  | Some t -> t
  | None -> Eodhd.Asset_type.Common_stock

let _sector_for ~sector_lookup symbol =
  match Hashtbl.find sector_lookup symbol with Some s -> s | None -> ""

(* Build composition-policy candidates in descending dollar-volume order so the
   dual-class dedup keeps the more-liquid class and [rank] is meaningful. *)
let _to_candidates ~asset_type_lookup ~sector_lookup eligible :
    CPT.candidate list =
  let sorted =
    List.sort eligible ~compare:(fun a b ->
        Float.compare b.avg_dollar_volume a.avg_dollar_volume)
  in
  List.mapi sorted ~f:(fun rank e ->
      {
        CPT.symbol = e.symbol;
        asset_type = _asset_type_for ~asset_type_lookup e.symbol;
        sector = _sector_for ~sector_lookup e.symbol;
        avg_dollar_volume = e.avg_dollar_volume;
        rank;
      })

let _policy_config ~config : CPT.config =
  {
    CPT.default_config with
    reit_policy = config.reit_policy;
    exclude_preferred = config.exclude_preferred;
  }

(* ------------------------------------------------------------------ *)
(* Snapshot assembly                                                   *)
(* ------------------------------------------------------------------ *)

let _make_entry ~uniform_weight (c : CPT.candidate) : Snapshot.entry =
  {
    symbol = c.symbol;
    weight = uniform_weight;
    sector = c.sector;
    synthetic = false;
    avg_dollar_volume = Some c.avg_dollar_volume;
  }

let _empty_universe_error ~date =
  let message =
    Printf.sprintf
      "build_eligible_universe: no symbol survived the eligibility gates at %s"
      (Date.to_string date)
  in
  Error { Status.code = Status.Failed_precondition; message }

let _make_snapshot ~date ~kept : Snapshot.t Status.status_or =
  let k = List.length kept in
  if k = 0 then _empty_universe_error ~date
  else
    let uniform_weight = 1.0 /. Float.of_int k in
    let entries = List.map kept ~f:(_make_entry ~uniform_weight) in
    Ok
      {
        Snapshot.date;
        method_ = Composition_from_individuals;
        size = k;
        entries;
        aggregate_period_return = 0.0;
      }

(* ------------------------------------------------------------------ *)
(* Build pipeline                                                      *)
(* ------------------------------------------------------------------ *)

let _build_validated ~date ~config ~inventory ~equity_like_lookup
    ~asset_type_lookup ~sector_lookup =
  let active = _active_symbols ~date ~config inventory in
  let equity_like =
    List.filter active ~f:(_is_equity_like ~equity_like_lookup)
  in
  let eligible = _score_all ~date ~config equity_like in
  let candidates = _to_candidates ~asset_type_lookup ~sector_lookup eligible in
  let { CPT.kept; reports = _ } =
    CP.apply ~config:(_policy_config ~config) candidates
  in
  _make_snapshot ~date ~kept

let build_with_staleness_report ~date ~config =
  let open Result.Let_syntax in
  let%bind inventory = CI.load_inventory config.inventory_path in
  let%bind equity_like_lookup =
    CI.load_equity_like_lookup config.symbol_types_path
  in
  let%bind asset_type_lookup =
    CI.load_asset_type_lookup config.symbol_types_path
  in
  let%bind sector_lookup = CI.load_sectors config.sectors_csv_path in
  let%bind snapshot =
    _build_validated ~date ~config ~inventory ~equity_like_lookup
      ~asset_type_lookup ~sector_lookup
  in
  let report = _staleness_report ~date ~config ~equity_like_lookup inventory in
  Ok (snapshot, report)

let build ~date ~config =
  Result.map (build_with_staleness_report ~date ~config) ~f:fst
