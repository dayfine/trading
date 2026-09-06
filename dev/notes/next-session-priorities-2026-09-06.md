# Next-session priorities — 2026-09-06 (decided with the user, evening of 2026-09-05)

Supersedes `next-session-priorities-2026-09-05.md` (its P0 items are done; its "P0 (new)"
list and "Stop surface" section are folded into the sequence below). Everything from
2026-09-04/05 is merged; zero open PRs; origin holds only `main`.

## The decided sequence (user direction 2026-09-05: "improve the macro gate, then size the stop buffer based on macro")

The stop surface (`dev/experiments/stop-width-cadence-surface-2026-09-05/`) found a large,
robust return lever — a 12% fallback stop with the trail raised weekly clears the
pre-registered bar on both 5y windows at 3 salts and at 26y (761% / maxDD 29.7 vs the
record's 303% / 36.3) — and also showed WHY it cannot be flipped as a constant: the 14%
arm's crash-week losses landed under Bullish/Neutral labels because the trend gate never
turned in 2020, and the 27-year breadth study found that entries made while breadth is
DETERIORATING lose in both books (−$604k record / −$668k arm) while RECOVERING-breadth
entries are the best in the run (+$627k / +$1.81M). So the width must be sized by a macro
state that can see a fast crash, and the state has to exist first. Order:

### 1. #2672 — delisting stub prints (data honesty; every later number inherits it)

Two sub-cases, both visible in the store:
- **Penny-print tail** (STMP 2021): after the cash deal the feed kept real OTC bars at
  $0.025–0.03 and the simulator stopped out into them (−$594k in the record, −$624k in the
  12%-weekly 26y arm). Fix: a series-tail guard — when a symbol's closes collapse below a
  few percent of the prior close at the END of its series (V15's shape, #2649), close the
  position at the last real print and tag the exit `delisted`.
- **Stale-bar entry** (DTV 2020): the store's last DTV bar is 2019-09-30, yet the 14%
  arm ENTERED it on 2020-03-28 at that retained price and valued it at 0.00 at the window
  end. Fix: refuse entries past a symbol's `active_through` (the marker already exists —
  `Snapshot_callbacks.active_through_for`, `Daily_panels.active_through_for`), and close any
  open position at its last real bar when the series ends.
Size: one feat-agent PR (entry guard + one exit-fill branch + tests, ~300–500 lines),
then the paired 26y record re-run (old vs fixed, ~3 h each on the 2000-vintage warehouse)
and a record re-base; CLE 2014 (−$147k) and every wide-stop arm move too. Sequence:
`feat-backtest` or `feat-weinstein` dispatch → full gates → re-run → docs re-base.

### 2. Macro gate gains breadth DIRECTION (a five-state read, default-off axis)

Today's gate emits Bullish / Neutral / Bearish from the index trend; it read Bullish to
2020-03-06 and Neutral through May, never Bearish. The composite already computes A-D,
new-highs/new-lows and percent-above-MA (`Macro_indicators`); what it lacks is direction.
Build: a state machine in `Macro` that emits `Bullish | Neutral | Deteriorating |
Recovering | Bearish`, where Deteriorating = percent-above-150d-MA below a threshold AND
falling over a lookback (or new-lows % above a threshold and rising), Recovering = below
the threshold and rising. First thresholds from the 27y study (`/tmp/yr-run` scripts,
committed under `dev/experiments/yearly-trade-review-2026-09-04/`; the breadth series is
regenerable): 45% above-MA, 5 points over 20 trading days, 8% new lows. Every threshold a
config field; default = the current three-state behaviour (R1); the new states are
axes (R2). Existing consumers keep reading the three-state projection until a surface
says otherwise. Test: the state series for 2020 must go Deteriorating by 2020-02-28 and
Recovering by mid-April; 2007–08 must read Bearish as today.

### 3. Per-state stop width in the stops config (default-off, one read site)

`initial_stop_buffer` becomes a map over the five macro states (default: the current
single value in every slot, so a no-op until set — R1). The fallback-stop builder reads
the state at entry (the trend is already in scope there: `Cascade_trace` carries
`macro_trend`, `Audit_recorder` records it at exit). First map to test, from the surface:
Bullish / Recovering → 12% (`0.9167`), Neutral → 8–10%, Deteriorating / Bearish → the
book's 4–6% band (`1.0`) or no new entries (that half belongs to admission, item 2).
Keep `stop_update_cadence Weekly` as a separate knob (the trigger is intraday in both
cadences; Weekly only raises the trail once a week — level effect, see the surface's
§Correction and `weinstein-book-reference.md` §5.7).

### 4. One combined surface, then the promotion decision

Cells: 2019–23 on the 2019-vintage warehouse, 2000–04 on the 2000-vintage warehouse,
salts 0–2, plus 26y; comparator = the fixed record AND the 12%-weekly-update arm.
Pre-registered rule as in the stop surface (equity ≥ comparator, maxDD ≤ comparator +
5pp, ex-monster, ≥ 2/3 salts on both windows, 26y maxDD not worse). Owed before any flip
of the stop pair regardless: the missing `sw26y-w12-D` arm (cadence vs width at 26y),
a dissection of the 26y drawdown window (crash-window stop-outs were 19 vs 19, so the
−6.5pp is not "fewer stop-outs"), a ledger entry, and paired goldens for every knob that
moves (`config-default-blast-radius.md`). Book-faithfulness for the writeup: the width is
a trader-mode dial under §5.1's 15% ceiling; the breadth state is the A-D chapter's own
instrument used as a state filter; the weekly trail update is Ch. 6's cadence.

## Standing results to diff against (all on the fixed basis)

- Record: 302.65% / 723 / Sharpe 0.40 / maxDD 36.26 (`record-rebase-2026-09-03`), with
  ~$741k of phantom stub-print loss inside it (#2672).
- 12%-weekly-update 26y arm: 761.20% / 862 / 0.58 / 29.73 (`sw26y-w12-W-s0`).
- 2019–23 record-convention null on the 2019-vintage warehouse: 16.8% / 179 / maxDD 22.0.
- Yearly review: 162 A-trades = +$9.05M; 552 B/C/D/F = −$6.36M; rotation exits 55% A,
  stop exits 31% whipsaw; RS at year start has no cross-sectional power; the record caught
  2.5% of the tradeable sector top-5 winners.

## P1 — carried

- Vintage warehouse gap fetch (~700 delisted names per vintage via EODHD; then
  `-incremental` is NOT the way to top up — #2669 — rebuild over a superset universe).
- Funnel admission surface (breakout gate, top-N) — after item 4; the 2.5% catch rate is
  the number to move, and the tradeable overlap (23% of recent winners in the record's
  2000 universe) says the warehouses matter as much as the gate.
- #2650 (tier-2/4 goldens in `goldens_affected_check.sh`; `perf-nightly` continue-on-error).
- F4 on #2675: one extra Tier-1 fixture row so the Tier 2/4 rule is distinguishable from
  its inverse.

## Ops notes (new this session)

- Kill container orphans by PID: `pkill -f "dune build"` matches its own shell first.
- `gh pr merge --admin --delete-branch` on the jj-colocated checkout fails the local step
  and skips the remote delete — delete the branch explicitly after `MERGED`, and never
  chain a `--delete` after a merge command that may have failed (a deleted head branch
  auto-closes an open PR; recovered once via `refs/pull/N/head`).
- Feat-agent stall mode confirmed twice: a backgrounded `dune build` re-wakes the agent
  forever; finish from the dispatcher (scoped verification → commit → push → body) and
  `TaskStop` it.
- Chain waiters must wait BEFORE taking the flock (`chain-v3.sh` pattern), or they abort
  on the running chain's lock.
- `dune runtest devtools` in a fresh worktree may end on the pre-existing
  `/tmp/.../sexp_drift_walk_test_root/unreadable` permission artifact; every check line
  before it is the signal.

## Do not

- Do not flip `initial_stop_buffer`, `stop_update_cadence` or any macro threshold on the
  evidence so far; the sequence above is the path, and #2672 comes first.
- Do not describe the Weekly cadence as weekly-close evaluation.
- Do not quote the 14%-daily 26y return without its maxDD (40.4 vs 36.3 — it fails the bar).
