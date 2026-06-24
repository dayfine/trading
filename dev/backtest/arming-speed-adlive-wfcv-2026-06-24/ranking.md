# Variant ranking

Baseline: baseline

## Pareto frontier (Sharpe up, Calmar up, MaxDD down)

- fast_v_arm_on_rate_alone=true

## Variants

| Variant | Sharpe | Calmar | MaxDD % | Frontier | Deflated Sharpe |
|---------|-------:|-------:|--------:|:--------:|----------------:|
| baseline | 0.562 | 1.030 | 9.95 | no | 0.9999 |
| fast_v_arm_on_rate_alone=true | 0.567 | 1.036 | 9.83 | yes | 0.9999 |
| fast_v_arm_on_rate_alone=false | 0.562 | 1.030 | 9.95 | no | 0.9999 |
