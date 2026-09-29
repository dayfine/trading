(** Audit-record integrity checks (issue #3002, part A): V19 (audit join) and
    V20 (audit price-basis sanity).

    Both read the [trade_audit.sexp] entry records through
    {!Validator_types.inputs.audit}. When no audit was loaded at all
    ([inputs.audit_absent = Some reason]) both skip every row and carry [reason]
    as the result's [skip_reason] — they never pass silently. *)

open Validator_types

val check_v19 : inputs -> Validator_step.finding
(** V19 (INVARIANT) — audit join. Every [trades.csv] round trip (LONG or SHORT)
    must resolve to a [trade_audit.sexp] entry record with the {b same}
    [position_id].

    The join key is [position_id]: {!Validator_artifacts.build_audit_lookup}
    resolves a row carrying one on the position_id table only, so a [None] from
    [inputs.audit] on such a row means no audit entry has that id. That is the
    #2989 shape (re-issued suspended tickets written to [trades.csv] with no
    audit entry) and any future break of the join.

    - A row with no [position_id] (legacy [trades.csv] predating #1942) has no
      join key: skipped, with a [skip_reason] saying so.
    - No audit loaded ([audit_absent = Some reason]): every row is skipped and
      [reason] is reported.
    - An audit that {i was} loaded but matches nothing fires on every
      position_id-bearing row — a dead join is exactly what V19 exists to catch.

    Complements, and does not replace, the report's [audit_join] statistic
    (which counts matches over every row, including legacy symbol|date joins).
*)

val check_v20 : inputs -> Validator_step.finding
(** V20 (INVARIANT) — audit price-basis sanity. On every trade's entry-audit
    record, [close / ma_value] must sit inside
    [[config.audit_basis_ratio_min, config.audit_basis_ratio_max]] (default
    [[0.2, 5.0]]); strictly outside flags.

    {b Numerator.} [adjusted_close_at_decision] when present — the same-basis
    read #2973 prescribes, since [ma_value] is on the adjusted basis. On audit
    files written before that field existed it falls back to the raw
    [close_at_decision], which is exactly the raw-vs-adjusted mix the check is
    for: the NVDA 2021-04-23 specimen (#2973) read raw close 610.61 against an
    adjusted MA of 13.67, ratio ~44.7. The specimen detail names which field was
    used.

    {b Why the band is [0.2 .. 5].} A genuine close sits within tens of percent
    of its weekly MA — a Stage-2 breakout by construction sits just above it,
    and even a crash or a parabolic run rarely leaves price below a fifth or
    above five times a 30-week average. A basis mix instead lands the ratio on
    the cumulative split factor, which for the names that trip it (NVDA: 4:1
    then 10:1 = 40) is far outside. The band is deliberately wide: it gives up
    detecting mixes by small split factors (2:1, 3:1 land inside it) in exchange
    for no false positives on real prices, which an INVARIANT needs.

    {b Skips} (counted in [n_skipped], never violations): no audit record for
    the trade, [ma_value] missing or [<= 0], or no close field at all. *)
