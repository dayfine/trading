# rt-freshness at 5 years on the BROAD universe — period isolated

**Status at commit time: NOT YET RUN.** Pre-registered; results land in a later
commit.

## Why this run exists

The 5y cell that produced the reversal (`../rt-freshness-5y-null-2026-08-20/`,
PR #2436) ran on **`universes/sp500.sexp`, 500 names**. The 26y cell (PR #2433)
ran on **top-3000**. So the comparison that concluded *"`Range_top_breakout`
fails its first independent cell"* changed **period AND universe at once**.

#2436 hedged that ("this run does not attribute the reversal"), but the hedge is
not the fix. **The fix is to not use sp500 at all** — per the user's standing
instruction (2026-08-20): *"we do NOT care about running on S&P500 universe;
even 5y should run on broad."* This is also what
`project_cell_e_2020_stall_regime` already says — **broad universe is THE
lever** — so an sp500 cell was never the right control.

## Design — one axis vs the 26y run

Both specs are the **26y specs verbatim**, with exactly two coupled edits:

| | 26y run (#2433) | this run |
|---|---|---|
| period | 2000-01-01 → 2026-06-26 | **2019-01-02 → 2023-12-29** |
| universe | top-3000, PIT **2000** | top-3000, PIT **2019** |
| breadth | 3000 | 3000 |
| every other knob | — | verbatim |

The PIT year moves with the window because a 2000-vintage composition applied to
a 2019 window is a different defect, not a control. Breadth is held at 3000,
which is the axis that was wrong before.

Arms differ **only** in `entry_freshness_basis` (`Ma_cross` vs
`Range_top_breakout`) — verified by diff.

6 cells: 2 arms × salts {0,1,2}, so the run yields the broad-5y **null** as well
as the treatment effect, same as both prior runs.

## What this can and cannot settle

**Can:** whether rt's reversal at 5y survives when the universe is held at
top-3000. That isolates **period** as the only moving axis against #2433.

**Cannot:** anything about macro-regime diversity. 2019-2023 is still one
post-2009 bull-dominated window, so per `promotion-confirmation.md` this is a
second cell, not a grid. A pre-2009 deep cell is still required before any
promotion talk.

## Decision rule, pre-registered

1. **Null first.** Compute the broad-5y null per metric from core's three salts.
   Nothing below that spread is interpretable, however suggestive.
2. **Score rt vs core under Rule 4** — the paired gap must beat that metric's own
   null, in the same direction, at **all three salts**. Report every metric,
   including the ones that fail (the 26y record's repeated defect was scoring
   only the metrics that passed).
3. **Read the outcome against #2436's sp500 result:**
   - **rt still reverses on broad-5y** ⇒ the reversal is a *period* effect and
     #2436's conclusion survives its universe error. `Range_top_breakout` stays
     not-promotable.
   - **rt does NOT reverse on broad-5y** ⇒ #2436's reversal was driven by the
     **universe**, not the period. Its headline claim is then wrong as stated,
     and the merged record plus its agent-memory note must be corrected. #2433's
     26y result would stand un-contradicted at 1-of-1 cells.
   - **mixed / in-null** ⇒ the broad-5y cell cannot resolve it; say so and do not
     pick a side.
4. Report the **broad-5y null vs the sp500-5y null** (0.9862 / 0.3616 / 0.0069 /
   0.1029 / 0.4167 for return / MaxDD / Sharpe / ulcer / win-rate). If the broad
   null is much larger, that alone explains why an sp500 cell looked decisive —
   and it would be a second, independent confirmation of the
   noise-floor-tracks-portfolio-regime finding from #2438.

Both outcomes are written down before the run, and one of them retracts a
merged conclusion.

---

# RESULTS (2026-08-20, all six cells)

Every number below is read from the per-arm `results/s<N>-<arm>-actual.sexp`,
never from the chain log — see the run notes at the bottom for why that matters.

## Core nulls (max−min across the three salts), vs the sp500-5y nulls

Same period, same dials, same salts. Only the universe differs.

| metric | broad-5y null | sp500-5y null | ratio |
|---|---:|---:|---:|
| return pp | **14.650** | 0.9862 | **14.9×** |
| Sharpe | 0.1738 | 0.0069 | **25.2×** |
| ulcer | 1.1186 | 0.1029 | 10.9× |
| win rate pp | 1.3706 | 0.4167 | 3.3× |
| MaxDD pp | **0.1581** | 0.3616 | **0.44×** |

Pre-registration item 4 is answered, and more sharply than expected: the noise
floor does **not** move uniformly with universe. Return and Sharpe get 15–25×
noisier on breadth; **MaxDD gets 2.3× more stable.**

## Rule 4 — paired gap (rt − core) vs that metric's own null, all three salts

| metric | s0 | s1 | s2 | gap ÷ null | verdict |
|---|---:|---:|---:|---|---|
| **MaxDD** | −2.351 | −0.219 | −3.049 | 14.9× / 1.4× / 19.3× | **PASSES** — rt better, all three |
| ulcer | −0.985 | −1.381 | −2.265 | **0.88×** / 1.2× / 2.0× | direction holds 3/3; s0 inside its null |
| return | −6.219 | −16.576 | **+7.826** | — | sign flips |
| Sharpe | −0.078 | −0.221 | **+0.089** | — | sign flips |
| **win rate** | +3.318 | **−3.068** | +2.196 | s1 = **2.24x** null | **FAILS Rule 4** — 2 salts agree above null, s1 opposes; see below |
| trades | −5 | **+4** | −12 | — | sign flips |
| holding days | −0.317 | −4.965 | **+1.204** | — | sign flips |
| sortino | −0.1061 | −0.2990 | **+0.1308** | — | sign flips |
| calmar | −0.0351 | −0.1001 | **+0.0497** | — | sign flips |

Every performance metric present in the committed `actual.sexp` files is listed,
per pre-registration item 2. Sortino and calmar were omitted from the first
version of this table under a heading claiming completeness; both sign-flip, so
nothing favourable was hidden, but the omitted class was exactly the one the
pre-registration singled out.

**⚠ The nulls are max−min of three draws**, which is a downward-biased estimate
of the true spread — a wider null makes every ratio smaller. #2436 carried this
caveat and licensed dropping it on a 12.31× margin. It is restored here because
this cell's weakest passing leg is **1.4×** and the mechanism headline (0.44×)
is a ratio of two such estimates quoted to 4 s.f. The retraction does not depend
on it; "MaxDD passes outright" does.

## Verdict — branch 2 fires: the reversal was the UNIVERSE, not the period

`Range_top_breakout` does **not** reverse on broad-5y in the way #2436
described — that cell reported all five metrics reversing, and here they do not.

**But "the metrics that survived at 26y hold" is false, and the precise count
matters.** Three metrics cleared Rule 4 at 26y (ulcer 1.43×, win rate 1.96×,
MaxDD 1.02×), not two. Of those three, on broad-5y:

| 26y Rule-4 survivor | broad-5y |
|---|---|
| MaxDD | **holds** — passes Rule 4 here too, 14.9× / 1.4× / 19.3× |
| ulcer | **direction holds** 3/3, but s0 sits inside its null (0.88×) |
| **win rate** | **FAILS Rule 4** — s0 (+3.318, 2.42x) and s2 (+2.196, 1.60x) agree with the 26y direction above null; **s1 (-3.068) actively opposes at 2.24x**. Not unanimous, so the leg does not carry. |

So this cell does not simply fail to reverse; it **splits** the 26y result.

Consequences, as pre-registered:

- **#2436's headline claim is wrong as stated** and is retracted; see the
  correction appended to `dev/experiments/rt-freshness-5y-null-2026-08-20/README.md`.
- **#2433's drawdown finding is not contradicted** — MaxDD now agrees across
  both windows. **Its win-rate leg FAILS Rule 4 here** — s0 and s2 agree with the 26y direction
  above null, s1 opposes at 2.24x, so the leg is not unanimous and should no
  longer be quoted as a Rule-4 survivor without this cell's counter-evidence. An earlier
  version of this section said "#2433's 26y result stands un-contradicted",
  which was false.
- `Range_top_breakout` is still **not promotable** — nothing here changes that,
  and see the scope caveat immediately below.

### The design supports a stronger claim than the first version made

Comment-stripped spec diffs (verified by qc-behavioral, #2448):

- `broad5y-00-core` vs the **sp500-5y** core — differ only in name/description/
  `universe_path`/`universe_size`. **Period byte-identical ⇒ universe-only leg.**
- `broad5y-00-core` vs the **26y** core — differ only in name/description/
  `period`/`universe_path`. **⇒ period-only leg.**

This is a **two-leg decomposition**, not a single comparison, and both legs point
the same way. The first version of this writeup under-claimed it.

## ⚠ Amendment to the pre-registration's scope claim

The text above says this cell makes "a second cell, not a grid." That is too
generous and is corrected here rather than edited in place, so the
pre-registered wording stays auditable.

**2019-2023 is nested inside 2000-2026.** Per `promotion-confirmation.md`,
"Overlapping windows are NOT independent" — so this is a *nested sub-window*,
not an independent grid cell, and it cannot count toward a promotion grid at
all. That does not weaken its actual purpose: universe is the only axis moved
against #2436, so it isolates that axis, which is exactly what nesting buys.

It answers **"period or universe?"** It does not answer **"does rt
generalise?"** No promotion claim may cite this cell.

This is the same defect found today in the nearfloor grid, whose cell C
(2010-2026) is nested inside its cell A (2000-2026).

## Why the mechanism, not just the confound

Breadth raises the return noise floor (more names ⇒ more tail lottery in the
terminal figure) and lowers the drawdown noise floor (more names ⇒ more
diversified drawdown path). So MaxDD is the one metric whose signal-to-noise
*improves* with breadth, while every return-flavoured metric degrades.

That sharpens the 26y finding that "return has ~10× worse SNR than any risk
metric," which was recorded with the caveat that "risk lever, not return lever"
might be a low-power artefact of the horizon. It is not a horizon artefact — it
is a property of **breadth**, and it moves in opposite directions for the two
metric families.

It also states the cost of the universe error concretely. On sp500-5y the
measured return gap was **−67.20pp against a 0.9862pp null — 68×**, which reads
as overwhelming. The same *arm* on broad-5y produces gaps of −6.219 / −16.576 /
**+7.826** pp against a 14.650pp null — 0.42x, 1.13x and 0.53x of it. Only s1 exceeds the null; s0 and s2 sit inside it, and s2 also flips sign.

An earlier version of this paragraph wrote "on sp500-5y a −6pp gap sits at 6× a
0.99pp null." That mislabelled scope — −6.219pp is *this* cell's s0 figure, not
the sp500 cell's, whose gap was an order of magnitude larger. It also called
14.65pp "the true null", which is wrong: **0.9862pp was the correct null for
sp500-500.** The error was never the null; it was measuring on a surface whose
result does not generalise.

## Run notes — two harness defects hit during this run

Both are now recorded in `.claude/rules/sweep-hygiene.md` (#2446).

1. **A parent-workspace `jj new` deleted the specs mid-run.** Salt 0 had already
   loaded them; salts 1 and 2 died 1 second apart on
   `lstat .../specs: no such file or directory`. The pinned worktree protected
   the build, not the inputs — `SPECS_HOST` resolved through the parent tree.
   Fixed by staging specs to `/tmp/broad5y-run/specs` and relaunching salts 1-2;
   salt 0 was skipped via the chain's own log guard. A 1-second cell is not an
   OOM, whatever the chain's error text suggests.
2. **The metric glob spanned both arms.** `${out}/*/actual.sexp` picks up every
   arm in the shared timestamped output root, so the arm finishing second gets a
   line with both arms' metrics concatenated. Scoped to
   `${out}/broad5y-${arm}/actual.sexp`. The same defect is present in #2433 and
   #2436 and corrupted neither, because both committed per-arm artifacts and
   their writeups were built from those.
