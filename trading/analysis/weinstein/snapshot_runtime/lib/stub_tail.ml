(** Stub-print tail guard — see [stub_tail.mli]. *)

open Core
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Widest range a warehouse could plausibly cover; used to read a symbol's full
   close series in one call when resolving its cutoff. *)
let _epoch = Date.create_exn ~y:1900 ~m:Month.Jan ~d:1
let _far_future = Date.create_exn ~y:2999 ~m:Month.Dec ~d:31

(* --- Pure truncation -------------------------------------------------- *)

(* Running maximum of [closes.(i .. n-1)], so the "is every bar from k to the
   end a stub" test is O(1) per candidate k and the whole scan is O(n). *)
let _suffix_maxima (closes : float array) : float array =
  let n = Array.length closes in
  let maxima = Array.create ~len:n Float.neg_infinity in
  for i = n - 1 downto 0 do
    let rest = if i = n - 1 then Float.neg_infinity else maxima.(i + 1) in
    maxima.(i) <- Float.max closes.(i) rest
  done;
  maxima

(* Index of the first bar of the terminal stub run, i.e. the smallest [k >= 1]
   such that every close in [k .. n-1] is below [ratio] of [closes.(k-1)].
   Smallest = longest run, and the test itself rules out any run whose interior
   recovers, so a mid-series collapse followed by a recovery never matches. *)
let _stub_run_start ~ratio (closes : float array) : int option =
  let n = Array.length closes in
  let maxima = _suffix_maxima closes in
  let rec scan k =
    if k >= n then None
    else
      let reference = closes.(k - 1) in
      if Float.( > ) reference 0.0 && Float.( < ) maxima.(k) (ratio *. reference)
      then Some k
      else scan (k + 1)
  in
  if n < 2 then None else scan 1

let cutoff_date ~ratio (closes : (Date.t * float) list) : Date.t option =
  if Float.( <= ) ratio 0.0 then None
  else
    let usable =
      List.filter closes ~f:(fun (_, c) -> not (Float.is_nan c))
      |> Array.of_list
    in
    let%bind.Option start = _stub_run_start ~ratio (Array.map usable ~f:snd) in
    Some (fst usable.(start - 1))

let truncate ~ratio (bars : Types.Daily_price.t list) =
  let closes =
    List.map bars ~f:(fun (b : Types.Daily_price.t) -> (b.date, b.close_price))
  in
  match cutoff_date ~ratio closes with
  | None -> bars
  | Some cutoff ->
      List.filter bars ~f:(fun (b : Types.Daily_price.t) ->
          Date.( <= ) b.date cutoff)

(* --- Warehouse-backed resolver ---------------------------------------- *)

type t = {
  ratio : float;
  read_closes : symbol:string -> (Date.t * float) list;
  memo : Date.t option String.Table.t;
}

let _read_closes_of_callbacks (cb : Snapshot_callbacks.t) ~symbol =
  match
    cb.read_field_history ~symbol ~from:_epoch ~until:_far_future
      ~field:Snapshot_schema.Close
  with
  | Ok rows -> rows
  | Error _ -> []

let of_callbacks ~ratio cb =
  {
    ratio;
    read_closes = _read_closes_of_callbacks cb;
    memo = String.Table.create ();
  }

let is_armed t = Float.( > ) t.ratio 0.0

let cutoff_for t ~symbol =
  if not (is_armed t) then None
  else
    Hashtbl.find_or_add t.memo symbol ~default:(fun () ->
        cutoff_date ~ratio:t.ratio (t.read_closes ~symbol))

let keeps t ~symbol ~date =
  match cutoff_for t ~symbol with
  | None -> true
  | Some cutoff -> Date.( <= ) date cutoff

let clamp_until t ~symbol ~until =
  match cutoff_for t ~symbol with
  | None -> until
  | Some cutoff -> if Date.( < ) cutoff until then cutoff else until

(* [Error NotFound] is the same answer an absent row gives, which every
   downstream consumer already folds to "no bar" / the empty view. *)
let _truncated_row_error ~symbol ~date =
  Error
    {
      Status.code = Status.NotFound;
      message =
        Printf.sprintf "Stub_tail: %s row %s is in the truncated stub tail"
          symbol (Date.to_string date);
    }

(* Point read: a date inside the truncated tail has no row. *)
let _wrapped_read_field t (cb : Snapshot_callbacks.t) ~symbol ~date ~field =
  if keeps t ~symbol ~date then cb.read_field ~symbol ~date ~field
  else _truncated_row_error ~symbol ~date

(* Range read: clamp the window's upper bound to the last real bar. *)
let _wrapped_read_field_history t (cb : Snapshot_callbacks.t) ~symbol ~from
    ~until ~field =
  cb.read_field_history ~symbol ~from
    ~until:(clamp_until t ~symbol ~until)
    ~field

let wrap_callbacks t (cb : Snapshot_callbacks.t) : Snapshot_callbacks.t =
  if not (is_armed t) then cb
  else
    {
      read_field = _wrapped_read_field t cb;
      read_field_history = _wrapped_read_field_history t cb;
      active_through_for = cb.active_through_for;
    }
