open Weinstein_types

(** Stage-2 MA-hold refinement (default-off mechanism).

    Fixes a diagnosed oscillation defect in the stage classifier: on a steady
    uptrend, a normal pullback that merely flattens the 30-week MA flips a held
    [Stage2] to [Stage3] ("topping"), then flips back to [Stage2] when the
    advance resumes. A human reads the whole move as one continuous Stage 2; the
    classifier fragments it into many short stages with dozens of spurious
    transitions (KO 2010-2018: ~45 transitions, 7+ Stage-2 pieces). The churn
    drives the whipsaw / late-reentry the trade-autopsy ranked #1 for missed
    gain (see [memory/project_stage_chart_visual_diagnostic]).

    This is faithful Weinstein, not a new mechanic. Stage 2 IS "price above a
    rising 30-week MA" (docs/design/weinstein-book-reference.md §Stage 2:
    Advancing); a pullback that holds the MA (close still at/above it) is still
    Stage 2, not a top. The refinement only blocks the {b S2 → S3} demotion
    while price holds the MA; a genuine break {b below} the MA still transitions
    out normally, so legitimate Stage-3 / Stage-4 exits are preserved.

    All functions are pure. The mechanism is a strict no-op when
    [enabled = false] (see {!apply}). *)

val apply :
  enabled:bool ->
  prior_stage:stage option ->
  standard_stage:stage ->
  current_close:float option ->
  current_ma:float ->
  stage
(** [apply ~enabled ~prior_stage ~standard_stage ~current_close ~current_ma]
    post-processes the standard classifier output with the MA-hold override.

    When [enabled = false] this is the identity ([standard_stage] is returned
    unchanged) — the proof that the mechanism is a no-op when off.

    When [enabled = true]: holds a prior [Stage2] advancing (rather than letting
    the standard logic demote it to [Stage3]) iff {b all} of:

    - the prior stage is a [Stage2];
    - the standard classifier output is a [Stage3] (the topping demotion this
      refinement targets — a [Stage4] below-MA break is left untouched);
    - the current close is defined and at/above the current MA
      ([current_close >= current_ma]).

    The held stage is a [Stage2] whose [weeks_advancing] continues from the
    prior Stage-2 count (incremented by one) and preserves the prior [late]
    flag. In every other case [standard_stage] is returned unchanged — the
    refinement never blocks a legitimate below-MA exit and never forces a
    Stage-2 entry. *)
