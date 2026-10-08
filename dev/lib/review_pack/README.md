# review_pack

Helpers for `dev/scripts/review_pack.sh`. POSIX sh + awk + jq; no Python.

| file | runs on | does |
|---|---|---|
| `trade_extract.awk` | host | one trade over its symbol's bar CSV: MFE/MAE, post-exit path + A–F grade, fill-vs-bar checks (split-basis aware), 8-week pick return, stop-breach lag, hard-stop replays, installed-stop distance, MTM exposure rows, daily chart bars. Side-aware: a SHORT row signs every statistic so + is in its favour and breaches its stop on the high (#3149) |
| `open_extract.awk` | host | one position still open at the window end (`open_positions.csv`) over its bar CSV: daily MTM exposure rows through the last day (#3125), the last bar carried onto the last day when the name has no bar there (#3144) |
| `open_json.awk` | host | open positions + their side and entry macro week, and the last-day exposure check vs `actual.sexp` `open_positions_value` (shorts signed negative, as the simulator marks them; #3144) → `<run>_open.json` |
| `periods.awk` | host | year or quarter table: return vs SPY, drawdowns, invested %, trades, realised P&L, macro weeks |
| `assemble.awk` | host | joins trades.csv + extraction + audit + macro + stage replay + the audit's `stop_floor_kind` into `<run>_trades.json` |
| `meta.sh` | host | summary metrics, overrides, validator checks, audit conformance, and the short leg when params enable it (tickets, fills, short P&L, Bearish weeks and those admitting a short to the top-N; #3111) → `<run>_meta.json` |
| `stage_sum.sh` | host | stage replay CSVs → stage at entry/exit, Stage 2/3/4 weeks held |
| `chart_shards.awk` | host | per-trade weekly stage + daily bars, sharded by entry year |
| `../../scripts/review_pack_render.sh` | host | renders a built site to PNGs (headless Chrome, data inlined behind a fetch shim so `file://` works) for the visual review step, `.claude/rules/backtest-result-review.md` |
| `stages.sh` | trading-1-dev | `stage_chart.exe` per trade (weekly stage replay) |
| `index.html` | browser | the page; reads `data/manifest.json` and the per-run files |

The A–F grade is hindsight (it reads the 65 trading days after the exit); the
rubric is the 2026-09-04 yearly review's
(`dev/experiments/yearly-trade-review-2026-09-04/grade.sh`).
