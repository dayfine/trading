(** V15: a round trip whose fill bar sits on a data SPLICE.

    Split out from {!Validator_bar_checks} because it asks a different question
    from every other check: V1-V14 ask whether the strategy's decision or the
    resulting fill was sound, V15 asks whether the BARS the strategy was handed
    describe one security at all. *)

open Validator_types

val check_v15 : inputs -> Validator_step.finding
(** V15 (EXP): no round trip that is {b both} implausibly profitable and
    implausibly brief — [|pnl_pct| > config.splice_pnl_pct_threshold] while held
    at most [config.splice_max_days_held] calendar days — whose entry bar or
    exit bar sits on a {b data splice}: an [adjusted_close] that moved by a
    factor strictly outside
    [[config.splice_adj_ratio_min, config.splice_adj_ratio_max]] against the
    immediately preceding daily bar.

    The ratio is taken on the {b adjusted} series precisely so that ordinary
    corporate actions do not flag: a split moves the raw close and leaves the
    adjusted close continuous, so only a discontinuity the adjustment does
    {i not} explain — a ticker recycled onto a different security, or a vendor
    splice — can trip this. The P&L test is on the {b magnitude}, so [side] does
    not enter: a SHORT caught by the same artifact loses as much as the LONG
    gains, and flags identically.

    Both legs are checked; the entry leg supplies the specimen when both are
    spliced. A row is {!Validator_step.Skip}ped, not passed, when it is a
    candidate the check cannot evaluate: symbol absent from the bar store, store
    entry with no daily bars, no bar on a fill date, a fill bar that is the
    {b first} of the series (no prior bar to compare against), or a non-positive
    prior [adjusted_close]. Rows that are not candidates at all pass untouched,
    so the skip count measures un-evaluable {i candidates} rather than the whole
    run.

    Note this check needs no [Validator_step.price_basis_ok] guard: it compares
    two bars of one stored series against each other and never against a
    [trades.csv] fill price, so a post-run re-basing of the store cancels out.

    EXP rather than INV because the flag is a data-quality signal about the bar
    store, not a break of a strategy invariant — the strategy did exactly what
    its inputs told it to.

    Motivating defect: issue #2646 — [CHS] 2004-12-17 -> 2004-12-20, adjusted
    close 4.0693 -> 15.8803 (x3.9) on volume ~5M -> ~1M, producing a +$513,550
    phantom three-day round trip. The committed scan of the same warehouse is
    [dev/experiments/arc-rerun-2026-09-01/results/splice-scan.csv] (11,028
    candidate bars; 184 of them tradeable). *)
