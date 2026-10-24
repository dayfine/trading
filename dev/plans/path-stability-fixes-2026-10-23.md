# Path stability: seeded noise, resize + capacity judged on spread, not return

Status: PRE-REGISTERED 2026-10-23, user-approved direction ("sure sg", after the #3266 read). Nothing has run. Amended before any run, same day (see "Amendment").

## Why

The #3266 rerun (`dev/experiments/verify-3266-rerun-2026-10-22/README.md` §3.4) showed that the 26y record path is
chaotic in our own mechanics, not in the market:

- Removing one barely-traded name (CMN) from five lists moved the end NAV **0.204 log**. The cause was a cash cascade:
  its leg used cash, so ASR's fill was cancelled and a CRM ticket was never placed (+$425k).
- A ticket only **$68.58 short** of its fill (FDX 2026-04, 99.99 % funded) was cancelled outright. That moved the end
  NAV another **0.037 log**.
- Our noise yardstick does not see any of this. The `TRADING_PATH_SEED_SALT` salt
  (`trading/trading/engine/lib/market_state.mli`) only re-draws the intraday price path. It never changes candidate
  order or funding, so three salts are near-replicates: N spans 0.044 log, against 0.204 from one list change.

Two mechanics turn small input changes into different tail draws:

1. **Alphabetical tiebreak.** Candidates with equal screener scores are ordered A→Z
   (`Screener_ranking`, `candidate_ranking = Alphabetical`), then capped by count and cash. The order is arbitrary:
   it was chosen for determinism, and the code says so.
   - #1786 / ledger `2026-06-29-candidate-ranking-tiebreak-grid` rejected `Quality` ordering because it **did not
     raise returns**.
   - It never asked whether an arbitrary rule should decide holdings, or how much it destabilises the path.
2. **All-or-nothing entry funding.** A ticket that cannot be fully funded at its fill is destroyed.
   - The fix already exists, default-off: G2b `entry_fill_size_to_available` with `entry_fill_min_size_fraction`
     (default 0.5), from #2468.
   - The funding grid (#2473, `project_funding_grid_monster_lottery`) kept it off because the **return** gap was a
     monster lottery. Its direct effect was positive (+$295k on 167 saved tickets).
   - The grid did not measure spread.

User framing, 2026-10-23: the "luck" is a code defect. These are simulator and screener **correctness and stability
fixes**. They are judged on whether they make the path less chaotic, not on whether they make more money.

## Scope

### Step 1: code (one feat PR, default-off, R1/R2)

- Add `candidate_ranking = Seeded` to `Screener_ranking` together with a `tiebreak_seed : int` field
  (`[@sexp.default 0]`).
  - Ties are ordered by a pure hash of `(tiebreak_seed, ticker, as_of_date)`, then by ticker as the final total-order
    key. It is deterministic and pure, with no global RNG.
  - Using the date in the hash stops the same name always winning, or always losing, its ties.
- The default stays `Alphabetical`, so every golden is bit-identical.
- Both fields route through `Overlay_validator`, so the chain can set `tiebreak_seed` per salt.
- Tests:
  - same seed → same order;
  - a different seed → a different order on a constructed tie group;
  - non-tied candidates are unaffected (score order kept);
  - `Alphabetical` is unchanged.
- No change to G2b. It is already a config axis.

### Amendment 2026-10-23 (before any run): seeds are the noise source, not an arm

The prior ledger entry `2026-06-30-tiebreak-noise-floor` (`dev/experiments/tiebreak-noise-floor-2026-06-30/FINDINGS.md`)
had already measured that uninformative tie orders swing Sharpe by up to 0.28 on top-1000, widening with breadth. It
concluded that the tiebreak is pure selection variance from putting scarce cash into a few tied names. The lever that
**reduces** that variance is more names at a smaller size (capacity), not a re-sort.

A seeded order removes the A→Z bias and makes the variance measurable, but it cannot reduce it. Varied seeds add a
draw, so a seeded arm would fail a "stabilises" test by construction. The first draft of Step 2 treated it as a
stabiliser; the user chose this amendment (2026-10-23). Step 1 (#3406) is unchanged.

### Step 2: the stability experiment (one chain, after Step 1 merges)

**Arms.** Four, on one pinned build:

| arm | tie order | `entry_fill_size_to_available` | `max_position_pct_long` | role |
|---|---|---|---|---|
| A | Alphabetical | false | 0.14 (record) | reference: today's yardstick |
| S | Seeded | false | 0.14 | **null**: honest noise |
| SR | Seeded | true (min fraction 0.5) | 0.14 | candidate stabiliser: resize |
| SC | Seeded | false | **0.07** | candidate stabiliser: capacity, about twice the names at half the size |

**Perturbations.** K = 6 per arm:
- p0: unperturbed;
- p1–p5: each deletes **one traded, minor name** from the lists.
  - The five names are fixed by rule before any run: from arm A p0's trade list on the window, the five traded symbols
    with the smallest |total-return P&L|, ties broken by ticker.
  - The same five deletions are used in every arm.
- In S, SR and SC, each perturbation pk also sets `tiebreak_seed = k`, so the tie draw varies along with the list.
  In A the seed is inert.

**Window and universe.** Top-3000 PIT v12 schedule, 2019-01-01 → 2024-12-31 (6y), record spec (`rb1-26.sexp` body)
with the window changed.

**Cost.** 24 cells at about 1.7 h each (1,031 s per simulated year, #3381) ≈ **41 h**, sequential, alone in the
container.

**Validity.** Each perturbed cell is gated on `validator_diff -check V6` against its arm's p0. Each arm's p0 is gated
on V6 against A p0. A mismatch excludes the cell and names the specimen.

### Metrics (pre-registered)

Per arm, over its K = 6 cells:

- **spread** = SD of ln(1 + total return) (primary), with the max − min range as secondary;
- the median ln(1 + R), Sharpe and max DD (secondary, read only for do-no-harm);
- **divergence onset:** for each p1–p5, the first date its NAV differs from the arm's p0 (descriptive).

### Decision rule (written before any run)

- **Yardstick (A vs S).** Report spread(S) / spread(A). If it is ≥ 1.5, the alphabetical yardstick is recorded as
  understating path noise. From then on, chains measure noise with seeded perturbations (seeds plus list deletions)
  in place of path salts.
- **Seeded order as the default.** Seeded removes an arbitrary A→Z bias. It is recommended as the new default **on
  user approval as a correctness fix**, whatever its spread or return. This is an explicit exception to
  `experiment-flag-discipline.md` R3, recorded here.
- **Stabiliser (SR, SC vs S).** An arm **stabilises** if:
  - spread(arm) ≤ 0.6 × spread(S); **and**
  - its median ln(1 + R) is not below S's median by more than spread(S).

  A ratio between 0.6 and 0.85 is "inconclusive", never a win.
- **Promotion.** A stabilising arm is recommended for default on user approval, the same R3 exception.
  - If both stabilise, the recommendation is the one with the smaller spread. A combined SRC cell set is a follow-up
    only if both pass.
  - SC changes sizing, which the June capacity surface showed trades return for drawdown. So its do-no-harm read also
    reports max DD and Calmar against S. A stabiliser that deepens the median max DD by more than spread(S) in
    percentage points is reported "stabilises with a DD cost": a user decision, not an automatic recommendation.
  - Promotion moves the record, so it is followed by the record re-baseline (with #3388 if decided by then).
- **Small n.** K = 6 gives a wide CI on an SD. The thresholds are set so that only a large effect counts.

### What this does not do

- No change to the strategy's rules (stage, breakout, stops, macro gate). Spine intact (`weinstein-faithful-core.md`).
- `Quality` ordering is not revived; the June REJECT (and the June noise-floor read) stand.
- No return-based claim. A tighter spread with a lower median return is reported as exactly that.

## Order of work

1. Step 1 feat PR (feat-weinstein or local): Seeded ranking, default-off, plus tests; full three gates.
2. Chain script plus specs for Step 2, committed and pre-registered at that commit (this plan is the read rule).
3. Run the chain (about 41 h), then the review packs for each arm's p0, the results-analyst read, a results PR and
   qc-results.
4. User decision on promotion.

Tracked in #3404.
