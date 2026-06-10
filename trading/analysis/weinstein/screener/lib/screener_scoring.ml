open Core
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Types and defaults                                                   *)
(* ------------------------------------------------------------------ *)

type sector_rating = Strong | Neutral | Weak [@@deriving show, eq, sexp]

type sector_context = {
  sector_name : string;
  rating : sector_rating;
  stage : stage;
}
[@@deriving sexp]

type scoring_weights = {
  w_stage2_breakout : int;
  w_early_stage2 : int option; [@sexp.option]
  w_strong_volume : int;
  w_adequate_volume : int;
  w_positive_rs : int;
  w_bullish_rs_crossover : int;
  w_clean_resistance : int;
  w_sector_strong : int;
  w_late_stage2_penalty : int;
}
[@@deriving sexp]

let default_scoring_weights =
  {
    w_stage2_breakout = 30;
    w_early_stage2 = None;
    w_strong_volume = 20;
    w_adequate_volume = 10;
    w_positive_rs = 20;
    w_bullish_rs_crossover = 10;
    w_clean_resistance = 15;
    w_sector_strong = 10;
    w_late_stage2_penalty = -15;
  }

type grade_thresholds = { a_plus : int; a : int; b : int; c : int; d : int }
[@@deriving sexp]
(** Score cutoffs for each grade. All are configurable. *)

let default_grade_thresholds = { a_plus = 85; a = 70; b = 55; c = 40; d = 25 }

(* ------------------------------------------------------------------ *)
(* Scoring signal helpers                                               *)
(* ------------------------------------------------------------------ *)

(** Early-Stage2 weight: explicit [w_early_stage2] when set, else the historical
    [w_stage2_breakout / 2] coupling (bit-identical to pre-field behaviour). *)
let _early_stage2_weight ~w =
  match w.w_early_stage2 with Some v -> v | None -> w.w_stage2_breakout / 2

(** Stage signal for long setups: Stage1→2 transition or early Stage2. *)
let _stage_long_signal ~w ~(a : Stock_analysis.t) =
  match (a.stage.stage, a.prior_stage) with
  | Stage2 _, Some (Stage1 _) ->
      [ (w.w_stage2_breakout, "Stage1→Stage2 breakout") ]
  | Stage2 { weeks_advancing; _ }, _ when weeks_advancing <= 4 ->
      [ (_early_stage2_weight ~w, "Early Stage2") ]
  | _ -> []

(** Late Stage2 deceleration penalty. *)
let _late_stage2_signal ~w ~(a : Stock_analysis.t) =
  match a.stage.stage with
  | Stage2 { late = true; _ } ->
      [ (w.w_late_stage2_penalty, "Late Stage2 (penalty)") ]
  | _ -> []

(** Volume confirmation signal for long setups (Stage 2 breakout). *)
let _volume_signal ~w ~(a : Stock_analysis.t) =
  match a.volume with
  | Some { confirmation = Strong _; _ } ->
      [ (w.w_strong_volume, "Strong volume") ]
  | Some { confirmation = Adequate _; _ } ->
      [ (w.w_adequate_volume, "Adequate volume") ]
  | _ -> []

