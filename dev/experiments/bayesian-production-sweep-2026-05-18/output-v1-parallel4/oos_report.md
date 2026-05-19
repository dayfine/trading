# OOS validation report

BO spec: `/workspaces/trading-1/dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod.sexp`

Candidate variant: `bo-iter-best`

Baseline variant: `cell-E`

Acceptance rule: per plan [dev/plans/bayesian-multi-param-scaling-2026-05-16.md] §6.3 — OOS mean Sharpe must be within 0.10 of in-sample mean Sharpe.

## In-sample vs OOS mean Sharpe

| Slice | Fold count | Mean Sharpe |
|---|---|---|
| In-sample | 27 | 0.8011 |
| OOS | 4 | 0.7595 |
| Gap (OOS - in-sample) | — | -0.0416 |

## Per-OOS-fold Sharpe

| Fold | Sharpe |
|---|---|
| `fold-026` | 1.4092 |
| `fold-027` | 1.9853 |
| `fold-028` | 0.4984 |
| `fold-029` | -0.8547 |

## Verdict

**ACCEPT**

- Gap (OOS - in-sample) = -0.0416
- Hurdle = 0.10 (absolute)
