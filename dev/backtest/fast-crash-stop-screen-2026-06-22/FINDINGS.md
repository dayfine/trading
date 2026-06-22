# Fast-crash absolute stop — screen FINDINGS (2026-06-22)

Read-only screen of the Build-2 mechanism (`stops_config.catastrophic_stop_pct`,
armed on `Fast_v`; merged #1695, default-off). Question: does the absolute stop
cut the 2020 fast-V drawdown without taxing returns elsewhere? Screen-rigor per
`.claude/rules/mechanism-validation-rigor.md`.

Scenarios: `trading/test_data/backtest_scenarios/experiments/fast-crash-stop-screen-2026-06-22/`
(cat-00/08/10/12) on `universes/fast-crash-screen.sexp` (27 continuing-listing
names), CSV mode, 2019-2021 (spans the 2020-V). Baseline-vs-{0.08,0.10,0.12}.

## Headline — the stop NEVER FIRED (all variants byte-identical)

| catastrophic_stop_pct | total return | window MaxDD | Sharpe | Calmar | trades | 2020-Q1 long exits |
|---|---|---|---|---|---|---|
| 0.00 (baseline) | 18.50% | 15.27% | 0.534 | 0.381 | 33 | Feb 28 – Mar 13, all `stop_loss` |
| 0.08 | 18.50% | 15.27% | 0.534 | 0.381 | 33 | identical |
| 0.10 | 18.50% | 15.27% | 0.534 | 0.381 | 33 | identical |
| 0.12 | 18.50% | 15.27% | 0.534 | 0.381 | 33 | identical |

`trades.csv` md5 identical across all four. The catastrophic stop never bit.

## Verdict: NEEDS-DIFFERENT-TEST-DESIGN
Not "no-benefit," not "promising" — the test **cannot exercise the mechanism**, so
the 2020-DD-cut hypothesis is neither confirmed nor refuted. The mechanism stays
default-off + an axis (no promote, no reject).

## The WHY (the transferable deliverable)

1. **Structural gap-down stops exit first and faster.** Every 2020 crash-window
   long exited on `stop_loss` (gap-down) **Feb 28 – Mar 13** (e.g. MCD/META Feb 28,
   V Feb 29, GOOGL Mar 13 last out). Zero positions held past mid-March.
2. **`Fast_v` cannot arm until the MA turns down — mid-March, too late.**
   `Decline_character.classify` returns `Fast_v` only with the index *below a
   falling MA* + 4wk drawdown >8%. After the 2019 bull the 30-week MA was still
   **rising** through late Feb; macro went `Bullish`→`Neutral` (02-28)→`Bearish`
   (03-06). By the time `Fast_v` could arm (~mid-March) there was **no long left**.
3. **The two stops never compete.** The arming gate (`Fast_v`, needs a confirmed
   falling MA) is structurally **slower** than the gap-down trigger it was meant to
   pre-empt. **The binding constraint is arming LATENCY, not stop width.**
4. **The motivating -38% DD did not reproduce here** — this survivor-biased 27-name
   universe peaked→troughed only -13.8% (struct stops exited early, clean). The
   -38% came from a broad PIT universe holding laggard/thinner names INTO the bottom
   — exactly the longs that could still be open when `Fast_v` finally arms.

## Inert-elsewhere check
Trivially PASS (inert everywhere, return == baseline) — but **vacuous**: inert
because it never fired at all, not because it fired only in the crash.

## Forward guidance (capitalize the finding)
- **The lever is the ARMING SPEED, not `catastrophic_stop_pct`.** The `Fast_v`
  falling-MA precondition lags the price crash ~3 weeks. To pre-empt a gap-down
  structural exit, the fast-V path likely needs to arm on **rate-of-decline alone**
  (drop the falling-MA requirement for `Fast_v`). This is a `Decline_character`
  threshold/config question — re-open there, NOT on `catastrophic_stop_pct`.
- **Re-run on a broad PIT universe (top-500/1000, 2019-2021)** — the longs that ride
  to the bottom (where the absolute stop could bite) live there, not in survivors.
  Needs a snapshot-warehouse rebuild (`build_scenario_snapshots`, ~26 min).
- **Paired 2×2** (structural-loose × {cat-off, cat-on}): loosen `min_correction_pct`
  so the structural stop doesn't gap longs out by Mar 13, isolating whether the
  catastrophic stop then bites.

## Caveats / infra
- Survivor-biased universe (27 continuing names) is biased AGAINST finding a benefit.
- No bars on disk at start (store cleaned); 42 symbols fetched fresh from EODHD for
  the run. (Note: the run's `inventory.sexp` rebuild was reverted — it had shrunk the
  full inventory to only the fetched symbols.)
