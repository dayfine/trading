# Session follow-ups — 2026-04-29 (evening)

Captures findings from today's evening dispatch round (PRs #683-#687)
that warrant tracked follow-up work. Pairs with
`dev/notes/short-side-gaps-2026-04-29.md` (which captures G1-G5);
this note documents NEW gaps + extensions surfaced today after that
note was authored.

## 1. Decade backtest non-determinism (NEW gap — call it G6)

Surfaced in `dev/notes/goldens-broad-long-only-baselines-2026-04-29.md`
during the per-cell baseline runs.

**Symptom**: `goldens-broad/decade-2014-2023` is reproducibly
non-deterministic across run modes. Three runs on identical code +
identical config produced two distinct outcome clusters:

- **Single-cell `--dir /tmp/decade-cell` runs** (run-1, run-3): bit-identical
  `145 trades / +1582.85 % return / 40.69 % WR / 103.3 d hold / $15.91 M unreal`.
- **Multi-cell `--dir goldens-broad` batch run** (run-2): drifted to
  `135 trades / +1627.09 % / 40.00 % / 98.0 d / $16.66 M unreal`.

**Likely cause**: parent-process heap state at simulation-fork time
depends on which prior scenarios were loaded. The simulator may
reach into a singleton (e.g. RNG seed, sector-map cache, panel-pool)
that's only initialised once per process, and prior cells leave
fingerprints.

**Why it matters**: pinned `expected` ranges for tier-4 release-gate
must be valid across BOTH run modes. The decade range was widened
to encompass both clusters in PR #687, but that's a band-aid — the
underlying non-determinism violates the "same input → same output"
invariant the design docs require.

**Fix surface**: `trading/trading/backtest/scenarios/scenario_runner.ml`
or the strategy's per-scenario reset. Audit which singletons / refs /
pools persist across `Simulator.create_deps` calls. Likely candidates:
- `Weinstein_strategy.make`'s closure-bound state (stop_states ref,
  weekly MA cache, prior_stages map).
- `Bar_history` / `Bar_panel` pools per #564.
- `Portfolio_risk`'s exposure tracker.
- `Audit_recorder`'s in-process accumulator.

**Owner**: `feat-backtest`. Write a regression test that runs the
same cell single + batch and asserts metric equality.

## 2. Force-liquidation case strengthened (extends G4)

`dev/notes/short-side-gaps-2026-04-29.md` G4 originally framed
force-liquidation as a short-side defense. PR #687's long-only
baselines reveal it's a **long-side problem too**:

| Cell | Long-only Return | Long-only MaxDD |
|---|---:|---:|
| bull-crash 2015-2020 | +148.77 % | 62.91 % |
| covid-recovery 2020-2024 | +15.12 % | 75.30 % |
| six-year 2018-2023 | +35.34 % | 74.86 % |
| **decade 2014-2023** | **+1582.85 %** | **94.31 %** |

The decade cell's 94 % MaxDD with +1582 % return = "compounds
aggressively then dies in 2022 bear, recovers by EOY 2023." No
reasonable risk budget tolerates a 94 % peak-to-trough.

The strategy's primary risk machinery is the per-position trailing
stop. The 94 % MaxDD says individual stops are insufficient — the
portfolio rides through 2022 with cascading position losses, none
of which trigger a portfolio-level halt.

**G4 extension**: the proposed `Force_liquidation` config block
should target BOTH side cases:

- Per-position `max_unrealized_loss_fraction` — fires regardless of
  long/short.
- Portfolio-level `min_portfolio_value_fraction` — fires regardless
  of holdings; halts new entries + force-closes when crossed (e.g.
  threshold 0.5 = halt if value drops below 50 % of recent peak).

A `min_portfolio_value_fraction = 0.5` (relative to peak, not initial)
would have force-closed positions in mid-2022 and halted reentries
until macro flipped Bullish — preserving the peak instead of giving
back to 0.6M.

**Updated owner**: still cross-cutting (`feat-weinstein` decides
policy; cash mechanics live in `Trading_portfolio`); priority
elevated from "nice-to-have for shorts" to "essential for any
long-running scenario."

## 3. covid-recovery 20.81% win rate (new finding)

