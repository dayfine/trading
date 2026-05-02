# Backtest comparison

- Date range: 2023-01-02 .. 2023-12-31
- Universe size: 491 (baseline) / 491 (variant)
- Initial cash: $1000000.00
- Final portfolio value: $1329344.21 (baseline) / $1342214.93 (variant), delta = $12870.72
- Round-trips: 26 (baseline) / 26 (variant), delta = 0

## Metric diffs

| Metric | Baseline | Variant | Delta |
|---|---|---|---|
| total_pnl | -33576.5700 | -33576.5700 | 0.0000 |
| avg_holding_days | 64.5769 | 64.5769 | 0.0000 |
| win_count | 5.0000 | 5.0000 | 0.0000 |
| loss_count | 21.0000 | 21.0000 | 0.0000 |
| win_rate | 19.2308 | 19.2308 | 0.0000 |
| sharpe_ratio | 1.6816 | 1.7234 | 0.0418 |
| max_drawdown | 9.8404 | 9.8404 | 0.0000 |
| profit_factor | 0.7394 | 0.7394 | 0.0000 |
| cagr | 33.1692 | 34.4666 | 1.2974 |
| calmar_ratio | 3.3707 | 3.5026 | 0.1318 |
| open_position_count | 9.0000 | 8.0000 | -1.0000 |
| open_positions_value | 1273609.1000 | 1251294.3900 | -22314.7100 |
| unrealized_pnl | 363539.0200 | 376409.7400 | 12870.7200 |
| trade_frequency | 3.2406 | 3.1874 | -0.0531 |
| total_return_pct | 32.9344 | 34.2215 | 1.2871 |
| volatility_pct_annualized | 13.3370 | 13.4434 | 0.1064 |
| downside_deviation_pct_annualized | 8.5891 | 8.6573 | 0.0683 |
| best_day_pct | 2.3592 | 2.3592 | 0.0000 |
| worst_day_pct | -3.5744 | -3.5744 | 0.0000 |
| best_week_pct | 6.0018 | 6.0018 | 0.0000 |
| worst_week_pct | -5.6225 | -5.6225 | 0.0000 |
| best_month_pct | 9.1595 | 8.8764 | -0.2831 |
| worst_month_pct | -5.4995 | -5.4995 | 0.0000 |
| best_quarter_pct | 12.5826 | 13.6726 | 1.0900 |
| worst_quarter_pct | 0.0000 | 0.0000 | 0.0000 |
| best_year_pct | 32.9344 | 34.2215 | 1.2871 |
| worst_year_pct | 0.0000 | 0.0000 | 0.0000 |
| num_trades | 26.0000 | 26.0000 | 0.0000 |
| loss_rate | 80.7692 | 80.7692 | 0.0000 |
| avg_win_dollar | 19051.8610 | 19051.8610 | 0.0000 |
| avg_win_pct | 19.5659 | 19.5659 | 0.0000 |
| avg_loss_dollar | -6135.0417 | -6135.0417 | 0.0000 |
| avg_loss_pct | -6.1200 | -6.1200 | 0.0000 |
| largest_win_dollar | 70683.2200 | 70683.2200 | 0.0000 |
| largest_loss_dollar | -15833.3200 | -15833.3200 | 0.0000 |
| avg_trade_size_dollar | 103818.4138 | 103818.4138 | 0.0000 |
| avg_trade_size_pct | 10.3818 | 10.3818 | 0.0000 |
| avg_holding_days_winners | 137.6000 | 137.6000 | 0.0000 |
| avg_holding_days_losers | 47.1905 | 47.1905 | 0.0000 |
| expectancy | -1291.4065 | -1291.4065 | 0.0000 |
| win_loss_ratio | 3.1054 | 3.1054 | 0.0000 |
| max_consecutive_wins | 2.0000 | 2.0000 | 0.0000 |
| max_consecutive_losses | 11.0000 | 11.0000 | 0.0000 |
| sortino_ratio_annualized | 2.3166 | 2.3837 | 0.0671 |
| mar_ratio | 2.0220 | 2.0971 | 0.0751 |
| omega_ratio | 1.3053 | 1.3120 | 0.0067 |
| avg_drawdown_pct | 3.2994 | 3.3536 | 0.0543 |
| median_drawdown_pct | 1.4529 | 1.7748 | 0.3219 |
| max_drawdown_duration_days | 129.0000 | 129.0000 | 0.0000 |
| avg_drawdown_duration_days | 24.8462 | 24.6154 | -0.2308 |
| time_in_drawdown_pct | 45.5531 | 45.3362 | -0.2169 |
| ulcer_index | 3.4887 | 3.4869 | -0.0018 |
| pain_index | 2.0291 | 2.0291 | -0.0001 |
| underwater_curve_area | 935.4318 | 935.4012 | -0.0306 |
| skewness | -0.3878 | -0.3899 | -0.0021 |
| kurtosis | 2.2252 | 2.1315 | -0.0937 |
| cvar_95 | -2.1330 | -2.1438 | -0.0108 |
| cvar_99 | -2.8595 | -2.8595 | 0.0000 |
| tail_ratio | 0.9037 | 0.9031 | -0.0007 |
| gain_to_pain | 1.3053 | 1.3120 | 0.0067 |
| concavity_coef | 0.0000 | 0.0000 | 0.0000 |
| bucket_asymmetry | 0.0000 | 0.0000 | 0.0000 |

## Scalar diffs

| Field | Delta (variant - baseline) |
|---|---|
| final_portfolio_value | 12870.7200 |
| n_round_trips | 0.0000 |
| n_steps | 0.0000 |

