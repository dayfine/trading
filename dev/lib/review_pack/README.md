# review_pack

Helpers for `dev/scripts/review_pack.sh`. POSIX sh + awk + jq; no Python.

| file | runs on | does |
|---|---|---|
| `trade_extract.awk` | host | one trade over its symbol's bar CSV: MFE/MAE, post-exit path + A–F grade, fill-vs-bar checks (split-basis aware), 8-week pick return, stop-breach lag (raw bars vs the raw stop, moved only by a split by the simulator's rule, Split_detector's defaults: a dividend does not shift it; #3262), hard-stop replays, installed-stop distance, fill-week volume ratio (#3141), MTM exposure rows, daily chart bars. Side-aware: a SHORT row signs every statistic so + is in its favour and breaches its stop on the high (#3149) |
| `open_extract.awk` | host | one position still open at the window end (`open_positions.csv`) over its bar CSV: daily MTM exposure rows through the last day (#3125), the last bar carried onto the last day when the name has no bar there (#3144) |
| `open_json.awk` | host | open positions + their side and entry macro week, and the last-day exposure check vs `actual.sexp` `open_positions_value` (shorts signed negative, as the simulator marks them; #3144) → `<run>_open.json` |
| `periods.awk` | host | year or quarter table: return vs SPY on the run's basis (price or total return, #3177), drawdowns, invested %, trades, realised P&L, macro weeks |
| `assemble.awk` | host | joins trades.csv + extraction + audit + macro + stage replay + the audit's `stop_floor_kind` into `<run>_trades.json`; the macro week of a fill is the last screen strictly before it, V23's rule (#3262) |
| `../../scripts/review_pack.sh` | host | stamps the pack code's commit and the snapshot dir in the manifest for the page header (#3262); also publishes `spy_warmup.json`: the 180 SPY bars before the window, read by the page for the regime only, so the window's first 34 weeks get UP / MIXED / DOWN (#3194) |
| `meta.sh` | host | summary metrics, the return basis (cash yield / dividends -> SPY price, total return or mixed; #3177), overrides, validator checks, audit conformance, and the short leg when params enable it (tickets, fills, short P&L, Bearish weeks and those admitting a short to the top-N; #3111) → `<run>_meta.json` |
| `stage_sum.sh` | host | stage replay CSVs → stage at entry/exit, Stage 2/3/4 weeks held |
| `chart_shards.awk` | host | per-trade weekly stage + daily bars, sharded by entry year |
| `../../scripts/review_pack_render.sh` | host | renders a built site to PNGs (headless Chrome, data inlined behind a fetch shim so `file://` works) for the visual review step, `.claude/rules/backtest-result-review.md`: the whole page at its measured height, cut into 1500 px parts with sips or ImageMagick (#3177); every table box but the per-trade one is unscrolled in the capture (#3262) |
| `stages.sh` | trading-1-dev | `stage_chart.exe` per trade (weekly stage replay), over the bar store the host passes (#3262) |
| `croot.sh` | host | the container path of this checkout: the bind mount plus its path below the mount source, so a worktree builds and runs its own tree (#3262) |
| `pack_sha.sh` | host | `pack_sha REPO`: the pack code's commit, `-dirty` when `dev/lib/review_pack` or `review_pack.sh` differ from it, for the page header (#3262) |
| `index.html` | browser | the page; reads `data/manifest.json` and the per-run files |

The A–F grade is hindsight (it reads the 65 trading days after the exit); the
rubric is the 2026-09-04 yearly review's
(`dev/experiments/yearly-trade-review-2026-09-04/grade.sh`).

## Missed winners (#3140, part 1)

`review_pack.sh` invokes `missed_winners.sh` with the existing `--data-dir` and
staged run. This one builder call extends the hand-off's file scope because
published chart shards contain traded names only: they cannot find an unowned
winner. No snapshot rebuild, container replay or new input flag is needed.
`missed_winners.awk` scans each available symbol with 30 weeks of warm-up; the
run window limits signals and forward returns. `missed_audit.awk` streams the
existing audit's cascade summaries, preserving absent decisions separately from
an explicitly empty decision list (older audits omit this field).

The card covers the available bar store, which can include names outside the
run's historical universe; it is not a PIT-universe reconstruction. Each
qualifying week is an episode. The 26-week high uses adjusted highs; the WMA
has linear weights 1–30; volume compares weekly totals; ADV is the trailing
20 available daily bars' adjusted close times stored volume. The forward peak
is a later weekly close within the window. A daily adjusted-close jump of at
least +50% or -50% breaks a price segment; signals require 30 weeks of history
within one segment and cannot earn a forward return across that break. This
conservative guard can exclude real jumps as well as vendor splices.

The page joins long holdings (including still-open positions) overlapping the
signal-to-peak interval. Rode/partial/cut use the overlapping closed trade's
reported return versus half the episode's forward return; still-open holdings
count as partial. These are hindsight summaries, not a causal capture estimate.
Screen decisions and macro evidence join by the UTC Monday calendar-week key,
including weeks that cross 1 January; a Thursday episode can read its Friday
screen without borrowing evidence from an adjacent week. Miss reasons prefer a
recorded ticket or skip, then the signal week's Bearish
macro, then a fully recorded zero-ticket week or absence from the recorded
screen top-N. The latter does not identify which upstream filter rejected the
name. Missing screening evidence stays unknown. Zero-ticket weeks below 50%
invested require both recorded decisions and a known NAV exposure; 10 in a
year triggers the flag. The card shows the chart run, just like its other
per-trade panels. Faithfulness and P&L anatomy changes remain outside this PR.

Validation uses a small unowned-symbol store fixture and browser-function
checks in `review_pack_test.sh`. The full 26-year store is not present in this
cloud workspace, so that record's counts and runtime remain for local QC.
