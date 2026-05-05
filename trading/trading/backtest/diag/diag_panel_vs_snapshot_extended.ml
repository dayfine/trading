(** Extended panel vs snapshot bar-reader parity diagnostic — investigation for
    issue #848 (path-dependent regression in [Bar_reader.of_snapshot_views]).

    The 2026-05-04 diag in [#846] (`diag_real_csv_parity.exe`) compared
    [Bar_panels.weekly_view_for ~n:52] and [Bar_panels.daily_bars_for] across
    ~132K (symbol, weekday) cells in 2019 and reported 0 differences. Yet the
    integration metrics differ (60.86% / 86 trades panel vs 22.2% / 112 trades
    snapshot). Something is path-dependent.

    This diag extends coverage to ALL primitives the strategy uses:
    - weekly_view_for ~n:52 (already covered by #846 diag)
    - daily_bars_for (already covered, but only by date-equality, not full
      OHLCV-equality of EVERY bar)
    - daily_view_for (used by entry_audit_capture — installed-stop support floor
      lookback)
    - weekly_bars_for (used by Macro_inputs.build_global_index_bars and
      Weekly_ma_cache._snapshot_weekly_history)
    - low_window (used internally by support-floor, sized at the
      stops_config.support_floor_lookback_bars)

    Plus expands the sample window to 2019-01..2023-12 (full sp500-2019-2023)
    and compares EVERY bar field (including [open_price] which the snapshot path
    returns as NaN — see [Snapshot_bar_views._assemble_daily_bars]).

    Run from the repo root:
    {v
      dune build trading/backtest/diag/diag_panel_vs_snapshot_extended.exe
      ./_build/default/trading/backtest/diag/diag_panel_vs_snapshot_extended.exe
    v}

    Per-primitive output: total cells / first-divergent (symbol, date, field) /
    accumulated-diff count. *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Symbol_index = Data_panel.Symbol_index
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Pipeline = Snapshot_pipeline.Pipeline
module Csv_storage = Csv.Csv_storage
module BA1 = Bigarray.Array1

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _build_calendar ~start ~end_ : Date.t array =
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' = if is_weekend then acc else d :: acc in
      loop (Date.add_days d 1) acc'
  in
  Array.of_list (loop start [])

let _data_dir = Fpath.v "/workspaces/trading-1/data"

let _read_bars symbol ~start_date ~end_date =
  let storage =
    match Csv_storage.create ~data_dir:_data_dir symbol with
    | Ok s -> s
    | Error err -> failwith ("Csv_storage.create: " ^ Status.show err)
  in
  match Csv_storage.get storage ~start_date ~end_date () with
  | Ok bars -> bars
  | Error err when Status.equal_code err.code Status.NotFound -> []
  | Error err -> failwith ("Csv_storage.get: " ^ Status.show err)

let _build_full_panel ~symbols ~calendar : Bar_panels.t =
  let symbol_index =
    match Symbol_index.create ~universe:symbols with
    | Ok t -> t
    | Error err -> failwith ("Symbol_index.create: " ^ Status.show err)
  in
  let ohlcv =
    match
      Ohlcv_panels.load_from_csv_calendar symbol_index ~data_dir:_data_dir
        ~calendar
    with
    | Ok t -> t
    | Error err ->
        failwith ("Ohlcv_panels.load_from_csv_calendar: " ^ Status.show err)
  in
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> failwith ("Bar_panels.create: " ^ Status.show err)

let _build_full_snapshot ~symbols ~start_date ~end_date :
    Snapshot_callbacks.t * Daily_panels.t =
  let dir = Stdlib.Filename.temp_dir "diag_ext_snap_" "" in
  let entries =
    List.map symbols ~f:(fun symbol ->
        let bars = _read_bars symbol ~start_date ~end_date in
        let rows =
          match
            Pipeline.build_for_symbol ~symbol ~bars
              ~schema:Snapshot_schema.default ()
          with
          | Ok r -> r
          | Error err ->
              failwith ("Pipeline.build_for_symbol: " ^ err.Status.message)
        in
        let path = Filename.concat dir (symbol ^ ".snap") in
        (match Snapshot_format.write ~path rows with
        | Ok () -> ()
        | Error err -> failwith ("Snapshot_format.write: " ^ err.Status.message));
        ({
           symbol;
           path;
           byte_size = 0;
           payload_md5 = "ignored";
           csv_mtime = 0.0;
         }
          : Snapshot_manifest.file_metadata))
  in
  let manifest =
    Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries
  in
  let manifest_path = Filename.concat dir "manifest.sexp" in
  (match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () -> ()
  | Error err -> failwith ("Snapshot_manifest.write: " ^ err.Status.message));
  let panels =
    match
      Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:1024
    with
    | Ok p -> p
    | Error err -> failwith ("Daily_panels.create: " ^ Status.show err)
  in
  (Snapshot_callbacks.of_daily_panels panels, panels)

(* Compare two Daily_price.t lists for full equality (every field). Returns
   [None] if equal, [Some msg] describing the first divergent bar. *)
let _f_eq a b = Float.equal a b || (Float.is_nan a && Float.is_nan b)

let _diff_bar_lists ~tag ~symbol ~as_of (panel : Types.Daily_price.t list)
    (snap : Types.Daily_price.t list) =
  let n_p = List.length panel in
  let n_s = List.length snap in
  if n_p <> n_s then
    Some
      (Printf.sprintf "%s %s %s: panel.len=%d snap.len=%d" tag symbol
         (Date.to_string as_of) n_p n_s)
  else
    let pa = Array.of_list panel in
    let sa = Array.of_list snap in
    let rec walk i =
      if i >= n_p then None
      else
        let p = pa.(i) in
        let s = sa.(i) in
        if not (Date.equal p.date s.date) then
          Some
            (Printf.sprintf
               "%s %s %s [bar %d/%d] dates differ: panel=%s snap=%s" tag symbol
               (Date.to_string as_of) i n_p (Date.to_string p.date)
               (Date.to_string s.date))
        else if not (_f_eq p.close_price s.close_price) then
          Some
            (Printf.sprintf
               "%s %s %s [bar %d/%d] close differ: panel=%.10f snap=%.10f" tag
               symbol (Date.to_string as_of) i n_p p.close_price s.close_price)
        else if not (_f_eq p.adjusted_close s.adjusted_close) then
          Some
            (Printf.sprintf
               "%s %s %s [bar %d/%d] adj_close differ: panel=%.10f snap=%.10f"
               tag symbol (Date.to_string as_of) i n_p p.adjusted_close
               s.adjusted_close)
        else if not (_f_eq p.high_price s.high_price) then
          Some
            (Printf.sprintf
               "%s %s %s [bar %d/%d] high differ: panel=%.10f snap=%.10f" tag
               symbol (Date.to_string as_of) i n_p p.high_price s.high_price)
        else if not (_f_eq p.low_price s.low_price) then
          Some
            (Printf.sprintf
               "%s %s %s [bar %d/%d] low differ: panel=%.10f snap=%.10f" tag
               symbol (Date.to_string as_of) i n_p p.low_price s.low_price)
        else if p.volume <> s.volume then
          Some
            (Printf.sprintf
               "%s %s %s [bar %d/%d] volume differ: panel=%d snap=%d" tag symbol
               (Date.to_string as_of) i n_p p.volume s.volume)
        else if not (_f_eq p.open_price s.open_price) then
          Some
            (Printf.sprintf
               "%s %s %s [bar %d/%d] open differ: panel=%.10f snap=%.10f \
                (NOTE: snapshot path emits NaN for open)"
               tag symbol (Date.to_string as_of) i n_p p.open_price s.open_price)
        else walk (i + 1)
    in
    walk 0

(* Compare daily_view: highs/lows/closes/dates float arrays. *)
let _diff_daily_views ~tag ~symbol ~as_of (panel : Bar_panels.daily_view)
    (snap : Bar_panels.daily_view) =
  if panel.n_days <> snap.n_days then
    Some
      (Printf.sprintf "%s %s %s: panel.n_days=%d snap.n_days=%d" tag symbol
         (Date.to_string as_of) panel.n_days snap.n_days)
  else
    let n = panel.n_days in
    let rec walk i =
      if i >= n then None
      else if not (Date.equal panel.dates.(i) snap.dates.(i)) then
        Some
          (Printf.sprintf "%s %s %s [%d/%d] dates differ: panel=%s snap=%s" tag
             symbol (Date.to_string as_of) i n
             (Date.to_string panel.dates.(i))
             (Date.to_string snap.dates.(i)))
      else if not (_f_eq panel.highs.(i) snap.highs.(i)) then
        Some
          (Printf.sprintf "%s %s %s [%d/%d] high differ: panel=%.10f snap=%.10f"
             tag symbol (Date.to_string as_of) i n panel.highs.(i)
             snap.highs.(i))
      else if not (_f_eq panel.lows.(i) snap.lows.(i)) then
        Some
          (Printf.sprintf "%s %s %s [%d/%d] low differ: panel=%.10f snap=%.10f"
             tag symbol (Date.to_string as_of) i n panel.lows.(i) snap.lows.(i))
      else if not (_f_eq panel.closes.(i) snap.closes.(i)) then
        Some
          (Printf.sprintf
             "%s %s %s [%d/%d] close differ: panel=%.10f snap=%.10f" tag symbol
             (Date.to_string as_of) i n panel.closes.(i) snap.closes.(i))
      else walk (i + 1)
    in
    walk 0

let _load_universe path =
  let univ_sexp = Sexp.load_sexp path in
  match univ_sexp with
  | Sexp.List [ Sexp.Atom "Pinned"; Sexp.List entries ] ->
      List.map entries ~f:(function
        | Sexp.List
            [
              Sexp.List [ Sexp.Atom "symbol"; Sexp.Atom s ];
              Sexp.List [ Sexp.Atom "sector"; _ ];
            ] ->
            s
        | _ -> failwith "diag_ext: bad universe entry")
  | _ -> failwith "diag_ext: bad universe sexp"

(* Run a per-primitive comparison across (symbol × as_of) cells. Records the
   total cell count, the difference count, and the first 10 divergence
   messages. *)
type counter = {
  mutable total : int;
  mutable diff : int;
  mutable first : string list;
}

let _new_counter () = { total = 0; diff = 0; first = [] }

let _record_diff c msg =
  c.diff <- c.diff + 1;
  if List.length c.first < 10 then c.first <- msg :: c.first

let _print_counter ~name (c : counter) =
  Printf.printf "%-22s: %d / %d cells differ\n" name c.diff c.total;
  if c.diff > 0 then
    List.iter (List.rev c.first) ~f:(fun s -> Printf.printf "    %s\n" s)

(* Emit a status line every 10K cells so the operator knows the diag is
   alive. *)
let _maybe_progress ~name (c : counter) =
  if c.total mod 10_000 = 0 then
    Printf.printf "  [%s] processed %d cells, %d diffs so far\n%!" name c.total
      c.diff

let _maybe_diff_weekly_view (c : counter) ~symbol ~as_of (panel_view, snap_view)
    =
  c.total <- c.total + 1;
  let panel_n = panel_view.Bar_panels.n in
  let snap_n = snap_view.Bar_panels.n in
  (if panel_n <> snap_n then
     _record_diff c
       (Printf.sprintf "%s %s: panel.n=%d snap.n=%d" symbol
          (Date.to_string as_of) panel_n snap_n)
   else
     let rec walk i =
       if i >= panel_n then ()
       else if
         not (Date.equal panel_view.dates.(i) snap_view.Bar_panels.dates.(i))
       then
         _record_diff c
           (Printf.sprintf "%s %s [%d] dates differ: panel=%s snap=%s" symbol
              (Date.to_string as_of) i
              (Date.to_string panel_view.dates.(i))
              (Date.to_string snap_view.Bar_panels.dates.(i)))
       else if not (_f_eq panel_view.closes.(i) snap_view.Bar_panels.closes.(i))
       then
         _record_diff c
           (Printf.sprintf "%s %s [%d] close differ: panel=%.10f snap=%.10f"
              symbol (Date.to_string as_of) i panel_view.closes.(i)
              snap_view.Bar_panels.closes.(i))
       else walk (i + 1)
     in
     walk 0);
  _maybe_progress ~name:"weekly_view" c

let _maybe_diff_bar_list ~tag (c : counter) ~symbol ~as_of
    (panel_bars, snap_bars) =
  c.total <- c.total + 1;
  (match _diff_bar_lists ~tag ~symbol ~as_of panel_bars snap_bars with
  | None -> ()
  | Some msg -> _record_diff c msg);
  _maybe_progress ~name:tag c

let _maybe_diff_daily_view ~tag (c : counter) ~symbol ~as_of
    (panel_view, snap_view) =
  c.total <- c.total + 1;
  (match _diff_daily_views ~tag ~symbol ~as_of panel_view snap_view with
  | None -> ()
  | Some msg -> _record_diff c msg);
  _maybe_progress ~name:tag c

let _ba_to_array (ba : (float, Bigarray.float64_elt, Bigarray.c_layout) BA1.t) =
  let n = BA1.dim ba in
  Array.init n ~f:(fun i -> BA1.get ba i)

let _diff_low_window ~tag (c : counter) ~symbol ~as_of
    (panel_opt : (float, Bigarray.float64_elt, Bigarray.c_layout) BA1.t option)
    (snap_opt : (float, Bigarray.float64_elt, Bigarray.c_layout) BA1.t option) =
  c.total <- c.total + 1;
  (match (panel_opt, snap_opt) with
  | None, None -> ()
  | Some _, None ->
      _record_diff c
        (Printf.sprintf "%s %s %s: panel returned Some, snap returned None" tag
           symbol (Date.to_string as_of))
  | None, Some _ ->
      _record_diff c
        (Printf.sprintf "%s %s %s: panel returned None, snap returned Some" tag
           symbol (Date.to_string as_of))
  | Some pa, Some sa ->
      let np = BA1.dim pa in
      let ns = BA1.dim sa in
      if np <> ns then
        _record_diff c
          (Printf.sprintf "%s %s %s: panel.dim=%d snap.dim=%d" tag symbol
             (Date.to_string as_of) np ns)
      else
        let pa_arr = _ba_to_array pa in
        let sa_arr = _ba_to_array sa in
        let rec walk i =
          if i >= np then ()
          else if not (_f_eq pa_arr.(i) sa_arr.(i)) then
            _record_diff c
              (Printf.sprintf "%s %s %s [%d/%d] differ: panel=%.10f snap=%.10f"
                 tag symbol (Date.to_string as_of) i np pa_arr.(i) sa_arr.(i))
          else walk (i + 1)
        in
        walk 0);
  _maybe_progress ~name:tag c

(* Sample weekdays per year. Pick a sparse but representative set: the 1st
   Friday of each month from 2019..2023. That's 60 dates × 506 symbols = 30360
   cells per primitive. Cheap to run, covers every quarter of every year of
   the sp500 scenario window. *)
let _sample_dates () =
  let dates = ref [] in
  for year = 2019 to 2023 do
    for month = 1 to 12 do
      let first_of_month = _ymd year month 1 in
      let dow = Date.day_of_week first_of_month in
      let days_to_friday =
        match dow with
        | Day_of_week.Mon -> 4
        | Day_of_week.Tue -> 3
        | Day_of_week.Wed -> 2
        | Day_of_week.Thu -> 1
        | Day_of_week.Fri -> 0
        | Day_of_week.Sat -> 6
        | Day_of_week.Sun -> 5
      in
      let first_friday = Date.add_days first_of_month days_to_friday in
      dates := first_friday :: !dates
    done
  done;
  List.rev !dates

let () =
  let univ_path =
    "/workspaces/trading-1/trading/test_data/backtest_scenarios/universes/sp500.sexp"
  in
  let universe = _load_universe univ_path in
  let warmup_start = _ymd 2018 6 6 in
  let end_date = _ymd 2023 12 29 in
  Printf.printf "Universe: %d symbols\n" (List.length universe);
  let sector_etfs =
    [
      "XLK";
      "XLF";
      "XLE";
      "XLV";
      "XLI";
      "XLP";
      "XLY";
      "XLU";
      "XLB";
      "XLRE";
      "XLC";
    ]
  in
  let global_indices = [ "GDAXI.INDX"; "N225.INDX"; "ISF.LSE" ] in
  let symbols = ("GSPC.INDX" :: universe) @ sector_etfs @ global_indices in
  let calendar = _build_calendar ~start:warmup_start ~end_:end_date in
  Printf.printf "Calendar: %d trading days (%s..%s)\n" (Array.length calendar)
    (Date.to_string warmup_start)
    (Date.to_string end_date);
  Printf.printf "Building Bar_panels...\n%!";
  let panel = _build_full_panel ~symbols ~calendar in
  Printf.printf "Building snapshot...\n%!";
  let cb, _dp =
    _build_full_snapshot ~symbols ~start_date:warmup_start ~end_date
  in
  let dates = _sample_dates () in
  Printf.printf "Test dates: %d (1st Friday/month, 2019-2023)\n"
    (List.length dates);
  let weekly_view_cnt = _new_counter () in
  let daily_bars_cnt = _new_counter () in
  let weekly_bars_cnt = _new_counter () in
  let daily_view_cnt = _new_counter () in
  let low_window_cnt = _new_counter () in
  List.iter dates ~f:(fun as_of ->
      List.iter symbols ~f:(fun symbol ->
          (* weekly_view_for ~n:52 *)
          let panel_wv =
            match Bar_panels.column_of_date panel as_of with
            | None ->
                {
                  Bar_panels.closes = [||];
                  raw_closes = [||];
                  highs = [||];
                  lows = [||];
                  volumes = [||];
                  dates = [||];
                  n = 0;
                }
            | Some d ->
                Bar_panels.weekly_view_for panel ~symbol ~n:52 ~as_of_day:d
          in
          let snap_wv =
            Snapshot_bar_views.weekly_view_for cb ~symbol ~n:52 ~as_of
          in
          _maybe_diff_weekly_view weekly_view_cnt ~symbol ~as_of
            (panel_wv, snap_wv);
          (* daily_bars_for *)
          let panel_db =
            match Bar_panels.column_of_date panel as_of with
            | None -> []
            | Some d -> Bar_panels.daily_bars_for panel ~symbol ~as_of_day:d
          in
          let snap_db = Snapshot_bar_views.daily_bars_for cb ~symbol ~as_of in
          _maybe_diff_bar_list ~tag:"daily_bars" daily_bars_cnt ~symbol ~as_of
            (panel_db, snap_db);
          (* weekly_bars_for ~n:52 *)
          let panel_wb =
            match Bar_panels.column_of_date panel as_of with
            | None -> []
            | Some d ->
                Bar_panels.weekly_bars_for panel ~symbol ~n:52 ~as_of_day:d
          in
          let snap_wb =
            Snapshot_bar_views.weekly_bars_for cb ~symbol ~n:52 ~as_of
          in
          _maybe_diff_bar_list ~tag:"weekly_bars" weekly_bars_cnt ~symbol ~as_of
            (panel_wb, snap_wb);
          (* daily_view_for ~lookback:60 — exercises the mid-term lookback used
             by support_floor in entry_audit_capture. *)
          let panel_dv =
            match Bar_panels.column_of_date panel as_of with
            | None ->
                {
                  Bar_panels.highs = [||];
                  lows = [||];
                  closes = [||];
                  dates = [||];
                  n_days = 0;
                }
            | Some d ->
                Bar_panels.daily_view_for panel ~symbol ~as_of_day:d
                  ~lookback:60
          in
          let snap_dv =
            Snapshot_bar_views.daily_view_for cb ~symbol ~as_of ~lookback:60
              ~calendar
          in
          _maybe_diff_daily_view ~tag:"daily_view" daily_view_cnt ~symbol ~as_of
            (panel_dv, snap_dv);
          (* low_window ~len:60 *)
          let panel_lw =
            match Bar_panels.column_of_date panel as_of with
            | None -> None
            | Some d -> Bar_panels.low_window panel ~symbol ~as_of_day:d ~len:60
          in
          let snap_lw =
            Snapshot_bar_views.low_window cb ~symbol ~as_of ~len:60 ~calendar
          in
          _diff_low_window ~tag:"low_window" low_window_cnt ~symbol ~as_of
            panel_lw snap_lw));
  Printf.printf "\n=== Per-primitive parity results ===\n";
  _print_counter ~name:"weekly_view_for(52)" weekly_view_cnt;
  _print_counter ~name:"daily_bars_for" daily_bars_cnt;
  _print_counter ~name:"weekly_bars_for(52)" weekly_bars_cnt;
  _print_counter ~name:"daily_view_for(60)" daily_view_cnt;
  _print_counter ~name:"low_window(60)" low_window_cnt
