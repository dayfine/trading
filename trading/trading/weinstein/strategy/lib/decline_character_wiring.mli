(** Strategy-side adapter for {!Decline_character.classify}.

    Build 2 (dev/notes/decline-character-exploration-2026-06-21-PM.md): the
    fast-crash absolute stop ([stops_config.catastrophic_stop_pct]) is armed
    only when the primary index is in a fast-V decline. This module bridges the
    snapshot-shaped weekly index view the strategy carries to the
    [index_bars : Daily_price.t list] input {!Decline_character.classify}
    expects.

    The conversion lives here, in the strategy lib (which already depends on
    [weinstein.macro]), so the stops lib and stops runner stay macro-agnostic
    (A2): they receive a plain [~armed:bool], not a {!Decline_character.t}. *)

val classifier_config :
  fast_v_arm_on_rate_alone:bool ->
  fast_v_min_rate_pct:float ->
  Decline_character.config
(** [classifier_config ~fast_v_arm_on_rate_alone ~fast_v_min_rate_pct] is
    [Decline_character.default_config] with [fast_v_ignores_ma_filter] set from
    the strategy-level [fast_v_arm_on_rate_alone] flag and [fast_v_min_rate_pct]
    set from the strategy-level field of the same name — a single source of the
    classifier config so both classify sites (the stop-arming {!update_ref} and
    the slow-grind-gate screen-time classify) stay consistent. With
    [fast_v_arm_on_rate_alone = false] and
    [fast_v_min_rate_pct = Decline_character.default_config.fast_v_min_rate_pct]
    (0.08) it reproduces [default_config] exactly (bit-identical to the pre-flag
    behaviour). *)

val classify :
  config:Decline_character.config ->
  macro:Macro.result ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  Decline_character.t
(** [classify ~config ~macro ~index_view] labels the current decline character
    of the primary index.

    Builds the [index_bars] list {!Decline_character.classify} reads (it
    consults only per-bar closes) from [index_view]'s weekly closes —
    chronological, oldest first, matching the [classify] contract. [macro] is
    the already-computed macro result for the current week. Pure and
    lookahead-free: every input is at the current week or earlier. *)

val update_ref :
  fast_v_arm_on_rate_alone:bool ->
  fast_v_min_rate_pct:float ->
  prior_decline_character:Decline_character.t ref ->
  macro_result_opt:Macro.result option ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  unit
(** [update_ref ~fast_v_arm_on_rate_alone ~fast_v_min_rate_pct
     ~prior_decline_character ~macro_result_opt ~index_view] stores a fresh
    {!classify} of the index into [prior_decline_character] when
    [macro_result_opt] is [Some] (a screening day) — using {!classifier_config}
    built from the strategy-level [fast_v_arm_on_rate_alone] arming-speed flag
    and [fast_v_min_rate_pct] arming rate threshold (defaults [false] / 0.08
    reproduce {!Decline_character.default_config} exactly). On a non-screening
    day ([None]) it is a no-op, so the ref retains the last classification: the
    strategy's stops pass reads it on the NEXT tick (strictly prior, no
    lookahead — the Build 2 fast-crash absolute-stop arming seam). The
    searchable mechanism flag is [stops_config.catastrophic_stop_pct]; the
    arming-speed flag is [fast_v_arm_on_rate_alone]; the arming rate threshold
    is [fast_v_min_rate_pct]. *)
