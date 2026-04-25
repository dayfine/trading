# Perf followup: GC behavior, Legacy bottleneck, Tiered Promote_full carrier (2026-04-24)

Three questions raised after H7 disproved. Investigated using
`legacy.memtrace.ctf` and `tiered.memtrace.ctf` from
`dev/experiments/perf/H7-verify/` plus the live-progression dumper at
`/tmp/dumper/` (not committed; ad-hoc tool).

## Q1: Are we GC'ing? **Yes — GC runs and reclaims memory, but RSS doesn't shrink.**

Legacy live-words progression (sampled words, every 250K events):

```
Event 3.0M:  3.3 MB live  ← allocation burst (e.g., a big Friday cycle)
Event 3.25M: 2.3 MB       ← GC ran, reclaimed 1 MB
... steady at ~2.3 MB through event 6.75M ...
Event 7.0M:  6.4 MB       ← another burst
Event 7.25M: 4.3 MB       ← GC again, reclaimed 2.1 MB
... steady at ~4.3 MB through event 9.25M (end of trace) ...
```

**OCaml's GC is functioning correctly.** Live count drops at each step boundary as the major GC sweeps. But **RSS stays at the high-water mark (1.87 GB Legacy / 3.65 GB Tiered)** because OCaml's GC compacts within the heap and rarely returns pages to the OS.

This single observation explains all 4 disproved hypotheses (H1, H2, H3, H7):
- **A churn-reduction fix doesn't help unless it prevents the heap from EVER expanding to peak.**
- Once the heap is at 3.5 GB on day 1 of the backtest, it stays there for the next 5.99 years.
- H7's `Csv_storage.get` streaming reduces churn AFTER the first peak; saves ~130 MB on the Promote_metadata phase only because Metadata happens BEFORE Promote_full's bigger peak.

## Q2: Legacy's bottleneck — same callsites as Tiered, half the volume

Legacy peak (estimated true bytes; at event 7.0M = peak burst, post-#543 trace):

| Site | Legacy KB | % of Legacy peak |
|---|---:|---:|
| Base.List.filter | 676,753 | **46%** |
| CSV._build_price (5 per-field variants) | ~230,000 | 16% |
| Stdlib.List.rev_append | 143,523 | 10% |
| Base.List.append_loop (5 sites) | ~163,000 | 11% |
| Trading_engine.Price_path (synthetic intraday) | 45,469 | 3% |
| Stdlib.Bigarray.Array1.create | 23,990 | 2% |
| **Total estimated peak** | **1,467 MB** | (matches actual 1.87 GB within sampling noise) |

**Same callsite ranking as Tiered**, just smaller absolute. The strategy code allocates a lot of intermediate lists per simulator step:
- `Base.List.filter` is dominant — likely from `_screen_universe` filtering candidates per step, `Stops_runner._compute_ma`'s `weekly_bars_for ~n:52`, `_make_entry_transition`'s support-floor lookback (90-day filter), and the various candidate ranking pipelines.
- `CSV._build_price` lives in the parser, allocated when bars are loaded into Bar_history. Persists through the run.
- The small Bigarray allocation is from `Ad_bars.load`'s breadth aggregation.

Legacy's bottleneck is **not** any one obvious "leak" — it's the strategy's overall use of immutable list operations on bar histories. To attack Legacy's RSS, the targets would be the same ones that would attack Tiered's: reduce `List.filter` allocations in the per-step strategy code (e.g., use `Sequence` lazy-iteration patterns, share intermediate lists more).

## Q3: Tiered's Promote_full carrier (partial answer)

Tiered's H7-verify trace truncated at event 1.07M (vs Legacy's 9.25M and pre-H7 Tiered's 4.6M). The malformed-trace bug fires earlier post-H7 — possibly because the streaming change reorders allocations in a way that trips memtrace's monotone-timestamp check sooner. So we don't directly see Tiered's actual peak in H7-verify.

What we DO see: at event 1.0M (early in trace), Tiered live = 1.3 MB sampled, top callsites:

| Site | Tiered KB at event 1.0M |
|---|---:|
| Base.List.filter | 894,576 |
| CSV._build_price | 387,147 |
| Stdlib.List.rev_append | 318,063 |
| Trading_engine.Price_path | 111,641 |

Comparing pre-H7 vs post-H7 Tiered's `Base.List.filter` LIVE: ~1,445 MB pre → ~894 MB post = **-551 MB** (-38%). The streaming fix DID reduce live List.filter allocations substantially. But total RSS didn't drop because the heap was already expanded.

## Implication for next attempt

Per Q1: the only way to reduce Tiered's RSS is to **prevent the heap from expanding to the first peak in the FIRST place.** Two approaches:

1. **Force `Gc.compact ()` after Promote_full** to force OCaml to return memory to the OS. One-line change. Cheap to test. May or may not work depending on OCaml's implementation of `compact` — on glibc malloc the compact can madvise unused pages back, on jemalloc it usually does. Worth trying.

2. **Process symbols in smaller batches with explicit Gc cycles between** so the working set never reaches the 292-symbol footprint at once. ~50 LOC change to `_promote_universe_to_full`.

3. **Don't promote Full for symbols never used** — in practice the inner Weinstein screener only enters a few dozen symbols. The current wrapper promotes ALL 292 to Full each Friday (the post-#519 fix). Could reverse that and only promote candidates from the inner screener — but that re-introduces the bug #519 fixed (inner needs Bar_history to even score).

Suggested first test: **option 1** (Gc.compact) — pure additive, ~1 line. If it works, RSS drops dramatically. If it doesn't, we know the heap is genuinely retained data and need approach 2 or 3.

## Methodological closure

After 4 disproved hypotheses, the day's diagnosis is:
- **The +95% Tiered RSS gap is real but is "OCaml heap that won't shrink".** Reducing churn doesn't help; the heap is already big.
- **The first Promote_full sets the peak.** Subsequent work fits inside.
- **Same callsites bottleneck both Legacy and Tiered**, just ratios differ.

The profiling pipeline built today (C2 harness + memtrace + per-phase trace + live-progression dumper) made 4 disprovals fast (~30min each). Building the harness took most of the day; using it would be the work going forward.

## Artifacts

- This note: `dev/notes/perf-q1-q3-followup-2026-04-24.md`
- Live-progression dumper: `/tmp/dumper/dump.ml` (not committed; tool is one-off; could be promoted to `dev/scripts/` if it becomes regularly used)
