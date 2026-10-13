# Next-session priorities — 2026-10-13 (supersedes 2026-10-12)

The short setup map is done and merged (#3286): a **no-build decision** for the book's short setup. A decision on
the shorts track is waiting on the user (§3). Open issues: **22** (cap 20).

## 0. Ground rules

Unchanged from 10-12 §0, with three additions:
- **Never run `gh pr checkout` or git checkout in the parent tree.** A QC agent moved the parent HEAD on 10-13 (onto
  #3280's tip); every QC brief now says so.
- **Cloud sessions react to reviews on their own PRs.** On 10-13 a cloud session pushed #3280's rework before a local
  rework agent could. Check `gh pr view <N> --json commits` before dispatching a rework.
- **Two sessions can pick the same issue.** For #3206 two cloud sessions opened #3282 and #3284. The first opened was
  kept, and the duplicate closed.

## 1. What this session settled

| item | result |
|---|---|
| #3276 | `.claude/rules/issue-hygiene.md`: an owner and a state on every issue, a `Verifies` line on results PRs, a weekly pass, a cap of 20 |
| #3279 | issue-hygiene script side (#3275): `issue_fix_audit.sh` sections (c)–(f), a VERIFIES column in `pr_gate_status.sh`, qc-results R11, the #2672 registry row |
| #3278 | setup map amendment 1: dividend splits (user question: avoid shorting dividend payers?) |
| #3286 | **short setup map: NO-BUILD.** 45,599 Stage 3→4 breakdowns on PIT top-3000, 2000–25. P1 (breakdown) median −3.76 %, beat 29.7 %; P2 (pullback) median −1.91 %, beat 31.4 % (the bar is beat ≥ 55 %). Without a stop the population is a coin flip against an SPY short. Every checklist item, given the others, selects worse shorts; SPY early Stage 4 is the worst slice. Two blind analyst reads agree. Dividends: don't exclude payers (beat 34.2 % both); a large dividend in the hold is slightly worse (beat 29.5 %, n 1,093) |
| #3280 | default-off symbol-class filter: warrants, units, curated non-USD (#3183, now verify/pending). LDG removed from the seed (reused ticker) |
| #3282 | default-off `sim_stop_beats_margin_cover` (#3206, now verify/pending) |
| #3281 | review-pack fixes (#3262 items), merged by another session; #3277 closed as superseded |
| #3174 / #2650 | user decisions 10-12: dividend stop adjustment for longs only is accepted; perf-nightly tier 2 stays non-blocking |
| issues | 51 → 22 open (triage 10-12, plus #3275 closed) |

## 2. Queue

1. **Shorts track: waiting on the user's decision (§3).** Until then the short flags stay default-off axes, and
   nothing retires.
2. **Weekly perf/usage review**: not done this week (`perf-review-weekly.md`). Its first run of the new
   `issue_fix_audit.sh` sections reads 22 open issues.
3. **verify/pending runs (local):** #3183 (membership effect of the symbol-class filter; land the `-WT`/`-U`/`-R`
   spellings first), #3206 (paired record run counting margin/stop collisions), #3174 (26y TR axis read). They are
   candidates for one combined local chain.
4. **PR #3283** (#3266 ISO week-year) carries `do-not-merge` (set by its session): it moves goldens. Read its paired
   table before any human decision.
5. **Cloud waves:** #3109, #3136, #2973, #3139, #2738. Codex: #3225, #3263, #2650 ask 1.
6. Record touch-ups (not blocking): #3265's six wording nits, #3273's squash title, the score-threshold `run.sh` header.

## 3. Decisions waiting (deferred to 11:00 PT)

**Close single-name shorts as a strategy track?** The evidence:
- Phase B round 1 lost.
- The index hedge was a no-build.
- The score threshold was not reliably better.
- The setup map is a no-build: the book's stop room, pullback entry, market phase and checklist each measured, and
  none is the cause.

The options:
- **(a) Close. Recommended by both analyst reads.**
  - Classify the single-name short book REJECT-do-not-revive in the ledger (an amendment).
  - The short-only flags then become Rule-4 retirement candidates after 3 unused sessions: `short_min_price_on_order_price`,
    `share_class_gate_covers_shorts`, `margin_config.short_maintenance_finra`, `short_tightened_ratchet_follows_decline`.
  - `enable_short_side` (default true, live weekly "Short candidates") would need its own default-flip PR.
- **(b) One more cheap screen**, pre-registered separately and host-only (about 2 h):
  - a price-defined wide top (late Stage 2 plus Stage 3, stop above the right shoulder), read on O1 +60 first;
  - close if beat < 55 % or median ≤ 0;
  - the second read expects it to fail.
- **(c) Keep the track open but idle**, with the flags as axes. Short interest is the remaining book lever, and it
  is data-blocked.

## 4. GHA watch

None.
