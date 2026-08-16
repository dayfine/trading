# Next-session priorities — 2026-08-16

**Supersedes** `next-session-priorities-2026-08-15.md`.

## Start here

1. `gh run list --branch main --workflow CI --limit 1` — main was green at 18:52.
2. **Check the grid first — it is still running.** `cat /tmp/v4grid-chain.log`

---

## In flight: the nearfloor confirmation grid

Detached (`nohup`), survives the session boundary. **7 runs, 3 done at 18:52,
~4h left.**

```sh
cat /tmp/v4grid-chain.log            # progress + results
pgrep -f v4grid-run.sh               # alive?
sh /tmp/v4grid-run.sh                # resume — skips any cell with a RESULT line
```

- Script: `/tmp/v4grid-run.sh`. Specs: `/tmp/v4grid-specs/` — **deliberately
  outside the repo**, see the process note below.
- Pinned worktree `.claude/worktrees/sweep-v4-seeded` at `60100bbf6`. Do not
  delete it while the grid runs.

**Narrowed from 11 runs to 7**: the `ttl4` and `both` arms were dropped because
ttl4 is now known mis-specified (defect D) and they answered a retired question.
What remains is the live question: **does nearfloor's edge hold across universe
and period?**

### Read each cell against ITS OWN null

Cell A (top-3000 × 2000-2026) null = **132.5pp**.
Cell B (sp500 × 2000-2026) null = **180.08pp** (591.38 / 771.47, mean 700.97) —
**wider than cell A's**, so do not carry A's yardstick across. Cell C gets 2
core salts for the same reason.

Decision rule is `promotion-confirmation.md`: promote a value only if it beats
baseline in a strong majority of cells **and** is never badly dominated. On
disagreement, keep nearfloor as a default-off axis and promote nothing.

---

## The queue (graded; full detail in `dev/plans/entry-anchor-and-ttl-2026-08-15.md`)

| order | | defect | impact | complexity |
|---|---|---|---|---|
| **1** | **F** | artifacts can't answer basic questions | med | **low** |
| **2** | **C+E** | one knob arms re-screen + clock; 21.7-year orders | high | **low** |
| **3** | **A** | the entry anchor E goes stale | **high** | med |
| **4** | **D** | the 4-week clock cuts the most profitable band | high | low |
| **5** | **B** | "prefer other candidates" built as hard rejection | med | med |

**Start with F.** It is pure emission, changes no behaviour, and **A is measured
through it** — the whole BFX/AXTI derivation needed a raw-bar dump and an
arithmetic inversion because the audit omits `ma_value`, the decision-date close,
and the resistance price E anchors to.

---

## The diagnostic — strongest evidence for A, and one open thread

Real top-3000 universe, real 15% gate, 2024-2026, three arms
(`/tmp/v4diag2/`, specs in `dev/experiments/entry-anchor-diagnostic-2026-08-15/`):

| arm | AXTI tickets | AXTI fills |
|---|---|---|
| core (`Window_extreme`) | 1 | 0 |
| nearfloor (`Nearest`) | 4 | 0 |
| nearfloor + `stop_anchor_at_entry_base` | 5 | 0 |

**Stop-side fixes raise admissions 1 → 4 → 5 and produce zero fills.**

And on the exact 2025-06-27 decision, the anchor arm gives **E = 2.71, risk 2.1%
— admitted**, against **E = 4.05, risk 57.3% — rejected** in the full-history
run. The only difference is how far back the anchor window could see. That is
the sharpest evidence for A.

### ⚠ Open thread — the zero fills are unexplained

A ticket resting at E = 2.71 placed 2025-06-27, with AXTI rising through that
level within weeks (first bar above 4.05 was 2025-09-16), **should have filled.**
It did not, in any arm. Candidates worth checking: `entry_extension_max_pct 2.0`
rejecting a fill that gaps too far past E; capital/budget starvation in the entry
walk; or the ticket being superseded. **Resolve this before acting on A** — it
may be a second, independent defect sitting behind the first.

---

## Turning the dissections into tests (task 20)

