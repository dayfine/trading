# Ladder v4 — asynchronous faithful entry ticket: scenario specs (2026-08-10)

PR-6 of `dev/plans/entry-ticket-async-v2-2026-08-10.md`. Twenty-four staging
scenarios that expand the plan's §5 experiment design over the ladder-v3
faithful-StopLimit base. **Specs only — nothing has been run from this
directory yet.**

- Plan (design + pre-registered predictions): `dev/plans/entry-ticket-async-v2-2026-08-10.md` §5
- v3 results + trade dissection: `dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md`
- v3 specs (the base these deltas are measured against): `../ladder-v3-faithful-stoplimit-2026-08-09/`
- Verdict memory: `project_faithful_ticket_structural_exclusion`

## Comparators (fixed, same window/universe)

| comparator | return |
|---|---:|
| record-nextopen | +7,321% |
| book-honest | +310% |
| faithful w4 (= cell 00 here) | +318% |
| faithful w13 | +262% |

## ⚠ The anchor axis is TRUNCATED

Plan §5 lists `anchor ∈ {4, 8, base-extent}`. **The base-extent anchor does not
exist**: `entry_anchor_local_range_weeks` is a plain int lookback and no
base-extent variant was ever built on main. The v4 anchor axis therefore runs
`{4, 8}` **only** — the two aggressive cells.

Per the plan's own §3-F1 caveat, the book's anchor is "the top of the CURRENT
trading range" and bases "can last months or years", so a 4–8 week local high
can be an intra-base swing high. These windows are **approximations** of the
book anchor, not the definition. **v4 must not be read as a fully-explored
anchor axis.** Every scenario header repeats this note.

## Cells

Method per plan §5: one-axis-at-a-time deltas off a single v2-core cell
(Stage A), then composed cells (Stage B). `Drop@X` = `Drop_over_max` with
`max_stop_distance_pct = X`; `Sizedown@X` = `Size_down` with
`stop_width_size_down_max_pct = X` (gate stays at 0.15); `Nearest@X` =
`support_floor_anchor_scope = Nearest` with `max_stop_distance_pct = X`.
`RTB` = `Range_top_breakout`. **ᵈ = diagnostic-only** — per plan §5 the 0.35 /
0.50 width cells and every `Size_down` cell are pre-registered as measurement
cells, **not** promotion candidates; promoting one would be an explicit,
documented deviation from book §5.1's 15% (and §5.3's trader preset is 4–6%).

### Stage A — one-axis deltas off the v2-core cell

| # | slug | anchor | freshness | TTL | width | vol-confirm | what it isolates |
|---|---|---|---|---|---|---|---|
| 00 | `core-w4` | 4w | Ma_cross | 0 | Drop@0.15 | false | reference cell; reproduces v3 faithful-w4 (+318%) |
| 01 | `anchor-w8` | 8w | Ma_cross | 0 | Drop@0.15 | false | anchor window (v3 killed its w8 arm) |
| 02 | `fresh-rangetop` | 4w | RTB | 0 | Drop@0.15 | false | F1 clock — plan prediction 3 |
| 03 | `ttl4` | 4w | Ma_cross | 4 | Drop@0.15 | false | F2 TTL — plan prediction 1 |
| 04 | `ttl8` | 4w | Ma_cross | 8 | Drop@0.15 | false | looser TTL bracket |
| 05 | `maxstop25` | 4w | Ma_cross | 0 | Drop@0.25 | false | F4 — where the §5.1 gate binds |
| 06 | `maxstop35-diag` | 4w | Ma_cross | 0 | Drop@0.35ᵈ | false | F4 diagnostic |
| 07 | `maxstop50-diag` | 4w | Ma_cross | 0 | Drop@0.50ᵈ | false | F4 diagnostic; clears AXTI's 36.2% |
| 08 | `sizedown50-diag` | 4w | Ma_cross | 0 | Sizedown@0.50ᵈ | false | F3 tolerated-participation reading |
| 09 | `nearfloor` | 4w | Ma_cross | 0 | Nearest@0.15 | false | the book's own width remedy (F3's faithful rival) |
| 10 | `volconf` | 4w | Ma_cross | 0 | Drop@0.15 | **true** | F5 — plan prediction 4 |
| 11 | `anchor-w8-rangetop` | 8w | RTB | 0 | Drop@0.15 | false | anchor × freshness interaction |

### Stage B — composed cells

