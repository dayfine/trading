# Velocity comparison — pre vs post autonomous-merge (2026-05-23)

**Window split:** the autonomous-merge policy (Claude merges PRs once all 3 gates pass: CI + qc-structural + qc-behavioral) first appeared as a per-session override on **2026-04-30** and became the default for `dayfine/trading` on 2026-05-04 (per `memory/feedback_no_pr_merging.md`). This doc compares the two eras.

## Headline comparison

| Period | Days | PRs | PRs/day | Total raw LOC | Raw LOC ex-#873 | Net LOC ex-#873 |
|---|---:|---:|---:|---:|---:|---:|
| **Pre-autonomous** (03-23 → 04-29) | 38 | 548 | 14.4 | 200,326 | 200,326 | 150,300 |
| **Autonomous era** (04-30 → 05-23) | 24 | 534 | **22.2** | 4,538,875 | 2,480,298 | 1,588,056 |
| Combined (pre + post) | 62 | 1,082 | 17.5 | 4,739,201 | 2,680,624 | 1,738,356 |
| Full window (search-capped) | 62 | 1,000* | 16.1 | 4,717,932 | 2,659,355 | 1,721,507 |

\* GitHub search API caps results at 1,000 PRs per query — the "full" window is truncated. **Use the combined pre+post row as the authoritative total.**

## What changed

- **+54% PRs/day.** 14.4 → 22.2 (24-day post window). Slightly more than half as many days produced roughly the same total PR count.
- **Largest LOC contribution sits in post window.** PR #873 (golden CSV fixtures, +2,043,707 LOC) merged 2026-05-05. Even after subtracting it, post-window code raw LOC (2,480,298) is ~12× the pre-window's 200,326 — driven mostly by other large data/CI fixtures (PR with +499,658 LOC in `ci` category, PR with +114k/−348k in `data` category — universe rebuilds).
- **Category mix shifted.** Pre-window had a long tail of one-off categories (`agents`, `agent-setup`, `tests`, etc., 1–3 PRs each) reflecting harness scaffolding. Post-window concentrates on `feat`, `docs`, `cleanup`, `fix`, `ops` — the standard delivery rotation.

## Category-mix delta (top categories)

| Category | Pre PRs | Pre PRs/day | Post PRs | Post PRs/day | Post/Pre rate |
|---|---:|---:|---:|---:|---:|
| feat | 97 | 2.55 | 167 | **6.96** | **2.73×** |
| fix | 33 | 0.87 | 71 | 2.96 | **3.41×** |
| docs | 77 | 2.03 | 95 | 3.96 | 1.95× |
| ops | 58 | 1.53 | 57 | 2.38 | 1.56× |
| cleanup | 8 | 0.21 | 47 | 1.96 | **9.30×** |
| chore | 9 | 0.24 | 11 | 0.46 | 1.93× |
| refactor | 12 | 0.32 | 10 | 0.42 | 1.32× |
| harness | 73 | 1.92 | 17 | 0.71 | **0.37×** |
| ci | 28 | 0.74 | 1 | 0.04 | 0.06× |
| other (freeform) | 70 | 1.84 | 0 | 0.00 | 0× |

**Observations:**

- **`feat` rate up 2.7×** — 2.55/day → 6.96/day. The single biggest absolute gain. Net-new capability shipped faster.
- **`fix` rate up 3.4×** — 0.87/day → 2.96/day. Bug fixes land at roughly 3× the pre-era pace. Plausible mechanism: autonomous loop lets QC findings + flaky-test fixes get patched within a session instead of queueing for human attention.
- **`cleanup` rate up 9.3×** — 0.21/day → 1.96/day. Coincides with the `code-health` agent + cleanup-branch workflow ramping up (`code-health-discipline.md`). Pre-autonomous era had 8 PRs in 38 days; post has 47 in 24 days.
- **`harness` rate down 63%** — 1.92/day → 0.71/day. Pre window was harness-heavy because the agent definitions, QC pipeline, and dispatch rules were being built. Post-window is maintenance only.
- **`ci` rate down 94%** — 0.74/day → 0.04/day. Same maturity-curve as `harness`: CI workflows were tuned pre-autonomous; once stable, fewer new CI PRs.
- **`other` zeroed out** — the 70 freeform-titled PRs were all in pre window (mostly the 51 March PRs before Conventional Commits was adopted; remainder April). Convention now universal.
- **`docs` rate up 1.95×** — 2.03/day → 3.96/day. Every feat PR pulls a status-file update + plan-doc edit. Autonomous mode amplifies the docs/feat coupling.

## Why per-day comparisons are tricky

- The post window includes 1 outlier PR (#873) and 2 large data/CI rebuilds. The pre window has none.
- The pre window includes the "ramp-up" March chunk (51 PRs in March 23-31, all freeform titles before Conventional Commits adopted). Comparing March's pace to mid-May's pace mixes two project-maturity regimes.
- Calendar days include weekends. Workdays-only ratios would be ~1.4× the numbers above.

## Reports

- Full window (capped at 1000): `dev/notes/velocity-2026-03-23-to-2026-05-23-full.md`
- Pre-autonomous: `dev/notes/velocity-2026-03-23-to-2026-04-29-pre-autonomous.md`
- Autonomous era: `dev/notes/velocity-2026-04-30-to-2026-05-23-autonomous.md`

OCaml comment-LOC snapshot (codebase as of report time, not per-window): see the "OCaml comment LOC" section of `dev/notes/velocity-since-2026-05-07.md`.

## Methodology + caveats

- Generated via `dev/scripts/velocity_report.sh --since X --until Y --out FILE`.
- Each window's PR list comes from `gh pr list --state merged --search "merged:>=X merged:<=Y"`. GitHub caps search results at 1000 per query — for the full 62-day window this drops 82 PRs. The pre and post windows each fit under the cap, so they are exact.
- LOC numbers in the headline come from PR-level `additions`/`deletions` totals (which include all file types); the by-language tables come from per-file `{path, additions, deletions}` and may differ slightly when some PRs have empty `files` arrays.
- Time windows are UTC midnight to UTC midnight (inclusive both ends). The script handles DST safely.
