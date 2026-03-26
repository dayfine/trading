open Core
open OUnit2
open Matchers

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)

(* Create a temp dir and clean it up after the test *)
let with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_live_source" "" in
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

let make_ds config = run_deferred (Live_source.make config)

let default_config dir =
  {
    (Live_source.default_config ~token:"unused") with
    Live_source.data_dir = dir;
  }

let test_bar_query_show _ =
  let query : Data_source.bar_query =
    {
      symbol = "AAPL";
      period = Types.Cadence.Weekly;
      start_date = None;
      end_date = None;
    }
  in
  let s = Data_source.show_bar_query query in
  assert_bool "show_bar_query contains symbol"
    (String.is_substring s ~substring:"AAPL");
  assert_bool "show_bar_query contains period"
    (String.is_substring s ~substring:"Weekly")

(* Cache is current (last bar = today) — all bars returned, no fetch needed *)
let test_live_cache_hit _ =
  with_temp_dir (fun dir ->
      let today = Date.today ~zone:Time_float.Zone.utc in
      let bars =
        [
          make_bar (Date.add_days today (-4)) 100.0;
          make_bar (Date.add_days today (-3)) 101.0;
          make_bar (Date.add_days today (-2)) 102.0;
          make_bar (Date.add_days today (-1)) 103.0;
          make_bar today 104.0;
        ]
      in
      write_cache dir "AAPL" bars;
      let module DS =
        (val make_ds (default_config dir) : Data_source.DATA_SOURCE)
      in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that result
        (is_ok_and_holds (fun returned ->
             assert_that returned (equal_to (bars : Types.Daily_price.t list)))))

(* Fresh cache (last bar = yesterday) — still current, no refetch *)
let test_live_fresh_cache_no_refetch _ =
  with_temp_dir (fun dir ->
      let yesterday =
        Date.add_days (Date.today ~zone:Time_float.Zone.utc) (-1)
      in
      let cached_bar = make_bar yesterday 100.0 in
      write_cache dir "AAPL" [ cached_bar ];
      let fetch_called = ref false in
      let fake_fetch _uri =
        fetch_called := true;
        Async.return (Ok "[]")
      in
      let config =
        {
          (Live_source.default_config ~token:"fake") with
          Live_source.data_dir = dir;
        }
      in
      let module DS =
        (val run_deferred (Live_source.make ~fetch:fake_fetch config)
            : Data_source.DATA_SOURCE)
      in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that !fetch_called (equal_to false);
      assert_that result
        (is_ok_and_holds (fun returned ->
             assert_that returned
               (equal_to ([ cached_bar ] : Types.Daily_price.t list)))))

(* Stale cache — last bar is old, triggers refetch and returns fresh data *)
let test_live_stale_cache_refetches _ =
  with_temp_dir (fun dir ->
      let old_date =
        Date.add_days (Date.today ~zone:Time_float.Zone.utc) (-5)
      in
      write_cache dir "AAPL" [ make_bar old_date 99.0 ];
      let today = Date.today ~zone:Time_float.Zone.utc in
      let fresh_bar =
        {
          Types.Daily_price.date = today;
          open_price = 100.0;
          high_price = 101.0;
          low_price = 99.0;
          close_price = 100.0;
          adjusted_close = 100.0;
          volume = 1000;
        }
      in
      let fake_json =
        Printf.sprintf
          {|[{"date":"%s","open":100.0,"high":101.0,"low":99.0,"close":100.0,"adjusted_close":100.0,"volume":1000}]|}
          (Date.to_string today)
      in
      let fetch_called = ref false in
      let fake_fetch _uri =
        fetch_called := true;
        Async.return (Ok fake_json)
      in
      let config =
        {
          (Live_source.default_config ~token:"fake") with
          Live_source.data_dir = dir;
        }
      in
      let module DS =
        (val run_deferred (Live_source.make ~fetch:fake_fetch config)
            : Data_source.DATA_SOURCE)
      in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that !fetch_called (equal_to true);
      assert_that result
        (is_ok_and_holds (fun returned ->
             assert_that returned
               (equal_to ([ fresh_bar ] : Types.Daily_price.t list)))))

