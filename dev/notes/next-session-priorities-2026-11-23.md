# Next-session priorities — 2026-11-23 (covers 11-22 14:50 PT → 11-23 01:45 PT; supersedes 2026-11-18)

The quota reset arrived and the session spent it on the cheap-stock line. #3681 (the current-NAV participation gate),
the live-size picks profile (#3693) and a scenario `initial_cash` field are merged. The pre-registered NAV-scale
experiment is running in five cloud sessions. The 11-20 weekly picks ran a day late. Main CI is green.

## 1. Merged (11-22/23)

| PR | what |
|---|---|
| #3655, #3657 | budget record, prune-candidates report (docs-only) |
| #3652 | weekly opam update |
| #3656 | weekly-start BAH SPY sweep. It is clamped to 2026-09-28 because the public SPY fixture is 49 days stale; the refresh belongs to #3676, see the comment there |
| #3692 | the sweep PR body now carries the clamp WARNING |
| #3694 | 2026-11-20 picks public summary. Bearish for a 3rd Friday, 0 longs, the 10 breakdowns are all tech. Private record: trading-results 4fdea71 |
| #3695 | `max_entry_adv_participation`, default off. Blocks rather than resizes; sized from current NAV; the picks gate sizes from `--portfolio` (#3681 → verify/pending) |
| #3698 | `WEEKLY_PROFILE=live-size` (#3693 → verify/pending; remaining: a position-scaled hold floor). The picks never ran the $1M entry floor: the weekly.sh universe floor was the real cheap-name blocker. On 10-23, live-size added only GRDX |
| #3697 | scenario `initial_cash`, default 1M, threaded through every scenario consumer (Closes #3696) |
| #3699 | NAV-scale pre-registration, specs and chain.sh, with a 5-verdict rule |

## 2. In flight

- **NAV-scale K=5** (`dev/experiments/nav-scale-participation-2026-11-23/`, build 44f1ba28e).
  - Five cloud routines, nav-scale-k0..k4: trig_01SoBuVpyWCkFCAwbXzMVeke, trig_01FBQpKpkipePZo4pP94ZaUE, trig_01Hno8Zn7zRzCN9jFsMBPyYk, trig_01JYjdRpvXpzuhHtAZqugxqc, trig_01PrBxDdya1RAFKHMZKTEnK1.
  - Started 09:36–09:40Z 11-23, ~10–12 h each. Each session runs the tripwire first.
  - Outputs: the public half goes to branch `experiment/nav-scale-kK`, the private half to trading-results.
  - Check `RemoteTrigger list_runs` for each.
- **When all five finish:**
  - Assemble one results PR from the five branches.
  - `results-analyst` drafts the read. It computes measures 4 and 5 from trades.csv + bars and joins P/F trades by symbol and entry date. P-1M DEAD/INVALID does not close #3681.
  - Then `qc-results`, then close the verify items on #3681 and #3693.

## 3. Queue

1. **Weekly picks cadence.** The Saturday slot has no trigger, so 11-21 was missed and run on Sunday. Options: a local
   cron/launchd job running `weekly.sh` on Saturday, or a reminder routine. Also run the live-size profile weekly next to the
   record once `portfolio.sexp` holds a real account size (it is the $100k placeholder now).
2. **#3693 remaining:** `max_hold_adv_participation`, the position-scaled hold floor. It only matters for the backtest
   (the picks never run the liquidity exit). Decide after the NAV-scale read.
3. **#3676:** move the bar fixtures to trading-results. This needs a deploy key and a repo secret from the user. It also unblocks the SPY refresh for the
   weekly-start sweep.
4. `weekly_snapshot_generator.ml` does not pass `virgin_supply_basis` through (from 11-18).
5. Older carried items: see the 11-18 handoff §3.4.

## 4. Market read (11-20 picks, the strategy's own answer)

Macro Bearish on 11-06, 11-13 and 11-20, 0 longs. Strong sectors are defensive plus Discretionary; IT, Industrials and
Comm Services are weak and breaking down. The system says: no new buys, hold cash, trail stops on anything held. It
flips on the gate returning to Neutral/Bullish with the index above a still-rising 30-week MA. Known costs: slow
re-entry after bottoms (missed 2009, 2019, 2022-11) and lag in melt-ups.

## 5. Lessons

- **Repo-wide `dune build @fmt` wedged for 3 h** in an agent worktree: defunct ocamlformat children, never reaped.
  Brief build agents to run scoped fmt only; kill the parent dune with `kill -9` if it shows Z children.
- **Override order is semantics.** Config overrides fold left to right and the last one wins. A "prepend the experiment's lines"
  instruction would have made every P arm identical to F; the setup agent caught it. Experiment lines go last.
- **QC mutation probes keep finding unpinned threads** (picks gate #3695, rolling-start #3697, a word-split label
  #3698). In each case the feature was wired, but no test failed when the wire was cut.

## Decisions waiting (deferred to 11:00 PT)

All three were decided at 11:00+ PT on 11-23 (addendum below).

## Addendum (11-23, after #3700)

- **Weekly picks: local launchd** (user: "local ok"). `~/.local/bin/trading-weekly-picks.sh`, run by
  `~/Library/LaunchAgents/com.difan.trading-weekly-picks.plist` every Saturday 09:00 local. It runs Friday's picks on
  both profiles, pushes the records to trading-results, opens one docs PR with the public summaries (never merges),
  stops the container, quits Docker Desktop and posts a macOS notification. Log: `~/Library/Logs/trading-weekly-picks.log`.
  First live run Sat 11-28; check the log and the PR that day.
- **Account size k** (user: "use 100k"). `portfolio.sexp` already holds 100000.0, so the live-size profile is real.
- **Docker** stopped at the user's request (container stopped, Docker Desktop quit). `ensure_container.sh` reopens it.
- **#3676 / #3701:** bar fixtures move to trading-results via the existing private repo, fetched in CI with
  `BOT_GITHUB_TOKEN`. The first CI run got a 403; the user widened the token to trading-results on 11-23 and CI is
  re-running. Then: confirm goldens unchanged, drop the probe step from `ci.yml`, QC, merge, and run
  `sh dev/scripts/fetch_test_bars.sh` in each local checkout.
