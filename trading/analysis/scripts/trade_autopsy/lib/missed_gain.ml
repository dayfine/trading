open Core
open Types

type weekly_bar = Daily_price.t

let close_at ~bars ~date =
  List.find bars ~f:(fun b -> Date.equal b.Daily_price.date date)
  |> Option.map ~f:(fun b -> b.Daily_price.close_price)

(* Walk the list with an explicit index of the anchor bar. We use
   [List.findi] to grab the anchor index, then [List.nth] forward by [weeks].
   This is O(n) in the position of the anchor but keeps the code allocation-
   free for short lookback windows. *)
let close_at_offset ~bars ~anchor_date ~weeks =
  match
    List.findi bars ~f:(fun _ b -> Date.equal b.Daily_price.date anchor_date)
  with
  | None -> None
  | Some (idx, _anchor_bar) -> (
      match List.nth bars (idx + weeks) with
      | None -> None
      | Some b -> Some b.Daily_price.close_price)

let close_at_end ~bars =
  match List.last bars with
  | None -> None
  | Some b -> Some b.Daily_price.close_price

let next_entry_after ~trades ~trade_entry_date ~after_date =
  List.find trades ~f:(fun t -> Date.( > ) (trade_entry_date t) after_date)

(* Step 1 of cyclical-low lookup: scan [window] for the bar with the lowest
   close. The fold body is tight enough that extracting it as a let-binding
   inside the fold breaks the nesting linter's avg-depth guard. *)
let _track_min_close acc b =
  let close = b.Daily_price.close_price in
  let date = b.Daily_price.date in
  match acc with
  | None -> Some (date, close)
  | Some (_, prev_low) when Float.( < ) close prev_low -> Some (date, close)
  | Some _ -> acc

let _lowest_close_in_window window =
  List.fold window ~init:None ~f:_track_min_close

(* Step 2: build the lookback window from the bar list. Returns [None] if the
   window collapses to zero bars (entry bar can't be its own predecessor). *)
let _window_before_entry ~bars ~entry_idx ~lookback_weeks =
  let start_idx = Int.max 0 (entry_idx - lookback_weeks) in
  let window_size = entry_idx - start_idx in
  if window_size <= 0 then None
  else Some (List.sub bars ~pos:start_idx ~len:window_size)

(* Cyclical-low lookup: find the index of the entry bar, walk backward at
   most [lookback_weeks] positions, take the minimum close in that window.
   We exclude the entry bar itself so a runaway breakout where the entry
   close is the lowest close in the window can't produce a trivial zero
   "weeks since low" reading. *)
let cyclical_low_close_before ~bars ~entry_date ~lookback_weeks =
  match
    List.findi bars ~f:(fun _ b -> Date.equal b.Daily_price.date entry_date)
  with
  | None -> None
  | Some (entry_idx, _) -> (
      match _window_before_entry ~bars ~entry_idx ~lookback_weeks with
      | None -> None
      | Some window -> _lowest_close_in_window window)
