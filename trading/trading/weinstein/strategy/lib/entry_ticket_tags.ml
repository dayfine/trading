(** Placement-time audit tags for a resting entry ticket. See
    [entry_ticket_tags.mli]. *)

open Core

type triple_confirmation = {
  breakout_volume_multiple : float option;
  rs_zero_cross : bool;
  in_base_advance_pct : float option;
}
[@@deriving show, eq]

(* Book §4.5 (3): "Stock already advanced significantly during Stage 1 base
   before breaking out — shows accumulation by smart money", quantified at 40%
   (National Semiconductor tripled inside its base; Blocker Energy +200%). *)
let book_min_in_base_advance_pct = 0.40

(** §4.5 (3), measured on the levels the analysis already carries: the base's
    top ([breakout_price]) over the base's floor ([breakdown_price], the minimum
    low of the same prior-base window). [None] when either level is undefined or
    the floor is non-positive (no meaningful denominator). *)
let _in_base_advance_pct (analysis : Stock_analysis.t) =
  match (analysis.breakout_price, analysis.breakdown_price) with
  | Some top, Some floor_ when Float.(floor_ > 0.0) ->
      Some ((top -. floor_) /. floor_)
  | _ -> None

(** §4.5 (2): the classified RS trend is the book's own "RS just crossed from
    negative to positive territory — A+ bonus" state. *)
let _rs_zero_cross (analysis : Stock_analysis.t) =
  match analysis.rs with
  | None -> false
  | Some (r : Rs.result) ->
      Weinstein_types.equal_rs_trend r.trend Weinstein_types.Bullish_crossover

let triple_confirmation_of_analysis (analysis : Stock_analysis.t) =
  {
    breakout_volume_multiple =
      Option.map analysis.volume ~f:(fun (v : Volume.result) -> v.volume_ratio);
    rs_zero_cross = _rs_zero_cross analysis;
    in_base_advance_pct = _in_base_advance_pct analysis;
  }

let _at_least threshold = function
  | None -> false
  | Some v -> Float.(v >= threshold)

let is_triple_confirmed ~strong_volume_threshold t =
  _at_least strong_volume_threshold t.breakout_volume_multiple
  && t.rs_zero_cross
  && _at_least book_min_in_base_advance_pct t.in_base_advance_pct

let freshness_basis_of_analysis (analysis : Stock_analysis.t) :
    Entry_freshness.basis =
  match analysis.range_top_freshness with
  | None -> Entry_freshness.Ma_cross
  | Some _ -> Entry_freshness.Range_top_breakout
