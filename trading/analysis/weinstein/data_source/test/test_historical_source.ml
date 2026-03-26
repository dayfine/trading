open Core
open OUnit2
open Matchers

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)

(* Create a temp dir and clean it up after the test *)
let with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_historical_source" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let make_bar date close =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1000;
  }

let make_query ?start_date ?end_date symbol : Data_source.bar_query =
  { symbol; period = Types.Cadence.Daily; start_date; end_date }

(* Write bars directly to the cache using Csv_storage *)
let write_cache data_dir symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> failwith ("write_cache: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> failwith ("write_cache save: " ^ Status.show e)
      | Ok () -> ())

(* Write a universe sexp file *)
let write_universe data_dir instruments =
  let module Universe = struct
    type t = Types.Instrument_info.t list [@@deriving sexp]
  end in
  let path = Fpath.(v data_dir / "universe.sexp") in
  match File_sexp.Sexp.save (module Universe) instruments ~path with
  | Error e -> failwith ("write_universe: " ^ Status.show e)
  | Ok () -> ()

let make_instrument symbol sector : Types.Instrument_info.t =
  {
    symbol;
    name = symbol ^ " Inc";
    sector;
    industry = "Test";
    market_cap = 1e6;
    exchange = "NYSE";
  }

let make_ds dir simulation_date =
  let config : Historical_source.config = { data_dir = dir; simulation_date } in
  Historical_source.make config

(* --- no-lookahead --- *)

let test_no_lookahead_hides_future_bars _ =
  with_temp_dir (fun dir ->
      (* 10 bars in 2022 (past) and 5 bars in 2023-Jul (future) *)
      let bars =
        List.init 10 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2022 ~m:Month.Jan ~d:(3 + i)) 100.0)
        @ List.init 5 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2023 ~m:Month.Jul ~d:(1 + i)) 200.0)
      in
      write_cache dir "AAPL" bars;
      let simulation_date = Date.create_exn ~y:2023 ~m:Month.Jun ~d:30 in
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that result
        (is_ok_and_holds (fun returned -> assert_that returned (size_is 10))))

(* Bar exactly on simulation_date is visible *)
let test_boundary_inclusive _ =
  with_temp_dir (fun dir ->
      let simulation_date = Date.create_exn ~y:2023 ~m:Month.Jun ~d:30 in
      let bars = [ make_bar simulation_date 150.0 ] in
      write_cache dir "AAPL" bars;
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that result
        (is_ok_and_holds (fun returned -> assert_that returned (size_is 1))))

(* Bar one day after simulation_date is invisible *)
let test_boundary_exclusive _ =
  with_temp_dir (fun dir ->
      let simulation_date = Date.create_exn ~y:2023 ~m:Month.Jun ~d:30 in
      let next_day = Date.add_days simulation_date 1 in
      let bars = [ make_bar next_day 150.0 ] in
      write_cache dir "AAPL" bars;
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that result
        (is_ok_and_holds (fun returned -> assert_that returned is_empty)))

(* All cached bars are in the future — returns empty, not an error *)
let test_all_bars_in_future _ =
  with_temp_dir (fun dir ->
      let bars =
        List.init 5 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2025 ~m:Month.Jan ~d:(2 + i)) 300.0)
      in
      write_cache dir "AAPL" bars;
      let simulation_date = Date.create_exn ~y:2022 ~m:Month.Jan ~d:1 in
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that result
        (is_ok_and_holds (fun returned -> assert_that returned is_empty)))

(* --- end_date clamping --- *)

(* An explicit end_date beyond simulation_date is silently clamped *)
let test_end_date_beyond_simulation_clamped _ =
  with_temp_dir (fun dir ->
      let bars =
        List.init 5 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2022 ~m:Month.Jan ~d:(3 + i)) 100.0)
      in
      write_cache dir "AAPL" bars;
      let simulation_date = Date.create_exn ~y:2022 ~m:Month.Jan ~d:5 in
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let end_date = Date.create_exn ~y:2030 ~m:Month.Dec ~d:31 in
      let result =
        run_deferred (DS.get_bars ~query:(make_query "AAPL" ~end_date) ())
      in
      assert_that result
        (is_ok_and_holds (fun returned ->
             assert_bool "end_date clamped to simulation_date"
               (List.for_all returned ~f:(fun b ->
                    Date.compare b.Types.Daily_price.date simulation_date <= 0)))))

(* An explicit end_date before simulation_date is respected as-is *)
let test_end_date_before_simulation_respected _ =
  with_temp_dir (fun dir ->
      let bars =
        List.init 5 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2022 ~m:Month.Jan ~d:(3 + i)) 100.0)
      in
      write_cache dir "AAPL" bars;
      let simulation_date = Date.create_exn ~y:2022 ~m:Month.Jan ~d:10 in
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      (* Only request up to the 4th bar *)
      let end_date = Date.create_exn ~y:2022 ~m:Month.Jan ~d:6 in
      let result =
        run_deferred (DS.get_bars ~query:(make_query "AAPL" ~end_date) ())
      in
      assert_that result
        (is_ok_and_holds (fun returned -> assert_that returned (size_is 4))))

