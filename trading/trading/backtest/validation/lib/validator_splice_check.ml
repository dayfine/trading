open Core
open Validator_types
open Validator_step

(* ---- V15: a huge, brief round trip whose fill bar sits on a splice ------ *)

(* CHS 2004-12-17 -> 2004-12-20: raw close 11.2875 -> 45.16 with the ADJUSTED
   close going 4.0693 -> 15.8803 (x3.9) and volume ~5M -> ~1M. A split moves
   the raw close and leaves the adjusted one continuous, so a jump of that size
   in the ADJUSTED series is a different security under a recycled ticker, not
   a corporate action. The arc's volume-eject "sold" it at Monday's open for
   +$513,550 on a three-day hold — 70% of the cell's realised P&L, and enough
   to flip the sign of the 26y fix-armed cell (issue #2646). *)

(* |pnl_pct|. Unsigned, so [side] does not enter: for a LONG the P&L percent is
   the price move and for a SHORT it is its negation, and the magnitude — the
   only thing this check reads — is the same either way. A splice hurts a SHORT
   exactly as much as it helps a LONG. *)
let _v15_abs_pnl_pct (row : trade_row) =
  if Float.( <= ) row.entry_price 0.0 then None
  else
    let move = (row.exit_price -. row.entry_price) /. row.entry_price in
    Some (100.0 *. Float.abs move)

(* Both halves of the shape must hold: an implausible move AND a hold too
   short for it. Either alone is an ordinary (if lucky) trade. *)
let _v15_is_candidate (c : check_config) (row : trade_row) =
  match _v15_abs_pnl_pct row with
  | None -> false
  | Some pnl ->
      Float.( > ) (Float.abs pnl) c.splice_pnl_pct_threshold
      && Date.diff row.exit_date row.entry_date <= c.splice_max_days_held

type _splice_leg = Splice_clean | Splice_unknown | Splice_found of string

let _v15_ratio ~(prev : daily_bar) ~(bar : daily_bar) =
  if Float.( <= ) prev.adjusted_close 0.0 then None
  else Some (bar.adjusted_close /. prev.adjusted_close)

let _v15_detail ~leg (prev : daily_bar) (bar : daily_bar) ratio =
  sprintf "%s bar %s adj_close %.4f -> %.4f (x%.3f vs prior bar %s)" leg
    (Date.to_string bar.date) prev.adjusted_close bar.adjusted_close ratio
    (Date.to_string prev.date)

let _v15_classify (c : check_config) ~leg (prev : daily_bar) (bar : daily_bar) =
  match _v15_ratio ~prev ~bar with
  | None -> Splice_unknown
  | Some r
    when Float.( < ) r c.splice_adj_ratio_min
         || Float.( > ) r c.splice_adj_ratio_max ->
      Splice_found (_v15_detail ~leg prev bar r)
  | Some _ -> Splice_clean

let _v15_leg (c : check_config) (b : bars) ~leg ~date =
  match daily_with_prev b date with
  | None -> Splice_unknown
  | Some (prev, bar) -> _v15_classify c ~leg prev bar

(* Entry leg first, so it supplies the specimen when both legs are spliced. *)
let _v15_legs (c : check_config) (b : bars) (row : trade_row) =
  [
    _v15_leg c b ~leg:"entry" ~date:row.entry_date;
    _v15_leg c b ~leg:"exit" ~date:row.exit_date;
  ]

let _v15_verdict (c : check_config) (b : bars) (row : trade_row) =
  let legs = _v15_legs c b row in
  match
    List.find_map legs ~f:(function Splice_found d -> Some d | _ -> None)
  with
  | Some detail -> Fail (spec row detail)
  | None ->
      if List.exists legs ~f:(function Splice_unknown -> true | _ -> false)
      then Skip
      else Pass

let _v15_step inputs (row : trade_row) =
  if not (_v15_is_candidate inputs.config row) then Pass
  else
    match inputs.bars row.symbol with
    | None -> Skip
    | Some b when Array.is_empty b.daily -> Skip
    | Some b -> _v15_verdict inputs.config b row

let check_v15 inputs = fold_steps inputs.trades ~f:(_v15_step inputs)
