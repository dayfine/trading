open Core
open Trading_base.Types

(* Bars eligible for the window: those dated on or before [as_of]. *)
let _eligible ~bars ~as_of =
  List.filter bars ~f:(fun (b : Types.Daily_price.t) ->
      Date.( <= ) b.date as_of)

(* Trailing [lookback_bars] of [eligible]. Assumes chronological order. *)
let _trim_to_lookback eligible lookback_bars =
  let n = List.length eligible in
  if n <= lookback_bars then eligible else List.drop eligible (n - lookback_bars)

(* Bars in the window dated on or before [as_of], trimmed to the trailing
   [lookback_bars]. Assumes [bars] is chronological (oldest first). *)
let _window ~bars ~as_of ~lookback_bars =
  if lookback_bars <= 0 then []
  else _trim_to_lookback (_eligible ~bars ~as_of) lookback_bars

(* Anchor extreme for the given side:
   Long  → highest [high_price] (the peak from which price fell).
   Short → lowest  [low_price]  (the trough from which price rallied). *)
let _anchor_extreme ~side (b : Types.Daily_price.t) =
  match side with Long -> b.high_price | Short -> b.low_price

(* Counter-move extreme for the given side — the extreme measured on bars
   strictly after the anchor:
   Long  → lowest  [low_price]  across the correction.
   Short → highest [high_price] across the counter-rally. *)
let _counter_extreme ~side (b : Types.Daily_price.t) =
  match side with Long -> b.low_price | Short -> b.high_price

(* Anchor index in the window: latest date among bars whose anchor-extreme ties
   the window's extremum. Using the latest tie keeps the "after-anchor" slice
   as short and recent as possible — a second equal anchor later in the window
   means the first anchor's counter-move already healed, so we anchor to the
   later one. *)
let _anchor_index ~side window =
  let init, ties =
    match side with
    | Long -> (Float.neg_infinity, Float.( >= ))
    | Short -> (Float.infinity, Float.( <= ))
  in
  let extremum =
    List.fold window ~init ~f:(fun acc b ->
        match side with
        | Long -> Float.max acc (_anchor_extreme ~side b)
        | Short -> Float.min acc (_anchor_extreme ~side b))
  in
  let idx =
    List.foldi window ~init:(-1) ~f:(fun i best b ->
        if ties (_anchor_extreme ~side b) extremum then i else best)
  in
  (extremum, idx)

(* Counter-move extreme across [bars]:
   Long  → lowest  low  ([Float.infinity] if empty).
   Short → highest high ([Float.neg_infinity] if empty). *)
let _counter_move_extreme ~side bars =
  let init =
    match side with Long -> Float.infinity | Short -> Float.neg_infinity
  in
  List.fold bars ~init ~f:(fun acc b ->
      match side with
      | Long -> Float.min acc (_counter_extreme ~side b)
      | Short -> Float.max acc (_counter_extreme ~side b))

(* Relative counter-move depth:
   Long  → (anchor_high - correction_low) / anchor_high — drawdown from peak.
   Short → (rally_high - anchor_low)     / anchor_low   — rally from trough.

   Zero when the anchor is non-positive — a pathological input that callers
   should not pass but we guard against to avoid division-by-zero or negative
   depths. *)
let _depth_pct ~side ~anchor ~counter =
  if Float.( <= ) anchor 0.0 then 0.0
  else
    match side with
    | Long -> (anchor -. counter) /. anchor
    | Short -> (counter -. anchor) /. anchor

(* Post-anchor slice logic: given an anchor and the bars after it, return
   [Some extreme] if the counter-move is deep enough, else [None]. *)
let _qualifying_level ~side ~anchor ~after_anchor ~min_pullback_pct =
  match after_anchor with
  | [] -> None
  | _ ->
      let counter = _counter_move_extreme ~side after_anchor in
      if Float.( >= ) (_depth_pct ~side ~anchor ~counter) min_pullback_pct then
        Some counter
      else None

let find_recent_level ~bars ~as_of ~side ~min_pullback_pct ~lookback_bars =
  match _window ~bars ~as_of ~lookback_bars with
  | [] -> None
  | window ->
      let anchor, anchor_idx = _anchor_index ~side window in
      let after_anchor = List.drop window (anchor_idx + 1) in
      _qualifying_level ~side ~anchor ~after_anchor ~min_pullback_pct