(** Volume confirmation signal for short setups (Stage 4 breakdown). Per
    Weinstein, volume is NOT required for a valid breakdown — stocks can fall of
    their own weight. Volume increase on breakdown is even more bearish, but
    absence doesn't invalidate the setup. Therefore [Strong] / [Adequate] add
    positive weight; [Weak] / no-data adds zero — never a penalty. Mirrors
    [_volume_signal]'s shape with breakdown-specific rationale labels. *)
let _volume_short_signal ~w ~(a : Stock_analysis.t) =
  match a.volume with
  | Some { confirmation = Strong _; _ } ->
      [ (w.w_strong_volume, "Strong breakdown volume") ]
  | Some { confirmation = Adequate _; _ } ->
      [ (w.w_adequate_volume, "Adequate breakdown volume") ]
  | _ -> []

(** Bullish RS signal for long setups. *)
let _rs_long_signal ~w ~(a : Stock_analysis.t) =
  match a.rs with
  | Some { trend = Bullish_crossover; _ } ->
      [ (w.w_positive_rs + w.w_bullish_rs_crossover, "RS bullish crossover") ]
  | Some { trend = Positive_rising; _ } ->
      [ (w.w_positive_rs, "RS positive & rising") ]
  | Some { trend = Positive_flat; _ } ->
      [ (w.w_positive_rs / 2, "RS positive") ]
  | _ -> []

(** Bearish RS signal for short setups. *)
let _rs_short_signal ~w ~(a : Stock_analysis.t) =
  match a.rs with
  | Some { trend = Bearish_crossover; _ } ->
      [ (w.w_positive_rs + w.w_bullish_rs_crossover, "RS bearish crossover") ]
  | Some { trend = Negative_declining; _ } ->
      [ (w.w_positive_rs, "RS negative & declining") ]
  | Some { trend = Negative_improving; _ } ->
      [ (w.w_positive_rs / 2, "RS negative") ]
  | _ -> []

(** Overhead resistance signal. *)
let _resistance_signal ~w ~(a : Stock_analysis.t) =
  match a.resistance with
  | Some { quality = Virgin_territory; _ } ->
      [ (w.w_clean_resistance, "Virgin territory") ]
  | Some { quality = Clean; _ } -> [ (w.w_clean_resistance, "Clean overhead") ]
  | Some { quality = Moderate_resistance; _ } ->
      [ (w.w_clean_resistance / 2, "Moderate resistance") ]
  | _ -> []

(** Below-breakdown clean-space signal for short setups. Mirror of
    [_resistance_signal] for the short-side cascade. Per Weinstein, the Short
    Entry Checklist requires "minimal nearby support below breakdown point" — a
    steep prior advance with small congestion is ideal. Heavy support below
    means the decline will struggle through prior congestion zones; minimal /
    virgin support below means the stock can fall freely. The shared
    [overhead_quality] variant carries side-flipped semantics — see [Support]
    module-level doc. *)
let _support_signal ~w ~(a : Stock_analysis.t) =
  match a.support with
  | Some { quality = Virgin_territory; _ } ->
      [ (w.w_clean_resistance, "Virgin support below") ]
  | Some { quality = Clean; _ } ->
      [ (w.w_clean_resistance, "Clean support below") ]
  | Some { quality = Moderate_resistance; _ } ->
      [ (w.w_clean_resistance / 2, "Moderate support below") ]
  | _ -> []

(** Sector bonus/penalty for long setups. *)
let _sector_long_signal ~w ~sector =
  match sector.rating with
  | Strong -> [ (w.w_sector_strong, "Strong sector") ]
  | Neutral -> []
  | Weak -> [ (-w.w_sector_strong, "Weak sector (penalty)") ]

(** Sector bonus/penalty for short setups. *)
let _sector_short_signal ~w ~sector =
  match sector.rating with
  | Weak -> [ (w.w_sector_strong, "Weak sector") ]
  | Neutral -> []
  | Strong -> [ (-w.w_sector_strong, "Strong sector (penalty)") ]

(** Stage signal for short setups: Stage3→4 transition or early Stage4. *)
let _stage_short_signal ~w ~(a : Stock_analysis.t) =
  match (a.stage.stage, a.prior_stage) with
  | Stage4 _, Some (Stage3 _) ->
      [ (w.w_stage2_breakout, "Stage3→Stage4 breakdown") ]
  | Stage4 { weeks_declining }, _ when weeks_declining <= 4 ->
      [ (w.w_stage2_breakout / 2, "Early Stage4") ]
  | _ -> []

(** Reduce a list of (points, label) signals to (total_score, rationale list).
    Zero-point entries are dropped from both the total and the rationale. Was:
    List.filter materialised a [non_zero] intermediate, then List.sum walked it
    once for points and List.map walked it again for labels — three list
    traversals and two intermediate lists per call. Now: a single
    List.fold_right accumulates both the total score and the rationale list in
    one pass with no intermediate. fold_right preserves the original signal
    order in the rationale, matching the prior List.map behaviour. Called twice
    per scored candidate (long + short). *)
let _tally signals =
  List.fold_right signals ~init:(0, []) ~f:(fun (pts, label) (sum, labels) ->
      if pts = 0 then (sum, labels) else (sum + pts, label :: labels))

(* ------------------------------------------------------------------ *)
(* Scoring                                                              *)
(* ------------------------------------------------------------------ *)

(** Compute a long-side score for a stock analysis. *)
let score_long ~weights ~sector (a : Stock_analysis.t) : int * string list =
  let w = weights in
  _tally
    (_stage_long_signal ~w ~a @ _late_stage2_signal ~w ~a @ _volume_signal ~w ~a
   @ _rs_long_signal ~w ~a @ _resistance_signal ~w ~a
    @ _sector_long_signal ~w ~sector)

(** Compute a short-side score for a stock analysis. *)
let score_short ~weights ~sector (a : Stock_analysis.t) : int * string list =
  let w = weights in
  _tally
    (_stage_short_signal ~w ~a @ _volume_short_signal ~w ~a
   @ _rs_short_signal ~w ~a @ _support_signal ~w ~a
    @ _sector_short_signal ~w ~sector)

(** Convert score to grade using configurable thresholds. *)
let grade_of_score ~thresholds score =
  if score >= thresholds.a_plus then A_plus
  else if score >= thresholds.a then A
  else if score >= thresholds.b then B
  else if score >= thresholds.c then C
  else if score >= thresholds.d then D
  else F

(* ------------------------------------------------------------------ *)
(* Price helpers                                                        *)
(* ------------------------------------------------------------------ *)

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
