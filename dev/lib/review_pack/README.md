# review_pack

Helpers for `dev/scripts/review_pack.sh`. POSIX sh + awk + jq; no Python.

| file | runs on | does |
|---|---|---|
| `trade_extract.awk` | host | one trade over its symbol's bar CSV: MFE/MAE, post-exit path + A–F grade, fill-vs-bar checks (split-basis aware), 8-week pick return, stop-breach lag, hard-stop replays, MTM exposure rows, daily chart bars |
| `periods.awk` | host | year or quarter table: return vs SPY, drawdowns, invested %, trades, realised P&L, macro weeks |
| `assemble.awk` | host | joins trades.csv + extraction + audit + macro + stage replay into `<run>_trades.json` |
| `meta.sh` | host | summary metrics, overrides, validator checks, audit conformance → `<run>_meta.json` |
| `stage_sum.sh` | host | stage replay CSVs → stage at entry/exit, Stage 3/4 weeks held |
| `chart_shards.awk` | host | per-trade weekly stage + daily bars, sharded by entry year |
| `stages.sh` | trading-1-dev | `stage_chart.exe` per trade (weekly stage replay) |
| `index.html` | browser | the page; reads `data/manifest.json` and the per-run files |

The A–F grade is hindsight (it reads the 65 trading days after the exit); the
rubric is the 2026-09-04 yearly review's
(`dev/experiments/yearly-trade-review-2026-09-04/grade.sh`).