(* --- start_date filtering --- *)

let test_start_date_combined_with_simulation_date _ =
  with_temp_dir (fun dir ->
      let bars =
        List.init 10 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2022 ~m:Month.Jan ~d:(3 + i)) 100.0)
      in
      write_cache dir "AAPL" bars;
      let simulation_date = Date.create_exn ~y:2022 ~m:Month.Jan ~d:12 in
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      (* start at the 5th bar — should return bars 5–10 (6 bars), all <= simulation_date *)
      let start_date = Date.create_exn ~y:2022 ~m:Month.Jan ~d:7 in
      let result =
        run_deferred (DS.get_bars ~query:(make_query "AAPL" ~start_date) ())
      in
      assert_that result
        (is_ok_and_holds (fun returned -> assert_that returned (size_is 6))))

(* --- missing data --- *)

(* Unknown symbol returns empty list, not an error *)
let test_unknown_symbol_returns_empty _ =
  with_temp_dir (fun dir ->
      let simulation_date = Date.create_exn ~y:2023 ~m:Month.Jan ~d:1 in
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result =
        run_deferred (DS.get_bars ~query:(make_query "UNKNOWN") ())
      in
      assert_that result
        (is_ok_and_holds (fun returned -> assert_that returned is_empty)))

(* --- universe --- *)

let test_universe_loaded _ =
  with_temp_dir (fun dir ->
      let instruments = [ make_instrument "SPY" "ETF" ] in
      write_universe dir instruments;
      let simulation_date = Date.create_exn ~y:2023 ~m:Month.Jan ~d:1 in
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_universe ()) in
      assert_that result
        (is_ok_and_holds (fun loaded ->
             assert_that loaded
               (equal_to (instruments : Types.Instrument_info.t list)))))

(* Universe file absent returns empty list, not an error *)
let test_universe_absent_returns_empty _ =
  with_temp_dir (fun dir ->
      let simulation_date = Date.create_exn ~y:2023 ~m:Month.Jan ~d:1 in
      let ds = make_ds dir simulation_date in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_universe ()) in
      assert_that result
        (is_ok_and_holds (fun loaded -> assert_that loaded is_empty)))

(* --- simulation stepping semantics --- *)

(* Two different simulation_dates over the same data give different results,
   demonstrating how the engine steps through time by updating simulation_date. *)
let test_step_by_step_gives_different_views _ =
  with_temp_dir (fun dir ->
      let bars =
        List.init 5 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2022 ~m:Month.Jan ~d:(3 + i)) 100.0)
      in
      write_cache dir "AAPL" bars;
      (* Step t=Jan-05: only 3 bars visible *)
      let ds_t0 = make_ds dir (Date.create_exn ~y:2022 ~m:Month.Jan ~d:5) in
      let module DS0 = (val ds_t0 : Data_source.DATA_SOURCE) in
      let result0 = run_deferred (DS0.get_bars ~query:(make_query "AAPL") ()) in
      (* Step t=Jan-07: all 5 bars visible *)
      let ds_t1 = make_ds dir (Date.create_exn ~y:2022 ~m:Month.Jan ~d:7) in
      let module DS1 = (val ds_t1 : Data_source.DATA_SOURCE) in
      let result1 = run_deferred (DS1.get_bars ~query:(make_query "AAPL") ()) in
      assert_that result0
        (is_ok_and_holds (fun returned -> assert_that returned (size_is 3)));
      assert_that result1
        (is_ok_and_holds (fun returned -> assert_that returned (size_is 5))))

let suite =
  "historical_source_test"
  >::: [
         "no_lookahead_hides_future_bars"
         >:: test_no_lookahead_hides_future_bars;
         "boundary_inclusive" >:: test_boundary_inclusive;
         "boundary_exclusive" >:: test_boundary_exclusive;
         "all_bars_in_future" >:: test_all_bars_in_future;
         "end_date_beyond_simulation_clamped"
         >:: test_end_date_beyond_simulation_clamped;
         "end_date_before_simulation_respected"
         >:: test_end_date_before_simulation_respected;
         "start_date_combined_with_simulation_date"
         >:: test_start_date_combined_with_simulation_date;
         "unknown_symbol_returns_empty" >:: test_unknown_symbol_returns_empty;
         "universe_loaded" >:: test_universe_loaded;
         "universe_absent_returns_empty" >:: test_universe_absent_returns_empty;
         "step_by_step_gives_different_views"
         >:: test_step_by_step_gives_different_views;
       ]

let () = run_test_tt_main suite
