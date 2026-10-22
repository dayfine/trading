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
| `career_scorecard.js` | browser | eight run-level diagnostic dimensions from published pack evidence; inlined into the built page so file-based renders need no extra asset |
| `faithfulness.{sh,jq}` | host | existing assembled trades JSON → weighted, coverage-aware long-trade checks and detectors in `<run>_faithfulness.json` |
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

## P&L anatomy (#3140, item 3)

`pnl_anatomy.sh` reads each staged run's `trades.csv`, `equity_curve.csv` and
the pack's existing `x_trades.tsv` continuation extraction. It publishes
`<run>_anatomy.json`; the Diagnostics card selects any run and shows each entry
year plus All. The earlier chart-run-only browser calculations are replaced by
this shared host calculation.

N counts closed trades. A winner has positive dollar P&L, a loss has negative
dollar P&L, and a breakeven contributes to N and expectancy but not to the win
or loss samples. Returns are the CSV's side-signed percentages; average loss
is shown as a positive magnitude. Expectancy is the mean signed return,
equivalent to win probability × average win minus loss probability × average
loss. Entry weight is entry notional / the last NAV on or before entry; relative
P&L is the sum of each trade's P&L / that entry NAV. Missing required values
make the affected metric null, rendered `n/a`, rather than dropping trades.

Top-5/10/20 share ranks signed dollar P&L and divides each top-k sum by net
realised P&L (undefined at zero net; above 100% and negative shares are valid).
Hill alpha uses winners and absolute losses separately: k=floor(n/10),
alpha=k/sum(log(x_i/x_(k+1))) over descending positive values. Fewer than ten
observations or a zero log sum gives `n/a`.

Hindsight counts use the existing 65-bar extraction window starting at the
first bar on or after exit (its closing price is the reference). Each relevant
trade needs that full window. Whipsaw is a losing trade followed by at least +15% in its favour;
good stop is a losing stop followed by at most -5% at bar 65; rotation regret
is a laggard exit followed by at least +15% in its favour. The existing
extraction already signs these returns for shorts. Whipsaw and regret can
overlap. If any relevant path is missing or truncated, that category is
`n/a`; the card also shows how many full continuations exist. No raw-data
rescan or new container replay is introduced.

The small `fixtures/review_pack/pnl_anatomy/` run and arithmetic comments in
`review_pack_test.sh` independently pin the year, whole-run and second-salt
values, concentration, tail indices, hindsight boundaries and missing-input
behaviour. Faithfulness is outside this slice.


## Faithfulness (#3140, item 2 slice 1; partial evidence)

`faithfulness.sh` reads only the existing `<run>_trades.json`; no new inputs,
container step or join changes. The 13-rule table at the top of
`faithfulness.jq` holds weights, book sections and evidence notes. Checks
1/3/7/11/13 weigh 2, the rest 1 (total 18). Known passes / known weight gives
the score: A ≥90%, B ≥80%, C ≥70%, D ≥60%, F below 60%; no known weight gives
`n/a`. Every row shows scored weight out of 18, all statuses and failed checks.
The grade describes observed evidence, not overall faithfulness. It is separate
from the hindsight performance grade. This is the requested long-trade rubric;
short/unknown-side rows are entirely `n/a` rather than penalising valid shorts.

The tab shows counts per run, ranked failed checks and sortable trade rows
(worst score first, unknown scores last). Missing files render `n/a`, preserving
old packs. Screen volume uses `vr`; fill volume uses `fvr`. RS reads the audit's
positive/negative labels (a bullish crossover is positive). Macro reads `mE`,
the fill's last preceding screen, not decision-time `aMacro`. Stop provenance
reads `sfk`, and installed width reads `isd`, never the screening proxy `sid`.
Any Stage-4 replay week fails check 13; zero needs a nonempty replay hold.
Reported `stop_loss` (§5.7) and `stage3_force_exit` (§1 Stage 3) pass check 12.
Involuntary `force_liquidation`, `margin_call` and `delisted` exits fail it.
`extension_stop`, `liquidity_exit` and `stale_force_exit` remain `n/a` without
a book rationale; laggard rotation needs unavailable exit-time weakness evidence.

**Input-contract blocker, reported on #3140:** assembled data omits MA slopes,
pre-entry history length, pullback/peak-volume context, actual overhead grade,
sector decision, designed order type/limit and exit-time weakness. Therefore:

- Checks 2/6/8 are always `n/a`. `aGrade` is the cascade grade, not resistance.
- Check 1 can fail on a non-Stage-2 replay, but Stage 2 alone cannot prove a
  rising MA (the classifier can retain the prior stage under mixed signals).
- Check 4 passes at fill volume ≥2; lower volume is `n/a` because it might be a
  quiet pullback. The tab shows <1, 1–<2, ≥2 ratio bins and unknown coverage;
  the overview flags measured ratios under 2 as an observation, not a failure.
