open Core
open Weinstein_snapshot

let _rs_vs_spy (analysis : Stock_analysis.t) : float option =
  Option.map analysis.rs ~f:(fun (r : Rs.result) -> r.current_normalized)

(* Clean quality label. [Weinstein_types.show_overhead_quality] (the derived
   [@@deriving show] printer) module-qualifies the constructor, e.g.
   "Weinstein_types.Heavy_resistance"; the display strings want the bare label
   (mirrors [regime_label] below, which strips the same prefix for the macro
   regime). *)
let overhead_quality_label : Weinstein_types.overhead_quality -> string =
  function
  | Virgin_territory -> "Virgin_territory"
  | Clean -> "Clean"
  | Moderate_resistance -> "Moderate_resistance"
  | Heavy_resistance -> "Heavy_resistance"
  | Insufficient_history -> "Insufficient_history"

let _v2_grade_string (s : Resistance_supply.result) : string =
  Printf.sprintf "%s (%.2f)" (overhead_quality_label s.quality) s.score

let _v1_grade_string (analysis : Stock_analysis.t) : string option =
  Option.map analysis.resistance ~f:(fun (r : Resistance.result) ->
      overhead_quality_label r.quality)

let resistance_grade (analysis : Stock_analysis.t) : string option =
  match analysis.supply with
  | Some s -> Some (_v2_grade_string s)
  | None -> _v1_grade_string analysis

let regime_label : Weinstein_types.market_trend -> string = function
  | Bullish -> "Bullish"
  | Bearish -> "Bearish"
  | Neutral -> "Neutral"

let macro_context (macro : Macro.result) : Weekly_snapshot.macro_context =
  { regime = regime_label macro.trend; score = macro.confidence }

(* Map one screener candidate to the decoupled snapshot shape. The snapshot
   schema is independent of [scored_candidate] (see weekly_snapshot.mli
   §Design), so this is a deliberate field-by-field copy. *)
let candidate_of_scored (c : Screener.scored_candidate) :
    Weekly_snapshot.candidate =
  {
    symbol = c.ticker;
    score = Float.of_int c.score;
    grade = Weinstein_types.grade_to_string c.grade;
    entry = c.suggested_entry;
    stop = c.suggested_stop;
    sector = c.sector.sector_name;
    rationale = String.concat ~sep:"; " c.rationale;
    rs_vs_spy = _rs_vs_spy c.analysis;
    resistance_grade = resistance_grade c.analysis;
    (* Unsized defaults — overwritten for longs by the generator's sizing pass;
       shorts keep these (short entries are default-off in the live strategy). *)
    sized_shares = 0;
    sized_position_value = 0.0;
    sized_position_pct = 0.0;
    sized_risk_amount = 0.0;
    sizing_note = None;
    (* Overwritten by [Weekly_snapshot_generator._overlay_structural_stop] for
       both long and short candidates before this record is rendered. Starts
       [false] here (the un-overlaid stop is the screener's fixed-percentage
       proxy) so a caller that skips the overlay step degrades honestly rather
       than fabricating a structural claim. *)
    stop_is_structural = false;
    (* Overwritten by [Weekly_snapshot_generator._build_candidates]'s
       [Spike_bar_gate.flag_candidates] pass when the spike-bar flag is armed
       (issue #2083 fix 3). Starts [false] — a caller
       that skips the flagging pass shows an unflagged (not falsely suspect)
       candidate. *)
    data_suspect = false;
  }
