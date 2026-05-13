open Core

type pullback_band = { low : float; high : float } [@@deriving sexp]

type config = {
  ma_slope_min : float;
  pullback_band : pullback_band;
  pullback_lookback_weeks : int;
  consolidation_range_pct : float;
  consolidation_weeks : int;
}
[@@deriving sexp]

let default_config =
  {
    ma_slope_min = 0.01;
    pullback_band = { low = 0.95; high = 1.05 };
    pullback_lookback_weeks = 8;
    consolidation_range_pct = 0.10;
    consolidation_weeks = 4;
  }

type result = {
  is_continuation : bool;
  pullback_low : float option;
  consolidation_high : float option;
  ma_slope_observed : float;
}
[@@deriving sexp]

type callbacks = {
  get_ma : week_offset:int -> float option;
  get_close : week_offset:int -> float option;
  get_high : week_offset:int -> float option;
  get_low : week_offset:int -> float option;
}

(** Compute the MA slope as a fraction over [_slope_lookback_weeks] weeks:
    [(ma_now - ma_back) / ma_back]. Returns [0.0] when either reading is
    unavailable or [ma_back] is non-positive (treats as "no slope evidence",
    which fails the [ma_slope_min] gate). *)
let _slope_lookback_weeks = 4

let _compute_ma_slope ~(get_ma : week_offset:int -> float option) : float =
  match (get_ma ~week_offset:0, get_ma ~week_offset:_slope_lookback_weeks) with
  | Some now, Some back when Float.( > ) back 0.0 -> (now -. back) /. back
  | _ -> 0.0

(** Scan offsets [1 .. lookback_weeks] for the most recent bar whose
    [close / ma_30w] sits inside [band]. Skip offset 0 deliberately — the
    current bar should be ABOVE the consolidation high (i.e. on a new breakout),
    not in the pullback band. Returns the offset of the matching bar, or [None].
*)
let _find_pullback_offset ~callbacks ~band ~lookback_weeks : int option =
  let rec loop off =
    if off > lookback_weeks then None
    else
      match
        (callbacks.get_close ~week_offset:off, callbacks.get_ma ~week_offset:off)
      with
      | Some close, Some ma when Float.( > ) ma 0.0 ->
          let ratio = close /. ma in
          if Float.( >= ) ratio band.low && Float.( <= ) ratio band.high then
            Some off
          else loop (off + 1)
      | _ -> loop (off + 1)
  in
  loop 1

(** Fold high/low/close over offsets [1 .. n]. The current bar (offset 0) is
    DELIBERATELY excluded — the consolidation window measures the base the stock
    just broke out of; including offset 0 would mean the breakout bar's high
    becomes the level the breakout must exceed, which is self-defeating.

    Returns [Some (high, low, sum_close)] iff every offset returned a defined
    bar; [None] on the first hole (mirrors the contiguous-tail semantics used by
    {!Stock_analysis._count_defined}). *)
let _scan_window ~callbacks ~n : (float * float * float) option =
  let rec loop off hi lo sum =
    if off > n then Some (hi, lo, sum)
    else
      match
        ( callbacks.get_high ~week_offset:off,
          callbacks.get_low ~week_offset:off,
          callbacks.get_close ~week_offset:off )
      with
      | Some h, Some l, Some c ->
          let hi' = Float.max hi h in
          let lo' = Float.min lo l in
          loop (off + 1) hi' lo' (sum +. c)
      | _ -> None
  in
  if n < 1 then None
  else
    match
      ( callbacks.get_high ~week_offset:1,
        callbacks.get_low ~week_offset:1,
        callbacks.get_close ~week_offset:1 )
    with
    | Some h, Some l, Some c -> loop 2 h l c
    | _ -> None

(** Check the consolidation-tightness gate over the last [weeks] bars. Returns
    [Some hi] when [(hi - lo) / avg_close <= range_pct], i.e. the window is
    tight enough to count as consolidation. [hi] is the window's highest [high],
    used downstream as the breakout level. [None] when the window is incomplete
    or fails the range gate. *)
let _consolidation_high ~callbacks ~weeks ~range_pct : float option =
  match _scan_window ~callbacks ~n:weeks with
  | None -> None
  | Some (hi, lo, sum) ->
      let avg = sum /. Float.of_int weeks in
      if Float.( <= ) avg 0.0 then None
      else
        let range_fraction = (hi -. lo) /. avg in
        if Float.( <= ) range_fraction range_pct then Some hi else None

(** Check the breakout-arm gate: the current close (offset 0) exceeds the
    consolidation high. Mirrors the book's "breaks out anew above the top of its
    resistance zone". Returns [false] when the current close is missing. *)
let _current_close_above ~(get_close : week_offset:int -> float option) ~level :
    bool =
  match get_close ~week_offset:0 with
  | Some c -> Float.( > ) c level
  | None -> false

let analyze_with_callbacks ~(config : config) ~(callbacks : callbacks) : result
    =
  let ma_slope_observed = _compute_ma_slope ~get_ma:callbacks.get_ma in
  let slope_ok = Float.( >= ) ma_slope_observed config.ma_slope_min in
  let pullback_off_opt =
    _find_pullback_offset ~callbacks ~band:config.pullback_band
      ~lookback_weeks:config.pullback_lookback_weeks
  in
  let pullback_low =
    Option.bind pullback_off_opt ~f:(fun off ->
        callbacks.get_low ~week_offset:off)
  in
  let consolidation_high =
    _consolidation_high ~callbacks ~weeks:config.consolidation_weeks
      ~range_pct:config.consolidation_range_pct
  in
  let breakout_ok =
    match consolidation_high with
    | Some level -> _current_close_above ~get_close:callbacks.get_close ~level
    | None -> false
  in
  let is_continuation =
    slope_ok && Option.is_some pullback_off_opt && breakout_ok
  in
  { is_continuation; pullback_low; consolidation_high; ma_slope_observed }
