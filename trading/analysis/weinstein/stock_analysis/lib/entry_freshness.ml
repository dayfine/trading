open Core

type basis = Ma_cross | Range_top_breakout [@@deriving show, eq, sexp]

(* 5% band under the ticket anchor. See .mli for the §4.7 rationale (the GTC
   buy-stop is written BEFORE the breakout, so admission must fire while the
   stock is still under the range top). *)
let proximity_pct = 0.05

(** §4.1 requirements 1-3, evaluated at the {i anchor} rather than the close:
    the resting ticket fills at [anchor], so that is the level that must clear a
    non-declining MA. A [Declining] MA is rejected outright — "a breakout below
    a declining MA is a trap, not a buy" (Ch. 3, Western Union). *)
let _trigger_clears_ma ~ma_direction ~ma_value ~anchor =
  match ma_direction with
  | Weinstein_types.Declining -> false
  | Rising | Flat -> Float.(anchor > ma_value)

(** The setup is live when the close has come up into the band just under the
    anchor. A missing anchor or close means there is no ticket level at all, so
    nothing is admitted (see .mli — no fallback to the MA-cross window). *)
let _setup_live ~ma_direction ~ma_value ~local_range_top ~current_close =
  match (local_range_top, current_close) with
  | Some anchor, Some close ->
      Float.(close >= anchor *. (1.0 -. proximity_pct))
      && _trigger_clears_ma ~ma_direction ~ma_value ~anchor
  | None, _ | _, None -> false

let range_top_freshness ~basis ~ma_direction ~ma_value ~local_range_top
    ~current_close =
  match basis with
  | Ma_cross -> None
  | Range_top_breakout ->
      Some (_setup_live ~ma_direction ~ma_value ~local_range_top ~current_close)
