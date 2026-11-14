(** Stale-entry cap (H2′, #3594). See [stale_entry_cap.mli]. *)

open Core

let ticket_anchor ~range_top ~cap_top ~breakout_price =
  match (cap_top, range_top, breakout_price) with
  | None, _, _ -> range_top
  | Some t, Some r, _ -> Some (Float.min r t)
  | Some t, None, Some b when Float.( > ) b t -> Some t
  | Some _, None, _ -> None

let anchors ~get_high ~get_split_factor ~replace_weeks ~cap_weeks
    ~breakout_price =
  let top weeks =
    Stock_analysis_scans.scan_recent_max_high ~get_high ~get_split_factor ~weeks
  in
  let range_top = top replace_weeks in
  (range_top, ticket_anchor ~range_top ~cap_top:(top cap_weeks) ~breakout_price)
