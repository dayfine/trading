# Variant ranking

Baseline: baseline

## Pareto frontier (Sharpe up, Calmar up, MaxDD down)

- min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0
- min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0

## Variants

| Variant | Sharpe | Calmar | MaxDD % | Frontier | Deflated Sharpe |
|---------|-------:|-------:|--------:|:--------:|----------------:|
| baseline | 0.654 | 0.917 | 23.59 | no | 0.9941 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 0.654 | 0.917 | 23.59 | no | 0.9941 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 0.753 | 1.131 | 18.03 | yes | 0.9999 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 0.634 | 0.821 | 17.42 | yes | 1.0000 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 0.609 | 0.802 | 17.69 | no | 1.0000 |
