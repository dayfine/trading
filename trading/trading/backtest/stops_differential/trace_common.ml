(** Shared printing helpers, deterministic LCG and bar fixtures for the stops
    surface trace. See [stops_surface_trace.ml] for the rationale. *)

open Core
open Trading_base.Types
open Weinstein_stops

(* ---- printing ---- *)

(* [%.17g] round-trips an IEEE double exactly, so two traces agree only if every
   float agrees bit-for-bit. *)
let f x = Printf.sprintf "%.17g" x
let line s = Printf.printf "%s\n" s
let show_side = function Long -> "L" | Short -> "S"

let show_state = function
  | Initial { stop_level; reference_level } ->
      Printf.sprintf "Initial(%s|%s)" (f stop_level) (f reference_level)
  | Trailing
      {
        stop_level;
        last_correction_extreme;
        last_trend_extreme;
        ma_at_last_adjustment;
        correction_count;
        correction_observed_since_reset;
      } ->
      Printf.sprintf "Trailing(%s|%s|%s|%s|%d|%b)" (f stop_level)
        (f last_correction_extreme)
        (f last_trend_extreme) (f ma_at_last_adjustment) correction_count
        correction_observed_since_reset
  | Tightened { stop_level; last_correction_extreme; reason; _ } ->
      Printf.sprintf "Tightened(%s|%s|%S)" (f stop_level)
        (f last_correction_extreme)
        reason

let show_event = function
  | Stop_hit { trigger_price; stop_level } ->
      Printf.sprintf "Hit(%s|%s)" (f trigger_price) (f stop_level)
  | Stop_raised { old_level; new_level; reason } ->
      Printf.sprintf "Raised(%s|%s|%S)" (f old_level) (f new_level) reason
  | Entered_tightening { reason } -> Printf.sprintf "Tighten(%S)" reason
  | No_change -> "NoChange"

let show_basis = function
  | Flag_off -> "flag_off"
  | Adjusted -> "adjusted"
  | Raw_fallback -> "raw_fallback"
  | Empty_window -> "empty_window"

(* ---- deterministic pseudo-randomness ---- *)

(* A plain LCG on OCaml's 63-bit int, masked to 30 bits. No [Random] (its stream
   is not guaranteed stable across compiler versions) and no libm (whose last
   bit is not guaranteed stable across platforms), so the golden is portable. *)
let _lcg = ref 1

let _next () =
  _lcg := ((!_lcg * 1103515245) + 12345) land 0x3FFFFFFF;
  !_lcg

(* A value in [0, 1) with exactly 5 decimal digits — exact in binary terms only
   as a ratio of small integers, which is all we need for reproducibility. *)
let unit_float () = Float.of_int (_next () mod 100_000) /. 100_000.
let reseed n = _lcg := n

(* ---- fixtures ---- *)

let as_of = Date.of_string "2024-06-28"
let sides = [ Long; Short ]

let bar ~date ~o ~h ~l ~c ~adj =
  Types.Daily_price.
    {
      date;
      open_price = o;
      high_price = h;
      low_price = l;
      close_price = c;
      volume = 1_000_000;
      adjusted_close = adj;
      active_through = None;
    }

let flat_bar ~date ~l ~h ~c = bar ~date ~o:c ~h ~l ~c ~adj:c
