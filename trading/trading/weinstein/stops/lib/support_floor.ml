open Core
open Trading_base.Types

(* ---- Callback bundle ---- *)

type callbacks = {
  get_high : day_offset:int -> float option;
  get_low : day_offset:int -> float option;
  get_close : day_offset:int -> float option;
  get_date : day_offset:int -> Core.Date.t option;
  n_days : int;
}

(* Single-pass collector: walks [bars] once accumulating eligible bars
   (date <= as_of) into a reversed list and counting them. The reversed
   layout means the trailing [lookback_bars] of the original chronological
   sequence is the [List.take lookback_bars] prefix of the reversed list. *)
let _collect_eligible_rev ~bars ~as_of =
  List.fold bars ~init:([], 0) ~f:(fun (acc, n) (b : Types.Daily_price.t) ->
      if Date.( <= ) b.date as_of then (b :: acc, n + 1) else (acc, n))

(* Trim a reversed eligible list (newest first) to the trailing
   [lookback_bars] entries; the reverse-order layout is then exactly what
   the callbacks consume — day_offset:0 is the newest bar (head of the
   reversed list), day_offset:n_days-1 is the oldest. *)
let _trim_rev_to_lookback eligible_rev ~n_eligible ~lookback_bars =
  if n_eligible <= lookback_bars then eligible_rev
  else List.take eligible_rev lookback_bars

let callbacks_from_bars ~bars ~as_of ~lookback_bars =
  if lookback_bars <= 0 then
    {
      get_high = (fun ~day_offset:_ -> None);
      get_low = (fun ~day_offset:_ -> None);
      get_close = (fun ~day_offset:_ -> None);
      get_date = (fun ~day_offset:_ -> None);
      n_days = 0;
    }
  else
    let eligible_rev, n_eligible = _collect_eligible_rev ~bars ~as_of in
    let trimmed =
      _trim_rev_to_lookback eligible_rev ~n_eligible ~lookback_bars
    in
    let arr = Array.of_list trimmed in
    let n_days = Array.length arr in
    let lookup f ~day_offset =
      if day_offset < 0 || day_offset >= n_days then None
      else Some (f arr.(day_offset))
    in
    {
      get_high = lookup (fun (b : Types.Daily_price.t) -> b.high_price);
      get_low = lookup (fun (b : Types.Daily_price.t) -> b.low_price);
      get_close = lookup (fun (b : Types.Daily_price.t) -> b.close_price);
      get_date =
        (fun ~day_offset ->
          if day_offset < 0 || day_offset >= n_days then None
          else Some arr.(day_offset).date);
      n_days;
    }

(* ---- Side-specific extractors ---- *)

(* Anchor extreme reader for the given side:
   Long  → callbacks.get_high (the peak high we anchor to).
   Short → callbacks.get_low  (the trough low we anchor to). *)
let _anchor_reader ~side ~callbacks =
  match side with Long -> callbacks.get_high | Short -> callbacks.get_low

(* Counter-move extreme reader for the given side:
   Long  → callbacks.get_low  (the correction low after the peak).
   Short → callbacks.get_high (the rally high after the trough). *)
let _counter_reader ~side ~callbacks =
  match side with Long -> callbacks.get_low | Short -> callbacks.get_high

(* Anchor offset on day-offset axis: smallest offset (= latest date) whose
   anchor extreme ties the window's extremum.

   The bar-list path tie-broke to the latest date by walking chronological
   indices and taking the last tying index with [>=]. In day-offset space
   the latest date is offset 0, so we walk offsets 0 → n_days-1 and take
   the FIRST tying offset (the one closest to today). *)
