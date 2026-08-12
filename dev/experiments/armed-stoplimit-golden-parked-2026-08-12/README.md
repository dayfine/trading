# Armed-StopLimit golden — written, validated, PARKED

This is the golden that closes the structural hole named in
`dev/notes/next-session-priorities-2026-08-11.md` P0: **no golden arms the
StopLimit entry family**, so the regime that F2 / F3 / F5 and the sim-entry fill
model are all scoped to had no coverage at all, and a real defect hid there for
as long as the hole existed.

It is written and it PASSes. It is **not landed**, for one reason: the regime it
covers is still nondeterministic after PR #2279, so its bands cannot be pinned.
See `dev/notes/residual-nondeterminism-2026-08-12.md` — same binary, same spec,
same env, back to back: 112.755 / 241 trades vs 112.670 / 240.

Pinning bands on a moving number would either be so wide the golden catches
nothing, or so tight it fails on the first postsubmit run for the wrong reason.
Neither is a gate.

## Land it as soon as the residual source is fixed

The measured values under `TRADING_DATA_DIR=<repo>/trading/test_data` (CI's
committed bars) cluster around:

```
total_return_pct ~112.3-112.8   total_trades 240-241
win_rate ~37.9-38.1             sharpe_ratio ~1.10
max_drawdown_pct ~16.6-17.0     avg_holding_days ~45.4
```

Once runs are reproducible, take one measurement, pin it, and tighten the bands
— the file already carries ±10% bands and a comment explaining why they are
tighter than the ±15% house default, and why widening them on a failure would be
the wrong response.

Destination: `trading/test_data/backtest_scenarios/goldens-sp500/`, which
`golden_sp500_postsubmit.sh` runs on every push to main via the `;; perf-tier: 3`
tag already in the header.

## Validation already done

Run under CI's data path against its own bands: **PASS** (114.5% / 239 in the
first measurement, inside the ±10% bands — that spread across runs is the very
problem parking it).
