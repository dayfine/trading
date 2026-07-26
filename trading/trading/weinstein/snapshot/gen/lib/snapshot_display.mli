(** Pure display-mapping helpers for the weekly snapshot: clean (unqualified)
    label strings and the screener-candidate → snapshot-schema copy. Split out
    of {!Weekly_snapshot_generator} (which orchestrates the pipeline); nothing
    here touches bars, config, or IO. *)

open Weinstein_snapshot

val overhead_quality_label : Weinstein_types.overhead_quality -> string
(** Bare constructor label (e.g. ["Heavy_resistance"]) — the derived
    [show_overhead_quality] printer module-qualifies the constructor, which the
    display strings must not carry. *)

val resistance_grade : Stock_analysis.t -> string option
(** Resistance grade for display (score/display split, §D5): the v2
    sketch-derived grade with its continuous score (e.g.
    ["Heavy_resistance (0.82)"]) when [analysis.supply] is populated, else the
    v1 binary grade. [analysis.supply] is [None] whenever [overhead_supply] is
    disarmed, so the disarmed v2 output stays byte-identical to the v1 grade
    string (both route through {!overhead_quality_label}). *)

val regime_label : Weinstein_types.market_trend -> string
(** Bare regime label (["Bullish"] / ["Bearish"] / ["Neutral"]). *)

val macro_context : Macro.result -> Weekly_snapshot.macro_context

val candidate_of_scored : Screener.scored_candidate -> Weekly_snapshot.candidate
(** Field-by-field copy onto the decoupled snapshot schema (see
    weekly_snapshot.mli §Design). Sized-instruction fields are left at their
    unsized defaults — the generator overwrites them for long candidates. *)