let _anchor_offset ~side ~callbacks =
  let read = _anchor_reader ~side ~callbacks in
  let init, better =
    match side with
    | Long -> (Float.neg_infinity, Float.( > ))
    | Short -> (Float.infinity, Float.( < ))
  in
  let n = callbacks.n_days in
  let best_off = ref (-1) in
  let best_val = ref init in
  for off = 0 to n - 1 do
    match read ~day_offset:off with
    | None -> ()
    | Some v ->
        if better v !best_val then (
          best_val := v;
          best_off := off)
  done;
  if !best_off < 0 then None else Some (!best_off, !best_val)

(* Side-specific [<] / [>] for the counter-move extreme. *)
let _counter_better = function Long -> Float.( < ) | Short -> Float.( > )

(* Update [(found, acc)] with a new value. *)
let _fold_extreme ~better (found, acc) v =
  if (not found) || better v acc then (true, v) else (found, acc)

(* Walk [start_off..end_off] inclusive, accumulating the side-specific
   counter-move extreme via [_fold_extreme]. Tail-recursive; replaces the
   imperative for-loop and keeps nesting depth flat. *)
let rec _scan_counter ~read ~better ~off ~end_off ((_, _) as state) =
  if off > end_off then state
  else
    let next_state =
      match read ~day_offset:off with
      | None -> state
      | Some v -> _fold_extreme ~better state v
    in
    _scan_counter ~read ~better ~off:(off + 1) ~end_off next_state

(* Counter-move extreme across [start_off, end_off] inclusive.
   Long  → minimum low.
   Short → maximum high.

   Returns [None] when the range is empty (start_off > end_off) or when no
   offset in the range yielded a defined value. The found-flag is kept
   separate from [acc] so a legitimately infinite extreme — pathological
   but not impossible in synthetic inputs — does not collide with the
   sentinel. *)
let _counter_extreme_in_range ~side ~callbacks ~start_off ~end_off =
  if start_off > end_off then None
  else
    let read = _counter_reader ~side ~callbacks in
    let better = _counter_better side in
    match _scan_counter ~read ~better ~off:start_off ~end_off (false, 0.0) with
    | true, acc -> Some acc
    | false, _ -> None

(* Relative counter-move depth:
   Long  → (anchor_high - correction_low) / anchor_high — drawdown from peak.
   Short → (rally_high  - anchor_low)     / anchor_low  — rally from trough.

   Zero when the anchor is non-positive — a pathological input that callers
   should not pass but we guard against to avoid division-by-zero or negative
   depths. *)
let _depth_pct ~side ~anchor ~counter =
  if Float.( <= ) anchor 0.0 then 0.0
  else
    match side with
    | Long -> (anchor -. counter) /. anchor
    | Short -> (counter -. anchor) /. anchor

(* Given an anchor offset + value, look for a qualifying counter-move on the
   newer side of the anchor and gate it against [min_pullback_pct].
   "Post-anchor" in chronological terms means offsets newer than the anchor,
   i.e. day_offsets [0, anchor_off - 1]. When [anchor_off = 0] the range is
   empty and no counter-move can exist. *)
let _qualifying_level_for_anchor ~side ~callbacks ~min_pullback_pct ~anchor_off
    ~anchor =
  match
    _counter_extreme_in_range ~side ~callbacks ~start_off:0
      ~end_off:(anchor_off - 1)
  with
  | None -> None
  | Some counter ->
      if Float.( >= ) (_depth_pct ~side ~anchor ~counter) min_pullback_pct then
        Some counter
      else None

let find_recent_level_with_callbacks ~callbacks ~side ~min_pullback_pct =
  if callbacks.n_days <= 0 then None
  else
    match _anchor_offset ~side ~callbacks with
    | None -> None
    | Some (anchor_off, anchor) ->
        _qualifying_level_for_anchor ~side ~callbacks ~min_pullback_pct
          ~anchor_off ~anchor

let find_recent_level ~bars ~as_of ~side ~min_pullback_pct ~lookback_bars =
  let callbacks = callbacks_from_bars ~bars ~as_of ~lookback_bars in
  find_recent_level_with_callbacks ~callbacks ~side ~min_pullback_pct
