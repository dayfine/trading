open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Bar_panels = Data_panel.Bar_panels

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

(** Build [n] consecutive weekday bars starting at [start_date] with a linearly
    rising price. Used to feed Stage.classify enough data for a Stage 2
    classification. *)
let make_rising_bars ~start_date ~n ~start_price =
  let rec weekdays d acc count =
    if count = 0 then List.rev acc
    else
      let next = Date.add_days d 1 in
      match Date.day_of_week d with
      | Day_of_week.Sat | Day_of_week.Sun -> weekdays next acc count
      | _ -> weekdays next (d :: acc) (count - 1)
  in
  let dates = weekdays start_date [] n in
  List.mapi dates ~f:(fun i date ->
      let price = start_price +. (Float.of_int i *. 0.5) in
      {
        Types.Daily_price.date;
        open_price = price;
        high_price = price *. 1.01;
        low_price = price *. 0.99;
        close_price = price;
        adjusted_close = price;
        volume = 1_000_000;
      })

(** Build a snapshot-backed [Bar_reader.t] over a synthetic universe.
    [symbols_with_bars] is [(symbol, bars)] pairs; each bar's date must be a
    weekday. Symbols absent from the list (e.g., ones referenced by a
    sector_etfs config but with no synthetic series) read as empty — the same
    contract the deleted [Bar_history.create ()] satisfied. *)
let make_bar_reader ~symbols_with_bars =
  match symbols_with_bars with
  | [] -> Bar_reader.empty ()
  | _ -> Bar_reader.of_in_memory_bars symbols_with_bars

(* ------------------------------------------------------------------ *)
(* Canonical constants                                                  *)
(* ------------------------------------------------------------------ *)

let test_spdr_sector_etfs_is_canonical_11_sector_list _ =
  assert_that Macro_inputs.spdr_sector_etfs
    (equal_to
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
       ])

(* Every sector label in spdr_sector_etfs must parse to a valid gics_sector.
   This catches mismatches like "Technology" vs "Information Technology". *)
let test_spdr_sector_etfs_names_are_valid_gics _ =
  let invalid =
    List.filter Macro_inputs.spdr_sector_etfs ~f:(fun (_, name) ->
        Option.is_none (Weinstein_types.gics_sector_of_string_opt name))
  in
  assert_that invalid is_empty

let test_default_global_indices_is_canonical_triple _ =
  (* GSPC.INDX is intentionally excluded — it is passed to Macro.analyze as
     ~index_bars, not via ~global_index_bars. *)
  assert_that Macro_inputs.default_global_indices
    (equal_to
       [ ("GDAXI.INDX", "DAX"); ("N225.INDX", "Nikkei"); ("ISF.LSE", "FTSE") ])

(* ------------------------------------------------------------------ *)
(* build_global_index_bars                                              *)
(* ------------------------------------------------------------------ *)

let test_build_global_index_bars_empty _ =
  let bar_reader = Bar_reader.empty () in
  let result =
    Macro_inputs.build_global_index_bars ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~bar_reader
      ~as_of:(Date.of_string "2024-12-31")
  in
  assert_that result is_empty

let test_build_global_index_bars_drops_symbols_without_bars _ =
  (* Only GDAXI has bars; N225 and FTSE are dropped. The result keeps the
     label (not the symbol), so "DAX" is what we check. *)
  let bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:10 ~start_price:100.0
  in
  let as_of = (List.last_exn bars).date in
  let bar_reader =
    make_bar_reader ~symbols_with_bars:[ ("GDAXI.INDX", bars) ]
  in
  let result =
    Macro_inputs.build_global_index_bars ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~bar_reader
      ~as_of
  in
  assert_that result (elements_are [ field fst (equal_to "DAX") ])

(* ------------------------------------------------------------------ *)
(* build_sector_map                                                     *)
(* ------------------------------------------------------------------ *)

(** The smallest number of rising daily bars that produces >= ma_period (30)
    weekly bars. 30 weeks × 5 weekdays = 150, so 250 is comfortably over. *)
let _sufficient_daily_bars = 250

let _empty_weekly_view : Bar_panels.weekly_view =
  {
    closes = [||];
    raw_closes = [||];
    highs = [||];
    lows = [||];
    volumes = [||];
    dates = [||];
    n = 0;
  }

