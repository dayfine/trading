open OUnit2
open Core
open Matchers
open Weinstein_strategy

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

(** Seed a [Bar_history.t] with [bars] for [symbol] by repeatedly feeding them
    through [accumulate], matching the strategy's usage pattern. *)
let seed_bar_history ~symbol ~bars =
  let t = Bar_history.create () in
  List.iter bars ~f:(fun bar ->
      let get_price s = if String.equal s symbol then Some bar else None in
      Bar_history.accumulate t ~get_price ~symbols:[ symbol ]);
  t

(* ------------------------------------------------------------------ *)
(* Canonical constants                                                  *)
(* ------------------------------------------------------------------ *)

let test_spdr_sector_etfs_is_canonical_11_sector_list _ =
  assert_that Macro_inputs.spdr_sector_etfs
    (equal_to
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
       ])

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
  let t = Bar_history.create () in
  let result =
    Macro_inputs.build_global_index_bars ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~bar_history:t
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
  let t = seed_bar_history ~symbol:"GDAXI.INDX" ~bars in
  let result =
    Macro_inputs.build_global_index_bars ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~bar_history:t
  in
  assert_that result (elements_are [ field fst (equal_to "DAX") ])

(* ------------------------------------------------------------------ *)
(* build_sector_map                                                     *)
(* ------------------------------------------------------------------ *)

(** The smallest number of rising daily bars that produces >= ma_period (30)
    weekly bars. 30 weeks × 5 weekdays = 150, so 250 is comfortably over. *)
let _sufficient_daily_bars = 250

let test_build_sector_map_empty_bar_history _ =
  let t = Bar_history.create () in
  let sector_prior_stages = Hashtbl.create (module String) in
  let result =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52 ~sector_etfs:Macro_inputs.spdr_sector_etfs
      ~bar_history:t ~sector_prior_stages ~index_bars:[]
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
  let t = seed_bar_history ~symbol:"XLK" ~bars in
  let sector_prior_stages = Hashtbl.create (module String) in
  let result =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Technology") ]
      ~bar_history:t ~sector_prior_stages ~index_bars
  in
  assert_that (Hashtbl.to_alist result) is_empty

let test_build_sector_map_drops_etfs_when_index_bars_empty _ =
  let bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:100.0
  in
  let t = seed_bar_history ~symbol:"XLK" ~bars in
  let sector_prior_stages = Hashtbl.create (module String) in
  let result =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Technology") ]
      ~bar_history:t ~sector_prior_stages ~index_bars:[]
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
  let t = seed_bar_history ~symbol:"XLK" ~bars in
  let index_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:4500.0
  in
  let sector_prior_stages = Hashtbl.create (module String) in
  let result =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Technology") ]
      ~bar_history:t ~sector_prior_stages ~index_bars
  in
  assert_that (Hashtbl.to_alist result)
    (elements_are
       [
         all_of
           [
             field fst (equal_to "XLK");
             field
               (fun (_, (ctx : Screener.sector_context)) -> ctx.sector_name)
               (equal_to "Technology");
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
