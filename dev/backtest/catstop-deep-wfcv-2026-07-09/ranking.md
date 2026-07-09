# Variant ranking

Baseline: baseline

## Pareto frontier (Sharpe up, Calmar up, MaxDD down)

- baseline
- catastrophic_stop_pct=0.0
- catastrophic_stop_pct=0.10

## Variants

| Variant | Sharpe | Calmar | MaxDD % | Frontier | Deflated Sharpe |
|---------|-------:|-------:|--------:|:--------:|----------------:|
| baseline | 0.492 | 0.894 | 12.11 | yes | 0.9973 |
| catastrophic_stop_pct=0.0 | 0.494 | 0.912 | 12.31 | yes | 0.9969 |
| catastrophic_stop_pct=0.10 | 0.492 | 0.894 | 12.11 | yes | 0.9973 |
