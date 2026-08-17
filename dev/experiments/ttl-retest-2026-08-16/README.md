# TTL re-test — defect D, and the two cells the knob split made expressible

Defect **D** of `dev/plans/entry-anchor-and-ttl-2026-08-15.md`. Six arms on the
ladder-v4 cell-00 base (top-3000 × 2000-2026, salt 0), differing only in the two
F2 fields that PR #2349 split apart.

## Why re-test at all

The tested axis was `{0, 4, 8}` weeks and never reached the useful range. P&L by
ticket rest time on cell 13 (942 joined trades):

| bucket | n | share | realized pnl | pnl/trade |
|---|---:|---:|---:|---:|
| ≤7d | 396 | 42.0% | 2,225,496 | 5,620 |
| 8-28d | 248 | 26.3% | 423,842 | 1,709 |
| **29-91d** | 152 | 16.1% | **1,273,096** | **8,376** |
| 92-182d | 59 | 6.3% | 404,455 | 6,855 |
| 183-365d | 32 | 3.4% | −10,173 | −318 |
| 1-3yr | 35 | 3.7% | 379,985 | 10,857 |
| **>3yr** | 20 | 2.1% | **−154,006** | **−7,700** |

**ttl4's 28-day cut lands on the lower edge of the best bucket.** The new axis is
`{13, 26, 52}` weeks — 13 weeks is ~91 days, i.e. the *top* of that bucket rather
than its bottom.

## The arms

| spec | re-screen | clock | asks |
|---|---|---|---|
| `00-null` | off | 0 | Determinism tripwire — must reproduce 281.71. |
| `01-rescreen-only` | **on** | 0 (unbounded) | **The book-supported half alone.** |
| `02-ttl13` | on | 13w (~91d) | Cut at the top of the best bucket, not its edge. |
| `03-ttl26` | on | 26w (~182d) | |
| `04-ttl52` | on | 52w (~1y) | |
| `05-clock156-only` | off | 156w (~3y) | **The defect-E absurdity bound alone.** |

Arms 01 and 05 could not be expressed before #2349: one field armed both
mechanisms, and returned `[]` at `0` without consulting the re-screen predicate
at all. They are the point of the split — 01 asks what the *faithful* half is
worth on its own, and 05 asks what removing only the 21.7-year absurdity costs.

## Reading it

**The null on this exact base/window/universe is 132.5pp**, measured from three
path salts (`dev/experiments/ladder-v4-seeded-2026-08-14/results.md`, cell 00 at
265.44 / 281.71 / 397.95). **No gap below 132.5pp is interpretable**, and every
arm here is a single salt, so this run can only find effects larger than that.
An arm that looks promising needs its own salts before it means anything.

`00-null` is the tripwire, not a measurement: post-#2279 the runs are
deterministic, so it must return **281.71** exactly. Any other number means the
binary moved between the seeded run and this one, and the comparison to the
132.5pp null is void.

The prior from the seeded run is that **the number is a free dial** — ttl4 vs
core was +0.5pp and ttl8 vs ttl4 was 35pp, both inside the null — so the
expected outcome is that 02/03/04 are indistinguishable from 01, and the
interesting cells are **01** (does the re-screen pay at all?) and **05** (does
bounding the 21.7-year tail cost anything?).

## Running

Specs are duplicated to `/tmp/ttl-retest-specs/` deliberately: a long chain must
read its inputs from outside the repo, because `jj new` deletes uncommitted repo
paths out from under a running run (`sweep-hygiene.md`).

Requires a build with the #2349 knob split — the field names
`enable_entry_ticket_rescreen` / `entry_order_max_rest_weeks` do not exist
before it, and a spec naming an unknown key fails validation loudly rather than
silently running the baseline (the #1051 hazard).

```sh
# pinned worktree at the merge commit of #2349, per sweep-hygiene.md
git worktree add --detach .claude/worktrees/sweep-ttl-retest <sha>
# then per arm, from that worktree:
TRADING_DATA_DIR=<wt>/trading/test_data TRADING_PATH_SEED_SALT=0 \
  ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
    --dir <workdir> --fixtures-root <wt>/trading/test_data/backtest_scenarios \
    --snapshot-dir /tmp/snap_top3000_dedup_v5thin_adj \
    --no-emit-all-eligible --parallel 1 --progress-every 26
```

~1h per arm, ~6h total. One at a time — a 26y top-3000 run holds ~2.2-2.4 GB and
no agent may be dispatched alongside it (`container-capacity-scheduling.md`).
