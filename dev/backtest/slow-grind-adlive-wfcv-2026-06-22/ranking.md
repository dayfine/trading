# Variant ranking

Baseline: baseline

## Pareto frontier (Sharpe up, Calmar up, MaxDD down)

- baseline
- enable_slow_grind_short_gate=true
- enable_slow_grind_short_gate=false

## Variants

| Variant | Sharpe | Calmar | MaxDD % | Frontier | Deflated Sharpe |
|---------|-------:|-------:|--------:|:--------:|----------------:|
| baseline | 0.661 | 1.152 | 10.93 | yes | 0.9999 |
| enable_slow_grind_short_gate=true | 0.612 | 1.064 | 10.61 | yes | 0.9999 |
| enable_slow_grind_short_gate=false | 0.661 | 1.152 | 10.93 | yes | 0.9999 |
