(** Checks that need the per-symbol bar store: V3 (dollar-ADV floor), V4 (stale
    open position), V7 (virgin-territory vs history), V9 (overhead supply), V10
    (entry-week spike), V13 (fill causality), V14 (entry-bar stop-out). *)

open Validator_types

val check_v3 : inputs -> Validator_step.finding
(** V3 (INV): entry-week dollar-ADV at or above [min_entry_dollar_adv]. No-op
    when the gate is unarmed ([min_entry_dollar_adv = None]). *)

val check_v4 : inputs -> Validator_step.finding
(** V4 (INV): no open position whose last bar is older than
    [stale_exit_after_days] before run end. No-op when unarmed. *)

val check_v7 : inputs -> Validator_step.finding
(** V7 (INV): a [Virgin_territory] label is backed by at least
    [virgin_lookback_bars] weekly bars of history. *)

val check_v9 : inputs -> Validator_step.finding
(** V9 (EXP): no LONG entry sitting beneath a prior top within [overhead_pct]
    above the entry. *)

val check_v10 : inputs -> Validator_step.finding
(** V10 (EXP): no LONG entry whose entry-week close is more than [spike_pct]
    above the [spike_lookback_weeks]-ago close. *)

val check_v13 : inputs -> Validator_step.finding
(** V13 (INV): every trade's [entry_date] and [exit_date] have a bar for that
    symbol, and [entry_price] / [exit_price] lie inside their bar's
    [[low, high]] widened by [config.fill_price_epsilon_pct].

    Both sides are checked; the first failing leg (entry before exit) supplies
    the specimen. A missing-bar specimen names the nearest earlier bar date so
    the size of the slip is visible. Rows whose symbol is absent from the bar
    store — or whose store entry carries no daily bars — are {!Skip}ped and
    counted in the finding's skip count, not flagged. The price leg alone is
    additionally waived when the bar's close and the fill price fail
    {!Validator_step.price_basis_ok}, since a re-based store would otherwise
    flag every fill for the symbol; a row waived that way is {!Skip}ped (and so
    counted) rather than passed, so no un-evaluable row is invisible in the
    report. The date leg is basis-free and always runs — a waived price leg
    never suppresses a missing-bar violation.

    Note the direction of the waiver: it fires on {i large} bar/fill ratios, so
    a fill more than ~50% above (or ~34% below) its bar's close is waived rather
    than flagged. The price leg therefore cannot report the extreme end of its
    own violation class; that end is indistinguishable from a re-based store.

    Motivating defect: [dev/experiments/arc-rerun-2026-09-01/README.md] §D1
    (landing in PR #2645) — 2,500+ exits dated on a Saturday at the preceding
    Friday's open. *)

val check_v14 : inputs -> Validator_step.finding
(** V14 (EXP): no [stop_loss] exit that happens within
    [config.entry_bar_stopout_max_bars] trading bars of entry while the entry
    bar itself {b closed on the safe side of the installed stop} — at or above
    it for a LONG, at or below it for a SHORT. Such a position never closed
    through its stop, so the trigger was judged against the entry bar's pre-fill
    low.

    The stop is reconstructed as [entry_price * (1 - d)] for a LONG ([1 + d] for
    a SHORT), where [d] is [stop_fill_distance_pct] when present (fill-basis,
    exact) and [stop_initial_distance_pct] otherwise (E-basis, approximate).
    Rows with neither column, no bar on the entry date, no bar store for the
    symbol, or a basis mismatch between bar and fill are {!Skip}ped.
    Non-[stop_loss] exits pass untouched.

    EXP rather than INV because a genuine gap-down entry day — one that closes
    {i past} the stop — is a legitimate same-bar stop-out and must not flag.

    Motivating defect: [dev/experiments/arc-rerun-2026-09-01/README.md] §D2
    (landing in PR #2645) — 173 of 261 one-day stop-losses had entry-day low <
    stop <= entry-day close and were sold at the next open above the stop. *)
