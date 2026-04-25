open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module BA2 = Bigarray.Array2

let _make_idx universe =
  match Symbol_index.create ~universe with
  | Ok t -> t
  | Error err ->
      assert_failure (Printf.sprintf "create failed: %s" err.Status.message)

let _make_price ~date_str ~open_ ~high ~low ~close ~volume () :
    Types.Daily_price.t =
  {
    date = Date.of_string date_str;
    open_price = open_;
    high_price = high;
    low_price = low;
    close_price = close;
    volume;
    adjusted_close = close;
  }

let test_create_initializes_to_nan _ =
  let idx = _make_idx [ "AAPL"; "MSFT" ] in
  let panels = Ohlcv_panels.create idx ~n_days:5 in
  assert_that panels
    (all_of
       [
         field Ohlcv_panels.n (equal_to 2);
         field Ohlcv_panels.n_days (equal_to 5);
         field
           (fun p -> Float.is_nan (BA2.get (Ohlcv_panels.close p) 0 0))
           (equal_to true);
         field
           (fun p -> Float.is_nan (BA2.get (Ohlcv_panels.close p) 1 4))
           (equal_to true);
         field
           (fun p -> Float.is_nan (BA2.get (Ohlcv_panels.volume p) 0 2))
           (equal_to true);
       ])

let test_write_row_populates_all_panels _ =
  let idx = _make_idx [ "AAPL"; "MSFT" ] in
  let panels = Ohlcv_panels.create idx ~n_days:3 in
  let p =
    _make_price ~date_str:"2024-01-02" ~open_:100.0 ~high:105.0 ~low:99.0
      ~close:102.5 ~volume:1_000_000 ()
  in
  Ohlcv_panels.write_row panels ~symbol_index:0 ~day:1 p;
  assert_that panels
    (all_of
       [
         field
           (fun pp -> BA2.get (Ohlcv_panels.open_ pp) 0 1)
           (float_equal 100.0);
         field
           (fun pp -> BA2.get (Ohlcv_panels.high pp) 0 1)
           (float_equal 105.0);
         field (fun pp -> BA2.get (Ohlcv_panels.low pp) 0 1) (float_equal 99.0);
         field
           (fun pp -> BA2.get (Ohlcv_panels.close pp) 0 1)
           (float_equal 102.5);
         field
           (fun pp -> BA2.get (Ohlcv_panels.volume pp) 0 1)
           (float_equal 1_000_000.0);
         (* unwritten cells remain NaN *)
         field
           (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 0 0))
           (equal_to true);
         field
           (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 1 1))
           (equal_to true);
       ])

let test_write_row_out_of_bounds _ =
  let idx = _make_idx [ "AAPL" ] in
  let panels = Ohlcv_panels.create idx ~n_days:2 in
  let p =
    _make_price ~date_str:"2024-01-01" ~open_:100.0 ~high:101.0 ~low:99.0
      ~close:100.5 ~volume:10_000 ()
  in
  assert_raises
    (Invalid_argument
       "Ohlcv_panels.write_row: symbol_index 5 out of range [0, 1)") (fun () ->
      Ohlcv_panels.write_row panels ~symbol_index:5 ~day:0 p);
  assert_raises
    (Invalid_argument "Ohlcv_panels.write_row: day 9 out of range [0, 2)")
    (fun () -> Ohlcv_panels.write_row panels ~symbol_index:0 ~day:9 p)

(* Build a synthetic CSV directory layout matching Csv_storage.symbol_data_dir
   ([data_dir/first/last/symbol/data.csv]) so that load_from_csv can read it. *)
let _write_csv ~data_dir ~symbol prices =
  let storage =
    match Csv.Csv_storage.create ~data_dir symbol with
    | Ok s -> s
    | Error err ->
        assert_failure
          (Printf.sprintf "csv create failed: %s" err.Status.message)
  in
  match Csv.Csv_storage.save storage prices with
  | Ok () -> ()
  | Error err ->
      assert_failure (Printf.sprintf "csv save failed: %s" err.Status.message)

let test_load_from_csv_three_symbols _ =
  let data_dir = Fpath.v (Core_unix.mkdtemp "/tmp/data_panel_load_test_") in
  let aapl_prices =
    [
      _make_price ~date_str:"2024-01-02" ~open_:100.0 ~high:101.0 ~low:99.0
        ~close:100.5 ~volume:1000 ();
      _make_price ~date_str:"2024-01-03" ~open_:101.0 ~high:102.0 ~low:100.0
        ~close:101.5 ~volume:1100 ();
    ]
  in
  let msft_prices =
    [
      _make_price ~date_str:"2024-01-02" ~open_:200.0 ~high:202.0 ~low:198.0
        ~close:201.0 ~volume:5000 ();
    ]
  in
  (* GOOG has no CSV — its rows must remain NaN. *)
  _write_csv ~data_dir ~symbol:"AAPL" aapl_prices;
  _write_csv ~data_dir ~symbol:"MSFT" msft_prices;
  let idx = _make_idx [ "AAPL"; "MSFT"; "GOOG" ] in
  let result =
    Data_panel.Ohlcv_panels.load_from_csv idx ~data_dir
      ~start_date:(Date.of_string "2024-01-01")
      ~n_days:5
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field Ohlcv_panels.n (equal_to 3);
            field Ohlcv_panels.n_days (equal_to 5);
            (* AAPL row 0: days 0 and 1 populated, days 2..4 NaN *)
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 0 0)
              (float_equal 100.5);
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 0 1)
              (float_equal 101.5);
            field
              (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 0 2))
              (equal_to true);
            field
              (fun pp -> BA2.get (Ohlcv_panels.volume pp) 0 0)
              (float_equal 1000.0);
            (* MSFT row 1: day 0 populated *)
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 1 0)
              (float_equal 201.0);
            field
              (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 1 1))
              (equal_to true);
            (* GOOG row 2: all NaN *)
            field
              (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 2 0))
              (equal_to true);
            field
              (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 2 4))
              (equal_to true);
          ]))

let suite =
  "Ohlcv_panels tests"
  >::: [
         "test_create_initializes_to_nan" >:: test_create_initializes_to_nan;
         "test_write_row_populates_all_panels"
         >:: test_write_row_populates_all_panels;
         "test_write_row_out_of_bounds" >:: test_write_row_out_of_bounds;
         "test_load_from_csv_three_symbols" >:: test_load_from_csv_three_symbols;
       ]

let () = run_test_tt_main suite
