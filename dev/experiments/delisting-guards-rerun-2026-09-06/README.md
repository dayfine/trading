# #2672 delisting guards — paired record re-run (2026-09-06)

**Status: RUNNING (2026-09-06).** Build pinned at 3113f751e = PR #2686's first commit; the two rework commits (cd6c8febc, 72670075a) and the squash 1b7295cae add only tests, docstrings and one exported helper, so the pinned build is behaviour-identical to merged main. Field names in
`specs/dg-*-on.sexp` / `chain.sh` are the merged ones.

## Question

How much of the canonical 26y record (302.65% / 723 / Sharpe 0.40 / maxDD 36.26,
`../record-rebase-2026-09-03/`) is phantom loss from delisting stub prints and
stale-bar entries (issue #2672), and does the record re-base once the three
default-off guards are armed?

## Cells (salt 0, one build)

| cell | window | universe / warehouse | arm |
|---|---|---|---|
| `dg-26y-off` | 2000-01-01..2026-06-26 | top-3000-2000 / `snap_top3000_dedup_v5thin_adj` | guards off — must reproduce `rec26y-new-s0` digit-for-digit (build-drift tripwire, `project_record_basis_divergence_0823`) |
| `dg-26y-on` | same | same | `entry_max_bar_age_days 10`, `stale_exit_without_prior_bar true`, `stub_print_max_ratio 0.05` (+ the record's own `stale_exit_after_days 5`) |
| `dg-5y-2019-off` / `-on` | 2019-01-02..2023-12-29 | top-3000-2019 / `snap_top3000_2019` (2019 vintage — DTV, ABK present) | same pair |

Pre-registered reads: STMP 2021 exit moves from $0.04 to the last real print
(~$329.6, `stale_force_exit` or `delisted`); CLE 2014 (interleaved series) is
**not** expected to move — it is the sibling defect class (issue comment
2026-09-05); DTV 2020-03-28 is not entered in the 2019 arm. Every other
difference is dissected trade-by-trade (`position_id` join) before any number
is quoted (`feedback_always_dissect_before_reporting`).

## Launch

```sh
SHA=<merged sha>; git worktree add --detach .claude/worktrees/sweep-dg0906 "$SHA"
# build scenario_runner in the worktree (docker, cwd = the worktree's trading/)
mkdir -p /tmp/dg0906-run/specs && cp specs/*.sexp /tmp/dg0906-run/specs/   # inputs outside any VCS tree
nohup sh chain.sh > /tmp/dg0906-run/launch.log 2>&1 &
```

Results are copied per arm to `/tmp/sweeps/dg0906/` and committed under
`results/` (`feedback_commit_raw_per_arm_artifacts`).

## Results so far (2026-09-06, build 3113f751e = PR #2686 tip, salt 0)

| cell | return % | trades | win % | Sharpe | maxDD % | wall |
|---|---:|---:|---:|---:|---:|---:|
| `dg-5y-2019-off` | 16.79 | 179 | 29.6 | 0.26 | 22.04 | 1992 s |
| `dg-5y-2019-on` | 52.12 | 169 | 32.5 | 0.58 | 21.65 | 2020 s |

**Tripwire passed:** the off arm reproduces the recorded 2019-vintage null
(16.8% / 179 / maxDD 22.0, priorities doc 2026-09-06) digit-for-digit.

**Dissection (join `symbol|entry_date`, `dissect` awk in this README's history):**
162 shared trades, drift **+$170,777 — all of it STMP** (2021-07-30 entry:
`stop_loss` at $0.04 on 2021-10-06, −$175,779 → series-end exit at $329.61 on
2021-10-11, +$1,530). 17 off-only trades (−$119,785) vs 7 on-only (−$48,977) are
path divergence after that cash difference; the only other |Δ| > $50k is MGNI
2023-07-11 (on-only, −$57,586, `stop_loss`). Read: **the +35pp is one phantom
loss removed**, not a mechanism gain — quote the cell as "STMP-corrected", never
as a lever. DTV does not appear in either trade set on this build (its entry
was in the 12%/14% wide-stop arms, not the record convention).

Caveat carried from qc-behavioral on #2686 (CP1-a): the stub-tail guard also
truncates a *genuine* terminal collapse below the ratio, so any delta mixes
phantom-loss removal with real-bankruptcy-loss removal; for this cell the
whole delta is STMP (a cash takeover), so the caveat is inert here — re-check
on the 26y arm, whose window holds many more delistings.

Observability defect found: the STMP series-end exit row has an empty
`exit_trigger` — pre-existing for every stale force-exit (the record carries 7
blank rows); filed as a separate issue.

26y arms: the chain aborted on its memory guard (`2941MiB free < 4096`) while
a rework agent was building; relaunch resumes at `dg-26y-off` (RESULT-skip).

| `dg-26y-off` | 302.65 | 723 | 34.3 | 0.40 | 36.26 | 9615 s |

**26y tripwire passed (06:23 PT):** `dg-26y-off` reproduces `rec26y-new-s0`
(302.65% / 723 / Sharpe 0.40 / maxDD 36.26) digit-for-digit on the #2686 build —
no build drift; the on arm's delta is attributable to the three guards alone.
| `dg-26y-on` | 139.81 | 714 | 33.1 | 0.29 | 38.39 | 10206 s |

## 26y dissection (09:15 PT) — a path lottery, not a guard cost

The on arm is **163pp below** the record it was meant to correct upward. Trade-level join
(`symbol|entry_date`): only **457** of ~720 trades are shared (drift +$188k, of which STMP
is +$597k: −$593,988 `stop_loss` at $0.04 → +$3,154 series-end exit at $329.61); **266
off-only trades netted +$1,246,524** versus **257 on-only trades at +$35,322**. The shared
2020 winners (BBWI, LOGI, NVDA) fill at identical prices for ~40% less P&L — the on arm
simply had less equity by then.

**First divergence: 2003-06-12.** Trade sets are identical up to that date with no P&L
difference. The off arm enters BKNG (2003-06-12, a −$17.8k stop-out four days later); the
on arm enters SEIC on 06-17 instead. The cascade records explain it: on the 2003-06-13
screen the off arm sees `total_stocks 2151`, the on arm `2150` (and 2183 vs 2182 a week
later). **The stub-tail guard truncates one 2003 delisting's terminal stub run**, so that
symbol leaves the universe a few bars earlier than in the off arm; the top-20 admission
list (with its alphabetical tiebreak, `project_screener_alphabetical_tiebreak`) reorders by
one slot, a marginal pick flips, and the paths never reconverge. (Symbol identity not
established — the audit records counts, not names; it does not change the conclusion.)

**Read:** the 26y salt-0 pair cannot attribute a guard effect — it is the 26y path
lottery (`project_clock52_promoted`: "26y = salt-LOTTERY"; `project_edge_is_the_fat_tail`).
The STMP correction itself is visible and exactly as expected in the shared trade. The
level, Sharpe and maxDD of the on arm are one draw of a different path, and the off-only
minus on-only gap (+$1.2M) is the monster reshuffle the record's fat tail always produces
under any early perturbation.

**Decision (recommended, user to confirm):** do NOT re-base the record on `dg-26y-on`.
Two honest options: (a) run salts 1–2 of both arms (4 × ~2.8 h) and read the guard effect
as a distribution; (b) arm only guards 1+2 in the record convention (they do not touch the
universe — guard 2 realises DTV-type zombies, guard 1 refuses stale entries) and treat the
STMP stub as a known −$594k phantom inside the record until guard 3 is evaluated with
salts. The 5y-2019 cell stays a clean STMP correction.

Also note: guard 3's universe effect is *earlier removal* of a dying symbol — every
per-symbol data-hygiene change (twin dedup, splice drops, this) perturbs the 26y path the
same way; a re-base after any of them needs salts, never a single pair.
