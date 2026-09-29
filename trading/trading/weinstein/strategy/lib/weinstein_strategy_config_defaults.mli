(** Named default values for {!Weinstein_strategy_config.config} fields.

    Each constant is referenced by both the field's [[@sexp.default ...]]
    attribute and the [default_config] literal, so the two cannot drift. Split
    out of [weinstein_strategy_config.ml] to keep that file under the
    file-length cap; it [include]s this module, so every name below is also
    reachable unqualified there. See the corresponding field docs in
    [weinstein_strategy_config.mli] for what each value means. *)

val macro_bearish_no_op_cap : float
(** No-op default for [macro_bearish_max_long_exposure_pct] ([0.70]): equals the
    normal long-exposure cap, so the macro-bearish trim never bites until a spec
    sets a tighter value. *)

val fast_v_min_rate_no_op : float
(** No-op default for [fast_v_min_rate_pct] ([0.08]): equals
    [Decline_character.default_config.fast_v_min_rate_pct]. *)

val default_stale_exit_days : int
(** Default [stale_exit_after_days] bar gap ([5] calendar days), flipped on
    2026-07-10 as a realism basis change (issues #1484 / #1487). *)

val bundle_w_overhead_supply : int
(** Continuous overhead-supply ranking weight ([30]) armed into the default
    screening weights by the 2026-07-23 bundle promotion. *)

val default_dawn_max_flip_age_weeks : int
(** Default [dawn_max_ma_flip_age_weeks] ([78] weeks ~= 1.5y, P1b memo). *)

val default_entry_extension_max_pct : float
(** Default [entry_extension_max_pct] ([2.0] percentage points, #2404). *)
