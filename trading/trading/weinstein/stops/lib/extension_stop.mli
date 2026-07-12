(** Extension stop — a wide tail-INSURANCE trail for a held long that has run
    far above its weekly moving average (a blow-off / parabolic advance).

    {1 What it is}

    Once a held long's weekly close reaches [trigger_ratio ×] its 30-week WMA
    (the stage classifier's MA basis — {!Stage.default_config}: [ma_period = 30],
    [ma_type = Wma]) the position {e arms} a wide trail; thereafter it exits on
    the first weekly close that is [trail_pct] below the running peak weekly
    close observed since the trigger. Weekly-close semantics throughout (book
    §Stop-Loss Rules: weekly re-evaluation).

    This module is {b pure} and {b date-agnostic}: it operates on the
    holding-window [(close, wma)] arrays that the strategy-side runner
    ({!Extension_stop_runner}) prepares. The peak / trigger / fire logic mirrors
    the merged extension screen
    ([analysis/scripts/extension_screen/bin/extension_screen.ml]) exactly.

    {1 It is TAIL-INSURANCE, not an alpha axis}

    This is a catastrophic-stop-class dial (same class as
    {!Catastrophic_stop} / [stops_config.catastrophic_stop_pct], PR #1695), NOT
    a performance knob. Extension events are {e rare} — the screen measured
    ~0.6-1% of episodes reach [2.0×] WMA30 over a quarter-century — so a
    walk-forward CV on this axis is structurally powerless (most folds contain
    zero events). Its acceptance basis is therefore the left-tail / dispersion /
    event-level audit (armed-vs-off record runs + the extension_screen
    counterfactual), {b never} fold Sharpe. See
    [dev/backtest/extension-screen-2026-07-11/FINDINGS.md] §"What survives".

    {1 Faithfulness (W2)}

    A faithful {b trader exit-aggressiveness} dial: on a parabolic advance far
    above the MA a trader takes profits / swing-sells rather than waiting for the
    MA violation ([docs/design/weinstein-book-reference.md] §5.3 "Trailing Stop —
    Trader Method": "Don't wait for MA violation — exit when pattern deviates
    from plan"; §Stage 3 detail Ch. 2: "Traders: exit with profits"). The
    strategy spine is untouched: stage classification, the Stage-2-only buy rule,
    breakout+volume entry, the macro/sector gate, and relative strength are all
    unaffected — only a held long gains one extra, discretionary weekly-close
    exit trigger.

    {1 Width}

    The screen pins the width: a [0.25] (25%) trail survives the on-ramp
    shakeouts of the very monsters it is meant to protect (the AXTI April 2025
    ~−18% mid-parabola dip, the January chop) and still banks the collapse;
    tighter [0.10-0.20] trails are on-ramp killers — they exit during the advance
    as often as at the top, taxing the fat tail (the 9th confirmation of the
    winner-touching tax, [[project_edge_is_the_fat_tail]]). Do NOT build tight. *)

type config = {
  trigger_ratio : float; [@sexp.default 0.0]
      (** Weekly close / 30-week WMA ratio at which the wide trail arms.
          [<= 0.0] (the default) DISABLES the mechanism — an exact no-op. A value
          such as [2.0] arms when the close reaches twice the WMA30. *)
  trail_pct : float; [@sexp.default 0.0]
      (** Fraction below the post-trigger running peak weekly close at which the
          armed trail fires. [<= 0.0] (the default) DISABLES the mechanism.
          Screen-pinned width: [0.25] survives on-ramp shakeouts; [0.10-0.20] are
          on-ramp killers. *)
}
[@@deriving show, eq, sexp]

val default_config : config
(** The no-op default ([trigger_ratio = 0.0], [trail_pct = 0.0]) — the mechanism
    is disabled, so merging it changes no backtest result
    ([.claude/rules/experiment-flag-discipline.md] R1). *)

val is_enabled : config -> bool
(** [true] iff both [trigger_ratio > 0.0] and [trail_pct > 0.0]. When [false] the
    mechanism is a no-op regardless of the price series. *)

val fired : config -> closes:float array -> wmas:float array -> bool
(** [fired config ~closes ~wmas] is [true] iff the armed extension trail has
    fired by the last element of the holding-window series.

    [closes] and [wmas] are the weekly adjusted-close and 30-week WMA of the
    position's {e holding window} (entry → as-of), same length, chronological
    (oldest first). [wmas.(i)] is [Float.nan] where the WMA window had not yet
    filled at week [i].

    Semantics (mirroring the merged extension screen):
    - Returns [false] when [is_enabled config] is [false], the arrays differ in
      length, or no week ever reaches the trigger.
    - {b Trigger}: the first week [i] with [wmas.(i)] finite and [> 0] and
      [closes.(i) /. wmas.(i) >= trigger_ratio].
    - {b Peak}: seeded at the trigger week's close; the running maximum of weekly
      closes after it. The fire-check at each later week is evaluated {e before}
      the peak is updated with that week's close, so a new high can never fire.
    - {b Fire}: the first later week whose [close <= peak *. (1. -. trail_pct)].

    Pure: same inputs always produce the same result. *)
