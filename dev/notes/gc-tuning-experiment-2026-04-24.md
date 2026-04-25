# GC tuning experiment: tight params don't help, heap is genuinely retained (2026-04-24)

## Hypothesis (from `dev/notes/perf-q1-q3-followup-2026-04-24.md` Q1)

> If RSS is dominated by "OCaml heap that won't shrink" rather than
> live retained data, tightening GC parameters
> (`space_overhead=20`, `allocation_policy=2 best-fit`) should drop
> Tiered RSS substantially.

## Test

```sh
OCAMLRUNPARAM="s=1M,space_overhead=20,allocation_policy=2" \
  /usr/bin/time -f '%M' \
  dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 --loader-strategy {legacy,tiered}
```

Same scoped 292-symbol fixture as PR #524 baseline.

## Result

| | Baseline (default GC) | Tight GC | Δ |
|---|---|---|---|
| Legacy peak RSS | 1,871,240 KB | 1,959,996 KB | **+88,756 KB (+4.7%, slightly WORSE)** |
| Tiered peak RSS | 3,652,852 KB | ≥3,683,564 KB (live measurement; wall-clock-killed) | **≥+30,712 KB (+0.8%, slightly WORSE)** |

Tight GC params made BOTH strategies slightly worse on peak RSS, AND
the run was substantially slower (more frequent compaction overhead).
**Hypothesis disproved.**

## What this confirms

The +95% Tiered RSS gap is **NOT** GC tuning slack. The heap is
genuinely retained data: the GC has nothing more to release. RSS
reflects actual live working set during peak, not "compactible
garbage left in the heap."

This validates the per-callsite memtrace analysis from the followup
note — the Base.List.filter / CSV._build_price callsites really do
hold live state. The "OCaml heap doesn't shrink" claim from Q1 was
a half-truth: it's a TRUE statement about behavior (RSS doesn't
shrink mid-run), but the implication (RSS = unreleased garbage)
turned out to be wrong. RSS is live data.

## Implication

To reduce Tiered RSS, the only remaining lever is **reducing actual
live retention**, not heap tuning. Two candidates from prior notes:

1. **Refactor `Bar_history.seed`** to mutate a shared list rather
   than `existing @ new_bars` (which keeps both old and new lists
   live momentarily during major-GC sweeps). Modest expected win.

2. **Process Friday-cycle symbols in smaller batches**, releasing
   intermediate state between batches. ~50 LOC change to
   `_promote_universe_to_full`. Bigger expected win — would prevent
   the heap from reaching the 292-symbol footprint at once.

3. **Use `Sequence` lazy iteration instead of `List.filter` +
   intermediate lists** in the strategy's per-step pipeline. Bigger
   refactor; helps Legacy and Tiered both.

None are dispatched today — leaving direction to user.

## Day's hypotheses tested + outcomes

| ID | Hypothesis | Outcome |
|---|---|---|
| H1 | Bar_history trim closes gap | DISPROVED (#531/#532) |
| H2 | Full.t.bars cap closes gap | DISPROVED (#542) |
| H3 | skip_ad_breadth closes gap | DISPROVED (#544) |
| H7 | CSV stream-parse closes gap | DISPROVED top-level; +130 MB Metadata win (#544) |
| GC tuning | Tight GC params recover slack | DISPROVED (this note) |

5 disproofs, 1 small partial win. The +95% Tiered RSS gap is genuinely
hard. The profiling pipeline built today (C2 harness + memtrace + per-phase
trace + live-progression dumper) is well-positioned for the next investigator
to attempt option 2 or 3.