(* No cache — fetch is called, result written to disk, second call hits cache *)
let test_live_cache_write _ =
  with_temp_dir (fun dir ->
      let today = Date.today ~zone:Time_float.Zone.utc in
      let expected_bar =
        {
          Types.Daily_price.date = today;
          open_price = 50.0;
          high_price = 52.0;
          low_price = 49.0;
          close_price = 51.0;
          adjusted_close = 51.0;
          volume = 2000;
        }
      in
      let fake_json =
        Printf.sprintf
          {|[{"date":"%s","open":50.0,"high":52.0,"low":49.0,"close":51.0,"adjusted_close":51.0,"volume":2000}]|}
          (Date.to_string today)
      in
      let fetch_count = ref 0 in
      let fake_fetch _uri =
        Int.incr fetch_count;
        Async.return (Ok fake_json)
      in
      let config =
        {
          (Live_source.default_config ~token:"fake") with
          Live_source.data_dir = dir;
        }
      in
      let module DS =
        (val run_deferred (Live_source.make ~fetch:fake_fetch config)
            : Data_source.DATA_SOURCE)
      in
      let result = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that result
        (is_ok_and_holds (fun bars ->
             assert_that bars
               (equal_to ([ expected_bar ] : Types.Daily_price.t list))));
      let cache_path = Filename.concat dir "A/L/AAPL/data.csv" in
      assert_bool "cache file created" (Sys_unix.file_exists_exn cache_path);
      (* Second call — cache is now current, fetch should not be called again *)
      let result2 = run_deferred (DS.get_bars ~query:(make_query "AAPL") ()) in
      assert_that !fetch_count (equal_to 1);
      assert_that result2
        (is_ok_and_holds (fun bars ->
             assert_that bars
               (equal_to ([ expected_bar ] : Types.Daily_price.t list)))))

(* start_date filter — only bars on or after start_date returned *)
let test_live_cache_date_range _ =
  with_temp_dir (fun dir ->
      let today = Date.today ~zone:Time_float.Zone.utc in
      let bars =
        [
          make_bar (Date.add_days today (-4)) 100.0;
          make_bar (Date.add_days today (-3)) 101.0;
          make_bar (Date.add_days today (-2)) 102.0;
          make_bar (Date.add_days today (-1)) 103.0;
          make_bar today 104.0;
        ]
      in
      write_cache dir "AAPL" bars;
      let module DS =
        (val make_ds (default_config dir) : Data_source.DATA_SOURCE)
      in
      let start = Date.add_days today (-2) in
      let result =
        run_deferred
          (DS.get_bars ~query:(make_query ~start_date:start "AAPL") ())
      in
      assert_that result
        (is_ok_and_holds (fun returned ->
             assert_that returned
               (elements_are
                  [
                    equal_to
                      (make_bar (Date.add_days today (-2)) 102.0
                        : Types.Daily_price.t);
                    equal_to
                      (make_bar (Date.add_days today (-1)) 103.0
                        : Types.Daily_price.t);
                    equal_to (make_bar today 104.0 : Types.Daily_price.t);
                  ]))))

(* Universe loaded from sexp file *)
let test_live_universe_from_sexp _ =
  with_temp_dir (fun dir ->
      let instruments =
        [ make_instrument "AAPL" "Technology"; make_instrument "XOM" "Energy" ]
      in
      write_universe dir instruments;
      let module DS =
        (val make_ds (default_config dir) : Data_source.DATA_SOURCE)
      in
      let result = run_deferred (DS.get_universe ()) in
      assert_that result
        (is_ok_and_holds (fun loaded ->
             assert_that loaded
               (elements_are
                  [
                    equal_to
                      (make_instrument "AAPL" "Technology"
                        : Types.Instrument_info.t);
                    equal_to
                      (make_instrument "XOM" "Energy" : Types.Instrument_info.t);
                  ]))))

(* No universe file — returns empty list rather than error *)
let test_live_universe_absent _ =
  with_temp_dir (fun dir ->
      let module DS =
        (val make_ds (default_config dir) : Data_source.DATA_SOURCE)
      in
      let result = run_deferred (DS.get_universe ()) in
      assert_that result
        (is_ok_and_holds (fun loaded -> assert_that loaded is_empty)))

let suite =
  "live_source_test"
  >::: [
         "bar_query_show" >:: test_bar_query_show;
         "live_cache_hit" >:: test_live_cache_hit;
         "live_fresh_cache_no_refetch" >:: test_live_fresh_cache_no_refetch;
         "live_stale_cache_refetches" >:: test_live_stale_cache_refetches;
         "live_cache_write" >:: test_live_cache_write;
         "live_cache_date_range" >:: test_live_cache_date_range;
         "live_universe_from_sexp" >:: test_live_universe_from_sexp;
         "live_universe_absent" >:: test_live_universe_absent;
       ]

let () = run_test_tt_main suite
