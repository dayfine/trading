# Path stability: seeded tie order + fill resize, judged on spread, not return

Status: PRE-REGISTERED 2026-10-23, user-approved direction ("sure sg", after the #3266 read). Nothing has run.

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

### Step 2: the stability experiment (one chain, after Step 1 merges)

**Arms.** Four, on one pinned build:

| arm | `candidate_ranking` | `entry_fill_size_to_available` |
|---|---|---|
| B (base) | Alphabetical | false |
| T | Seeded | false |
| R | Alphabetical | true (min fraction 0.5) |
| TR | Seeded | true |

**Perturbations, the same set for every arm.** K = 6 runs per arm:
- p0: unperturbed;
- p1–p5: each deletes **one traded, minor name** from the lists, a CMN-type change.
  - The five names are fixed now by rule, before any run: from arm B's trade list on the window, take the five
    traded symbols with the smallest |total-return P&L|, ties broken by ticker.
  - Deleting a traded name guarantees the path is perturbed.
- For T and TR, each perturbation also uses its own `tiebreak_seed` (0–5). Seeded order is meant to be a draw; for B
  and R the seed is inert.

**Window and universe.** Top-3000 PIT v12 schedule, 2019-01-01 → 2024-12-31 (6y), record spec (`rb1-26.sexp` body)
with the window changed. Six years is long enough for a cascade to compound, as the 26y path diverged within 1–2
years of a change, and keeps the chain inside about 1.5 days.

**Cost estimate.**
- At the current 26y rate (about 1,031 s per simulated year, #3381), each 6y cell takes about 1.7 h.
- 24 cells × about 1.7 h ≈ **41 h**, run sequentially, alone in the container.
- A 5y window would save about 15 %. The window above is fixed; if #3381 is fixed first, the chain gets cheaper.

**Validity.** Every cell is gated on `validator_diff -check V6` against arm B p0 (`mechanism-validation-rigor.md`
check 8). A V6 mismatch excludes that cell and names the specimen.

### Metrics (pre-registered)

Per arm, over its K = 6 cells:

- **spread** = SD of ln(1 + total return) (primary), with the max − min range as secondary;
- the median ln(1 + R), Sharpe and max DD (secondary, read only for do-no-harm);
- **divergence onset:** for each p1–p5, the first date its NAV differs from the arm's p0 (descriptive).

### Decision rule (written before any run)

- **Stabilises:** an arm's spread is ≤ 0.6 × B's spread, and its median ln(1 + R) is not below B's median by more than
  B's own spread.
- **Promotion to default:** an arm that stabilises is recommended as the new default, **on user approval as a
  correctness fix**. This is an explicit exception to `experiment-flag-discipline.md` R3, which asks for a return-based
  ACCEPT. Recorded here so the exception is visible.
  - If both T and R stabilise, the recommendation is TR, provided TR also stabilises. Otherwise it is the single arm
    with the smaller spread.
  - Promotion moves the record, so it is followed by the record re-baseline (with #3388 if decided by then).
- **No arm stabilises:** record it. The yardstick change still lands, with the reason recorded: chains report spread
  across perturbations (list deletions plus seeds) in place of path-salt spread, because the salt is shown to
  understate path noise.
- **Small n.** K = 6 per arm gives a wide CI on an SD. The 0.6 threshold is set so that only a large effect counts.
  A ratio between 0.6 and 0.85 is reported as "inconclusive", never as a win.

### What this does not do

- No change to the strategy's rules (stage, breakout, stops, macro gate). Spine intact (`weinstein-faithful-core.md`).
- `Quality` ordering is not revived; the June REJECT stands.
- No return-based claim. A tighter spread with a lower median return is reported as exactly that.

## Order of work

1. Step 1 feat PR (feat-weinstein or local): Seeded ranking, default-off, plus tests; full three gates.
2. Chain script plus specs for Step 2, committed and pre-registered at that commit (this plan is the read rule).
3. Run the chain (about 41 h), then the review pack for B p0 and TR p0, the results-analyst read, a results PR and
   qc-results.
4. User decision on promotion.

Tracked in #3404.
