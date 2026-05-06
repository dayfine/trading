open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

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
(* ad_bars_at_or_before                                                 *)
(* ------------------------------------------------------------------ *)
(* Regression coverage for the future-leak guard introduced in #612.
   The guard trims the composer-loaded synthetic A-D series
   ([Ad_bars.load], whose Synthetic tail typically extends to the most
   recent [compute_synthetic_adl.exe] run) to dates [<= as_of] before
   the macro callbacks read [get_cumulative_ad ~week_offset:0]. Without
   the trim, the cumulative-as-of-last-bar would be ~years past the
   simulator's current tick — breaking the [Bearish] composite during
   real bear-market replays.

   The deleted [test_macro_panel_callbacks_real_data.ml] (per #876) was
   the sole direct integration test pinning this contract; this block
   restores it as focused unit tests against {!Macro_inputs.ad_bars_at_or_before}
   directly. The function is still called from production at
   [weinstein_strategy.ml] inside [_run_macro_screen]. *)

let _make_ad_bar ~date ~advancing ~declining : Macro.ad_bar =
  { date; advancing; declining }

(* Build a span of weekly A-D bars with monotone-increasing dates,
   straddling the [as_of] boundary so the filter has both retained and
   stripped bars to discriminate. The advancing/declining counts are
   arbitrary fixed values — only the date field drives the filter. *)
let _ad_bars_straddling_as_of ~as_of =
  let weeks_before = [ -21; -14; -7; 0 ] in
  let weeks_after = [ 7; 14; 21 ] in
  List.map (weeks_before @ weeks_after) ~f:(fun offset ->
      _make_ad_bar
        ~date:(Date.add_days as_of offset)
        ~advancing:1500 ~declining:1500)

let test_ad_bars_at_or_before_strips_future_bars _ =
  let as_of = Date.of_string "2022-10-14" in
  let ad_bars = _ad_bars_straddling_as_of ~as_of in
  let result = Macro_inputs.ad_bars_at_or_before ~ad_bars ~as_of in
  (* Every retained bar's date must be [<= as_of]; the post-as_of
     trio (offsets +7, +14, +21) must be stripped. The retained
     prefix is deterministic because the input is sorted ascending. *)
  assert_that result
    (elements_are
       [
         field
           (fun (b : Macro.ad_bar) -> b.date)
           (equal_to (Date.add_days as_of (-21)));
         field
           (fun (b : Macro.ad_bar) -> b.date)
           (equal_to (Date.add_days as_of (-14)));
         field
           (fun (b : Macro.ad_bar) -> b.date)
           (equal_to (Date.add_days as_of (-7)));
         field (fun (b : Macro.ad_bar) -> b.date) (equal_to as_of);
       ])

let test_ad_bars_at_or_before_keeps_boundary_bar _ =
  (* Inclusivity: a bar exactly on [as_of] is retained ([<=], not [<]). *)
  let as_of = Date.of_string "2022-10-14" in
  let ad_bars =
    [
      _make_ad_bar ~date:(Date.add_days as_of (-7)) ~advancing:1500
        ~declining:1500;
      _make_ad_bar ~date:as_of ~advancing:1500 ~declining:1500;
      _make_ad_bar ~date:(Date.add_days as_of 1) ~advancing:1500 ~declining:1500;
    ]
  in
  let result = Macro_inputs.ad_bars_at_or_before ~ad_bars ~as_of in
  assert_that result
    (elements_are
       [
         field
           (fun (b : Macro.ad_bar) -> b.date)
           (equal_to (Date.add_days as_of (-7)));
         field (fun (b : Macro.ad_bar) -> b.date) (equal_to as_of);
       ])

let test_ad_bars_at_or_before_passthrough_when_all_in_range _ =
  (* Production-tail fast path: the input list is returned unchanged
     when its last bar already lies on or before [as_of]. *)
  let as_of = Date.of_string "2022-10-14" in
  let ad_bars =
    [
      _make_ad_bar
        ~date:(Date.add_days as_of (-14))
        ~advancing:1500 ~declining:1500;
      _make_ad_bar ~date:(Date.add_days as_of (-7)) ~advancing:1500
        ~declining:1500;
    ]
  in
  let result = Macro_inputs.ad_bars_at_or_before ~ad_bars ~as_of in
  assert_that result
    (elements_are
       [
         field
           (fun (b : Macro.ad_bar) -> b.date)
           (equal_to (Date.add_days as_of (-14)));
         field
           (fun (b : Macro.ad_bar) -> b.date)
           (equal_to (Date.add_days as_of (-7)));
       ])

let test_ad_bars_at_or_before_empty_input _ =
  let as_of = Date.of_string "2022-10-14" in
  let result = Macro_inputs.ad_bars_at_or_before ~ad_bars:[] ~as_of in
  assert_that result is_empty

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

let _empty_weekly_view : Snapshot_bar_views.weekly_view =
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
(* Snapshot-views parity (Phase F.3.d)                                  *)
(* ------------------------------------------------------------------ *)
(* Pin that {!Macro_inputs.build_*_of_snapshot_views} produces bit-equal
   output to the [bar_reader]-backed constructors on the same underlying
   bar history. Both paths ultimately fan out through
   {!Snapshot_runtime.Snapshot_bar_views} (the [bar_reader] is itself
   snapshot-backed after F.3.a-4); parity is the load-bearing property
   for migrating callers from one entry-point to the other. *)

let _build_snapshot_callbacks
    (symbol_bars : (string * Types.Daily_price.t list) list) :
    Snapshot_callbacks.t =
  let dir = Stdlib.Filename.temp_dir "test_macro_inputs_" "" in
  let entries =
    List.map symbol_bars ~f:(fun (symbol, bars) ->
        let rows =
          match
            Pipeline.build_for_symbol ~symbol ~bars
              ~schema:Snapshot_schema.default ()
          with
          | Ok rs -> rs
          | Error err ->
              failwithf "Pipeline.build_for_symbol %s: %s" symbol
                err.Status.message ()
        in
        let path = Filename.concat dir (symbol ^ ".snap") in
        (match Snapshot_format.write ~path rows with
        | Ok () -> ()
        | Error err ->
            failwithf "Snapshot_format.write %s: %s" symbol err.Status.message
              ());
        {
          Snapshot_manifest.symbol;
          path;
          byte_size = 0;
          payload_md5 = "ignored";
          csv_mtime = 0.0;
        })
  in
  let manifest =
    Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries
  in
  let manifest_path = Filename.concat dir "manifest.sexp" in
  (match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () -> ()
  | Error err -> failwithf "Snapshot_manifest.write: %s" err.Status.message ());
  let panels =
    match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:16 with
    | Ok p -> p
    | Error err -> failwithf "Daily_panels.create: %s" err.Status.message ()
  in
  Snapshot_callbacks.of_daily_panels panels

(* Build a per-entry matcher for a (label, weekly_view) pair from an
   expected entry: composes label equality + per-field array equality
   under one [all_of]. Float arrays compare with epsilon=1e-9 — both
   paths round-trip through {!Snapshot_bar_views} for the synthetic
   in-memory fixture, so any drift larger than IEEE round-trip noise
   would be a regression. Used in [elements_are] to validate the full
   [(label, weekly_view) list] under one [assert_that]. *)
let _global_view_entry_matcher
    ((expected_label, expected_view) : string * Snapshot_bar_views.weekly_view)
    =
  let float_array_matches arr =
    elements_are (Array.to_list arr |> List.map ~f:(float_equal ~epsilon:1e-9))
  in
  let date_array_matches arr =
    elements_are (Array.to_list arr |> List.map ~f:equal_to)
  in
  all_of
    [
      field fst (equal_to expected_label);
      field
        (fun ((_, v) : string * Snapshot_bar_views.weekly_view) -> v.n)
        (equal_to expected_view.n);
      field
        (fun ((_, v) : string * Snapshot_bar_views.weekly_view) ->
          Array.to_list v.closes)
        (float_array_matches expected_view.closes);
      field
        (fun ((_, v) : string * Snapshot_bar_views.weekly_view) ->
          Array.to_list v.raw_closes)
        (float_array_matches expected_view.raw_closes);
      field
        (fun ((_, v) : string * Snapshot_bar_views.weekly_view) ->
          Array.to_list v.highs)
        (float_array_matches expected_view.highs);
      field
        (fun ((_, v) : string * Snapshot_bar_views.weekly_view) ->
          Array.to_list v.lows)
        (float_array_matches expected_view.lows);
      field
        (fun ((_, v) : string * Snapshot_bar_views.weekly_view) ->
          Array.to_list v.volumes)
        (float_array_matches expected_view.volumes);
      field
        (fun ((_, v) : string * Snapshot_bar_views.weekly_view) ->
          Array.to_list v.dates)
        (date_array_matches expected_view.dates);
    ]

(* Build a per-entry matcher for a (label, Daily_price.t list) pair from
   an expected entry. Bar lists compare element-wise on the numeric fields
   the bar-list path round-trips through [Snapshot_bar_views] (date,
   adjusted_close, close, high, low, volume) — those are the load-bearing
   fields the Macro callbacks read. *)
let _global_bars_entry_matcher
    ((expected_label, expected_bars) : string * Types.Daily_price.t list) =
  let bar_matcher (b : Types.Daily_price.t) =
    all_of
      [
        field (fun (x : Types.Daily_price.t) -> x.date) (equal_to b.date);
        field
          (fun (x : Types.Daily_price.t) -> x.adjusted_close)
          (float_equal ~epsilon:1e-9 b.adjusted_close);
        field
          (fun (x : Types.Daily_price.t) -> x.close_price)
          (float_equal ~epsilon:1e-9 b.close_price);
        field
          (fun (x : Types.Daily_price.t) -> x.high_price)
          (float_equal ~epsilon:1e-9 b.high_price);
        field
          (fun (x : Types.Daily_price.t) -> x.low_price)
          (float_equal ~epsilon:1e-9 b.low_price);
        field
          (fun (x : Types.Daily_price.t) -> Float.of_int x.volume)
          (float_equal ~epsilon:1e-9 (Float.of_int b.volume));
      ]
  in
  all_of
    [
      field fst (equal_to expected_label);
      field snd (elements_are (List.map expected_bars ~f:bar_matcher));
    ]

let test_snapshot_parity_global_index_views _ =
  let gdaxi_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:15000.0
  in
  let n225_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:30000.0
  in
  let as_of = (List.last_exn gdaxi_bars).date in
  let symbols = [ ("GDAXI.INDX", gdaxi_bars); ("N225.INDX", n225_bars) ] in
  let bar_reader = Bar_reader.of_in_memory_bars symbols in
  let cb = _build_snapshot_callbacks symbols in
  let bar_reader_views =
    Macro_inputs.build_global_index_views ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~bar_reader
      ~as_of
  in
  let snapshot_views =
    Macro_inputs.build_global_index_views_of_snapshot_views ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~cb ~as_of
  in
  assert_that snapshot_views
    (elements_are (List.map bar_reader_views ~f:_global_view_entry_matcher))

let test_snapshot_parity_global_index_views_drops_missing _ =
  (* Only GDAXI present; N225 + FTSE missing → both paths drop them
     identically and produce a single-entry list keyed by "DAX". *)
  let bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:30 ~start_price:15000.0
  in
  let as_of = (List.last_exn bars).date in
  let symbols = [ ("GDAXI.INDX", bars) ] in
  let bar_reader = Bar_reader.of_in_memory_bars symbols in
  let cb = _build_snapshot_callbacks symbols in
  let bar_reader_views =
    Macro_inputs.build_global_index_views ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~bar_reader
      ~as_of
  in
  let snapshot_views =
    Macro_inputs.build_global_index_views_of_snapshot_views ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~cb ~as_of
  in
  assert_that snapshot_views
    (elements_are (List.map bar_reader_views ~f:_global_view_entry_matcher))

let test_snapshot_parity_global_index_bars _ =
  let bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:15000.0
  in
  let as_of = (List.last_exn bars).date in
  let symbols = [ ("GDAXI.INDX", bars) ] in
  let bar_reader = Bar_reader.of_in_memory_bars symbols in
  let cb = _build_snapshot_callbacks symbols in
  let bar_reader_pairs =
    Macro_inputs.build_global_index_bars ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~bar_reader
      ~as_of
  in
  let snapshot_pairs =
    Macro_inputs.build_global_index_bars_of_snapshot_views ~lookback_bars:52
      ~global_index_symbols:Macro_inputs.default_global_indices ~cb ~as_of
  in
  assert_that snapshot_pairs
    (elements_are (List.map bar_reader_pairs ~f:_global_bars_entry_matcher))

let test_snapshot_parity_sector_map _ =
  (* Both ETF + index have enough bars → both paths populate XLK with the
     same {!Screener.sector_context} and update [sector_prior_stages]
     identically. *)
  let etf_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:100.0
  in
  let index_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:4500.0
  in
  let as_of = (List.last_exn etf_bars).date in
  let symbols = [ ("XLK", etf_bars); ("INDEX", index_bars) ] in
  let bar_reader = Bar_reader.of_in_memory_bars symbols in
  let cb = _build_snapshot_callbacks symbols in
  let index_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:"INDEX" ~n:52 ~as_of
  in
  let bar_reader_prior_stages = Hashtbl.create (module String) in
  let snapshot_prior_stages = Hashtbl.create (module String) in
  let ticker_sectors =
    Hashtbl.of_alist_exn (module String) [ ("XLK", "Information Technology") ]
  in
  let bar_reader_map =
    Macro_inputs.build_sector_map ~stage_config:Stage.default_config
      ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Information Technology") ]
      ~bar_reader ~as_of ~sector_prior_stages:bar_reader_prior_stages
      ~index_view ~ticker_sectors ()
  in
  let snapshot_map =
    Macro_inputs.build_sector_map_of_snapshot_views
      ~stage_config:Stage.default_config ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Information Technology") ]
      ~cb ~as_of ~sector_prior_stages:snapshot_prior_stages ~index_view
      ~ticker_sectors ()
  in
  let sorted_alist h =
    Hashtbl.to_alist h
    |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
  in
  let expected_alist = sorted_alist bar_reader_map in
  let expected_prior_alist =
    Hashtbl.to_alist bar_reader_prior_stages
    |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
  in
  let snap_prior_alist =
    Hashtbl.to_alist snapshot_prior_stages
    |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
  in
  let entry_matcher (k, (e : Screener.sector_context)) =
    all_of
      [
        field fst (equal_to k);
        field
          (fun (_, (ctx : Screener.sector_context)) -> ctx.sector_name)
          (equal_to e.sector_name);
      ]
  in
  let prior_entry_matcher (k, _) = field fst (equal_to k) in
  assert_that
    (sorted_alist snapshot_map, snap_prior_alist)
    (all_of
       [
         field fst (elements_are (List.map expected_alist ~f:entry_matcher));
         field snd
           (elements_are (List.map expected_prior_alist ~f:prior_entry_matcher));
       ])

let test_snapshot_parity_sector_map_drops_etfs_with_insufficient_bars _ =
  (* 25 daily bars = ~5 weekly bars, below ma_period (30) → both paths
     produce an empty map. *)
  let etf_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:25 ~start_price:100.0
  in
  let index_bars =
    make_rising_bars
      ~start_date:(Date.of_string "2024-01-01")
      ~n:_sufficient_daily_bars ~start_price:4500.0
  in
  let as_of = (List.last_exn etf_bars).date in
  let symbols = [ ("XLK", etf_bars); ("INDEX", index_bars) ] in
  let bar_reader = Bar_reader.of_in_memory_bars symbols in
  let cb = _build_snapshot_callbacks symbols in
  let index_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:"INDEX" ~n:52 ~as_of
  in
  let ticker_sectors =
    Hashtbl.of_alist_exn (module String) [ ("XLK", "Information Technology") ]
  in
  let snapshot_map =
    Macro_inputs.build_sector_map_of_snapshot_views
      ~stage_config:Stage.default_config ~lookback_bars:52
      ~sector_etfs:[ ("XLK", "Information Technology") ]
      ~cb ~as_of
      ~sector_prior_stages:(Hashtbl.create (module String))
      ~index_view ~ticker_sectors ()
  in
  assert_that (Hashtbl.to_alist snapshot_map) is_empty

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
           "ad_bars_at_or_before strips bars dated after as_of"
           >:: test_ad_bars_at_or_before_strips_future_bars;
           "ad_bars_at_or_before keeps boundary bar (date = as_of)"
           >:: test_ad_bars_at_or_before_keeps_boundary_bar;
           "ad_bars_at_or_before passes through when all bars in range"
           >:: test_ad_bars_at_or_before_passthrough_when_all_in_range;
           "ad_bars_at_or_before returns empty for empty input"
           >:: test_ad_bars_at_or_before_empty_input;
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
           "Snapshot parity: build_global_index_views"
           >:: test_snapshot_parity_global_index_views;
           "Snapshot parity: build_global_index_views drops missing"
           >:: test_snapshot_parity_global_index_views_drops_missing;
           "Snapshot parity: build_global_index_bars"
           >:: test_snapshot_parity_global_index_bars;
           "Snapshot parity: build_sector_map"
           >:: test_snapshot_parity_sector_map;
           "Snapshot parity: build_sector_map drops insufficient ETFs"
           >:: test_snapshot_parity_sector_map_drops_etfs_with_insufficient_bars;
         ])
