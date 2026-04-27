# Post-#602 RSS matrix — GC tuning addendum (2026-04-26)

Follow-on to `dev/notes/panels-rss-matrix-post602-2026-04-26.md` (#603).
Tests Option A's recommended runtime knob: re-runs the same 4 cells
with `OCAMLRUNPARAM=o=60,s=512k` (more aggressive major-GC, smaller
minor heap).

## Setup

Same scenarios. Same panel build (post-#602 main, `730d6cbf`).
Difference: `OCAMLRUNPARAM=o=60,s=512k` set in env.

## Result

| N | T | post-#602 RSS / Wall | + GC tuning RSS / Wall | Δ RSS | Δ Wall |
|---:|---:|---:|---:|---:|---:|
| 50 | 1y | 363 / 0:06 | **264 / 0:06** | −99 (−27%) | 0 |
| 50 | 6y | 511 / 0:21 | **322 / 0:24** | −189 (−37%) | +3s |
| 292 | 1y | 1,704 / 0:28 | **1,216 / 0:43** | −488 (−29%) | +15s |
| 292 | 6y | 2,323 / 1:44 | **1,453 / 2:51** | −870 (−37%) | +1:07 |

## Fit (GC-tuned)

`RSS ≈ 68 + 4.3·N + 0.2·N·(T − 1)` MB

| Component | pre-#602 | post-#602 (untuned) | post-#602 + GC tuning |
|---|---:|---:|---:|
| α (fixed) | 86 | 86 | **68** (lower) |
| β (per-symbol) | 5.12 | 5.5 | **4.3** (best) |
| γ (per-symbol-per-year) | 0.22 | 0.5 | **0.2** (recovered) |

**β recovered to 4.3** — better than ever recorded post-Stage-4. **γ
back to 0.2** (pre-#602 level). GC tuning didn't just fix the
regression; it improved on the baseline.

Wall regresses ~50% at the largest cell (vs untuned post-#602: 2:51
vs 1:44) but stays substantially faster than pre-#602 (4:05). The
trade-off is asymmetric: small N×T cells are essentially free
(0:06 same), large cells trade some wall for substantial RSS.

## Cumulative win vs pre-Stage-4

At N=292 T=6y: **3,468 MB → 1,453 MB (−58% RSS)** and **6:00 → 2:51
(−53% wall)**. Stage 4 + 4.5 + #602 + GC tuning combined.

## Release-gate projection

| N × T | post-#602 (untuned) | + GC tuning |
|---|---:|---:|
| 1,000 × 10y | 12.5 GB | **6.2 GB** ✓ fits 8 GB |
| 5,000 × 10y | 50 GB | 30 GB |
| 10,000 × 10y | 100 GB | 61 GB |

**N=1,000 × 10y fits the 8 GB ceiling** with GC tuning. That's a
viable scope for tier-4 release-gate, smaller than the original
5,000 / 10,000 plan target but achievable today without architectural
change.

For broader (N=5,000+) tier-4: the architecture needs a fundamental
change — likely a hybrid tier where most symbols carry only metadata
+ last-price (no full panel) and only "interesting" symbols (Stage 2
/ Stage 4 in active sectors) get full bar history. Separate plan
beyond Stage 4.5; revisit after the S&P-500 golden lands as a stable
benchmark.

## Action items

1. **Document the OCAMLRUNPARAM knob** in `dev/scripts/perf_tier1_smoke.sh`
   and similar perf runners. New benchmarking runs default to GC-tuned.
2. **Update the master columnar plan** §"Memory expectations" with
   the post-tuning fit so future projections use 4.3 / 0.2 not 5.5 /
   0.5.
3. **Consider the 8 GB target reachable at N≤1000**. Treat tier-4 at
   broader N as a separate architectural milestone (hybrid tier).

## References

- Source matrix: `dev/notes/panels-rss-matrix-post602-2026-04-26.md` (#603 merged)
- Memtrace: `dev/notes/panels-memtrace-postA-2026-04-26.md` (#601)
- Master plan: `dev/plans/columnar-data-shape-2026-04-25.md` §Memory expectations
