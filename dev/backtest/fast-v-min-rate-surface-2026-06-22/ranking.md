# Variant ranking

Baseline: baseline

## Pareto frontier (Sharpe up, Calmar up, MaxDD down)

- baseline
- fast_v_min_rate_pct=0.08

## Variants

| Variant | Sharpe | Calmar | MaxDD % | Frontier | Deflated Sharpe |
|---------|-------:|-------:|--------:|:--------:|----------------:|
| baseline | 0.699 | 1.348 | 10.60 | yes | 1.0000 |
| fast_v_min_rate_pct=0.08 | 0.699 | 1.348 | 10.60 | yes | 1.0000 |
| fast_v_min_rate_pct=0.12 | 0.666 | 1.332 | 11.06 | no | 0.9999 |
| fast_v_min_rate_pct=0.16 | 0.664 | 1.331 | 11.10 | no | 0.9999 |
