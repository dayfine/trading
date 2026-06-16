open Core

type return_row = {
  label : string;
  total_return_pct : float;
  cagr_pct : float;
  note : string;
}
[@@deriving sexp]

type report = {
  start_date : Date.t;
  end_date : Date.t;
  period_instruments : Coverage.coverage list;
  rows : return_row list;
}
[@@deriving sexp]

(* The nine original (Dec-1998) SPDR sector ETFs that anchor the period, plus
   the two index buy-and-hold instruments. Late-inception ETFs (XLRE, XLC) are
   excluded from the period-defining set — see [sector_etf_universe]. *)
let _index_symbols = [ "SPY"; "BRK-B" ]

let _original_sector_etfs =
  [ "XLK"; "XLF"; "XLE"; "XLV"; "XLI"; "XLY"; "XLP"; "XLU"; "XLB" ]

let period_defining_symbols = _index_symbols @ _original_sector_etfs

let sector_etf_universe =
  [
    ("XLK", "Information Technology");
    ("XLF", "Financials");
    ("XLE", "Energy");
    ("XLV", "Health Care");
    ("XLI", "Industrials");
    ("XLY", "Consumer Discretionary");
    ("XLP", "Consumer Staples");
    ("XLU", "Utilities");
    ("XLB", "Materials");
    ("XLRE", "Real Estate");
    ("XLC", "Communication Services");
    (* SPY is the relative-strength benchmark; never traded but must be in the
       universe so its bars are loaded. *)
    ("SPY", "Index");
  ]

let read_coverage ~data_dir symbol =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error err ->
      Error (sprintf "create storage for %s: %s" symbol (Status.show err))
  | Ok storage -> (
      match Csv.Csv_storage.get storage () with
      | Error err -> Error (sprintf "read %s: %s" symbol (Status.show err))
      | Ok [] -> Error (sprintf "no bars for %s" symbol)
      | Ok prices -> (
          let dates =
            List.map prices ~f:(fun (p : Types.Daily_price.t) -> p.date)
          in
          let first_bar = List.min_elt dates ~compare:Date.compare in
          let last_bar = List.max_elt dates ~compare:Date.compare in
          match (first_bar, last_bar) with
          | Some first_bar, Some last_bar ->
              Ok ({ symbol; first_bar; last_bar } : Coverage.coverage)
          | _ -> Error (sprintf "no datable bars for %s" symbol)))

(* Read [symbol]'s adjusted-close series over the full file as chronological
   [(date, adjusted_close)] pairs (dividend-adjusted). *)
let _adjusted_close_series ~data_dir symbol =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error err ->
      failwithf "create storage for %s: %s" symbol (Status.show err) ()
  | Ok storage -> (
      match Csv.Csv_storage.get storage () with
      | Error err -> failwithf "read %s: %s" symbol (Status.show err) ()
      | Ok prices ->
          List.map prices ~f:(fun (p : Types.Daily_price.t) ->
              (p.date, p.adjusted_close)))

let _cagr ~start_date ~end_date ~total_return_pct =
  let test_days = Coverage.inclusive_days ~start_date ~end_date in
  Walk_forward.Walk_forward_runner.cagr_pct ~test_days ~total_return_pct

let _bah_row ~data_dir ~start_date ~end_date ~symbol ~label =
  let close_series = _adjusted_close_series ~data_dir symbol in
  let total_return_pct =
    Coverage.bah_total_return_pct ~start_date ~end_date ~close_series
  in
  {
    label;
    total_return_pct;
    cagr_pct = _cagr ~start_date ~end_date ~total_return_pct;
    note = "buy & hold, dividend-adjusted close";
  }

(* Total return % from a backtest summary: (final - initial) / initial. *)
let _summary_total_return_pct (summary : Backtest.Summary.t) =
  Coverage.total_return_pct ~initial:summary.initial_cash
    ~final:summary.final_portfolio_value

let _weinstein_row ~start_date ~end_date ~strategy_choice ~sector_map_override
    ~label ~note =
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date ~strategy_choice
      ~sector_map_override ()
  in
  let total_return_pct = _summary_total_return_pct result.summary in
  {
    label;
    total_return_pct;
    cagr_pct = _cagr ~start_date ~end_date ~total_return_pct;
    note;
  }

let _sector_map_override entries =
  let tbl = Hashtbl.create (module String) in
  List.iter entries ~f:(fun (symbol, sector) ->
      Hashtbl.set tbl ~key:symbol ~data:sector);
  tbl

let _spy_only_row ~data_dir:_ ~start_date ~end_date =
  _weinstein_row ~start_date ~end_date
    ~strategy_choice:
      (Backtest.Strategy_choice.Spy_only_weinstein
         { symbol = "SPY"; ma_period_weeks = 30; enable_stage4_short = false })
    ~sector_map_override:(_sector_map_override [ ("SPY", "Index") ])
    ~label:"SPY-only Weinstein"
    ~note:"Spy_only_weinstein, 30-week investor MA, long/flat"

let _sector_row ~data_dir:_ ~start_date ~end_date =
  _weinstein_row ~start_date ~end_date
    ~strategy_choice:
      (Backtest.Strategy_choice.Sector_rotation_weinstein
         {
           k = 3;
           ma_period_weeks = 30;
           enable_macro_gate = false;
           use_scenario_universe = false;
           sector_cap = None;
         })
    ~sector_map_override:(_sector_map_override sector_etf_universe)
    ~label:"Sector-ETF Weinstein"
    ~note:"Sector_rotation_weinstein k=3, 30-week investor MA, RS vs SPY"

let run ~data_dir =
  let coverages =
    List.map period_defining_symbols ~f:(fun symbol ->
        match read_coverage ~data_dir symbol with
        | Ok c -> c
        | Error msg -> failwithf "coverage: %s" msg ())
  in
  match Coverage.period_intersection coverages with
  | None -> failwith "empty period intersection across period-defining symbols"
  | Some (start_date, end_date) ->
      let rows =
        [
          _bah_row ~data_dir ~start_date ~end_date ~symbol:"SPY"
            ~label:"SPY buy-and-hold";
          _bah_row ~data_dir ~start_date ~end_date ~symbol:"BRK-B"
            ~label:"BRK-B buy-and-hold";
          _spy_only_row ~data_dir ~start_date ~end_date;
          _sector_row ~data_dir ~start_date ~end_date;
        ]
      in
      { start_date; end_date; period_instruments = coverages; rows }

let _fmt_pct f = if Float.is_nan f then "n/a" else sprintf "%+.1f%%" f

let _render_row r =
  sprintf "| %s | %s | %s | %s |" r.label
    (_fmt_pct r.total_return_pct)
    (_fmt_pct r.cagr_pct) r.note

let render_markdown report =
  let header =
    sprintf
      "## Top-line results\n\n\
       Pinned testing period: **%s -> %s** (common bar coverage of SPY, BRK-B, \
       and the nine original SPDR sector ETFs).\n"
      (Date.to_string report.start_date)
      (Date.to_string report.end_date)
  in
  let table_head =
    "| Strategy | Total return | CAGR (%/yr) | Notes |\n|---|---|---|---|"
  in
  let table_rows =
    List.map report.rows ~f:_render_row |> String.concat ~sep:"\n"
  in
  let footer =
    "\n\
     Regenerate: `dune exec \
     trading/backtest/readme_toplines/bin/readme_toplines.exe -- --readme \
     README.md` (run inside the dev container)."
  in
  String.concat ~sep:"\n" [ header; table_head; table_rows; footer ]
