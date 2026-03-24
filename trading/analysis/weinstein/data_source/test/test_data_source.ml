open Core
open OUnit2

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)

(* Create a temp dir and clean it up after the test *)
let with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_data_source" "" in
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
  {
    symbol;
    period = Types.Cadence.Daily;
    start_date;
    end_date;
  }

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

(* ---- Live source tests ---- *)

let test_live_cache_hit _ =
  with_temp_dir (fun dir ->
      let today = Date.today ~zone:Time_float.Zone.utc in
      let bars =
        [ make_bar (Date.add_days today (-4)) 100.0
        ; make_bar (Date.add_days today (-3)) 101.0
        ; make_bar (Date.add_days today (-2)) 102.0
        ; make_bar (Date.add_days today (-1)) 103.0
        ; make_bar today 104.0
        ]
      in
      write_cache dir "AAPL" bars;
      let config = Live_source.default_config ~token:"unused" in
      let config = { config with Live_source.data_dir = dir } in
      let ds = run_deferred (Live_source.make config) in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      match result with
      | Error e -> assert_failure ("Unexpected error: " ^ Status.show e)
      | Ok returned ->
          assert_equal ~printer:Int.to_string (List.length bars)
            (List.length returned);
          let last = List.last_exn returned in
          assert_equal ~printer:Date.to_string today last.Types.Daily_price.date)

let test_live_cache_write _ =
  (* Inject a fake fetch_fn that returns a minimal EODHD JSON response *)
  with_temp_dir (fun dir ->
      let today = Date.today ~zone:Time_float.Zone.utc in
      let date_str = Date.to_string today in
      let fake_json =
        Printf.sprintf
          {|[{"date":"%s","open":50.0,"high":52.0,"low":49.0,"close":51.0,"adjusted_close":51.0,"volume":2000}]|}
          date_str
      in
      let fake_fetch _uri = Async.return (Ok fake_json) in
      let config = { (Live_source.default_config ~token:"fake") with Live_source.data_dir = dir } in
      let ds = run_deferred (Live_source.make ~fetch:fake_fetch config) in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      (match result with
      | Error e -> assert_failure ("Unexpected fetch error: " ^ Status.show e)
      | Ok bars ->
          assert_equal ~printer:Int.to_string 1 (List.length bars);
          let bar = List.hd_exn bars in
          assert_equal ~printer:Date.to_string today bar.Types.Daily_price.date);
      (* Verify the bar was written to the cache at the expected path *)
      let cache_path =
        Filename.concat dir
          (Printf.sprintf "A/L/AAPL/data.csv")
      in
      assert_bool "cache file created" (Sys_unix.file_exists_exn cache_path))

let test_live_stale_cache_refetches _ =
  (* A cache whose last bar is old (2 days ago or more) should trigger a refetch *)
  with_temp_dir (fun dir ->
      let old_date = Date.add_days (Date.today ~zone:Time_float.Zone.utc) (-5) in
      write_cache dir "AAPL" [ make_bar old_date 99.0 ];
      let today = Date.today ~zone:Time_float.Zone.utc in
      let date_str = Date.to_string today in
      let fake_json =
        Printf.sprintf
          {|[{"date":"%s","open":100.0,"high":101.0,"low":99.0,"close":100.0,"adjusted_close":100.0,"volume":1000}]|}
          date_str
      in
      let fetch_called = ref false in
      let fake_fetch _uri =
        fetch_called := true;
        Async.return (Ok fake_json)
      in
      let config = { (Live_source.default_config ~token:"fake") with Live_source.data_dir = dir } in
      let ds = run_deferred (Live_source.make ~fetch:fake_fetch config) in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let _ = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_bool "stale cache triggers refetch" !fetch_called)

let test_live_universe_from_sexp _ =
  with_temp_dir (fun dir ->
      let instruments =
        [ make_instrument "AAPL" "Technology"
        ; make_instrument "XOM" "Energy"
        ]
      in
      write_universe dir instruments;
      let config = { (Live_source.default_config ~token:"unused") with Live_source.data_dir = dir } in
      let ds = run_deferred (Live_source.make config) in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_universe ()) in
      match result with
      | Error e -> assert_failure (Status.show e)
      | Ok loaded ->
          assert_equal ~printer:Int.to_string 2 (List.length loaded);
          assert_equal ~printer:Fn.id "AAPL" (List.hd_exn loaded).symbol;
          assert_equal ~printer:Fn.id "Technology" (List.hd_exn loaded).sector)

let test_live_universe_absent _ =
  with_temp_dir (fun dir ->
      let config = { (Live_source.default_config ~token:"unused") with Live_source.data_dir = dir } in
      let ds = run_deferred (Live_source.make config) in
      let module DS = (val ds : Data_source.DATA_SOURCE) in
      let result = run_deferred (DS.get_universe ()) in
      match result with
      | Error e -> assert_failure (Status.show e)
      | Ok loaded -> assert_equal ~printer:Int.to_string 0 (List.length loaded))

(* ---- Historical source tests ---- *)

let test_historical_no_lookahead _ =
  with_temp_dir (fun dir ->
      (* Write bars from 2022-01-03 to 2023-06-30 *)
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
          assert_bool "no future bars" (List.for_all returned ~f:(fun b ->
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

let test_bar_query_show _ =
  let query : Data_source.bar_query =
    { symbol = "AAPL"; period = Types.Cadence.Weekly; start_date = None; end_date = None }
  in
  let s = Data_source.show_bar_query query in
  assert_bool "show_bar_query contains symbol"
    (String.is_substring s ~substring:"AAPL")

let suite =
  "data_source_test"
  >::: [
         "bar_query_show" >:: test_bar_query_show;
         "live_cache_hit" >:: test_live_cache_hit;
         "live_cache_write" >:: test_live_cache_write;
         "live_stale_cache_refetches" >:: test_live_stale_cache_refetches;
         "live_universe_from_sexp" >:: test_live_universe_from_sexp;
         "live_universe_absent" >:: test_live_universe_absent;
         "historical_no_lookahead" >:: test_historical_no_lookahead;
         "historical_end_date_clamped" >:: test_historical_end_date_clamped;
         "historical_universe" >:: test_historical_universe;
       ]

let () = run_test_tt_main suite
