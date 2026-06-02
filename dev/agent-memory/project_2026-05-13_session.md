---
name: 2026-05-13 marathon session findings
description: 21 PRs merged in one session — NAV fix + universe foundation + tuning evidence + 2 negative results
type: project
originSessionId: 6b136992-6cc4-4ab4-bc18-44211fdc0bdd
---
Session 2026-05-13 → 2026-05-14 landed **21 PRs**. Key findings worth carrying
forward:

**Headline correctness fixes:**
- **#1063 Portfolio_view NAV avg-cost fallback** — pre-fix 16y long-short had
  a 300+-event death-loop on Peak_tracker. Post-fix: 1 force-liq, Sharpe 0.70,
  Calmar 0.46, MaxDD 19.8%. Long-only force-liqs went 0.
- **#1066** re-pinned 10y/16y goldens + 5y wall_seconds.
- **#1076 Daily_price.active_through** — survivorship-aware foundation; no
  golden drift (default None preserves byte-equivalence). Unblocks P5 PI
  filter.

**Why PR #1051 verdict was wrong (#1061):** the 81-cell weight sweep used
fake key paths (`weights.rs/volume/breakout/sector`) — real names are
`w_positive_rs / w_strong_volume / w_stage2_breakout / w_sector_strong`.
`runner.ml:_apply_overrides` silently dropped them. M5.4-E4 (correct paths)
shows weights move metrics 22pp/0.12 Sharpe. **#1069** is the validation
linter that closes this hazard — FAIL LOUDLY on overlay keys not resolving.

**Cascade gate vs. weights distinction is cosmetic.** `min_grade = C` is
algebraically `score ≥ 40`. Real binding mechanism is entry-walk cash
consumption — only ~1.3 of 12.5 admitted candidates enter per Friday, so
rank order is decisive.

**Q5 score-cliff cannot be improved by re-weighting** — both negative:
- Hard cap (`max_score_override = 79`, entry-caps arm B): Sharpe 0.85→0.59,
  MaxDD 18.4%→52.1% (regime shift).
- Soft penalty (#1080 E5a/b/c): all degrade vs baseline on Sharpe + WR +
  MaxDD. Q5's 28.6% WR is real but per-trade profit factor on winners is
  large enough that admitting them is net positive — both levers drop the
  asymmetry.

**Axis-1 winner (#1079, #1081 validation):** `installed_stop_min_pct = 0.08`.
- 5y: Calmar 0.40→0.53 (+0.13)
- 10y broad-1000: +0.008 (in neutral band — keep as candidate, pair with
  axis-3 to recover lift)
- 16y long-only: +0.06
- 16y long-short: +0.04
- Mechanism: avg-hold 41d→68d, trades 264→174.

**Continuation buys (Interpretation B) merged default-off (#1078)** — needs
real-data impact measurement (planned L1 sweep, blocked on disk crash).

**Docker / disk operational issues:**
- `.claude/worktrees/` agent dirs accumulate quickly (~3-7GB each).
- Disk hit 100% TWICE this session; Docker filesystem corrupts when
  bottoming out. Sweep `dev/scripts/sweep_stale_worktrees.sh` regularly.
- Concurrent agents can run out of disk fast — limit to ~2 BG agents that
  build OCaml at once.

**Files added today (durable):**
- `dev/notes/historical-universe-status-2026-05-13.md`
- `dev/notes/p3-tuning-sweep-design-2026-05-13.md`
- `dev/notes/screener-weights-inertness-2026-05-13.md`
- `dev/notes/q5-score-feature-attribution-2026-05-13.md`
- `dev/plans/continuation-buys-2026-05-13.md`
- `dev/plans/short-side-margin-2026-05-13.md`

**Followups still open:**
- L1 (continuation buys impact) — staged but disk blocked.
- L2 (axis-2 min_correction_pct sweep) — staged but disk blocked.
- Axis-3 `min_score_override` floor sweep — not yet started.
- Cross-sweep axis-1 (0.08) × axis-3 — recommended to recover broad-1000 lift.
- Short-side margin Phase 1 (Reg-T accounting + borrow fee) — design at
  `dev/plans/short-side-margin-2026-05-13.md`.
- Continuation buys Interpretation A (pyramid) — gated behind core-module
  decision (Position.t needs `AddToHolding` transition).
