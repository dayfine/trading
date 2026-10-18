# Fresh-eyes study, staged design: macro → sector → a few stocks looked at closely (2026-10-18)

Supersedes the per-stock forward pass of `fresh-eyes-weinstein-2026-10-13.md` §4 **for any resumption**. The
charts, the stepper, the rule card and the comparison (§3, §5, §6 of that plan) are unchanged. Run only if the
reading of the 24-stock partial pass (`dev/experiments/fresh-eyes-2026-10-13/results/forward/`) leaves a question
worth $250–300 of plan quota.

## 1. Why the first design cost so much

Measured on the paused forward pass (5,337 calls, $429.52 notional, 2026-10-14..15):

| fact | number |
|---|---|
| cost per call (Opus, fresh context, one 2400 px composite image) | $0.0805 |
| share of cost in the per-call image written to cache (never re-read) | ~70 % |
| calls that returned `none` | 87 % (4,657) |
| looks at the 4-week default with nothing held | 4,142 |
| cost per stock-year | ~$1.07 |
| projected full pass (100 stocks) | $1,050–1,350, about 2.5–3 weekly quotas |

It drained what was left of a week's plan quota in under a day; then four workers sat in pause loops for three
days and every other session was blocked.

The cause is structural: every stock was read closely every month, whatever the market and whether or not the
stock was interesting. Weinstein does not read that way. He reads the market, then the groups, then a short list.

## 2. The staged reader

Each monthly checkpoint (last Friday of the month, 2000-01..2026-06, 318 cuts) runs four steps. Fresh context per
call, as before; no step sees the future.

| step | input | model | output |
|---|---|---|---|
| A. Market | the market pack (SPY + 30-week MA, A-D line, sector strength table), one image | Opus | market phase (bull / caution / bear) and whether to look for longs, shorts or neither |
| B. Groups | the sector strength chart, one image (merged into A when legible) | Opus | up to 3 strong and 3 weak groups |
| C. Screen | contact sheets: 20 small 5-year charts per image, the alive members of the favoured groups (all alive members when A says neither) | Sonnet | up to K = 5 names per side worth a close look, with one line each |
| D. Close look | the full 2×2 composite for each shortlisted name and for each held position at a fill, a stop, or every 8 weeks | Opus | the order JSON of the current reader |

The stepper still fills orders and runs stops mechanically between checkpoints, so held positions need no monthly
look. Step C is the "scorer that only looks closely at a small set": a cheap model on thumbnails decides where the
expensive model spends.

**What changes in the experiment:** the reader now chooses among stocks, as the book and our system do, so the
trades are a book-reader portfolio, not 100 independent single-stock reads. The comparison against our classifier
(§5 of the first plan) is unchanged; trades gain a ranking question ("did the reader pick the names our screener
ranked high?").

**Image size:** step D drops from 2400 px to about 1568 px wide. A two-cut legibility check on the pilot (the same
cut at both sizes, same answer) gates it.

## 3. Cost projection (100 stocks, 318 monthly cuts)

Unit costs from the forward pass, scaled by image size; ranges carry the uncertainty.

| step | calls | $/call | cost |
|---|---|---|---|
| A + B, market and groups | 318 | 0.08–0.10 | $25–32 |
| C, contact sheets (avg ~60 alive members in favoured groups → 3 sheets) | ~950 | 0.02–0.04 (Sonnet) | $19–38 |
| D, shortlist (≤ 5 per side, ~6 on average with one side active) | ~1,900 | 0.05–0.08 | $95–152 |
| D, held positions (fills, stops, every 8 weeks; ~3 open on average) | ~500 | 0.05–0.08 | $25–40 |
| quota probes (every 25 calls) | ~150 | 0.02 | $3 |
| **total** | **~3,800** | | **$170–265** |

Against the per-stock design (~$1,200): about 5× cheaper. Wall time at 2 jobs: ~10–14 h of calls.

**In quota terms.** The plan quota is not metered in dollars. The forward pass used about $430 of notional cost to
finish a week that had already been partly used, so one full week is at least $430 and likely $500–700. The
projection is therefore **roughly 30–60 % of one week**. The pilot (§4) measures the real conversion: the
seven-day utilization delta per notional dollar, read with `dev/scripts/quota_status.sh` before and after.

## 4. Pilot and guards

1. **Pilot: 12 monthly cuts (2008-01..2008-12), all four steps.** ≈ $8–12. Read: quota % per dollar, step C's
   shortlist vs step D's actions (does D act on most of C's picks?), image-size legibility.
2. **Size the full run from the pilot**, in % of the week, against the day's allowance from `quota_status.sh`.
   Split it across days if it exceeds one day's allowance: the run is restartable per cut.
3. **Guard in the driver:** call `sh dev/scripts/quota_status.sh --guard <MAX>` before each cut, MAX = 1 −
   management reserve (0.85 by default) or lower. Exit 3 stops the run cleanly; it never waits in a pause loop.
4. **On a usage-limit reply, stop, don't wait.** The first design's 24-pause retry loop held four workers for
   three days. A limit reply ends the run; the next day's session restarts it after reading the allowance.

## 5. Build order

1. `scripts/contact_sheet.sh`: 20 thumbnails per page from the existing renderer (host only).
2. `scripts/staged.sh`: the monthly driver (A → B → C → D), state per cut, quota guard, stop on limit.
3. Pilot (§4.1), cost report, decision to run.
4. Full run, split by days; comparison (`scripts/compare.sh`, extended with the ranking question); analyst read;
   results PR.

The `batch-model-run` skill (`.claude/skills/batch-model-run/SKILL.md`) carries the generic rules: projection
table, pilot calibration, staging, guard, stop on limit.
