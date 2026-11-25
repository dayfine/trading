# Next-session priorities — 2026-11-25

Supersedes `next-session-priorities-2026-11-24.md`.

## 1. Merged (11-24 → 11-25)

- **#3721 universe-depth K=5 results: all three reads INVALID.** V6 fails on all 15 seed pairs because the v13
  composition lists re-admitted rename twins (GLPG/LKFT in every S3 cell; CMD/CMN, KONA/KONAQ, NCS/CNR_old2 in U4;
  EURN/CMBT in UN4). 439 of 512 v12 top-3000 twin-drop rows have both legs back in v13, and the 11-23 fetch added new
  aliases (LKFT, KONA, NCS). Shapes, not verdicts: U4 − S3 median +0.045 (3/5, noise-sized); N3 − S3 −1.09 (0/5,
  DD +16 pp); UN4 − U4 −2.10 (0/5). Read: `dev/experiments/universe-depth-2026-11-23/RESULTS.md`; ledger
  `2026-11-25-universe-depth.sexp`.
- #3693 closed won't-build and #3710 closed as stale (user, 11-24).

## 2. Consequences now in force

- Weekly picks stay on top-3000 (v12 lists).
- **The pit-v13 lists are blocked** for any measured cell, including a record re-baseline, until the twin dedupe is
  repaired.
- `require_structural_stop false` stays non-promotable (spine item 5); addendum A1–A4 not triggered.

## 3. Next, in order

1. **Repair the v13 twin dedupe:** re-apply the v12 twin drops, scan the 11-23 additions against the whole store,
   alias dropped legs out of both list families, and extend #3713 so the co-occurrence check compares a new vintage
   against the previous vintage's drops (today it checks each list only against its own drops file).
2. Then the rerun the user picks (section 4). Build the review pack from the private trades/equity files this time
   (RV1 was open on #3721).
3. Carried: #3717 (r2 pull-dir retry); #3676 (`fetch_test_bars.sh` after pulling main); first launchd picks Sat 11-28
   09:00 PT (record + live-size); `weekly_snapshot_generator` does not thread `virgin_supply_basis`; triage foreign /
   vendor-splice names (PLZL found trading only through the fallback door, D3 in RESULTS.md).
4. Optional hardening: an entry-time guard treating rename twins like share classes (flag-gated), so a missed list
   twin cannot be bought twice.

## 4. Decisions waiting (deferred to 11:00 PT)

- **Universe-depth rerun after the list repair.**
  - (a) Rerun S3 + U4 only, 10 cells — **recommended**. U4 is the only open question. K=5 reaches the PASS shape with
    probability ~0.68 at a true +0.3 log, so INCONCLUSIVE is the likely outcome unless depth pays well.
  - (b) Rerun all 20 cells: completes the record, but no N3/UN4 result can change a decision.
  - (c) Stop: record INVALID; practical outcome is the same as INCONCLUSIVE (picks stay on top-3000).

## 5. Lessons

- **An idle cloud session loses its VM.** k0 and k3 went idle after a 2 h `run_in_background` wait hit its cap; the
  sandbox was reclaimed and the setsid chain died with it (about 10 h lost each). Keep one Monitor running at all
  times and re-arm it on every expiry; wake a stalled session with a `persist_session` trigger; the dispatcher checks
  `last_event_at` (> 45 min stale = dead).
- **A list rebuild must re-apply the previous vintage's twin drops.** v13's own scan ran and still re-admitted 439
  v12-confirmed rows.
