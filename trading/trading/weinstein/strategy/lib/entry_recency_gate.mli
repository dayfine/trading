(** The [entry_max_bar_age_days] entry-recency gate (issue #2672, guard 1 of 3).

    Drops entry candidates whose most recent {b daily} bar is older than
    [max_bar_age_days] calendar days before the decision date — i.e. the symbol
    has stopped printing and the "current price" the entry path would read is a
    stale ghost.

    {b Why this exists.} The strategy resolves a candidate's effective entry
    price from [List.last (Bar_reader.daily_bars_for ~as_of:current_date)]
    ({!Entry_audit_helpers.latest_close}) with no recency check, so a symbol
    whose series ended months earlier still offers a plausible-looking close.
    The measured case (issue #2672): {b DTV}'s last bar is 2019-09-30, yet the
    strategy entered it on 2020-03-28 at $58.09 — the price of a bar 180 days
    stale — and then carried the position to the window end. The delisting
    marker that should have caught this ([Daily_price.active_through]) is
    plumbed but never populated on any warehouse, so the gate must key on the
    {b series' own last bar date}, which is what this module reads.

    {b Not a delisting detector.} A symbol can be perfectly alive and still trip
    this gate (a long trading halt, a thin name that did not print). The gate
    only asserts that the strategy will not open a position on a price it cannot
    see confirmed recently; whether the symbol is delisted is a data-ingestion
    question ({!Daily_price.active_through}), not a strategy one.

    Composes in {!Entry_assembly} after {!Entry_liquidity_gate} /
    {!Short_borrow_gate}; a dropped candidate simply never reaches the entry
    walk (the same convention as the sibling assembly-stage gates — a
    per-candidate audit trace would require threading the recorder into
    {!Entry_assembly}, a documented follow-up seam, not this PR).

    {b Default [max_bar_age_days = 0] = off}, bit-identical to every existing
    baseline / golden. Axis-expressible as
    [((flag entry_max_bar_age_days) (values (0 5 10 20)))]. Sibling #2672
    guards: [stale_exit_without_prior_bar] (realises the zombie this gate would
    have prevented) and [stub_print_max_ratio] (drops the penny-print tail that
    makes a delisted series look tradeable). See
    [Weinstein_strategy_config.entry_max_bar_age_days]. Pure with respect to the
    supplied bar reader / lookup. *)

open Core

val filter :
  max_bar_age_days:int ->
  current_date:Date.t ->
  last_bar_date_for:(string -> Date.t option) ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [filter ~max_bar_age_days ~current_date ~last_bar_date_for candidates] drops
    candidates (long AND short) whose most recent bar date [d], per
    [last_bar_date_for candidate.ticker], satisfies
    [Date.diff current_date d > max_bar_age_days].

    A candidate is {b kept} when [last_bar_date_for] returns [None] (no reading
    — a missing reading must never drop a candidate, matching
    {!Short_borrow_gate.filter}) or when the gap is within the allowance. A bar
    dated in the future relative to [current_date] yields a negative gap and is
    kept.

    No-op when [max_bar_age_days <= 0] (the default): returns [candidates]
    unchanged (bit-identical). Pure. *)

val apply :
  max_bar_age_days:int ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** Strategy-side adapter: builds the [last_bar_date_for] lookup from
    [bar_reader] via
    [List.last (Bar_reader.daily_bars_for ~symbol ~as_of:current_date)] — the
    same single read {!Entry_audit_helpers.latest_close} performs to resolve the
    effective entry price, so the gate and the price it guards cannot disagree
    about which bar is "latest" — then delegates to {!filter}. No-op at
    [max_bar_age_days <= 0], which is also the short-circuit that keeps the read
    itself off the default path. *)
