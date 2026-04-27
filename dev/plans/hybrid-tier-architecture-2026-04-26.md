# Plan: hybrid-tier architecture for tier-4 release-gate (2026-04-26)

## Status

PROPOSED. Triggered by the post-Stage-4.5 RSS matrix
(`dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md`):
even with GC tuning, the per-symbol cost is **β ≈ 4.3 MB**, and
the 8 GB tier-4 ceiling is exceeded at any N ≳ 1,500.

The original Tiered loader (deleted in Stage 3 PR 3.3, #573) was a
3-level hashtable cache (Metadata / Summary / Full) with a Friday
promote cycle. It got deleted because the implementation was
~95% RSS-overhead vs Legacy — bookkeeping costs swamped the win.
Panel mode (Stage 4) replaced it with a single uniformly-cheap
Bigarray storage layer.

**This plan adds tiering back** — but as a property of the *strategy
working set*, not the data layer. Panels stay; the strategy holds
hot vs cold per-symbol state separately. Hot symbols get the full
working set (callbacks, indicator caches, position state, trade
history); cold symbols get only enough state to decide whether to
promote them next Friday.

## The wedge

Per `dev/notes/panels-memtrace-postA-2026-04-26.md`, the residual
~5 MB / loaded symbol lives in OCaml-heap structures that are
proportional to *loaded* universe, not screening *survivors*:

1. **`Trading_simulation_data__Price_cache.by_date` Hashtbl** —
   per-symbol date→price index; ~1500 entries × ~80 bytes per
   bucket = ~120 KB / symbol.
2. **`Trading_engine__Price_path._sample_*` working buffers** —
   4 KB per allocation; per-day-per-symbol churn that promotes
   into major heap before GC reclaims.
3. **`Stop_log` / `Trading_state` per-position records** — only
   for held positions, but accumulates across the run.
4. **Per-symbol stage classification state** (`prior_stages`
   Hashtbl) — small but every loaded symbol has an entry.
5. **Position / order / portfolio scalar state** — bounded by
   active positions but each one carries trade history.

Items 1, 2, 4 scale with **loaded** N and dominate at scale. Items 3
and 5 scale with **traded** N (held positions) and are small.

Observation: most symbols at most times are uninteresting — Stage 1
(early base) or Stage 4 with no setup. They cost ~5 MB each but
contribute zero candidate flow to the screener.

## Goal

Drop β from ~4.3 MB / loaded symbol to ~0.5 MB for cold symbols
while keeping ~5 MB for hot symbols. At 10% hot rate (typical for a
broad universe in mixed regimes):

`RSS(N) ≈ 68 + 0.5·N_cold + 5·N_hot + 0.2·N·(T−1)`
       ≈ `68 + 0.5·(0.9·N) + 5·(0.1·N) + 0.2·N·(T−1)`
       ≈ `68 + 0.95·N + 0.2·N·(T−1)` MB

At N=10,000 × T=10y: 68 + 9,500 + 18,000 = **27.6 GB**. Still over
8 GB. Need ~5% hot rate (~500 hot symbols at N=10K) to fit:

`RSS ≈ 68 + 0.5·(0.95·N) + 5·(0.05·N) + 0.2·N·(T−1)`
     ≈ `68 + 0.725·N + 0.2·N·(T−1)`

At N=10,000 × T=10y: 68 + 7,250 + 18,000 = **25 GB**. Still over.

`γ` (per-symbol-per-year) is the binding constraint at long T.
Reducing it requires **per-symbol streaming** — drop accumulated
state for cold symbols periodically (e.g. demote back to "untouched"
state every quarter). That's beyond this plan's scope.

**Realistic target with hybrid tier**: tier-4 release-gate at
**N=5,000 × T=10y** fits 8 GB if hot rate ≤ 20% AND the γ component
is held to ~0.1 (cold symbols accumulate no state).

`RSS(5000, 10) ≈ 68 + 0.5·4000 + 5·1000 + 0.1·5000·9 = 68 + 2,000 + 5,000 + 4,500 = 11.6 GB`

Still over. Need γ → 0 for cold symbols (no per-year accumulation
at all). Achievable by dropping `Stop_log` / `Trace` entries for
cold symbols (they have no positions / no per-tick events anyway).

**Pessimistic (cold has γ=0)**: 68 + 2,000 + 5,000 + 0.2·1000·9 =
**8.9 GB**. Marginal but achievable with careful hygiene.

The plan is therefore **N=5,000 × T=10y with hybrid tier + γ=0 for
cold = ~9 GB**. Either the ceiling moves to ~10 GB or we run on a
narrower universe.

## Architecture

### Tier definitions

| Tier | What's resident | Promotion criterion |
|---|---|---|
| **Cold** | Symbol + sector + last close + last stage | Default for all loaded symbols at startup. |
| **Warm** | Cold + recent N weeks of OHLCV + Stage MA cache | Stage 1 with developing base, OR Stage 3. Promoted from Cold on Friday tick when stage classifier indicates a "watch" candidate. |
| **Hot** | Full panel row (5y of OHLCV) + full indicator caches + screener bundle | Stage 2 in active sector, OR Stage 4 in active sector. Promoted from Warm when the symbol passes the screener cascade. |

Demotion: every Friday after the screen, walk Hot symbols;
demote to Warm if no longer Stage 2/4 in active sector AND no held
position. Walk Warm; demote to Cold if no longer in "watch" state
AND no held position.

A held position pins the symbol at Hot regardless of stage (the
stop machine + position state needs the bar history).

### Data structure

**Bar_panels** stays as the hot-tier storage; Bigarray rows are
allocated only for Hot symbols. Cold and Warm symbols don't have a
panel row.

New `Tiered_panels.t`:

```ocaml
type tier = Cold | Warm | Hot

type cold_state = {
  symbol : string;
  sector : string;
  last_close : float;        (* updated in place per tick *)
  last_stage : Stage.stage;  (* updated weekly *)
  last_stage_date : Date.t;
}

type warm_state = {
  cold : cold_state;
  recent_weekly : float array;   (* last ~30 weeks of closes *)
  recent_dates : Date.t array;
  ma_30w_cache : float;          (* current MA value, scalar *)
}

type hot_state = {
  warm : warm_state;
  panel_row : int;               (* index into Bar_panels *)
  callbacks : Panel_callbacks.t; (* full callback bundle *)
  position : Trading_state.position option;
  stop_log_entries : Stop_log.entry list;
}

type t = {
  symbols : (string, tier_state) Hashtbl.t;
  hot_pool : Bar_panels.t;       (* sized to max_hot_count, not max_loaded *)
  ...
}

and tier_state =
  | Cold of cold_state
  | Warm of warm_state
  | Hot of hot_state
```

The `Bar_panels.t` is sized to the **expected max hot count** (e.g.
N_loaded × 0.2), not N_loaded. The panel row index pool is freed on
demotion and reused.

### Promotion / demotion flow

Per Friday tick:

1. **Walk Cold symbols**: read latest OHLCV from CSV (incremental),
   update `last_close` in place. Run cheap `Stage.classify_metadata`
   (a coarse classifier that uses just `last_close` + `last_stage_date`
   age — ballpark stage estimate). If output is "promote candidate",
   move to Warm.
2. **Walk Warm symbols**: update `recent_weekly` (drop oldest week,
   append new). Run full `Stage.classify_with_callbacks` over the
   30-week buffer. Run sector check. If passes, promote to Hot.
   If fails for 4+ weeks, demote to Cold.
3. **Walk Hot symbols**: full `Stock_analysis.analyze_with_callbacks`
   (current Stage 4.5 PR-A behavior). After screening, demote to
   Warm if not held + not in active stage anymore.

The screener cascade now applies to **Hot symbols only** — that's
the natural surviving set. PR-A and PR-B's filters become a no-op
in the hot loop (everything in Hot already passes).

### Cold-tier streaming: the γ collapse

For Cold symbols:
- No `Stop_log` entries (no positions).
- No `Trace` events per tick (the orchestrator only traces phase
  transitions, not per-symbol-per-tick).
- No `prior_stages` Hashtbl entry (the tier state itself has the
  stage).
- CSV reads are streaming: open file, seek to recent rows, read N
  lines, close. No `Hashtbl<symbol, Daily_price.t list>` cache.

This drops γ to ~0 for Cold symbols. Hot symbols retain the
existing γ ~0.2 MB/symbol/year.

### Memory math (revisited)

| Component | Per-symbol cost |
|---|---:|
| Cold: symbol + sector + last_close + last_stage + last_stage_date | ~80 bytes |
| Cold: streaming CSV reader (per access) | ~4 KB transient |
| Warm: 30 weeks of weekly closes + dates + MA scalar | ~600 bytes |
| Warm: backfill OHLCV from CSV (per promotion) | ~50 KB transient |
| Hot: panel row (5 OHLCV × T_max days × 8) | ~96 KB at T=2520 |
| Hot: indicator caches (4 indicators × T × 8) | ~80 KB at T=2520 |
| Hot: Stop_log + position + callbacks closures | ~few KB |

Hot symbols cost ~200 KB resident (vs measured ~4.3 MB today —
the difference is the OCaml-heap working set: short-lived
`Daily_price.t list` allocations promoted to major heap, etc).
Even with conservative hot-cost = 1 MB / symbol:

`RSS(5000, 10) ≈ 68 + 0.005·N_cold + 1·N_hot + γ_hot·N_hot·T`

At 10% hot rate: 68 + 22 + 500 + 0.2·500·9 = **1.5 GB**. Fits 8 GB
comfortably even with conservative numbers.

The numbers above are the *theoretical floor* assuming clean
implementation. Real implementations carry overhead; expect
~2× the floor in practice. So `RSS(5000, 10) ≈ 3 GB`.

## Phasing

### Phase 1: design + measurement infra (~1 week, doc-only)

- Confirm the cost model. Run an experiment: at N=292 / N=1000 /
  N=5000 with full panel mode, measure RSS contribution from cold
  symbols specifically (instrument with `Gc.stat` snapshots before/
  after each phase).
- Decide tier boundaries (Cold / Warm / Hot vs Cold / Hot binary).
  Three-tier is more memory-efficient but costs implementation
  complexity. Two-tier (Cold / Hot) is simpler; revisit if it
  doesn't fit 8 GB.

Output: design doc + measurement note.

### Phase 2: tier data structure (~600 LOC, 3-4 PRs)

- New `Tiered_panels` module under `data_panel/` with the cold/warm/
  hot state types.
- `Bar_panels.t` becomes the hot-row backing store, sized to
  `max_hot_count`, not `n_loaded`.
- Tier transitions are methods: `Tiered_panels.promote`,
  `Tiered_panels.demote`. Each manages panel-row allocation.
- Strategy / screener still see the same `weekly_view_for` /
  callback surface — backed by hot-tier data only.

### Phase 3: promotion logic (~400 LOC, 2 PRs)

- Friday cycle: walk Cold → cheap classifier → Warm if needed.
  Walk Warm → full Stage classify → Hot if passes screener
  prerequisites. Demotion symmetric.
- Streaming CSV reader for Cold tier (`Csv_storage.read_recent`
  primitive).
- Held positions pin Hot tier regardless of stage.

### Phase 4: streaming γ collapse (~300 LOC, 2 PRs)

- Drop `Stop_log` / `Trace` / `prior_stages` accumulation for
  Cold and Warm symbols.
- Per-symbol GC compaction on demotion (`Gc.compact ()` after
  freeing a panel row pool slot — reverses fragmentation).

### Phase 5: validation + tuning (~200 LOC, 1-2 PRs)

- N=5,000 spike on a 5-year scenario (broad-data universe) —
  measure peak RSS. Target ≤ 8 GB.
- N=10,000 spike — stretch goal; not required for tier-4.
- Update `dev/plans/columnar-data-shape-2026-04-25.md` §Memory
  expectations with the new fit.

Total: ~1,500 LOC across 8-9 PRs over ~3-4 weeks.

## Decisions to make before Phase 2

1. **Two-tier or three-tier?** Three (Cold / Warm / Hot) is more
   efficient; two (Cold / Hot) is simpler. Recommend starting with
   two and adding Warm only if the Cold→Hot promotion churn is
   too expensive.
2. **Hot row pool size**: configurable? Worst case N_hot >
   `max_hot_count`, what happens? Probably reject the promotion
   and keep the symbol Warm (or Cold). The screener should never
   need more than a few hundred Hot symbols at a time on any
   realistic regime.
3. **CSV streaming for Cold tier**: read whole file each access
   (slow; small data) or maintain a per-symbol file handle (fast;
   FD limit at 10K symbols)? Probably read-whole-file with an
   LRU file-content cache for recently-touched Cold symbols.
4. **Indicator panel sizing**: today indicators are universe-wide
   panels (`Indicator_panels.t` is N × T). With hybrid tier, do
   indicator panels also become hot-only? Yes — same shape as
   `Bar_panels` (Hot row pool). This is a non-trivial refactor of
   `Indicator_panels` + `Get_indicator_adapter`.

## Risks

### R1: cascade thrashing

If symbols thrash between Cold and Hot rapidly (e.g. boundary
cases), promotion / demotion overhead dominates. Mitigation: add
hysteresis — require N consecutive weeks of "uninteresting" before
demotion.

### R2: held positions blocking demotion forever

If a held symbol stays Stage 4 + weak sector, it blocks the panel
row indefinitely. Mitigation: it has to — the stop machine needs
the history. Document that held-position count caps the Hot pool
floor; if held > 500, the architecture needs rethinking.

### R3: cold-symbol stage classification is approximate

A coarse `Stage.classify_metadata` based on stale data may miss
genuine Stage 1 → Stage 2 transitions (the screener's most
valuable catch). Mitigation: cheap classifier is conservative —
errs on promoting too many to Warm. Warm tier does the real check.

### R4: implementation overhead

The deleted Tiered loader (#573) was a similar concept and
~95% RSS-regressed. Could happen again. Mitigation:
- Tier state lives in OCaml heap, not parallel hashtables. No
  duplicated bar storage.
- Promotion / demotion is allocation-free where possible (slice
  reuse).
- Phase 1 measurement gates the rest of the plan: if the cost
  model doesn't fit, abort and pursue different scope (e.g.
  ceiling at N=1,000).

## What this plan does NOT do

- **Does not change the strategy logic.** The screener cascade,
  stop machine, signal generation are all unchanged. Hybrid tier
  is a storage optimisation, not a behaviour change. Parity gate
  unchanged.
- **Does not solve N=10,000 release-gate at the 8 GB ceiling.**
  Aim for N=5,000. N=10,000 needs additional work (per-symbol
  streaming with no in-memory state at all, or a different
  partitioning strategy — e.g. process universe in 2,000-stock
  batches and merge results).
- **Does not introduce live mode.** Stage 5 (universe rebalance
  for live) remains separate.

## References

- Spike + matrix progression (the data this plan rests on): listed
  in `dev/plans/columnar-data-shape-2026-04-25.md` §"Memory and
  CPU expectations" → "Measured fit".
- Memtrace findings: `dev/notes/panels-memtrace-postA-2026-04-26.md`.
- Original tier loader history: `dev/plans/backtest-scale-optimization-2026-04-17.md`,
  Stage 3 PR 3.3 (#573) deletion.
- Stage 4.5 plan: `dev/plans/panels-stage045-lazy-tier-cascade-2026-04-26.md`
  (lazy-tier within-strategy; orthogonal to this plan's tier-of-state).

## Triggers to start

- After the S&P 500 golden lands as a stable benchmark
  (`trading/test_data/backtest_scenarios/goldens-sp500/`).
- When tier-4 release-gate becomes a near-term concern (currently
  blocked behind Stage 4 / 4.5 + S&P 500 work).
- Phase 1 (measurement infra) can start anytime — it doesn't
  conflict with other work.
