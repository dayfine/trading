# Next-session priorities — 2026-10-03 (supersedes 2026-09-27)

Written 21:30 PT 2026-10-02 by the Fable session, for a less context-rich model to execute. Every step
below says what to run, what the output should look like, and what decision to make from it. Do the
tasks in order. Do not skip a verification step because the result "looks obvious".

> **Status 03:15 PT 2026-10-03.** P0 is DONE: results PR #3091 merged (dilutes 6/6, no phase 2; qc-results
> APPROVED on iteration 2). `perf_long_cells.sh update` ran (24 rows, check ok) and the `sweep-anchor`
> worktree is removed. P1 (#3086, the gate-reopen pack signal) **merged 03:22 PT** after two behavioral rework
> iterations (both test-only: boundary pins and a node-pinned `reopenEpisodes`); the harness workspace is
> forgotten and removed. Screens 4(a)/(b) are done and merged with #3091. #3092 (perf ledger) merged. **What is left
> for the next session is P2 (section 4, the user's decision) and the session-end chores (section 5).**
> Sections 1–2 below are the record of how P0 was done; do not redo them.

## 0. Ground rules (read every one before starting)

1. **Never commit, print, upload or quote the book file**
   `/Users/difan/Downloads/486827303-Stan-Weinstein-s-Secrets-For-Profiting-in-Bull-and-Bear-Mark-pdf.txt`.
   It may be read locally to settle a faithfulness question; cite chapter + a few words only.
2. **No Python.** Shell (POSIX `sh`), `awk`, `jq`, OCaml only. macOS `awk` has no `mktime`; use the
   Julian-day function in `episodes.awk` (section 2.6) for date arithmetic.
3. **VCS = jj, never bare `git` for commit/branch/push.** Read-only `git` (`git show`, `git worktree list`,
   `git rev-parse`) is fine.
4. **A backtest chain is running until ~01:30 PT 2026-10-03** (section 1). Until the log says
   `LANE A DONE`: no agent that builds (`feat-*`, `qc-structural`, `qc-behavioral`, `harness-maintainer`),
   no `dune` in the container. Read-only agents (`qc-results`, `Explore`) are fine. At most 3 agents ever.
5. **QC outranks backtests.** `sh dev/scripts/pr_gate_status.sh` first at every pause. If a PR needs a
   QC dispatch and the container is free, do that before launching anything long.
6. **Never post a gate-format QC verdict (`## Results QC`, `## Structural QC`, `## Behavioral QC`) on a PR
   yourself.** Dispatch the `qc-results` agent (results-only PRs) and let it post. Merge on its APPROVED
   at the current tip.
7. **`gh pr update-branch` is denied.** If `gh pr edit` fails, use
   `gh api -X PATCH repos/dayfine/trading/pulls/N -F body=@file`.
8. **sp500 is never evidence.** Every number in a conclusion comes from the PIT top-3000 cells.
9. **The idle-cash SPY sleeve / barbell is user-declined.** Do not propose, test or mention it as an option.
10. Times are PT. Say how long a wait will be before waiting. Compact at ~250k context.
11. Shell gotcha: in zsh `echo ====` fails (`=word` expansion). Use `echo ----`.

## 1. State at hand-off

| item | value |
|---|---|
| open PRs | none (checked 20:58 PT) |
| main | green, `a46e7bbc3338` (#3083) |
| disk | 47 GB free (threshold: stop launching below 50 GB; abort a chain below 20 GB) |
| running chain | entry-anchor-recovery lane A, pid in `/tmp/anchor-run/launch-A.log`, log `/tmp/anchor-run/chain-A.log` |
| chain progress | 16 of 24 cells done at 20:58 PT; `ia26-5r-s0` running; then `ia0/ia4/ia13/ia26-5r-s1`, then `-s2`; ~30 min per cell → done ~01:30 PT |
| chain outputs (host view) | `.sweep-output/entry-anchor-recovery/<arm>-<window>-s<salt>-v11-{actual.sexp,trades.csv,trade_audit.sexp,macro_trend.sexp,equity_curve.csv,open_positions.csv,params.sexp,summary.sexp,validator.sexp.sexp,validator.sexp.md}` |
| pinned worktree | `.claude/worktrees/sweep-anchor` (remove after the results PR merges) |
| experiment branch | bookmark `exp/entry-anchor-recovery` at `b0025fff1be5` (pre-registration only; pushed; **no PR yet**) |
| experiment dir | `dev/experiments/entry-anchor-recovery-2026-10-02/` (README with rules 1–8, `specs/`, `results/{chain-anchor.sh,launch.sh}`) |
| summary page for the user | https://claude.ai/artifact/7i7h5AxfGUkypw9KAk25LE (scratchpad `recovery-reentry.html`) |
| background poll | task `b7fd2wd2n` waits for `LANE A DONE` in the chain log |
| **done 22:10 PT 10-02** | PR #3085 (this file, docs-only, CI only → merge). PR #3086 (`harness/review-pack-reopen-episodes`: the P1 detector, section 3) — **needs qc-structural + qc-behavioral after the chain**, then merge. Screens 4(a) and 4(b) are written: `dev/experiments/entry-anchor-recovery-2026-10-02/anchor-position-screen.md` (in the results commit, not yet pushed). Memory `project_recovery_reentry_gap.md` written; update its 5r line when the chain ends. jj: main workspace `@` = results commit `nymoprqq` (child of the pre-reg commit; holds the screen note + 5 read scripts); docs commit `ykmxorpp` = bookmark `docs/next-session-2026-10-03`; harness work lives in jj workspace `.claude/worktrees/jjws-harness-reopen` (forget + rm after #3086 merges: `jj workspace forget harness-reopen`). |

### Results already in (5d = 2007-06-01→2012-06-29, all three salts done)

Calmar / max DD. Null = `ia0` = the 09-29 investor preset byte-copied.

| arm | s0 | s1 | s2 |
|---|---|---|---|
| ia0 (null) | 0.235 / 14.4 | 0.232 / 14.4 | 0.233 / 14.3 |
| ia4 | −0.113 / 25.2 | −0.120 / 25.6 | −0.117 / 25.7 |
| ia13 | −0.126 / 24.7 | −0.133 / 25.0 | −0.132 / 25.1 |
| ia26 | −0.022 / 19.9 | −0.058 / 20.2 | −0.055 / 20.4 |

V6 pair gate (`v6diff:ia0-5d:exit=0`) passed on every 5d cell. Every arm **dilutes 3/3 at 5d** (README
rule 4). Rule 6 therefore gives **no phase 2** whatever 5r says.

5r so far (s0 only): ia0 +30.6 % / DD 22.4 / Calmar 0.241; ia4 −6.0 % / 41.6 / −0.029; ia13 +4.6 % /
32.8 / 0.027. ia26-5r-s0 and salts 1–2 pending.

### The "why" that must go into the writeup (already established, read-only, from committed artifacts)

These are the findings the writeup is built around. Each one names the artifact it came from so a
reader can recheck it.

1. **The lever is global; the problem is post-crash.** A 4/13/26-week high triggers on minor rallies
   in every market. 5d ia4 s0 made 24 entries before 2009 for about −$140k vs the null's 15 for −$32k;
   −$84k of it in June–July 2007 with the macro gate Bullish. 5r s0 ia4 has 194 trades vs the null's
   126 and DD 41.6 vs 22.4.
2. **On the investor preset the 2009 gap shows as `No_structural_stop` skips, not as unfilled tickets.**
   T1 (hybrid) placed 116 tickets in May–Aug 2009 and filled none (ticket median 60 % above the close).
   The investor null placed **2** tickets in the same months
   (`grep -oE '\(entry_date 2009-0[5-8]-[0-9]+\)' .sweep-output/entry-anchor-recovery/ia0-5d-s0-v11-trade_audit.sexp | wc -l`).
   The cascade admitted the top 20 every week (`cascade_summaries` → `long_top_n_admitted 20`), then
   `require_structural_stop` skipped them: with the ticket at the pre-crash high, the support-floor scan
   below it finds no correction low within 15 %, the stop falls back to the 4 % buffer, and the investor
   rule skips a fallback stop (`weinstein_strategy_config.mli`, `require_structural_stop`). Same root
   cause (the anchor), different proximate reason than T1. ia4 moved the ticket down, the floor came
   within range, 25 tickets were placed May–Aug 2009.
3. **Even when filled, the 2009 recovery entries whipsawed.** ia4 s0, 25 entries May–Sep 2009
   (`awk -F, 'NR>1 && $3 ~ /^2009-0[5-9]/' .sweep-output/entry-anchor-recovery/ia4-5d-s0-v11-trades.csv`):
   11 exited on `stop_loss`, 10 of them losers at −13.8 to −16.4 % (NSIT +12.7 % was a trailed winner);
   6 of the 10 in the June–July 2009 pullback (CASC1 −16.4 % in 10 days, PXP −14.9 % in 11, CHU, GIL,
   CHCO, ARCB), THRM and ALV in mid-May, NYT and OLN in October; the winners (EBAY +31.7 %, AWI +31.0 %,
   LPS +18.3 %) left by laggard rotation. Net −$12k. **Any anchor fix has this cap.** (Restated after
   qc-results on #3091 caught the first wording; always re-derive such a sentence from the artifact.)
4. **The recovery gap is not one pattern across 26 years.** On the 26y investor s0
   (`.sweep-output/investor-preset/inv26sc-investor-s0-v11-*`), for every macro-gate reopen after ≥ 8
   non-Bullish weeks (19 episodes), entries in the first 13 / 26 weeks and the 26-week return vs SPY:

   | reopen | entries 13w / 26w | strategy 26w | SPY 26w | read |
   |---|---|---|---|---|
   | 2003-05-02 | 7 / 15 | +21.6 % | +13.8 % | caught |
   | 2009-05-08 | 0 / 10 | −1.5 % | +16.4 % | missed |
   | 2010-10-08 | 4 / 19 | +7.4 % | +15.1 % | lagged |
   | 2012-08-10 | 8 / 14 | +20.5 % | +9.1 % | caught |
   | 2019-02-15 | 2 / 9 | −0.5 % | +5.1 % | missed |
   | 2020-06-05 | 6 / 15 | +25.2 % | +16.8 % | caught |
   | 2022-11-25 | 0 / 3 | −1.3 % | +5.3 % | missed |
   | 2025-05-23 | 12 / 19 | −8.0 % | +14.5 % | invested and lost |

   Full 19-row table: run `episodes.awk` (section 2.6). Caught when the old highs had aged out of the
   60-week window (2003) or were reclaimed fast (2020); missed when stocks sat well below their 60-week
   highs at reopen (2009, 2019, 2022). **2025 is a different failure**: 21 entries after the reopen,
   −$267k, 10 stop-outs (AD −29.4 % on a 5.2 % initial stop, TNXP −25.1 % on 5.6 %).
5. **Narrow structural stops are not a lever.** 26y investor s0, initial stop < 6 %: 67 trades, 28 %
   win rate, 75 % stop exits, yet **+$598k** net (s1: 69 / 29 % / +$562k). Do not propose a minimum
   stop width.
6. The proxy screen (README §Why): the 91 unfilled T1 names, held 26 weeks, made a median +17.5 % vs
   SPY +19–32 %. Catching the recovery buys exposure, not stock-picking edge.

## 2. P0 — finish the anchor experiment (results-only PR). Start when the chain is done.

### 2.1 Confirm the chain finished cleanly

```sh
grep -cE '^\[.*RESULT ia' /tmp/anchor-run/chain-A.log      # expect 24
grep -E 'ABORT|FAIL|LANE A DONE|no result' /tmp/anchor-run/chain-A.log
ls .sweep-output/entry-anchor-recovery/*-actual.sexp | wc -l   # expect 24
```

If a cell is missing or reads `FAIL`: do **not** relaunch blindly. Read the cell's log in
`.sweep-output/entry-anchor-recovery/` and `/tmp/anchor-run/launch-A.log`. A 1-second failure is a
missing input, not an OOM. Record the missing cell in the writeup as "no reading" for that salt and
continue; relaunch only that cell (`sh /tmp/anchor-run/chain-anchor.sh B <token>` with the token format
`arm-window:salt[:pair]`, e.g. `ia26-5r:2:ia0-5r`, `WTREL=.claude/worktrees/sweep-anchor`,
`EXPECT_HEAD=$(git -C .claude/worktrees/sweep-anchor rev-parse --short HEAD)`, `CELL_TIMEOUT=7200`).

### 2.2 Extract the metrics table (all 24 cells)

```sh
grep -E 'RESULT ia' /tmp/anchor-run/chain-A.log | grep -oE 'RESULT [^ ]+|total_return_pct [-0-9.]{6}|total_trades [0-9]+|max_drawdown_pct [0-9.]{5}|calmar_ratio [-0-9.]{6}|v6diff:[^ ]+' | paste - - - - - -
```

Every `v6diff:ia0-<w>:exit=` must be `0`. If any is not 0, that pair at that salt is "no reading"
(README rule 1); say so in the writeup. The metric-glob tripwire from `sweep-hygiene.md`: run
`awk '{n=gsub(/total_return_pct/,"&"); if(n>1) print FILENAME": "n" per line"}' .sweep-output/entry-anchor-recovery/*-actual.sexp`
— must print nothing.

### 2.3 Rule 2 — same-build anchor check for the 5r nulls

The 09-29 investor cells live under `dev/experiments/trader-presets-2026-09-29/results/` (file names
`tp-i-5r-s<N>-v11-trades.csv`, `tp-i-5r-s<N>-v11-actual.sexp`; if that directory does not have them,
`ls dev/experiments/*/results/tp-i-5r-s0-v11-trades.csv` finds them). For each salt:

```sh
for s in 0 1 2; do
  cmp dev/experiments/trader-presets-2026-09-29/results/tp-i-5r-s$s-v11-trades.csv .sweep-output/entry-anchor-recovery/ia0-5r-s$s-v11-trades.csv && echo "5r s$s trades identical"
  grep -oE '(total_return_pct|max_drawdown_pct|calmar_ratio) [-0-9.]+' dev/experiments/trader-presets-2026-09-29/results/tp-i-5r-s$s-v11-actual.sexp | paste - - -
  grep -oE '(total_return_pct|max_drawdown_pct|calmar_ratio) [-0-9.]+' .sweep-output/entry-anchor-recovery/ia0-5r-s$s-v11-actual.sexp | paste - - -
done
```

The 5d nulls were already found byte-identical. A 5r mismatch is **reported, not fatal**: the in-chain
pairs stay valid because both arms share one build (README rule 2 says exactly this).

### 2.4 Rule 4 — outcome per arm per window

For each arm (ia4, ia13, ia26) and window (5d, 5r): compare to ia0 at the same salt.

- "adds": Calmar ≥ null at ≥ 2 of the 3 valid salts **and** max DD never more than 5 pp worse than the
  null at any valid salt.
- "dilutes": Calmar < null at every valid salt (or DD > 5 pp worse at any salt and Calmar not ≥ at 2+).
- "mixed": anything else.
- "no reading": fewer than 2 valid salts.

Write the 6 outcomes in a table. Expected: dilutes everywhere (5d is already 3/3 dilutes for every arm).
Rule 5 (per-trade join) applies only to an "adds"; expected not needed. Rule 6: no arm qualifies →
**no phase 2**; the README §Verdict must say so and say why (finding 1 above).

### 2.5 Build, render and LOOK at the review packs (container must be free — after `LANE A DONE`)

Build four packs: the null and the most-changed arm in each window.

```sh
P=.sweep-output/entry-anchor-recovery
sh dev/scripts/review_pack.sh --out .sweep-output/review-anchor-ia0-5d --title "Investor null (ia0), 2007-12" s0=$P/ia0-5d-s0-v11- s1=$P/ia0-5d-s1-v11- s2=$P/ia0-5d-s2-v11-
sh dev/scripts/review_pack.sh --out .sweep-output/review-anchor-ia4-5d --title "Anchor 4w (ia4), 2007-12" s0=$P/ia4-5d-s0-v11- s1=$P/ia4-5d-s1-v11- s2=$P/ia4-5d-s2-v11-
sh dev/scripts/review_pack.sh --out .sweep-output/review-anchor-ia0-5r --title "Investor null (ia0), 2021-26" s0=$P/ia0-5r-s0-v11- s1=$P/ia0-5r-s1-v11- s2=$P/ia0-5r-s2-v11-
sh dev/scripts/review_pack.sh --out .sweep-output/review-anchor-ia4-5r --title "Anchor 4w (ia4), 2021-26" s0=$P/ia4-5r-s0-v11- s1=$P/ia4-5r-s1-v11- s2=$P/ia4-5r-s2-v11-
for d in ia0-5d ia4-5d ia0-5r ia4-5r; do sh dev/scripts/review_pack_render.sh --site .sweep-output/review-anchor-$d/site; done
```

**The prefix is everything before `actual.sexp`, including the trailing `-`** (`…-s0-v11-`). Without the
dash the script exits 2 with `no trades.csv under prefix` (hit once on 10-02). If the chain is still
holding the container, add `--no-container` (no audit report / stage replays; rebuild with the container
later for the full cards). The pack built this way from a real run takes about a minute. Each build takes several minutes (audit report + stage
replays in the container). Then **`Read` `top.png` and `part-1.png` … `part-6.png`** of every pack and
check, per `.claude/rules/backtest-result-review.md` §The procedure step 3:

- charts span the whole window; KPI strip equals `actual.sexp` (return, DD, trades);
- no mojibake / `NaN` / `undefined` / empty panels;
- "stop breached before the exit day" ≈ 0 (trigger-bar fills are on); "bought in a Bearish macro week"
  = 0 on ia0. On ia4 it will be > 0 — that is finding 1, not a pack bug;
- the signal block bullets (eras vs SPY, regime × era, one-trade years, open-position return). Copy
  each bullet into the writeup and say confirm / refine / reject.

Any pack defect → fix in `dev/lib/review_pack/` and pin in `trading/devtools/checks/review_pack_test.sh`
(separate harness PR, full gates). Any simulator defect → GitHub issue with the specimen.

Publish each pack: `Artifact` tool, `file_path` = `<pack>/site/index.html`, `files` = every file under
`<pack>/site/data/` keyed by its relative path (`data/<name>`), `icon` = `chart`. Put the four links in
the writeup.

### 2.6 Rule 3 (liveness) and the episode tables — commit the scripts

Copy the two read scripts from the scratchpad into the experiment and commit them:

```sh
S=/private/tmp/claude-501/-Users-difan-Projects-trading-1/13438ee6-bde6-4f74-839d-eef43a46dd35/scratchpad
cp $S/episodes.awk $S/skips.awk dev/experiments/entry-anchor-recovery-2026-10-02/results/
```

If the scratchpad is gone, rewrite them from these specs:

- `episodes.awk` — args: `reopen.txt trades.csv equity_curve.csv spy.csv`. `reopen.txt` = one date per
  line, produced by
  `grep -oE '\(date [0-9-]+\) \(trend [A-Za-z]+' <prefix>-macro_trend.sexp | awk '{d=$2; t=$4; gsub(/[()]/,"",d); gsub(/[()]/,"",t); if (t=="Bullish") { if (nb>=8) print d; nb=0 } else nb++ }'`.
  For each reopen date: count `trades.csv` rows (column 3 = entry_date) within 0–90 and 0–181 days,
  sum column 9 (pnl_dollars) over 0–181 days, and print NAV return (equity_curve column 2) and SPY
  return (`data/S/Y/SPY/data.csv` column 6, adjusted_close) from the reopen date to +182 days using the
  last row on or before each date. Dates → Julian day with the standard integer formula (no `mktime`).
- `skips.awk` — streams a `trade_audit.sexp`; on every `(entry_date YYYY-MM-DD)` remember `YYYY-MM`;
  count `reason_skipped No_structural_stop` and `reason_skipped Insufficient_cash` under that month;
  print months matching `-v pat=<regex>`. Note: skips are recorded only as `alternatives_considered`
  of an entered record, so a month with no entry shows no skips (undercount; say so).

Rule 3 numbers, per salt and arm, 5d:

```sh
for a in ia0 ia4 ia13 ia26; do for s in 0 1 2; do
  printf "%s s%s entries 2009-05-01..08-31: " $a $s
  awk -F, 'NR>1 && $3>="2009-05-01" && $3<="2009-08-31"' .sweep-output/entry-anchor-recovery/$a-5d-s$s-v11-trades.csv | wc -l
done; done
```

Average invested % of NAV 2009-05-08→2009-12-31 comes from the pack's `site/data/s<N>_nav.json`
(rows `[date, nav, invested_pct, positions]`):
`jq '[.[] | select(.[0] >= "2009-05-08" and .[0] <= "2009-12-31") | .[2]] | add / length' .sweep-output/review-anchor-ia4-5d/site/data/s0_nav.json`.
Known so far: null 0 entries at every salt; arms 15–21 entries, netting about −$4k.

Also report per arm: trade count, stop-exit share (`$13=="stop_loss"`), median `days_held` (column 5) —
the README's "Expected costs" paragraph asked for these.

### 2.7 Write the results file

Create `dev/experiments/entry-anchor-recovery-2026-10-02/results-2026-10-03.md`. Use
`dev/experiments/trader-presets-rerun-2026-10-02/results-2026-10-02.md` as the shape to copy. Sections, in
order:

1. **Verdict** (first lines): "Every arm dilutes at 5d 3/3 (and at 5r: <fill in>). No phase 2 (rule 6).
   No ledger entry (rule 8: a ledger entry only follows phase 2). No default changes."
2. **Rule-by-rule** — rules 1–8, each with the numbers and the artifact path they come from.
3. **Why** — findings 1–6 from section 1 of this file, with the tables. This is the valuable part.
4. **Review-pack look** — the four pack links and, per pack, what was checked and found (RV1/RV3).
   Every signal bullet the packs printed: confirm / refine / reject, one line each.
5. **Exposure** — only with the regime split per period (RV2); take it from the packs' regime × era
   tables, do not quote an average exposure alone.
6. **Forward guidance** — what this rules in and out (section 4 of this file, items a–d).
7. **Artifacts** — list what is committed under `results/`.

Also append a short **§Log** and **§Verdict** to the experiment `README.md` (date, verdict line, link to
the results file). Do not edit the pre-registered rules.

### 2.8 Copy artifacts into `results/`

```sh
R=dev/experiments/entry-anchor-recovery-2026-10-02/results
for f in .sweep-output/entry-anchor-recovery/ia*-v11-{actual.sexp,trades.csv,open_positions.csv,params.sexp,summary.sexp,equity_curve.csv,validator.sexp.sexp,validator.sexp.md}; do cp "$f" $R/; done
cp .sweep-output/entry-anchor-recovery/*.rss $R/ 2>/dev/null
cp /tmp/anchor-run/chain-A.log $R/chain-A.log
ls $R | wc -l    # 24 cells × 8 files + rss + chain log + 2 scripts + chain-anchor.sh + launch.sh
```

Do **not** copy `trade_audit.sexp` (tens of MB each) or `macro_trend.sexp`; they stay in
`.sweep-output/`. Say so in the writeup's artifacts section.

### 2.9 Commit, push, open the PR

```sh
cd /Users/difan/Projects/trading-1
jj new exp/entry-anchor-recovery -m "experiments(entry-anchor-recovery): results — every local-range anchor arm dilutes at 5d and 5r; no phase 2"
# ... the edits above happen in this working copy; jj snapshots automatically ...
jj diff --stat | tail -3          # only files under dev/experiments/entry-anchor-recovery-2026-10-02/
jj bookmark set exp/entry-anchor-recovery -r @
jj git push -b exp/entry-anchor-recovery
gh pr create --base main --head exp/entry-anchor-recovery --title "experiments(entry-anchor-recovery): results — local-range anchor dilutes in both windows; no phase 2" --body-file /tmp/pr-body.md
```

The PR body (`/tmp/pr-body.md`): verdict line; the 6-outcome table; the four pack links; a
"Review-pack look" paragraph; "Test plan" listing the exact commands run (2.2, 2.3, 2.6) — the test
plan is written from the diff, not from intent; end with
`🤖 Generated with [Claude Code](https://claude.com/claude-code)`. The commit message ends with
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

`sh dev/scripts/pr_gate_status.sh <N>` must read `STRUCT=skip` and `NEXT-ACTION: dispatch qc-results`.
If it reads otherwise, a non-results file slipped in — fix the diff first.

### 2.10 QC and merge

Dispatch one `qc-results` agent (`Agent` tool, `subagent_type: "qc-results"`, `isolation: "worktree"`),
prompt: the PR number, "results-only PR; review per `.claude/agents/qc-results.md`; check out with plain
git (`git fetch origin pull/N/head && git checkout --detach FETCH_HEAD`), never jj; post the verdict as a
PR review under `## Results QC`". It needs no container, so it may run beside anything. When the
notification arrives: `sh dev/scripts/pr_gate_status.sh <N>`.

- `NEEDS_REWORK`: read the full review (`gh pr view N --json reviews --jq '.reviews[-1].body'`), fix every
  checked-fail item as a **second commit** (`jj new -m "fix(review): address qc-results iteration 1 (#N)"`,
  then `jj bookmark set` + `jj git push`), update the PR body too, re-dispatch. Cap: 2 iterations.
- `APPROVED` at the current tip and `gh pr checks N` all `pass`: `gh pr merge N --squash --delete-branch`.

After the merge:

```sh
rm -rf .claude/worktrees/<qc-agent-worktree>          # the agent's worktree, immediately
sh dev/scripts/perf_long_cells.sh update dev/experiments/entry-anchor-recovery-2026-10-02/results/chain-A.log   # needs the dir on main → after merge
git worktree remove --force .claude/worktrees/sweep-anchor
```

### 2.11 Memory

`~/.claude/projects/-Users-difan-Projects-trading-1/memory/project_recovery_reentry_gap.md` **already
exists** (written 22:10 PT 10-02) with findings 1–7 and the 5d verdict; its `MEMORY.md` index line is in
place. After the chain: replace its "5r pending" phrasing with the 5r outcomes per arm and the final
6-outcome line, and append one dated line to `project_investor_preset_broad.md` pointing at it. Keep
`MEMORY.md` under 24 KB.

## 3. P1 — turn the eye-catch into a detector (harness PR, full three gates, container free)

**DONE as PR #3086 (22:00 PT 10-02), awaiting QC.** Built and rendered against the 26y investor s0: the
bullet and 19-row table match the awk read exactly. Remaining: after `LANE A DONE`, dispatch
qc-structural, then qc-behavioral (each `isolation: "worktree"`, plain `git` checkout, dune in the
container against the agent's own worktree), merge on both APPROVED + CI green, then
`jj workspace forget harness-reopen && rm -rf .claude/worktrees/jjws-harness-reopen`. The spec below is
what was built; keep it for the rework brief if QC asks for changes.

User rule (`backtest-result-review.md` §What the eye catches becomes a detector): the "amazingly flat
2008–09" observation must surface in the pack without anyone looking for it. Add a **"Gate reopen
episodes"** signal.

Where: `dev/lib/review_pack/index.html`, function `renderSignals(nav, spy)` (around line 447). Data
already loaded on the page: `D.macro` = `[[date, trend, breadth], ...]` weekly; `nav` =
`[[date, nav, invested_pct, positions], ...]` daily; `spy` (same dates as `nav`, from `spyOnNavDates`);
`D.trades[CH()]` = trade objects with `ed` (entry date), `pnl`, `trig`.

Logic (mirror `episodes.awk`):

1. Episodes: walk `D.macro`; count consecutive weeks with trend ≠ `Bullish`; when a `Bullish` week ends a
   run of ≥ 8, that week's date is a reopen.
2. Per episode: `e13` = trades with `ed` in [reopen, reopen+91d); `e26` likewise 182d; strategy return
   = nav at reopen+182d / nav at reopen − 1 (last row on or before); SPY return likewise from `spy`.
3. Flag the episode when **SPY 26-week return ≥ +8 %** and either (a) `e13 ≤ 2` and strategy trails SPY
   by ≥ 8 pp ("sat out the recovery"), or (b) `e13 ≥ 6` and strategy trails by ≥ 8 pp ("invested and
   lagged"). Thresholds are constants at the top of the function with a one-line comment each.
4. Output: one bullet `<b>Gate reopen episodes:</b> N reopens after ≥ 8 closed weeks; sat out: 2009-05
   (0 entries in 13 w, −1.5 % vs SPY +16.4 %), …; invested and lagged: 2025-05 (12 entries, −8.0 % vs
   +14.5 %).` plus a small table (reopen, closed weeks, e13/e26, strategy, SPY) in the same card style as
   the era table.

Pin it: `trading/devtools/checks/review_pack_test.sh` — follow the existing pin style in that file (the
test builds a pack from fixtures and greps the rendered strings; read the file before adding). Pin the
26y investor fixture if present, else add the smallest fixture that produces one "sat out" row.
Add a row to the signal table in `.claude/rules/backtest-result-review.md`. Also append the finding to
`memory/feedback_render_and_look_at_review_pack.md`.

Branch `harness/review-pack-reopen-episodes` off `main@origin`; CI + qc-structural + qc-behavioral.
`dune runtest` for the check runs in the container → only when no chain is running.

## 4. P2 — the next strategy step. Three read-only items first, one free arm, then a user decision.

Do these in this order. None needs code or the container except (c).

**(a) and (b) are DONE (22:00 PT 10-02):** `dev/experiments/entry-anchor-recovery-2026-10-02/anchor-position-screen.md`
(in the results commit). Outcomes: (a) far graded tops occur in **every** year (skipped candidates ≥ 20 %
under their graded top: 9 % in 2017, 44 % in 2009, 47 % in 2000; half of all structural-stop skips are
within 10 % of it) → a base-bounded anchor is a global lever → **do not build it**. (b) 2025 is a
selection shortfall, identical in all three salts (picks' 26-week forward median +4.7 % vs SPY +14.5 %),
not cash and not path → no lever from it. What follows is the original spec, kept for the record; the
live items are (c) and (d).

### (a) Screen: how often does the graded top sit above the current base? (decides whether a
"base-bounded anchor" is targeted or global)

Hypothesis: the 8–60-week max high (`breakout_price`) sits in a *prior Stage 4 decline* only after
sizeable declines (2009, 2019, 2022); in normal markets it is the base top anyway. If true, anchoring at
"the range since the stock's last Stage 4 week" changes few entries outside recoveries — a targeted,
book-faithful fix (top of the current base, `weinstein-book-reference.md` end of §4.1). If false, it is
another global lever like ia-N and should not be built.

Method (26y investor s0 audit, `.sweep-output/investor-preset/inv26sc-investor-s0-v11-trade_audit.sexp`,
599 entry records): for each `((symbol S) (entry_date D) …` record take `suggested_entry`; read the raw
`close` on the decision date D from `data/<first letter>/<last letter>/<S>/data.csv` (e.g.
`data/E/Y/EBAY/data.csv`; columns `date,open,high,low,close,adjusted_close,volume,active_through`; use
`close`, the raw basis — audit prices are pre-split). Ratio `r = suggested_entry / close`. Report, by
year and for the first 13 weeks after each reopen: n, median r, share with r ≥ 1.20. Expectation if the
hypothesis holds: share ≥ 1.20 is high in 2009-05…08, 2019-02…05, 2022-11…2023-02 and low (< 10 %)
elsewhere. Write the result as a short note in the experiment dir
(`dev/experiments/entry-anchor-recovery-2026-10-02/anchor-position-screen.md`) with the awk committed.

Plumbing fact for the design: `Weinstein_trading_state.prior_stages` keeps **one** prior stage per
ticker, not a history, so "weeks since last Stage 4" needs a new per-ticker field (`last_stage4_date`
or `base_start_week`) threaded from the stage classifier. That is a `feat-weinstein` build, default-off
flag, `.claude/rules/experiment-flag-discipline.md` R1–R3.

### (b) Dissect the 2025 reopen (the live-relevant failure; larger than 2009 in the current window)

From `inv26sc-investor-s0-v11-trades.csv`, the 21 entries with `entry_date` in 2025-05-23…2025-12-31
(−$267k; 10 stop exits −$523k). Answer, with a table: sector / market-cap tier of each pick (sector is
in the audit record `sector_name`); which were biotech/event names (AD, TNXP, BALY, AIP); how many
initial stops were < 6 % and whether those were the gap losers; `n_stop_raises` on the losers (all 0 →
no time to raise); and whether the same names appear in s1/s2 (path vs selection). Compare the picks'
26-week forward return (from `data/…/data.csv`) with SPY's +14.5 %. Conclusion to reach: is 2025 a
selection problem (picks lagged a narrow mega-cap tape), a stop problem (gaps through 5 % stops), or a
regime problem (small caps lagged). Write it into the same note file as (a), section 2.

### (c) Free arm: `entry_ticket_macro_suspend On_bearish_macro` on the investor preset

Knob exists (#2995, default `Off`), never measured. Book-faithful (suspend buying in a bear tape). Expected
effect small (2007 losses came with the gate Bullish). Only when the container is free and (a)/(b) are
written. Make a new experiment dir `dev/experiments/macro-suspend-investor-2026-10-0X/` with: README
(hypothesis, arms `ms0` = ia0 byte-copy, `msB` = + `((entry_ticket_macro_suspend On_bearish_macro))`,
windows 5d + 5r, salts 0–2, rules 1–8 copied from the anchor README with the liveness rule changed to
"fills in Bearish-screen weeks per salt: null > 0, arm = 0"), specs, chain = copy of
`results/chain-anchor.sh` with the paths renamed, launcher like `results/launch.sh`. Pre-register
(commit + push) **before** launching. 12 cells ≈ 6–7 h.

### (d) Shorts — only on the user's explicit go

One liveness pair on 5d (investor + `enable_short_side true` with the faithful gates and the margin model
on), not a programme. Prior record: `project_p0_levers_no_build_2026_06_20` (reserved sleeve lost at
every fraction on broad), `project_p1a_deep_short_screens` (hedge value seen only ungated, on sp500 —
not evidence), `project_short_realism_p0`. Expect sparse shorts. Do not build anything before the pair
shows liveness.

**Decision the user still owes:** (c) macro-suspend arm, (d) shorts liveness pair, or a selection-side
experiment for the 2025 shape (not yet designed; it would start as a read-only screen of what the RS
ranker picks in a narrow rally). Default if unspecified: (c), because it is free and pre-registrable in
an hour. Do not launch (c) while any PR waits for QC.

## 5. Session-end chores (every session)

```sh
sh dev/scripts/export-memory.sh
sh dev/scripts/budget_local_record.sh            # and --date 2026-10-02 if the session crossed UTC midnight
```

Commit this file + the exports as a docs-only PR (CI only, then `gh pr merge --squash --delete-branch`).
Print the time (PT) at the end. Remove every `.claude/worktrees/agent-*` directory whose agent has
finished.

## 6. Open follow-ups (not this session unless idle)

- #3084 open-position signal behavioural pin; #3074 anchor-kind tag in `trades.csv` (blocks any
  continuation-vs-base read); #3075 long-rested ticket stale stop (AAON); #3057.
- Equal-weight benchmark (RSP / IWM) not in the data store.
- "Months under 5 % invested while SPY UP" pack signal (superseded by section 3 if that lands).

## 7. Things that look right but are wrong (do not do these)

- Reading "average exposure 42 %" as a cost. Always the regime split, per period.
- Treating the T1 "91 unfilled tickets" story as the investor preset's mechanism. The investor skips
  before ticketing (`No_structural_stop`).
- Proposing a minimum structural-stop width (finding 5: narrow stops net positive).
- Proposing any N-week-high anchor again (this experiment: dilutes 6/6).
- Launching a chain or an agent while `pr_gate_status.sh` shows a PR waiting for QC.
- Posting a `## Results QC` review yourself.
- A "26y phase 2" for this experiment — rule 6 forbids it; the record must say why.
