open Weinstein_types

(** Dual-MA early Stage-2 admission (default-off mechanism).

    A gap-closing experiment for the [late_stage2_admission] failure mode: the
    slow 30-week MA admits Stage 2 months late off bear bottoms (e.g. Mar 2009 /
    Mar 2020). This module computes a fast confirmation MA self-contained from
    the [get_close] callback (no new panel callback) and uses it to {b promote}
    a would-be [Stage1] to [Stage2] or {b prevent a demotion} of a prior
    [Stage2] while the fast MA is rising and price is above it.

    All functions are pure. The mechanism is a strict no-op when
    [early_admission_ma_period = None] (see {!compute}). *)

val compute :
  get_close:(week_offset:int -> float option) ->
  early_admission_ma_period:int option ->
  slope_threshold:float ->
  slope_lookback:int ->
  bool
(** [compute ~get_close ~early_admission_ma_period ~slope_threshold
     ~slope_lookback] is the early-admission signal.

    Returns [false] immediately when [early_admission_ma_period = None] (the
    off-path), guaranteeing the mechanism is a no-op unless the flag is set.

    When [Some fast_p]: builds a simple [fast_p]-week MA of recent closes and
    returns [fast_rising && fast_above] where

    - [fast_rising] — the fast MA at offset 0 vs offset [slope_lookback] is
      rising, using the same slope-vs-threshold rule as the slow-MA direction
      classifier ([slope_pct = (cur - back) / |back|]; rising iff
      [slope_pct > slope_threshold]; never rising when [back = 0]).
    - [fast_above] — the current close exceeds the current fast MA.

    Any missing close (current close or either fast-MA window) makes the signal
    [false]. *)

val apply :
  early_admit:bool -> prior_stage:stage option -> standard_stage:stage -> stage
(** [apply ~early_admit ~prior_stage ~standard_stage] post-processes the
    standard classifier output with the early-admission override.

    When [early_admit = false] this is the identity ([standard_stage] is
    returned unchanged) — the proof that the mechanism is a no-op when off. When
    [early_admit = true]:

    - a would-be [Stage1] is promoted to a fresh [Stage2]
      ([weeks_advancing = 0]);
    - a prior [Stage2] that the slow-MA logic would demote ([standard_stage] is
      not itself a [Stage2]) is held advancing ([weeks_advancing] increments,
      prior [late] flag preserved);
    - any other case (standard already [Stage2], or prior not [Stage2] with a
      non-[Stage1] standard) is left untouched — early admission never blocks a
      slow-MA [Stage2] and never forces an exit. *)
