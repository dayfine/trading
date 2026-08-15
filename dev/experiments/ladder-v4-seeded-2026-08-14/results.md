# Ladder v4, re-measured on the seeded binary — results

11 runs, 2026-08-14 13:03 → 2026-08-15 10:49. Pinned worktree at `60100bbf6`,
top-3000 PIT-2000, 2000-01-01..2026-06-26, snapshot warehouse
`/tmp/snap_top3000_dedup_v5thin_adj`, `--parallel 1`.

Supersedes the 2026-08-11 chain entirely. That one ran on the **nondeterministic**
binary (chain start 08-11T05:22Z; path-seed fix #2279 merged 08-12T08:43Z) and
its own duplicate-cell null put the floor at ~278pp, so none of its cell ranking
was interpretable.

## The null first

Cell 00-core-w4, identical config, three independent path-seed salts:

| salt | return | trades |
|---|---|---|
| 0 | 281.71 | 1147 |
| 1 | 397.95 | 1135 |
| 2 | 265.44 | 1172 |

**Spread 132.5pp on a mean of 315.0** — ±21% of the mean, from the seed alone.
Trade counts move by 37 as well.

All three reproduce the previously recorded values digit-for-digit, so the binary
is bit-reproducible across sessions: this spread is genuine path sensitivity, not
residual nondeterminism.

**132.5pp is the yardstick.** No variant gap below it is interpretable.

## Results

Paired against core at the **same salt** (s0 = 281.71), so both arms see the same
intraday path realization:

| cell | return | trades | vs core s0 | clears the null? |
|---|---|---|---|---|
| **13-rt-nearfloor** | 568.10 | 953 | **+286.4** | **YES** |
| **15-rt-ttl4-nearfloor** | 508.12 | 868 | **+226.4** | **YES** |
| **09-nearfloor** | 483.10 | 970 | **+201.4** | **YES** |
| 01-anchor-w8 | 374.27 | 1134 | +92.6 | no |
| 07-maxstop50-diag | 363.86 | 1493 | +82.2 | no |
| 03-ttl4 | 282.20 | 1099 | +0.5 | no |
| 04-ttl8 | 247.20 | 1100 | −34.5 | no |
| 05-maxstop25 | 236.95 | 1322 | −44.8 | no |

## Finding 1 — TTL is nearly free, and the clock number is not load-bearing

`03-ttl4` returned **282.20** against core's **281.71** on the same seed:
**+0.5pp**. `04-ttl8` vs `03-ttl4` is 35pp, well inside the null — so moving the
clock from 4 weeks to 8 does nothing measurable.

That is exactly what the faithfulness pass predicted. One knob arms two
mechanisms (`weinstein_strategy_screening.ml:299` returns `[]` at 0 without even
consulting the re-screen predicate): the weekly **re-screen cancel** and the
**clock** backstop. ttl4 and ttl8 were already near-identical on rest-time
(68.2% vs 65.3% filling within a week, both hard-zero beyond 90 days), and they
are near-identical on return too. **The re-screen is doing the work; the number
is a free dial** — which is the right way round, since the re-screen is the
book-supported half (§4.7 cancel authority, §7 weekly review) and the number is
one the book never names.

So arming TTL removes the entire stale-signal population — from 54-105 fills more
than a *year* after their signal, to zero fills beyond 90 days — **at no return
cost the data can detect.**

⚠ Single salt per variant. "No measurable cost" means *smaller than 132pp*, not
zero. Pinning it tighter needs 3 salts of ttl4.

## Finding 2 — nearfloor is the only axis that clears the null, and it does so three ways

| mix | return |
|---|---|
| 09-nearfloor | 483.10 |
| 15-rt-ttl4-nearfloor | 508.12 |
| 13-rt-nearfloor | 568.10 |

All three sit above the null's **maximum** (397.95), not merely above its mean.
Three independent mixes agreeing is stronger than one cell clearing a bar.

They also trade **fewer names** (868-970 vs core's 1147), consistent with
`project_record_gap_is_concentration` — the record runs ~half our concurrent
position count at the same exposure.

## What this retires

`anchor-w8`, `maxstop25` and `maxstop50` all land inside the noise. The old
table's apparent structure on those axes was the unseeded path, not the config.
`maxstop50`'s old 726.2 — the single best number in the 08-11 run — comes back at
**363.86**, inside the null. It was noise.

`volconf` was not re-run: its REJECT survives on structural grounds (3x candidate
explosion, 3145 vs 1136 trades, return collapsing to −47.6%), which no path seed
produces.

## What this does NOT establish

**This is one window and one universe.** Per `promotion-confirmation.md` a
ledger ACCEPT from a single walk-forward surface is necessary but not sufficient
to flip a default; the candidate must clear a confirmation grid of ≥3
(period × universe) contexts, with the promotable *value* robust across the grid
rather than winning on the one window that produced the ACCEPT.

The 2000-2026 window does at least span two genuine bear regimes (dot-com bust
and the GFC), which satisfies the macro-diversity requirement for *one* cell —
the 2026-05-31 early-admission reversal is the standing warning about grids that
only see bull data.

**Next step is the grid, not a default flip.** Two candidates go into it, and
they compose: **nearfloor** (the return effect) and **ttl4** (the faithfulness
fix, free). `15-rt-ttl4-nearfloor` is that combination and posts 508.12.
