(** Issue #3136, strategy side: [liquidity_config.true_dollar_volume] defaults
    off (R1), is an axis via the real [Overlay_validator] (R2), and when on arms
    the strategy's bar reader with {!Backtest.True_dollar_divisor}, which reads
    [F(t)] from the symbol's [splits.csv] on the PIT ranking's rules. With it,
    the liquidity gates read raw close times raw volume: AMZN 2018-06-14 drops
    by its later 20:1, C 2010-06-14 rises by its later 1:10. *)

open OUnit2
open Core
open Matchers
module CA = Corporate_actions
module P = Backtest.Panel_corporate_actions
module BR = Weinstein_strategy.Bar_reader

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "AMZN" ] ~index_symbol:"GSPCX"

let _after overlays =
  Backtest.Overlay_validator.apply_overrides (_default_config ())
    (List.map overlays ~f:Sexp.of_string)

let _on = "((liquidity_config ((true_dollar_volume true))))"
let _off = "((liquidity_config ((true_dollar_volume false))))"

let test_flag_default_off_and_axis _ =
  let flag (c : Weinstein_strategy.config) =
    c.liquidity_config.true_dollar_volume
  in
  let armed config =
    Option.is_some (P.split_divisor ~config ~data_dir:(Fpath.v "/nonexistent"))
  in
  let on = _after [ _on ] in
  let off = _after [ _on; _off ] in
  assert_that
    [
      (flag (_default_config ()), armed (_default_config ()));
      (flag on, armed on);
      (flag off, armed off);
    ]
    (elements_are
       [
         equal_to (false, false); equal_to (true, true); equal_to (false, false);
       ])

let _tmp_dir () =
  let dir = Stdlib.Filename.temp_file "true_dollar_divisor_" ".d" in
  Stdlib.Sys.remove dir;
  Core_unix.mkdir_p dir;
  dir

(* Writes [symbol]'s data.csv ([(date, close, volume)] rows) and splits.csv. *)
let _write_symbol ~root ~symbol rows splits =
  let path = Universe.Composition_bar_reader.bars_path ~bars_root:root symbol in
  Core_unix.mkdir_p (Filename.dirname path);
  let line (d, c, v) = sprintf "%s,%f,%f,%f,%f,%f,%.0f" d c c c c c v in
  Out_channel.write_lines path
    ("date,open,high,low,close,adjusted_close,volume" :: List.map rows ~f:line);
  match CA.write_splits ~data_dir:(Fpath.v root) symbol splits with
  | Ok () -> ()
  | Error err -> assert_failure (Status.show err)

let _d = Date.of_string

(* AMZN as stored around its 2022-06-06 20:1 (raw close 2447 -> 124.79), and C
   around its 2011-05-09 1:10 reverse (4.52 -> 44.16). *)
let _fixture () =
  let root = _tmp_dir () in
  _write_symbol ~root ~symbol:"AMZN"
    [
      ("2018-06-14", 1723.86, 63_488_299.0);
      ("2022-06-03", 2447.0, 97_603_319.0);
      ("2022-06-06", 124.79, 135_268_984.0);
    ]
    [ { CA.date = _d "2022-06-06"; factor = 20.0 } ];
  _write_symbol ~root ~symbol:"C"
    [
      ("2010-06-14", 3.88, 38_228_780.0);
      ("2011-05-06", 4.52, 5_131_670.0);
      ("2011-05-09", 44.16, 49_168_100.0);
    ]
    [ { CA.date = _d "2011-05-09"; factor = 0.1 } ];
  Backtest.True_dollar_divisor.of_data_dir ~data_dir:(Fpath.v root)

let test_divisor_reads_applied_splits _ =
  let f = _fixture () in
  assert_that
    [
      f ~symbol:"AMZN" (_d "2018-06-14");
      f ~symbol:"AMZN" (_d "2022-06-06");
      f ~symbol:"C" (_d "2010-06-14");
      f ~symbol:"MISSING" (_d "2010-06-14");
    ]
    (elements_are
       [ float_equal 20.0; float_equal 1.0; float_equal 0.1; float_equal 1.0 ])

let _bar date ~close ~volume : Types.Daily_price.t =
  {
    date = _d date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

let _reader () =
  BR.of_in_memory_bars
    [
      ("AMZN", [ _bar "2018-06-14" ~close:1723.86 ~volume:63_488_299 ]);
      ("C", [ _bar "2010-06-14" ~close:3.88 ~volume:38_228_780 ]);
    ]

(* The one-bar dollar-ADV a liquidity gate reads, through the armed reader. *)
let _adv reader ~symbol ~as_of =
  Weinstein_strategy.Liquidity_metric.dollar_adv
    ?split_divisor:(BR.split_divisor_for reader ~symbol)
    ~lookback_days:20
    (BR.daily_bars_for reader ~symbol ~as_of:(_d as_of))

let test_armed_reader_reads_true_dollars _ =
  let config = _after [ _on ] in
  let ca = P.create ~config ~data_dir:(Fpath.v "/unused") in
  let armed =
    P.arm_bar_reader { ca with split_divisor = Some (_fixture ()) } (_reader ())
  in
  let plain = _reader () in
  assert_that
    [
      _adv plain ~symbol:"AMZN" ~as_of:"2018-06-14";
      _adv armed ~symbol:"AMZN" ~as_of:"2018-06-14";
      _adv plain ~symbol:"C" ~as_of:"2010-06-14";
      _adv armed ~symbol:"C" ~as_of:"2010-06-14";
    ]
    (elements_are
       [
         is_some_and (float_equal ~epsilon:1.0 (1723.86 *. 63_488_299.0));
         is_some_and
           (float_equal ~epsilon:1.0 (1723.86 *. 63_488_299.0 /. 20.0));
         is_some_and (float_equal ~epsilon:1.0 (3.88 *. 38_228_780.0));
         is_some_and (float_equal ~epsilon:1.0 (3.88 *. 38_228_780.0 /. 0.1));
       ])

let suite =
  "true_dollar_divisor"
  >::: [
         "flag default off and axis" >:: test_flag_default_off_and_axis;
         "divisor reads applied splits" >:: test_divisor_reads_applied_splits;
         "armed reader reads true dollars"
         >:: test_armed_reader_reads_true_dollars;
       ]

let () = run_test_tt_main suite
