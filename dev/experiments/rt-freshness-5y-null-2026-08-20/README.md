# Does the 5-year testbed have a drawdown null? — 2 arms × 3 salts

**Status at commit time: NOT YET RUN.** Everything below is pre-registered.
Results and the verdict land in a later commit, so the decision rule provably
predates the numbers.

## The question

The 26y seeded A/B (`../rt-freshness-seeded-2026-08-20/`) found
`entry_freshness_basis = Range_top_breakout` improving MaxDD **38.76 → 30.81**,
clearing a *measured* 4.76pp null at all three salts. The 5-year sp500 testbed
(`../ladder-v4-small-deterministic-2026-08-12/`) says the opposite:
**16.98 → 21.43**, i.e. **+4.45pp the wrong way**.

The 26y writeup first dismissed the 5y result with *"5 years of 187 names cannot
resolve a ~3pp drawdown effect."* **That threshold was asserted, never
measured** — qc-behavioral F4 on #2433. Dismissing the 5y number requires its
drawdown null to sit above ~4.5pp, and **no run in this repo establishes any 5y
null at all.**

Every prior 5y cell was a *single realization*. Re-running one reproduces
digit-for-digit (verified 2026-08-20) — which proves the binary is
deterministic, and says nothing whatsoever about spread **across** salts. That
spread is what a null is, and it is what has never been looked at.

## Design

Two arms × salts {0,1,2} = 6 cells, ~4 min each against committed
`trading/test_data` ⇒ ~25 min total. Arms are paired within a salt so both see
the same intraday path realization; compare within-salt, never mean-to-mean.

- `specs/sm-v4-00-core-w4.sexp` (`Ma_cross`) — copied verbatim from
  `../ladder-v4-small-deterministic-2026-08-12/specs/`
- `specs/sm-v4-02-fresh-rangetop.sexp` (`Range_top_breakout`) — same source

Verified single-flag delta: the two differ only in `entry_freshness_basis`
plus `name`/`description`.

This is deliberately the **same six-cell shape as the 26y run**, so the two
nulls are directly comparable rather than two differently-shaped estimates.

## Decision rule, pre-registered

1. **Tripwire.** core at salt 0 must reproduce `total_return_pct` ≈ **112.28**
   and `max_drawdown_pct` ≈ **16.98**. A miss means the binary or the data
   moved and nothing else is interpretable.
2. **Null per metric** = max − min across core's three salts.
3. **Read the answer off the null, not the point estimate:**
   - 5y MaxDD null **> 4.45pp** ⇒ the 5y contradiction is inside its own noise.
     It never was evidence against the 26y result, and the dismissal in the 26y
     writeup becomes correct *for the first time* — measured, not asserted.
   - 5y MaxDD null **< 4.45pp** ⇒ the contradiction is **real**, and the 26y
     drawdown finding is regime- or universe-conditional rather than general.
     This blocks a confirmation grid framed on 26y alone, and **must be
     reported as loudly as the favourable outcome.**
   - null within ~1pp of 4.45 ⇒ underpowered at 3 salts. Say so and extend to
     5 salts rather than picking a side.
4. Report the rt-vs-core gap per salt against that null under the same
   all-three-salts rule the 26y run used. Sign flips ⇒ not moved.

Both outcomes are written down before the run, and one of them undercuts a
finding this session already published. That is the point of writing them first.

## Why this is worth the 25 minutes

It is the cheapest open measurement in the program relative to what it settles.
Either it retires a standing contradiction between two horizons, or it caps how
far the 26y result can be carried. `run.sh` carries the same reasoning inline.

