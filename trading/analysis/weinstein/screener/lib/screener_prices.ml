(** Screener price helpers, factored out of [screener_scoring.ml] (file-length
    cap) and re-exported there by [include]. See [screener_prices.mli]. *)

open Core

(** Suggested entry: breakout price plus a configurable buffer. *)
let suggested_entry ~entry_buffer_pct breakout_price =
  let raw = breakout_price *. (1.0 +. entry_buffer_pct) in
  Float.round_nearest (raw *. 100.0) /. 100.0

(** Long stop: configurable fraction below entry. *)
let suggested_stop ~initial_stop_pct entry = entry *. (1.0 -. initial_stop_pct)

(** Estimate swing target using simplified Weinstein swing rule: target =
    breakout + (breakout - base_low). *)
let swing_target ~breakout ~base_low_opt =
  match base_low_opt with
  | None -> None
  | Some base_low ->
      if Float.(breakout > base_low) then
        Some (breakout +. (breakout -. base_low))
      else None

(** Proxy for the prior base low: configurable fraction below the 30-week MA. *)
let base_low ~base_low_proxy_pct (a : Stock_analysis.t) : float option =
  match a.stage.ma_value with
  | v when Float.(v > 0.0) -> Some (v *. (1.0 -. base_low_proxy_pct))
  | _ -> None
