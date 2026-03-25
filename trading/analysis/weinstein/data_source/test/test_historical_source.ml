open Core
open OUnit2

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
  { symbol; name = symbol ^ " Inc"; sector; industry = "Test"; market_cap = 1e6; exchange = "NYSE" }

let test_historical_no_lookahead _ =
  with_temp_dir (fun dir ->
      (* Write bars from 2022-01-03..2022-01-12 and 2023-07-01..2023-07-05 *)
      let bars =
        List.init 10 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2022 ~m:Month.Jan ~d:(3 + i)) 100.0)
        @ List.init 5 ~f:(fun i ->
              make_bar
                (Date.create_exn ~y:2023 ~m:Month.Jul ~d:(1 + i))
                200.0)
      in
      write_cache dir "AAPL" bars;
      let simulation_date = Date.create_exn ~y:2023 ~m:Month.Jun ~d:30 in
      let config : Historical_source.config = { data_dir = dir; simulation_date } in
      let ds = Historical_source.make config in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      match result with
      | Error e -> assert_failure (Status.show e)
      | Ok returned ->
          (* Only 2022 bars should be visible; 2023-Jul bars are beyond simulation_date *)
          assert_bool "no future bars"
            (List.for_all returned ~f:(fun b ->
                 Date.compare b.Types.Daily_price.date simulation_date <= 0));
          assert_equal ~printer:Int.to_string 10 (List.length returned))

let test_historical_end_date_clamped _ =
  with_temp_dir (fun dir ->
      let bars =
        List.init 5 ~f:(fun i ->
            make_bar (Date.create_exn ~y:2022 ~m:Month.Jan ~d:(3 + i)) 100.0)
      in
      write_cache dir "AAPL" bars;
      let simulation_date = Date.create_exn ~y:2022 ~m:Month.Jan ~d:5 in
      let config : Historical_source.config = { data_dir = dir; simulation_date } in
      let ds = Historical_source.make config in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      (* Request up to 2030 — should be clamped to simulation_date *)
      let end_date = Date.create_exn ~y:2030 ~m:Month.Dec ~d:31 in
      let result =
        run_deferred (DS.get_bars ~query:(make_query "AAPL" ~end_date) ())
      in
      match result with
      | Error e -> assert_failure (Status.show e)
      | Ok returned ->
          assert_bool "end_date clamped to simulation_date"
            (List.for_all returned ~f:(fun b ->
                 Date.compare b.Types.Daily_price.date simulation_date <= 0)))

let test_historical_universe _ =
  with_temp_dir (fun dir ->
      let instruments = [ make_instrument "SPY" "ETF" ] in
      write_universe dir instruments;
      let simulation_date = Date.create_exn ~y:2023 ~m:Month.Jan ~d:1 in
      let config : Historical_source.config = { data_dir = dir; simulation_date } in
      let ds = Historical_source.make config in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_universe ()) in
      match result with
      | Error e -> assert_failure (Status.show e)
      | Ok loaded ->
          assert_equal ~printer:Int.to_string 1 (List.length loaded);
          assert_equal ~printer:Fn.id "SPY" (List.hd_exn loaded).symbol)

let suite =
  "historical_source_test"
  >::: [
         "historical_no_lookahead" >:: test_historical_no_lookahead;
         "historical_end_date_clamped" >:: test_historical_end_date_clamped;
         "historical_universe" >:: test_historical_universe;
       ]

let () = run_test_tt_main suite
