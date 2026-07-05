# Backtest comparison

- Date range: 2023-01-02 .. 2023-12-31
- Universe size: 500 (baseline) / 500 (variant)
- Initial cash: $1000000.00
- Final portfolio value: $1092696.09 (baseline) / $1092696.09 (variant), delta = $0.00
- Round-trips: 31 (baseline) / 31 (variant), delta = 0

## Metric diffs

| Metric | Baseline | Variant | Delta |
|---|---|---|---|
| total_pnl | -130023.8450 | -130023.8450 | 0.0000 |
| avg_holding_days | 45.2581 | 45.2581 | 0.0000 |
| win_count | 5.0000 | 5.0000 | 0.0000 |
| loss_count | 26.0000 | 26.0000 | 0.0000 |
| win_rate | 16.1290 | 16.1290 | 0.0000 |
| sharpe_ratio | 0.5854 | 0.5854 | 0.0000 |
| max_drawdown | 14.5900 | 14.5900 | 0.0000 |
| profit_factor | 0.1471 | 0.1471 | 0.0000 |
| cagr | 9.3297 | 9.3297 | 0.0000 |
| calmar_ratio | 0.6395 | 0.6395 | 0.0000 |
| open_position_count | 7.0000 | 7.0000 | 0.0000 |
| open_positions_value | 967976.3400 | 967976.3400 | 0.0000 |
| unrealized_pnl | 223645.3150 | 223645.3150 | 0.0000 |
| trade_frequency | 3.6655 | 3.6655 | 0.0000 |
| total_return_pct | 9.2696 | 9.2696 | 0.0000 |
| volatility_pct_annualized | 14.4244 | 14.4244 | 0.0000 |
| downside_deviation_pct_annualized | 8.9659 | 8.9659 | 0.0000 |
| best_day_pct | 3.2143 | 3.2143 | 0.0000 |
| worst_day_pct | -3.1952 | -3.1952 | 0.0000 |
| best_week_pct | 7.9364 | 7.9364 | 0.0000 |
| worst_week_pct | -5.8937 | -5.8937 | 0.0000 |
| best_month_pct | 12.4175 | 12.4175 | 0.0000 |
| worst_month_pct | -6.7687 | -6.7687 | 0.0000 |
| best_quarter_pct | 6.4988 | 6.4988 | 0.0000 |
| worst_quarter_pct | -0.2684 | -0.2684 | 0.0000 |
| best_year_pct | 9.2696 | 9.2696 | 0.0000 |
| worst_year_pct | 0.0000 | 0.0000 | 0.0000 |
| num_trades | 31.0000 | 31.0000 | 0.0000 |
| loss_rate | 83.8710 | 83.8710 | 0.0000 |
| avg_win_dollar | 4485.1670 | 4485.1670 | 0.0000 |
| avg_win_pct | 6.0413 | 6.0413 | 0.0000 |
| avg_loss_dollar | -5863.4492 | -5863.4492 | 0.0000 |
| avg_loss_pct | -6.2699 | -6.2699 | 0.0000 |
| largest_win_dollar | 17622.2550 | 17622.2550 | 0.0000 |
| largest_loss_dollar | -15212.8400 | -15212.8400 | 0.0000 |
| avg_trade_size_dollar | 101970.6027 | 101970.6027 | 0.0000 |
| avg_trade_size_pct | 10.1971 | 10.1971 | 0.0000 |
| avg_holding_days_winners | 116.8000 | 116.8000 | 0.0000 |
| avg_holding_days_losers | 31.5000 | 31.5000 | 0.0000 |
| expectancy | -4194.3176 | -4194.3176 | 0.0000 |
| win_loss_ratio | 0.7649 | 0.7649 | 0.0000 |
| max_consecutive_wins | 2.0000 | 2.0000 | 0.0000 |
| max_consecutive_losses | 9.0000 | 9.0000 | 0.0000 |
| sortino_ratio_annualized | 0.6484 | 0.6484 | 0.0000 |
| mar_ratio | 0.3985 | 0.3985 | 0.0000 |
| omega_ratio | 1.0995 | 1.0995 | 0.0000 |
| avg_drawdown_pct | 4.1559 | 4.1559 | 0.0000 |
| median_drawdown_pct | 2.2485 | 2.2485 | 0.0000 |
| max_drawdown_duration_days | 161.0000 | 161.0000 | 0.0000 |
| avg_drawdown_duration_days | 43.6250 | 43.6250 | 0.0000 |
| time_in_drawdown_pct | 59.4937 | 59.4937 | 0.0000 |
| ulcer_index | 5.5272 | 5.5272 | 0.0000 |
| pain_index | 3.8279 | 3.8279 | 0.0000 |
| underwater_curve_area | 1512.0218 | 1512.0218 | 0.0000 |
| skewness | -0.0004 | -0.0004 | 0.0000 |
| kurtosis | 2.2596 | 2.2596 | 0.0000 |
| cvar_95 | -2.2344 | -2.2344 | 0.0000 |
| cvar_99 | -3.0997 | -3.0997 | 0.0000 |
| tail_ratio | 1.0016 | 1.0016 | 0.0000 |
| gain_to_pain | 1.0995 | 1.0995 | 0.0000 |
| concavity_coef | 0.0000 | 0.0000 | 0.0000 |
| bucket_asymmetry | 0.0000 | 0.0000 | 0.0000 |
| benchmark_alpha_pct_annualized | 0.0000 | 0.0000 | 0.0000 |
| benchmark_beta | 0.0000 | 0.0000 | 0.0000 |
| tracking_error_pct_annualized | 0.0000 | 0.0000 | 0.0000 |
| information_ratio | 0.0000 | 0.0000 | 0.0000 |
| correlation_to_benchmark | 0.0000 | 0.0000 | 0.0000 |
| rolling_sharpe_stability | 0.7797 | 0.7797 | 0.0000 |
| trade_frequency_annualized | 19.7605 | 19.7605 | 0.0000 |
| position_turnover | 0.0176 | 0.0176 | 0.0000 |
| position_concentration_hhi | 0.1546 | 0.1546 | 0.0000 |

## Scalar diffs

| Field | Delta (variant - baseline) |
|---|---|
| final_portfolio_value | 0.0000 |
| n_round_trips | 0.0000 |
| n_steps | 0.0000 |

