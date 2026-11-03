(** A stop level stored with float noise still triggers on a bar that prints at
    it to the cent (issue #3505).

    Specimen SGNT-wein-703: the stop is stored as [23.759999999999998] and the
    2014-08-04 low is [23.76]. A bare [low <= stop] missed it and the stop fired
    a day late. {!Weinstein_stops.check_stop_hit} and
    {!Weinstein_stops.Catastrophic_stop.check_hit} compare through
    {!Trading_base.Stop_trigger}, so the noise is absorbed while a price one
    tick short of the stop still does not trigger. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_stops
open Matchers

let _sgnt_stop = 23.759999999999998

let _bar ~low ~high =
  Types.Daily_price.
    {
      date = Date.of_string "2014-08-04";
      open_price = 24.0;
      high_price = high;
      low_price = low;
      close_price = 24.0;
      volume = 1_000_000;
      adjusted_close = 24.0;
      active_through = None;
    }

let _hit side ~low ~high =
  check_stop_hit
    ~state:(Initial { stop_level = _sgnt_stop; reference_level = 25.0 })
    ~side ~bar:(_bar ~low ~high) ()

let test_check_stop_hit_sgnt _ =
  assert_that
    [
      _hit Long ~low:23.76 ~high:24.5;
      _hit Long ~low:23.77 ~high:24.5;
      _hit Long ~low:23.80 ~high:24.5;
      _hit Short ~low:23.0 ~high:23.76;
      _hit Short ~low:23.0 ~high:23.75;
    ]
    (equal_to [ true; false; false; true; false ])

(* Catastrophic level = trailing_high * (1 - pct): 26.4 * 0.1 off gives float
   noise around 23.76. A low at 23.76 triggers it; 23.77 does not. *)
let test_catastrophic_hit_sgnt _ =
  let hit ~low =
    Catastrophic_stop.check_hit ~armed:true ~pct:0.1 ~trailing_high:26.4
      ~bar:(_bar ~low ~high:24.5) ~side:Long
  in
  assert_that [ hit ~low:23.76; hit ~low:23.77 ] (equal_to [ true; false ])

let suite =
  "stop_hit_float_noise"
  >::: [
         "SGNT stop hit by low 23.76, not 23.77" >:: test_check_stop_hit_sgnt;
         "catastrophic SGNT level hit by low 23.76"
         >:: test_catastrophic_hit_sgnt;
       ]

let () = run_test_tt_main suite
