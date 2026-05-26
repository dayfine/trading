# T1.4 — Proxy-fidelity calibration procedure

Owner: feat-backtest (track: `tuning`).
Plan: `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` §M1 T1.4.

## What the calibrator does

`proxy_calibration.exe` (built at
`trading/trading/backtest/tuner/bin/proxy_calibration.ml`) consumes two
`fold_actuals.sexp` files produced by `walk_forward_runner.exe` — one for
the cheap (e.g. 6-fold) walk-forward spec and one for the expensive (e.g.
26-fold) spec. Both runs should evaluate Cell E on the same base scenario;
the cheap fold layout is expected to be a subset of the expensive one (so
matching fold-names share a market regime).

For each fold whose `fold_name` appears in both inputs (after filtering to
the requested `variant_label`, default `cell-E`), the exe projects a chosen
per-fold metric (default `sharpe_ratio`) into a paired observation. It then
computes the Spearman rank correlation between the cheap and expensive
sequences. The verdict is **PASS** iff `ρ ≥ threshold` (default `0.7` per
plan §M1 T1.4 acceptance row).

Output is a self-contained markdown report with the matched-fold count, the
ρ value, the verdict, and a per-fold table for inspection. Exit code is
`0` on PASS, `1` on FAIL — so a CI gate can branch on the verdict directly.

## Why fold_actuals.sexp, not aggregate.sexp

The dispatch text loosely referred to "aggregate.sexp" but Spearman ρ
requires per-fold samples. The `aggregate.sexp` file carries cross-fold
summary stats only (mean / stdev / min / max). The sibling `fold_actuals.sexp`
artefact (written by `Walk_forward.Walk_forward_runner._write_fold_actuals`)
carries the per-fold rows we need.

## CLI surface

```bash
proxy_calibration.exe \
  --cheap <path-to-cheap/fold_actuals.sexp> \
  --expensive <path-to-expensive/fold_actuals.sexp> \
  [--metric sharpe|totalreturn|calmar|cagr|maxdrawdown] \
  [--threshold <float>] \
  [--variant <label>] \
  [--out <markdown_path>]
```

| Flag | Default | Notes |
|---|---|---|
| `--cheap` | (required) | path to cheap walk-forward `fold_actuals.sexp` |
| `--expensive` | (required) | path to expensive walk-forward `fold_actuals.sexp` |
| `--metric` | `sharpe` | metric column to correlate; accepts `sharpe`/`totalreturn`/`calmar`/`cagr`/`maxdrawdown` (case-insensitive, hyphens or underscores OK) |
| `--threshold` | `0.7` | acceptance threshold for ρ |
| `--variant` | `cell-E` | variant_label filter; both inputs are restricted before joining (multi-variant `fold_actuals.sexp` files otherwise produce non-deterministic last-writer-wins joins) |
| `--out` | (stdout) | optional markdown report path |

## Local-only production run

The v6 / v4 production sweep `fold_actuals.sexp` files are NOT accessible
in GHA. They live on the maintainer's local machine under:

```
/Users/difan/Projects/trading-1/.sweep-output/v6-11knob/<cell-name>/fold_actuals.sexp
/Users/difan/Projects/trading-1/.sweep-output/v4-9knob/<cell-name>/fold_actuals.sexp
```

The canonical T1.4 calibration runs Cell E on:

- the **cheap proxy** — the 6-fold subset spec used in the BO inner loop; and
- the **expensive set** — the 26-fold full-history spec used for promote-gate
  validation.

To produce both inputs (one-time pre-flight before T1.4 calibration), run
`walk_forward_runner.exe` against the cheap spec and the expensive spec for
Cell E's parameter assignment. Each produces a `fold_actuals.sexp` in its
output directory.

Then point the calibrator at both:

```bash
docker exec trading-1-dev bash -c \
  "cd /workspaces/trading-1/trading && eval \$(opam env) && \
   dune exec --no-build trading/backtest/tuner/bin/proxy_calibration.exe -- \
     --cheap /path/to/cheap-6fold/fold_actuals.sexp \
     --expensive /path/to/expensive-26fold/fold_actuals.sexp \
     --metric sharpe \
     --threshold 0.7 \
     --variant cell-E \
     --out /tmp/t1-4-calibration-verdict.md"
```

The exe will emit a one-line `eprintf` summary
(`matched=N rho=X.XXXXXX threshold=0.7000 verdict=PASS|FAIL`) to stderr and
the full markdown to the `--out` file (or stdout if omitted). Exit code is
the verdict.

## Where the verdict goes

When the local operator runs the calibrator against real cheap/expensive
fold_actuals data, the verdict goes to
`dev/notes/t1-4-calibration-verdict-<YYYY-MM-DD>.md`. The verdict file
should record:

- which cheap and expensive specs were used (paths + fold counts);
- which metric was correlated (Sharpe is the default; CAGR and MaxDD are
  also worth recording for a sanity-check column);
- the calibrator's `eprintf` summary line (`matched=N rho=X.XXXXXX
  threshold=0.7000 verdict=PASS|FAIL`);
- the full markdown report inline (or as an attachment);
- the verdict — PASS unblocks T1.2 successive-halving (the cheap tier is
  a faithful proxy for the expensive); FAIL means the cheap proxy must
  be redesigned (e.g. wider fold span or different fold selection).

## Acceptance criterion (plan §M1 T1.4)

> Cell E on the 6-fold cheap proxy vs the 26-fold expensive walk-forward
> set; require **ρ ≥ 0.7** for the proxy to be acceptable.

PASS at the local-only run unblocks downstream T1.2 successive-halving
(which assumes the cheap-tier ranking is preserved at the expensive tier).
FAIL pauses T1.2 until a better cheap-tier design is identified.
