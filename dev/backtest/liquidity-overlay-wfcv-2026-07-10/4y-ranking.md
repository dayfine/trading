# Variant ranking

Baseline: baseline

## Pareto frontier (Sharpe up, Calmar up, MaxDD down)

- baseline
- min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0
- min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0
- min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0

## Variants

| Variant | Sharpe | Calmar | MaxDD % | Frontier | Deflated Sharpe |
|---------|-------:|-------:|--------:|:--------:|----------------:|
| baseline | 0.719 | 0.674 | 26.70 | yes | 0.9929 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 0.719 | 0.674 | 26.70 | yes | 0.9929 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 0.626 | 0.470 | 26.06 | no | 0.8724 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 0.677 | 0.630 | 22.24 | yes | 0.9124 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 0.670 | 0.637 | 22.07 | yes | 0.9128 |