| # | slug | anchor | freshness | TTL | width | vol-confirm | what it isolates |
|---|---|---|---|---|---|---|---|
| 12 | `rt-ttl4` | 4w | RTB | 4 | Drop@0.15 | false | M1 + M2 together, gate untouched |
| 13 | `rt-nearfloor` | 4w | RTB | 0 | Nearest@0.15 | false | two book-supported changes |
| 14 | `rt-volconf` | 4w | RTB | 0 | Drop@0.15 | true | pure process-fidelity pair |
| 15 | `rt-ttl4-nearfloor` | 4w | RTB | 4 | Nearest@0.15 | false | faithful triple; F5's marginal read vs 16 |
| **16** | **`rt-ttl4-nearfloor-volconf`** | 4w | RTB | 4 | Nearest@0.15 | true | **FLAGSHIP** — fully faithful, no diagnostic knob |
| 17 | `rt-ttl8-nearfloor-volconf` | 4w | RTB | 8 | Nearest@0.15 | true | TTL robustness of the flagship |
| 18 | `rt-ttl4-nearfloor-volconf-w8` | 8w | RTB | 4 | Nearest@0.15 | true | anchor robustness (within the truncated axis) |
| 19 | `rt-ttl4-maxstop25` | 4w | RTB | 4 | Drop@0.25 | false | process vs width-gate separation |
| 20 | `rt-ttl4-maxstop35-diag` | 4w | RTB | 4 | Drop@0.35ᵈ | false | diagnostic extension of 19 |
| 21 | `rt-ttl4-sizedown50-diag` | 4w | RTB | 4 | Sizedown@0.50ᵈ | false | diagnostic; faithful rival is 15 |
| 22 | `rt-volconf-sizedown50-diag` | 4w | RTB | 0 | Sizedown@0.50ᵈ | true | diagnostic; max tail-participation bound |
| 23 | `rt-ttl4-nearfloor-maxstop25` | 4w | RTB | 4 | Nearest@0.25 | false | book remedy + one notch of loosening |

Cell **16** is the arm that answers the plan's actual question: does
asynchronous-ticket process fidelity alone close any of the ladder-v3 gap? If
it does not, plan §5's stop rule applies — **re-dissect, do not knob-search.**

## Standing caveats (repeated in every scenario header)

- **Overhead grading gates no arm.** No cell applies a hard book §4.3 overhead
  gate. Overhead enters only via the default-on continuous supply score
  (`overhead_supply` armed + screener `w_overhead_supply = 30`, bundle-promoted
  2026-07-23) — a **rank demotion** of heavy-overhead names, never an
  exclusion. Per plan §1, a faithful process may legitimately exclude the
  crash-recovery monsters: **AXTI-capture is not a success criterion.**
- **Preset mix.** All arms run full-size tickets (a *trader* sizing dial) on the
  *investor* stop/exit base — deliberate, per plan §3 "Preset statement",
  because scale-in (½ + ½) was built and REJECTED (#1855 arc, fat-tail tax).
- **F5 sim/report divergence.** `Weekly_snapshot_generator` does **not** thread
  the F5 placement waiver (qc-behavioral finding on #2267), so once
  `volume_confirm_at_fill` is armed the simulator and the weekly report
  disagree on admission. Compare arms to arms, never sim to report.
- **Audit limitation.** Ticket-age-at-**fill** is structurally capped at ~1 week
  until the `position_id` join lands (#2270). The TTL axis's *behavioural*
  effect is measurable; "how long tickets actually rested before filling" is
  not yet.

## Mechanisms and their PRs

| axis | config field | PR |
|---|---|---|
| freshness basis | `entry_freshness_basis` | #2261 |
| ticket TTL | `entry_order_ttl_weeks` | #2263 |
| stop width | `stop_width_mode`, `stop_width_size_down_max_pct`, `stops_config.support_floor_anchor_scope` | #2258 |
| volume confirm | `volume_confirm_at_fill` | #2267 |
| audit fields | (measurement only) | #2270 |

All are default-off / no-op-defaulted per
`.claude/rules/experiment-flag-discipline.md` R1. Every spec writes **all**
v4 axes explicitly — including no-op values — so each file states its full v4
coordinate and a typo'd flag fails `Overlay_validator` validation rather than
silently running the baseline (the #1051 "81 bit-identical cells" hazard). That
is pinned by `trading/backtest/scenarios/test/test_ladder_v4_overlays.ml`.

## Running

Not a golden — these carry sentinel `expected` bands and are excluded from the
golden-parse sweep in `test_scenario.ml`. Run provenance recorded in every
header: split-safe warehouse `/tmp/snap_top3000_dedup_v5thin_adj`,
`SNAPSHOT_CACHE_MB=1024`, `--no-emit-all-eligible`, `--parallel 1`, universe
top-3000 PIT-2000, window 2000-01-01 → 2026-06-26.

Run artifacts (trades / audit / faithfulness reports) are **not** committed —
per v3 convention they live under `.sweep-output/` (ephemeral, host-local).
