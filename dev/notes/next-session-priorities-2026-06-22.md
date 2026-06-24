# Next-session priorities — 2026-06-22 (handoff)

**Supersedes** `next-session-priorities-2026-06-21-PM.md`. Autonomous overnight run
(user AFK ~10h). Main green throughout; everything below shipped as merged PRs.

## TL;DR — the decline-character idea is BUILT (3 mechanisms, all default-off)

Per the user's 2026-06-21 directive ("explore the idea + build the other things")
and the 2020-crash discussion (the long side exits a fast-V crash ~3-4 weeks late,
at the bottom, eating ~38% DD; shorts get squeezed in the V), the shared primitive
+ both branches are now on main, **all default-off (zero behavior change until a
flag flips)**:

| PR | What | Default |
|---|---|---|
| #1692 | **Build 1 — `Decline_character` classifier** (`Slow_grind\|Fast_v\|Not_declining`), pure, lookahead-free. `trading/analysis/weinstein/macro/lib/decline_character.mli` | n/a (read-only signal) |
| #1695 | **Build 2 — fast-crash absolute stop** (`catastrophic_stop_pct`, armed only on `Fast_v`). Tail-RISK insurance, dormant in normal tapes. `trading/trading/weinstein/stops/lib/catastrophic_stop.mli` | `0.0` = no-op |
| #1696 | **Build 3 — faithful short** (`neutral_blocks_shorts` Bearish-only + `enable_slow_grind_short_gate`). Tightens shorts to confirmed slow bears. `screener.ml` + strategy plumbing | both `false` = prior behavior |

Also landed: #1689 (barbell end-to-end wiring, P0.1), #1691 (the build plan doc).
**Orchestrator cron landed #1697 (barbell `floor_weight` Variant_matrix axis)** —
the other #1683 follow-up — so the P0.2 weight cert is now wired to search.

Design + rationale (READ FIRST next session):
`dev/notes/decline-character-exploration-2026-06-21-PM.md`.

## The honesty caveat that gates the payoff (carry this forward)
The **novel A/D-lead input is NOT yet wired** — the snapshot pipeline still passes
`~ad_bars:[]` (`trading/analysis/weinstein/snapshot_pipeline/lib/pipeline.ml:103`),
so the macro "A-D Line" indicator is Neutral/inert. Today the classifier runs on
its computable-now legs: **rate-of-decline** (Build 2's `Fast_v` = steep rate) and
**weeks-below-declining-MA** (Build 3's `Slow_grind`). Those are real and faithful;
the A/D-*lead* refinement awaits Build 0.

## ⚡ Screen result already in (fast-crash stop, Build 2) — READ THIS

The Build-2 fast-crash stop was screened this session
(`dev/backtest/fast-crash-stop-screen-2026-06-22/FINDINGS.md`, PR #1703):
**it NEVER FIRED** (all `catastrophic_stop_pct` values byte-identical). WHY:
`Fast_v` arms only with the *index below a falling MA*, which in 2020 wasn't true
until ~mid-March — by then the structural gap-down `stop_loss` had already exited
every long (Feb 28–Mar 13). **The binding constraint is arming LATENCY, not stop
width** — and it's largely universe-independent (the arming keys off the ^GSPC MA).
So the **real next lever is `Decline_character` arming SPEED**: add a default-off
knob to arm `Fast_v` on **rate-of-decline ALONE** (drop the falling-MA precondition
for the fast-V path), then re-screen on a broad PIT universe (top-500/1000 2019-2021,
needs a snapshot rebuild). This redirects Build-2 follow-up away from
`catastrophic_stop_pct` tuning. The faithful short (Build 3) is NOT yet screened.

## Next steps (priority order)

### 1. SCREEN the remaining branch (faithful short, Build 3) + the arming-speed variant
Before any WF-CV. For each, run a backtest with the flag ON vs OFF over a window
spanning 2020 (fast-V) AND 2000-02/2008 (slow bears), decompose by regime:
- **Fast-crash stop (Build 2):** `catastrophic_stop_pct ∈ {0, 0.08, 0.10, 0.12}`.
  Hypothesis: caps the 2020 DD (the ~38% the structural stop missed) WITHOUT taxing
  the fat-tail winners in normal regimes (it's armed only on `Fast_v`, so it should
  be dormant outside crashes — verify that). If it taxes the tail elsewhere, the
  arming gate is too loose.
- **Faithful short (Build 3):** `neutral_blocks_shorts=true` ± `enable_slow_grind_short_gate=true`.
  Hypothesis (from the night's screen): the slow-grind gate flips the short leg from
  net-negative (squeezed in 2020) to net-positive by skipping the V-squeezes while
  keeping 2002/2008. Decompose by bear window.
- Apply `.claude/rules/mechanism-validation-rigor.md` (distribution not point,
  scale, regime decomposition, calibrated verdict). Screen → if promising, WF-CV via
  `experiment-gap-closing` → `promotion-confirmation.md` grid.
- **Data:** needs a snapshot warehouse (the deep one was cleaned). Rebuild via
  `build_scenario_snapshots` (~26min, see `feedback_large_n_needs_snapshot_mode`) OR
  run a small SP500 window in CSV mode for a quick first signal.

### 2. Build 0 — A/D data wiring (NOT default-off — needs oversight, re-pins goldens)
Generate synthetic ADL ≥1998 (`trading/analysis/scripts/compute_synthetic_adl`) +
wire `Ad_bars.load` into `pipeline.ml:103` (replace `~ad_bars:[]`). **This CHANGES
macro behavior** (activates the A-D Line indicator → macro trend shifts → entries/
exits change → goldens re-pin). So it is a behavior-changing change behind the
existing `skip_ad_breadth` flag, requiring golden re-pin + review — do it attended,
not as a default-off drop. It sharpens the classifier's A/D-lead leg (makes the
novel signal real). Sequence AFTER the screens give a first signal on the
computable-now legs.

### 3. P0.2 — barbell weight cert (needs your weight mandate)
#1697 wired the `floor_weight` axis. Run the `promotion-confirmation.md` grid
(1998-26 full + 1998-2008 grind + 2009-26 bull + a top-1000/3000 breadth cell) to
certify the light floor weight 0.30-0.40 (per the correct-window frontier). The
weight choice is **mandate-driven (your call)** — light 0.30-0.40 (keep edge, modest
DD relief) vs heavier 0.50-0.70 (max risk-adjusted). Note `barbell-breadth-2026-06-21`
showed the weight is universe-dependent (floor dominates top-1000).

## Process lessons logged this session (memory)
- **qc-structural missed CI linter FAILs TWICE** (#1692 nesting, #1696 file-length+nesting)
  — its env didn't run the dune-wired `devtools/checks`. **CI is the only authoritative
  linter gate; always `gh pr checks` before trusting a structural "lint passed".**
- **Concurrent QC agents wiped the parent `.jj/`** (recovered losslessly via
  `jj git init --colocate`). **Serialize jj-writing QC agents.**
- **A feat-agent hit a worktree/jj desync** (committed via the parent default
  workspace) — PR content was still correct; cleaned by resetting parent `@` off main.
- A QC agent left an orphaned `dune build` holding the container lock 27 min — kill
  stray dune before local verifies.

## State
Main green (HEAD 72e1ab68f). 0 feature PRs open. The 3 mechanisms are default-off
so main is fully shippable. Worktrees + memory cleaned.
