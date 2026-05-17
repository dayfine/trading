# Private tuned-configs repo — design plan

**Filed:** 2026-05-18 (autonomous session). Design only; implementation
deferred until the next BO sweep produces a config worth blessing.

---

## 0. Why a separate repo

Tuning artifacts (BO winners, walk-forward best-points, OOS-validated config
blobs) have a different lifecycle from the strategy codebase:

1. **Faster iteration cadence.** Each tuning campaign mints a new blessed
   point. Per-config history doesn't belong on `main` branch.
2. **Different audience.** Configs may carry alpha-relevant choices we
   wouldn't want public alongside open-source-able code.
3. **Decouple regression baselines from live config.** The main repo's
   `goldens-*/*.sexp` files are *regression-pinned* (we want them
   stable so they catch behavioral drift). The "current best config" is
   what we trade with — different concern, different versioning.
4. **Backup + audit trail.** A dedicated history of every promoted
   config + how it was derived is institutional memory.

## 1. Repo layout

```
dayfine/trading-configs-private   (private GitHub repo)
├── README.md                     — what this repo is + how to use
├── configs/
│   ├── 2026-05-18-cell-e-baseline/
│   │   ├── config.sexp            ← the actual config_overrides blob
│   │   ├── provenance.md          ← how this was derived
│   │   ├── walk-forward.sexp      ← 30-fold CV results (optional)
│   │   └── oos-validation.sexp    ← OOS holdout results (optional)
│   ├── 2026-06-XX-bayesian-v1-winner/
│   │   └── ...
│   └── archive/                   ← superseded but kept for history
│       └── 2026-04-XX-cell-d/
├── live/
│   └── current.sexp -> ../configs/2026-05-18-cell-e-baseline/config.sexp
└── _metadata/
    └── catalog.sexp               ← machine-readable index
```

Each `configs/<date>-<name>/` directory is **append-only**: never re-edit a
committed config; supersede by adding a new dated dir + bumping the `live/`
symlink.

## 2. Consumer interface

### Recommended: Option B — env-var pointer + new runner flag

- Operator clones the private repo alongside the main repo (any location).
- `backtest_runner` gets a new CLI flag `--config-path <file.sexp>` that
  loads the sexp at `<file.sexp>` and deep-merges it into the default
  Weinstein_strategy config (same semantics as `--override <key>=<value>`
  / `--shared-override`).
- Scenarios that should track the "current best" config point at
  `${TRADING_CONFIGS_DIR:-../trading-configs-private}/live/current.sexp`.
- Existing `--override` / `--shared-override` flags remain — for ad-hoc
  tweaks on top of the loaded base.

Pros: zero coupling between the two repos; either can move independently.
Operator chooses where to clone the private repo.

### Alternative A — git submodule

Add `trading-configs-private/` as a submodule of the main repo. Scenarios
can reference paths inside `trading-configs-private/live/current.sexp`.

Pros: tighter coupling, easier reproduction (single `git clone` resolves
everything).

Cons: submodule UX is fiddly; we'd inherit submodule-state-confusion
risks.

### Alternative C — copy on promote

When promoting a config, copy the sexp into a one-off scenario file
under `dev/configs-promoted/<date>-<name>.sexp` in the main repo.

Pros: maximally decoupled (no private repo dependency at all).

Cons: defeats the "keep config history out of main repo" goal.

**Pick Option B.** Most pragmatic for a single-operator workflow; can
migrate to A later if the team grows.

## 3. Evolution discipline

- One commit per promoted config (no batching).
- Commit message format:
  `promote: <date>-<name> — Sharpe X.XX ± 0.XX (n=<folds>), <window>`
  Example:
  `promote: 2026-06-15-bayesian-v1 — Sharpe 0.84 ± 0.06 (30 folds), 2010-2026`
- Promote script (`dev/scripts/promote_config.sh` in main repo):
  - Takes a path to a tuner-output `config.sexp` + the walk-forward / OOS
    artifacts.
  - Creates `<date>-<name>/` in the private repo with the four files.
  - Writes `provenance.md` from a template (BO seed, walk-forward fold
    count, OOS Sharpe + delta vs prior live).
  - Updates the `live/current.sexp` symlink.
  - Regenerates `_metadata/catalog.sexp` from `configs/*/provenance.md`.
  - Commits the new directory + symlink change in the private repo.
- Never re-edit a committed config: supersede by adding a new dated dir.

## 4. MVP setup (when ready to promote first config)

1. Create `dayfine/trading-configs-private` private GitHub repo.
2. Clone to `~/Projects/trading-configs-private/` (or wherever).
3. Seed with the current Cell E config as
   `configs/2026-05-18-cell-e-baseline/config.sexp`.
4. Add `dev/scripts/promote_config.sh` to the main repo.
5. Add `--config-path <file>` CLI flag to `backtest_runner` (small PR;
   reuses `Backtest.Config_override.parse_to_sexp` for the deep-merge).
6. First scenario consumer: a `live-strategy-current.sexp` scenario in
   `trading/test_data/backtest_scenarios/live/` that points at
   `${TRADING_CONFIGS_DIR}/live/current.sexp` via the new flag.

## 5. Open questions

- **GitHub secret hygiene** — the private repo will live in `dayfine/`.
  No automation pushes to it; promotion is a manual operator step. No CI
  secrets needed beyond `gh auth` on the operator's machine.
- **Sync with regression baselines** — when a promoted config becomes the
  "current" one, do we also re-pin the canonical regression scenarios
  (`goldens-sp500/sp500-2019-2023.sexp`)? Open. For now: no automatic
  re-pin. Regression baselines stay sticky; the private repo carries the
  evolving target. A drift > 1pp triggers a manual decision: re-pin the
  baseline OR investigate the divergence.
- **OOS-failure rollback** — what if the live config fails OOS validation
  on a future window? Procedure: revert `live/current.sexp` symlink to the
  prior config in the same commit. New BO sweep follows.

## 6. Not in scope (today)

- Public-data ingest configs (already lives in main repo's `dev/status/`
  data tracks).
- Per-broker fill-cost configs (cost_model overlay) — those are scenario
  parameters, not strategy parameters. Stay in main repo.
- Universe-snapshot goldens — those are *inputs* to the strategy, not
  *parameters*. Stay in main repo at `trading/test_data/goldens-custom-universe/`.

## 7. Acceptance criteria

When the first BO sweep produces a config worth blessing:
- [ ] Private repo created + seeded with current Cell E.
- [ ] `--config-path` flag wired into backtest_runner.
- [ ] `promote_config.sh` works end-to-end against a real BO output.
- [ ] One live scenario consumes `live/current.sexp` and produces the
      expected pinned-baseline metrics.

Total estimated effort: ~150 LOC (runner flag + promote script + scenario
wiring) + 1 hour ops setup (repo create + initial seed).
