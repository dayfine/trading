(** Audit-record checks (issue #3002): part A's V19 (audit join) and V20 (audit
    price-basis sanity); part B's V21 (installed vs proxy stop) and V23
    (macro-gate bypass at fill).

    All four read [trade_audit.sexp] — V19-V21 its entry records through
    {!Validator_types.inputs.audit}, V23 its per-screen macro reads through
    {!Validator_types.inputs.screens}. When no audit was loaded at all
    ([inputs.audit_absent = Some reason]) each skips every row it covers and
    carries [reason] as the result's [skip_reason] — none passes silently. *)

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

val check_v21 : inputs -> Validator_step.finding
(** V21 (EXPECTATION) — installed vs suggested stop. Flags an entry whose
    [installed_stop] sits more than [config.installed_vs_proxy_stop_max_pct]
    (default [0.03]) away from the audit's [screener_proxy_stop]:
    [|installed_stop - screener_proxy_stop| / screener_proxy_stop], strictly
    greater flags. LONG and SHORT rows alike.

    {b What it measures.} The screener prices a candidate's risk off a fixed ~8%
    proxy; the strategy installs its own stop off the support floor or the
    [Buffer_fallback] buffer, and sizes off that. The two routinely differ
    (#2975: EQT, proxy 21.49 = 8% under [E = 23.36], installed 22.43 = the ~4%
    fallback, 4.35% apart). An EXPECTATION, not an invariant: the count says how
    often the risk the screener graded is not the risk the position carries, and
    a large count on a run is a reason to look at the fallback rate — it is not
    a bug on its own.

    {b Why the proxy is the denominator.} Both levels are stop prices, so their
    gap relative to the one the screener published reads directly as "how far
    the installed stop moved from the advertised one". Dividing by the entry
    price instead would express the gap as a change in stop {i distance}; the
    two agree to within the stop distance itself (~8%) and neither needs the
    fill price, so the audit alone decides the row.

    {b Skips} (counted in [n_skipped], with a [skip_reason]): no audit record
    for the trade, [installed_stop = 0.0] (legacy audit predating capture), or
    [screener_proxy_stop] missing or [<= 0]. No audit loaded: every row skipped
    with the load reason. *)

val check_v23 : inputs -> Validator_step.finding
(** V23 — macro-gate bypass at fill. Flags a {b LONG} round trip whose entry
    fill came after a screen that read [Bearish]: the latest
    {!Validator_types.screen_read} dated {b strictly before} the [trades.csv]
    entry (fill) date has [screen_macro_trend = Bearish]. Strictly before
    because the weekly screen runs at the Friday close, so a fill dated on a
    screen Friday traded before that screen existed.

    This is a {b fill-time} read, which is what #2976 is about: a ticket placed
    on a Bullish screen rests, the tape turns Bearish, and the ticket still
    fills. It is not V2's input — [entry_context.macro_trend] is the
    {b placement} screen's read, and that screen admitted the ticket by
    construction.

    SHORT rows are not evaluated or counted: the long macro gate and the #2976
    suspension are long-only, and a short entered after a Bearish screen is the
    intended behaviour.

    {b Skips} (counted, with a [skip_reason]): a long filled before the first
    recorded screen; every long when the audit carries no cascade summaries
    ([inputs.screens = []]); every long, with the load reason, when no audit was
    loaded.

    Severity: see {!v23_severity}. *)

val v23_severity : inputs -> severity
(** V23's default severity, from the run's [entry_ticket_macro_suspend]
    ([inputs.macro_suspend]):

    - [Some On_bearish_macro] → {!Invariant}. That mode withdraws every resting
      long ticket on any screen whose long macro gate rejects, and a [Bearish]
      trend always rejects (the gate's [neutral_blocks_longs] only widens it to
      [Neutral]), so a fill after a Bearish screen is impossible.
    - [Some Off], [Some On_index_stage4] → {!Expectation}. [Off] suspends
      nothing; [On_index_stage4] suspends only while the index is Stage 4, so a
      Bearish composite with the index elsewhere legitimately lets a ticket
      fill.
    - [None] (no readable [params.sexp]) → {!Expectation}. A chain that knows
      the flag is armed can still promote it with
      [config.severity_overrides = [("V23", "INVARIANT")]], which beats this
      default. *)
