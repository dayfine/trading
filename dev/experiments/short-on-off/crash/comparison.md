# Backtest comparison

- Date range: 2020-01-02 .. 2020-06-30
- Universe size: 491 (baseline) / 491 (variant)
- Initial cash: $1000000.00
- Final portfolio value: $870859.99 (baseline) / $876956.45 (variant), delta = $6096.46
- Round-trips: 21 (baseline) / 16 (variant), delta = -5

## Metric diffs

| Metric | Baseline | Variant | Delta |
|---|---|---|---|
| total_pnl | -181117.1000 | -131847.0800 | 49270.0200 |
| avg_holding_days | 21.9524 | 25.2500 | 3.2976 |
| win_count | 0.0000 | 0.0000 | 0.0000 |
| loss_count | 21.0000 | 16.0000 | -5.0000 |
| win_rate | 0.0000 | 0.0000 | 0.0000 |
| sharpe_ratio | -1.0315 | -1.1198 | -0.0883 |
| max_drawdown | 22.7144 | 20.2738 | -2.4406 |
| profit_factor | 0.0000 | 0.0000 | 0.0000 |
| cagr | -24.4655 | -23.3887 | 1.0768 |
| calmar_ratio | -1.0771 | -1.1536 | -0.0765 |
| open_position_count | 8.0000 | 8.0000 | 0.0000 |
| open_positions_value | 811472.7300 | 872903.7300 | 61431.0000 |
| unrealized_pnl | 52770.2650 | 9387.2050 | -43383.0600 |
| trade_frequency | 3.9026 | 3.1221 | -0.7805 |
| total_return_pct | -12.9140 | -12.3044 | 0.6096 |
| volatility_pct_annualized | 14.9160 | 13.3002 | -1.6158 |
| downside_deviation_pct_annualized | 11.4806 | 10.6479 | -0.8327 |
| best_day_pct | 3.6029 | 3.0646 | -0.5383 |
| worst_day_pct | -5.5235 | -5.5235 | 0.0000 |
| best_week_pct | 5.8550 | 4.2582 | -1.5968 |
| worst_week_pct | -9.9605 | -9.9605 | 0.0000 |
| best_month_pct | 0.4188 | 1.5135 | 1.0947 |
| worst_month_pct | -6.7532 | -5.7127 | 1.0405 |
| best_quarter_pct | 0.0000 | 0.0000 | 0.0000 |
| worst_quarter_pct | -10.8605 | -9.8658 | 0.9946 |
| best_year_pct | 0.0000 | 0.0000 | 0.0000 |
| worst_year_pct | -12.9140 | -12.3044 | 0.6096 |
| num_trades | 21.0000 | 16.0000 | -5.0000 |
| loss_rate | 100.0000 | 100.0000 | 0.0000 |
| avg_win_dollar | 0.0000 | 0.0000 | 0.0000 |
| avg_win_pct | 0.0000 | 0.0000 | 0.0000 |
| avg_loss_dollar | -8624.6238 | -8240.4425 | 384.1813 |
| avg_loss_pct | -7.1010 | -5.8157 | 1.2852 |
| largest_win_dollar | 0.0000 | 0.0000 | 0.0000 |
| largest_loss_dollar | -22157.4500 | -22157.4500 | 0.0000 |
| avg_trade_size_dollar | 154813.6386 | 174267.7350 | 19454.0964 |
| avg_trade_size_pct | 15.4814 | 17.4268 | 1.9454 |
| avg_holding_days_winners | 0.0000 | 0.0000 | 0.0000 |
| avg_holding_days_losers | 21.9524 | 25.2500 | 3.2976 |
| expectancy | -8624.6238 | -8240.4425 | 384.1813 |
| win_loss_ratio | 0.0000 | 0.0000 | 0.0000 |
| max_consecutive_wins | 0.0000 | 0.0000 | 0.0000 |
| max_consecutive_losses | 21.0000 | 16.0000 | -5.0000 |
| sortino_ratio_annualized | -1.0580 | -1.0867 | -0.0287 |
| mar_ratio | -0.5347 | -0.5707 | -0.0360 |
| omega_ratio | 0.8311 | 0.8130 | -0.0181 |
| avg_drawdown_pct | 3.4318 | 3.1267 | -0.3051 |
| median_drawdown_pct | 0.5146 | 0.5146 | 0.0000 |
| max_drawdown_duration_days | 131.0000 | 131.0000 | 0.0000 |
| avg_drawdown_duration_days | 21.3750 | 21.3750 | 0.0000 |
| time_in_drawdown_pct | 32.3353 | 32.3353 | 0.0000 |
| ulcer_index | 9.0650 | 8.1497 | -0.9153 |
| pain_index | 4.5999 | 4.1746 | -0.4253 |
| underwater_curve_area | 1536.3734 | 1394.3168 | -142.0567 |
| skewness | -1.4022 | -2.2236 | -0.8214 |
| kurtosis | 9.7179 | 13.8050 | 4.0872 |
| cvar_95 | -3.0539 | -2.7418 | 0.3121 |
| cvar_99 | -4.9037 | -4.8715 | 0.0322 |
| tail_ratio | 0.7200 | 0.6461 | -0.0740 |
| gain_to_pain | 0.8311 | 0.8130 | -0.0181 |
| concavity_coef | 0.0000 | 0.0000 | 0.0000 |
| bucket_asymmetry | 0.0000 | 0.0000 | 0.0000 |

## Scalar diffs

| Field | Delta (variant - baseline) |
|---|---|
| final_portfolio_value | 6096.4600 |
| n_round_trips | -5.0000 |
| n_steps | 0.0000 |