- Check 9 can fail below the trigger or on an audited unfaithful fill. A
  positive `fvt` plus `faithful=false` proves "filled from above" (above the
  limit); a positive faithful fill is unknown because Market orders also
  report faithful=true. `fvt` must exist, since the legacy join maps absent
  execution faithfulness to false. A rounded zero fill-vs-trigger cannot rule
  out a small upper-limit breach. The join itself stays unchanged.
- "Sold a healthy Stage-2 stock" needs exit MA slope. Stop exits and non-Stage-2
  replays rule it out; remaining cases stay unknown. No healthy sale is claimed.
- "SPAC / under 52 weeks" needs history, not ticker identity. The SDA entry
  on 2023-07-12 is a committed specimen that correctly remains unknown.

These unavailable pass/fail paths cannot be tested truthfully without extending
the input contract. Each check has a fixture pinning its observable statuses
and missing-data behaviour; the detector fixture pins distribution, above-limit
proof, false exclusions and the SDA unknown. The PR remains partial. Career
scorecard and container-built R1–R8 stay in slice 2. The 52-week and 15% cutoffs
are pack policies from #3140; citations identify the related book principle,
not numeric rules attributed to the book.


## Career scorecard (#3140, item 2 slice 2)

The Faithfulness tab adds eight rows for the selected run, with score / 100,
a one-line because, book sections and the scoring policy. It shows how many
of eight dimensions have evidence. There is deliberately no overall grade.
`career_scorecard.js` is a pure browser helper, inlined by the existing builder
into `index.html`; the portable render still needs only the page and its data.
It reads published faithfulness, trades, meta and anatomy, plus the page's
existing regime and gate-reopen calculations. No new flag, join or replay.

The formulas below are diagnostic report conventions, not quantitative rules
attributed to Weinstein or a strategy verdict. Citations identify the related
book principles. Each component must have observations before its dimension
can score; unavailable components make the dimension `n/a`. Pass rates pool
only known pass/fail statuses and show their measured denominator. Detector
rates likewise use only observed true/false values. They do not assert that
unmeasured trades passed. Selection can therefore score on partial evidence,
just as slice 1 can; the missing checks are not silently counted as passes.

| Dimension | Score and evidence | Book sections |
|---|---|---|
| Bear defense | Mean of check-7 pass rate and fraction of DOWN calendar years with strategy return ≥ SPY. Each year's strategy/SPY DOWN-day returns print in the because. | §2.1 |
| Selection | Pooled pass rate for checks 1, 5, 6, 8. | §4.1–4.4, §3.1 |
| Volume | Pooled pass rate for checks 3, 4. | §4.2 |
| Stop / risk | Mean of checks 10/11 pass rate and fraction of observed fills not above the limit. Above-limit hits and measured fills print. | §5.1, §4.7 |
| Riding winners | Mean of check-12 pass rate and 100 × payoff/(1+payoff). Anatomy supplies the All-row payoff. The slice-1 healthy-sale detector can never read true, so it is not scored and the because says so; it re-enters the mean when that detector can fire. | §5.2, §5.6 |
| Portfolio construction | 100 × min(1, 10 / average entry weight %). The 10% reference is a reporting policy, not a book allocation rule. All top-5/10/20 P&L shares print as context; there is no concentration penalty for a fat-tail strategy, including shares >100% or negative net-P&L shares. | §5.1 |
| Recovery playbook | Mean of 100 × min(13-week entries / 6, 1) per complete gate-reopen episode. Six is the page's existing "many entries" reference. Each episode's date and count print; no complete episode means n/a. | §2.1, §4.1 |
| Shorts | n/a when meta has no enabled short leg. With reported fills and P&L: 100 for fills with positive P&L, 50 for flat P&L, 0 for losses or a reported zero-fill leg. Counts and dollars print. | §6.1 |

DOWN returns compound the same daily strategy/SPY ratios as the existing era
regime table, grouped by calendar year. Regimes remain lagged weekly MA/slope
readings, warmed up on existing SPY bars. Every run uses its own price/total-
return SPY basis (mixed uses total return, as the page does), not the chart
run's basis. Having no DOWN period yields `n/a`, not a perfect defense score. Recovery
uses existing `reopenEpisodes`, including its complete 26-week outcome window
and side-aware gate for a short-only book; the score uses its 13-week entry
counts. These scores measure observed activity and outcomes, not whether more
exposure would have been desirable in every case.

The career-*.json fixtures independently pin each dimension's arithmetic,
source numbers in the because, a missing component and shorts off. The tests
also pin year-boundary compounding, score bounds, flat/loss/zero-fill shorts,
recovery saturation, selected-run basis and direction, eight-row rendering,
coverage and the helper's inclusion in the built page. Slice 1 checks and
weights remain unchanged. Its unavailable evidence paths and the local
container-built 26-year R1–R8 report remain outside this slice.
