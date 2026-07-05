(** Pure detection of the scale-in add trigger. See .mli. *)

open Core

type trigger = Pullback | Early_new_high | Either | Consolidation_breakout
[@@deriving sexp, eq, show]

(* Default pullback-touch band: a bar's low within 3% above the breakout level
   counts as the retest of the breakout zone. *)
let default_pullback_proximity_pct = 0.03

(* Default extension gate: no add when the close sits more than 15% above the
   30-week MA (price has outrun its own trend). *)
let default_extension_max_pct = 0.15

(* Consolidation-breakout defaults (book gives no numbers; all axes): a real
   zone spans at least 4 completed weeks, ranges no more than 10% top to
   bottom, sits within 10% above the 30-week MA, and the breakout bar carries
   at least 1.25x the window's average volume. *)
let default_consolidation_min_weeks = 4
let default_consolidation_band_pct = 0.10
let default_consolidation_ma_proximity_pct = 0.10
let default_consolidation_volume_ratio_min = 1.25

type consolidation_config = {
  min_weeks : int; [@sexp.default default_consolidation_min_weeks]
  band_pct : float; [@sexp.default default_consolidation_band_pct]
  ma_proximity_pct : float;
      [@sexp.default default_consolidation_ma_proximity_pct]
  volume_ratio_min : float;
      [@sexp.default default_consolidation_volume_ratio_min]
}
[@@deriving sexp, eq, show]

let default_consolidation_config =
  {
    min_weeks = default_consolidation_min_weeks;
    band_pct = default_consolidation_band_pct;
    ma_proximity_pct = default_consolidation_ma_proximity_pct;
    volume_ratio_min = default_consolidation_volume_ratio_min;
  }

type config = {
  initial_entry_fraction : float; [@sexp.default 1.0]
  max_adds : int; [@sexp.default 1]
  add_trigger : trigger; [@sexp.default Pullback]
  add_fraction : float option; [@sexp.default None]
  pullback_proximity_pct : float; [@sexp.default default_pullback_proximity_pct]
  extension_max_pct : float; [@sexp.default default_extension_max_pct]
  require_not_late : bool; [@sexp.default true]
  consolidation : consolidation_config;
      [@sexp.default default_consolidation_config]
}
[@@deriving sexp, eq, show]

let default_config =
  {
    initial_entry_fraction = 1.0;
    max_adds = 1;
    add_trigger = Pullback;
    add_fraction = None;
    pullback_proximity_pct = default_pullback_proximity_pct;
    extension_max_pct = default_extension_max_pct;
    require_not_late = true;
    consolidation = default_consolidation_config;
  }

(* Current bar + strictly-prior bars, both in chronological order collapsed to
   (current, rev_prior). [None] when fewer than two bars — a pullback or a
   continuation needs at least one full bar after the entry week. *)
let _split_current bars =
  match List.rev bars with
  | current :: (_ :: _ as rev_prior) -> Some (current, rev_prior)
  | _ -> None

(* Some prior bar's low touched the pullback zone. *)
let _touched_pullback_zone ~touch_level rev_prior =
  List.exists rev_prior ~f:(fun (b : Types.Daily_price.t) ->
      Float.( <= ) b.low_price touch_level)

(* The current bar holds the breakout level and turns back up. *)
let _held_and_turned ~entry_price ~(current : Types.Daily_price.t) ~rev_prior =
  let prev_close = (List.hd_exn rev_prior).Types.Daily_price.close_price in
  Float.( >= ) current.close_price entry_price
  && Float.( > ) current.close_price prev_close

let pullback_hold ~proximity_pct ~entry_price ~bars_since_entry =
  match _split_current bars_since_entry with
  | None -> false
  | Some (current, rev_prior) ->
      let touch_level = entry_price *. (1.0 +. proximity_pct) in
      _touched_pullback_zone ~touch_level rev_prior
      && _held_and_turned ~entry_price ~current ~rev_prior

let early_new_high ~entry_price ~bars_since_entry =
  match _split_current bars_since_entry with
  | None -> false
  | Some (current, rev_prior) ->
      let prior_max =
        List.fold rev_prior ~init:Float.neg_infinity
          ~f:(fun acc (b : Types.Daily_price.t) -> Float.max acc b.close_price)
      in
      Float.( > ) current.Types.Daily_price.close_price prior_max
      && Float.( > ) current.Types.Daily_price.close_price entry_price

(* The last [n] elements of [xs] (all of [xs] when shorter). *)
let _last_n xs n =
  let len = List.length xs in
  if len <= n then xs else List.drop xs (len - n)

(* Window predicates for the continuation buy. The window is the [min_weeks]
   completed bars immediately before the current (breakout-candidate) bar. *)
let _window_is_tight ~band_pct closes =
  let max_c = List.fold closes ~init:Float.neg_infinity ~f:Float.max in
  let min_c = List.fold closes ~init:Float.infinity ~f:Float.min in
  Float.( > ) max_c 0.0 && Float.( <= ) ((max_c -. min_c) /. max_c) band_pct

let _window_near_ma ~ma_proximity_pct ~ma closes =
  let min_c = List.fold closes ~init:Float.infinity ~f:Float.min in
  Float.( > ) ma 0.0 && Float.( <= ) min_c (ma *. (1.0 +. ma_proximity_pct))

let _breaks_out_on_volume ~volume_ratio_min ~(current : Types.Daily_price.t)
    window =
  let closes =
    List.map window ~f:(fun (b : Types.Daily_price.t) -> b.close_price)
  in
  let max_c = List.fold closes ~init:Float.neg_infinity ~f:Float.max in
  let avg_vol =
    List.fold window ~init:0.0 ~f:(fun acc (b : Types.Daily_price.t) ->
        acc +. Float.of_int b.volume)
    /. Float.of_int (List.length window)
  in
  Float.( > ) current.close_price max_c
  && Float.( >= ) (Float.of_int current.volume) (volume_ratio_min *. avg_vol)

let consolidation_breakout ~(consolidation : consolidation_config) ~ma
    ~bars_since_entry =
  match _split_current bars_since_entry with
  | None -> false
  | Some (current, rev_prior) ->
      let window = _last_n (List.rev rev_prior) consolidation.min_weeks in
      let closes =
        List.map window ~f:(fun (b : Types.Daily_price.t) -> b.close_price)
      in
      List.length window >= consolidation.min_weeks
      && _window_is_tight ~band_pct:consolidation.band_pct closes
      && _window_near_ma ~ma_proximity_pct:consolidation.ma_proximity_pct ~ma
           closes
      && _breaks_out_on_volume ~volume_ratio_min:consolidation.volume_ratio_min
           ~current window

let add_signal ~trigger ~proximity_pct ~consolidation ~ma ~entry_price
    ~bars_since_entry =
  match trigger with
  | Pullback -> pullback_hold ~proximity_pct ~entry_price ~bars_since_entry
  | Early_new_high -> early_new_high ~entry_price ~bars_since_entry
  | Either ->
      pullback_hold ~proximity_pct ~entry_price ~bars_since_entry
      || early_new_high ~entry_price ~bars_since_entry
  | Consolidation_breakout ->
      consolidation_breakout ~consolidation ~ma ~bars_since_entry

let extended_above_ma ~max_pct ~close ~ma =
  Float.( > ) ma 0.0 && Float.( > ) ((close -. ma) /. ma) max_pct