let test_build_sector_map_empty_bar_history _ =
  let bar_reader = Bar_reader.empty () in
  let sector_prior_stages = Hashtbl.create (module String) in
  let result =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52 ~sector_etfs:Macro_inputs.spdr_sector_etfs ~bar_reader
      ~as_of:(Date.of_string "2024-12-31")
      ~sector_prior_stages ~index_view:_empty_weekly_view
      ~ticker_sectors:(Hashtbl.create (module String))
      ()
  in
  assert_that (Hashtbl.to_alist result) is_empty

let test_build_sector_map_drops_etfs_with_insufficient_bars _ =
  (* 25 daily bars = ~5 weekly bars, below ma_period (30). *)
  let bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:25 ~start_price:100.0
  in
  let index_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:4500.0
  in
  let as_of = (List.last_exn bars).date in
  let bar_reader =
    make_bar_reader ~symbols_with_bars:[ ("XLK", bars); ("INDEX", index_bars) ]
  in
  let index_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:"INDEX" ~n:52 ~as_of
  in
  let sector_prior_stages = Hashtbl.create (module String) in
  let result =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Information Technology") ]
      ~bar_reader ~as_of ~sector_prior_stages ~index_view
      ~ticker_sectors:
        (Hashtbl.of_alist_exn
           (module String)
           [ ("XLK", "Information Technology") ])
      ()
  in
  assert_that (Hashtbl.to_alist result) is_empty

let test_build_sector_map_drops_etfs_when_index_bars_empty _ =
  let bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:100.0
  in
  let as_of = (List.last_exn bars).date in
  let bar_reader = make_bar_reader ~symbols_with_bars:[ ("XLK", bars) ] in
  let sector_prior_stages = Hashtbl.create (module String) in
  let result =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Information Technology") ]
      ~bar_reader ~as_of ~sector_prior_stages ~index_view:_empty_weekly_view
      ~ticker_sectors:
        (Hashtbl.of_alist_exn
           (module String)
           [ ("XLK", "Information Technology") ])
      ()
  in
  assert_that (Hashtbl.to_alist result) is_empty

let test_build_sector_map_populates_entry_for_valid_etf _ =
  (* Sufficient rising bars for both the ETF and the index → Sector.analyze
     produces a classification → the map gets an entry keyed by ETF symbol. *)
  let bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:100.0
  in
  let as_of = (List.last_exn bars).date in
  let index_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:4500.0
  in
  let bar_reader =
    make_bar_reader ~symbols_with_bars:[ ("XLK", bars); ("INDEX", index_bars) ]
  in
  let index_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:"INDEX" ~n:52 ~as_of
  in
  let sector_prior_stages = Hashtbl.create (module String) in
  let result =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Information Technology") ]
      ~bar_reader ~as_of ~sector_prior_stages ~index_view
      ~ticker_sectors:
        (Hashtbl.of_alist_exn
           (module String)
           [ ("XLK", "Information Technology") ])
      ()
  in
  assert_that (Hashtbl.to_alist result)
    (elements_are
       [
         all_of
           [
             field fst (equal_to "XLK");
             field
               (fun (_, (ctx : Screener.sector_context)) -> ctx.sector_name)
               (equal_to "Information Technology");
           ];
       ]);
  (* Sector_prior_stages was updated as a side effect so subsequent calls can
     detect Stage1→Stage2 transitions. *)
  assert_that
    (Hashtbl.find sector_prior_stages "XLK")
    (is_some_and (fun _ -> ()))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("macro_inputs"
    >::: [
           "spdr_sector_etfs is the canonical 11-sector list"
           >:: test_spdr_sector_etfs_is_canonical_11_sector_list;
           "spdr_sector_etfs names are valid GICS"
           >:: test_spdr_sector_etfs_names_are_valid_gics;
           "default_global_indices is the canonical triple"
           >:: test_default_global_indices_is_canonical_triple;
           "build_global_index_bars returns empty for empty bar history"
           >:: test_build_global_index_bars_empty;
           "build_global_index_bars drops symbols without bars"
           >:: test_build_global_index_bars_drops_symbols_without_bars;
           "build_sector_map returns empty for empty bar history"
           >:: test_build_sector_map_empty_bar_history;
           "build_sector_map drops ETFs with insufficient bars"
           >:: test_build_sector_map_drops_etfs_with_insufficient_bars;
           "build_sector_map drops ETFs when index_bars is empty"
           >:: test_build_sector_map_drops_etfs_when_index_bars_empty;
           "build_sector_map populates entry for valid ETF"
           >:: test_build_sector_map_populates_entry_for_valid_etf;
         ])