The infrastructure exists and none of this session's work uses it:
`scenario_runner`, `goldens-small/` (spec + pinned `expected`, wired into
`dune runtest`), the candidate-universe builder (#2311) and its byte-identical
payoff validation (#2319); runs deterministic since #2279.

Three to pin, each a small universe over a short window (seconds to run):

1. **AXTI 2025-06-27** — assert `suggested_entry`, `installed_stop`, and the
   `Stop_too_wide` rejection. Pins A, and **fails the moment A is fixed** — which
   is exactly what makes it useful.
2. **BFX 2020-04-17** — negative control: must stay rejected, so an A-fix does
   not start admitting 2.2×-MA parabolic moves.
3. **CHRW 2022→2025** — pins the TTL structural result: 1,070-day rest under
   ttl0, cancelled under ttl4, re-screened 4× and never filled.

---

## Carried forward

- **#8** recompute async `exit_trigger` groupings against a post-fix run — the
  old join wrote *wrong* triggers, not just empty ones (49 rows changed where
  only 29 had been empty; `stage3_force_exit` read 0 firings).
- **#10** the 808s per-run floor. Universe size is not what dominates cost:
  dropping 91% of the universe removed only 21% of run time.
- **#13** candidate supply vs capacity — in bull regimes we are
  **capital-constrained, not candidate-constrained** (utilization 70.2% against a
  70% cap). Reframed as a selection-quality question, not throughput.

---

## Process notes from this session

- **`jj new` deletes uncommitted repo paths out from under a running chain.** It
  killed the payoff chain's final copy, and then killed the grid two hours in —
  *after* I had written the lesson down. Long-running scripts must read their
  inputs from **outside the repo** (`/tmp/v4grid-specs`), and their chains should
  skip already-completed work so a restart is cheap.
- **Every long chain needs a resume path.** The grid now skips any cell with a
  `RESULT` line in its log; that turned a 2-hour loss into a 5-minute one.
- **Node's `process.argv[1]` is the script path, not the first argument.** Two
  patch scripts silently rewrote *themselves* and reported success; the artifact
  went out uncorrected until a grep caught it.
- **zsh does not word-split unquoted variables.** A branch-deletion loop received
  20 names as one string, and a spec generator produced files with spaces in
  their names. Use `while IFS= read -r` over a file.
- **Verify a claim's basis before generalising.** "The stop reaches into the
  crash floor" was wrong (it is 4% under a recent swing low); "the gate measures
  the wrong thing" held for AXTI but not BFX, which is a *correct* rejection at
  2.2× its 30-week MA. The 30-week MA was the check that separated them, and it
  should have been the first thing pulled.

---

## Rebuilding the task list

The harness task list is **scoped to a session UUID**
(`~/.claude/tasks/<uuid>/N.json`), so a new session starts empty. This doc is
the durable copy — recreate the list from the table below.

The 2026-08-15 session's tasks are still readable at
`~/.claude/tasks/f38d1024-5259-467e-95cf-9aa2c8fe4ddb/` if the full
descriptions are wanted.

| # | task | state | blocked by |
|---|---|---|---|
| 15 | nearfloor confirmation grid (7 runs, narrowed) | **in flight** | — |
| 22 | why did zero AXTI tickets fill? | pending | — |
| 14 | **[F, queue 1]** emit utilization + E-provenance into artifacts | pending | — |
| 16 | **[C+E, queue 2]** split the TTL knob; bound the clock ~3yr | pending | — |
| 17 | **[A, queue 3]** fix the stale entry anchor E | pending | **22** |
| 18 | **[D, queue 4]** re-test TTL at {13, 26, 52} weeks | pending | **16** |
| 19 | **[B, queue 5]** make the 15% stop rule a demotion | pending | — |
| 20 | turn the dissections into pinned scenario tests | pending | — |
| 8 | recompute async `exit_trigger` groupings post-fix | pending | — |
| 10 | attack the 808s per-run floor | pending | — |
| 13 | candidate supply vs capital capacity | pending | — |

**Suggested opening move:** check the grid (15), then start **F (14)** — it is
pure emission, blocks nothing, and A is measured through it. Do **not** start A
(17) before resolving 22.