Per PR #687: `covid-recovery-2020-2024` baseline 20.81 % win rate
versus Weinstein book target 40-50 %. Worst of the four goldens-broad
cells. Suggests one of:

- Entry timing in 2020-2021 chop is too aggressive — Stage-2
  breakouts in V-shaped recovery + reflation rally are noisy.
- Trailing-stop tightness too aggressive for early-Stage-2 entries
  whose MA hasn't stabilised.
- Cascade gates may need recalibration for post-COVID data; many
  sectors had distorted breadth in 2020-2022.

**Strategy-tuning finding**, not a bug. Optimal-strategy's
counterfactual analysis (now wired in via PR #677's release-report
delta column) is the right tool to investigate which entries the
strategy missed vs took on this cell. **Defer until G1-G4 close**
— short-side bugs would cloud the analysis right now.

**Owner**: `feat-weinstein` (cascade-tuning) once short-side track
unblocks.

## 4. run-in-env.sh fallback narrowing (PR #685 follow-up)

qc-behavioral on PR #685 flagged a non-blocking concern: the bug-2
fallback in `dev/lib/run-in-env.sh` (lines 123-127) silently uses
the parent-repo path when `docker inspect` returns empty. This
narrows but doesn't fully close the silent-wrong-tree failure mode
— a daemon that answers `docker exec true` (passes liveness probe)
but fails `docker inspect` (e.g. permission issue, version skew)
would still mis-route.

**Fix surface**: in the fallback branch, log a stderr WARNING
noting "docker inspect failed; using parent-repo path
$PROJECT_ROOT". Not blocking, but should be observable when it
fires — silent fallback is a worse failure mode than the original
silent-success bug it replaces.

**Header docstring**: lines 21-23 of `dev/lib/run-in-env.sh` say
"Both paths verify dune-workspace exists" — stale relative to the
local-branch implementation. Should be brought back into sync with
the actual code.

**Owner**: `harness-maintainer`. Tiny PR — couple of `eprintf`
lines + docstring fix.

## 5. qc-structural false-positive pattern

Today's PRs #677, #687 both received qc-structural NEEDS_REWORK
verdicts that were structurally wrong:

- **#677**: ocamlformat env mismatch (host 0.27.0 vs project 0.29.0)
  — agent ran `dune build @fmt` against host opam, not container.
- **#687**: claimed "128 unintended files from concurrent feature
  development" — agent looked at `git log origin/main..HEAD` and
  miscounted commits' files instead of the PR's actual diff
  (`gh pr view <N> --json files` returns the canonical 6).

In both cases qc-behavioral approved cleanly and the PRs were merged
after manual override.

**Pattern**: qc-structural sometimes confuses cumulative ancestry
with PR scope. The agent's protocol should require it to use
`gh pr view <N> --json files` (or `gh pr diff <N>`) for the
authoritative file list, not derived from git-log walks.

**Owner**: `harness-maintainer`. Update agent prompt to mandate
`gh pr view` for file enumeration.

**DONE 2026-04-30**: `.claude/agents/qc-structural.md` Step 3 replaced with `gh pr view $PR_NUMBER --json files` as canonical file enumeration. `.claude/rules/qc-structural-authority.md` A3 row updated with explicit warning citing PR #687 false-positive. PR: harness/qc-structural-gh-pr-view.

## Sequencing for upcoming work

Per `dev/notes/short-side-gaps-2026-04-29.md` plus today's findings:

1. **G5 in flight** (audit harness Weinstein-strategy-backed scenario;
   prerequisite for G1-G4 verification). Branch
   `feat/audit-harness-weinstein-bear-window`.
2. **G1 + G2** (short stop direction; metrics short pairing) once G5
   harness lands. Both small, both surface immediately on G5's
   failing tests.
3. **G3 + G4** (cash floor + force-liquidation, now extended per
   §2 above). Touches core `Trading_portfolio` — qc-structural A1
   flag expected. Bigger PR than originally scoped.
4. **G6** (decade non-determinism). Independent of G1-G4;
   investigate after #687's range widening proves stable.
5. **covid-recovery WR investigation** (§3). Use optimal-strategy's
   counterfactual analysis after G1-G4 close.
6. **run-in-env.sh fallback log** (§4). Tiny PR, can ship anytime.
7. **qc-structural prompt fix** (§5). Tiny harness PR, can ship
   anytime.
