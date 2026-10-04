# Macro-suspend of resting entry tickets on the investor preset, 5d + 5r (2026-10-04)

## Why

User decision 2026-10-03: run next-session item 4(c) after the shorts pair
(`dev/notes/next-session-priorities-2026-10-03.md` §4(c)). The knob `entry_ticket_macro_suspend` (#2976 / #2995,
default `Off`) **suspends** resting long entry tickets while the macro gate rejects new longs, and re-issues them
unchanged on the first weekly screen where it admits again. Book: Ch. 8, "Suspend buying even if you see a few
stocks breaking out" (`docs/design/weinstein-book-reference.md` §2.1, resolved 2026-09-16); spine item 6.

Prior record:
- One salt on the earlier hybrid preset (`investor-preset-2026-09-26/results-2026-09-28.md`, cell 9d): +4.6 pp
  return, max DD 4.8 pp worse, V6 agree. A different preset at one salt: no reading carries over.
- `entry-anchor-recovery-2026-10-02/results-2026-10-03.md`: on the ia4 arm, "bought in a Bearish macro week" was
  22 entries (19 %) vs 6 (8 %) on the null. That bear-rally fill cost is the only part this knob can touch.
- The 26y walkthrough counted 103 of 724 fills (14 %) in Bearish-screen weeks from tickets placed in a
  Bullish/Neutral tape (the knob's docstring).

**Hypothesis.** Small effect on the investor preset: the null's 2007 losses came with the gate Bullish, and its
bear-week fills are few. The knob removes fills in Bearish-screen weeks; whether the re-issued tickets then fill
better or worse is the open question.

## Arms

| arm | spec | difference |
|---|---|---|
| `ms0` | `specs/ms0-{5d,5r}.sexp` | byte-copy of `entry-anchor-recovery-2026-10-02/specs/ia0-{5d,5r}.sexp` (investor preset) except header and name |
| `msB` | `specs/msB-{5d,5r}.sexp` | `ms0` + `((entry_ticket_macro_suspend On_bearish_macro))` |

## Windows, salts, build

- 5d = 2007-06-01 → 2012-06-29; 5r = 2021-06-01 → 2026-06-26. PIT top-3000 schedule, warehouse `_v11pit`.
- Salts 0, 1, 2. 12 cells, 5d first (every salt), then 5r. ~25–50 min per cell (`perf-long-cells.csv`), ~6–7 h.
- Pinned worktree at `origin/main` (`results/launch.sh`); specs and chain read from this pre-registration commit.

## Reading rule (pre-registered 2026-10-04, before any cell runs)

Rules 1–8 of `../entry-anchor-recovery-2026-10-02/README.md`, with the arm names changed and rule 3 replaced.

1. **Gate.** `validator_diff -check V6` exit 0 per pair per salt. Valid salts: 2 of 3, or 2 of 2, else
   "no reading" (`../trader-presets-2026-09-29/README.md` rule 1).
2. **Same-build anchor.** Each `ms0` cell must match the 10-02 `ia0` cell on the same window and salt
   (`actual.sexp` metrics, and `trades.csv` on the columns both files carry). A mismatch is reported; the
   in-chain pairs stay valid, since both arms share the build.
3. **Liveness (mechanism check, both windows).** Per salt, count long entries whose fill date falls in a
   Bearish-screen week: the `trend` of the latest `macro_trend.sexp` row dated on or before the entry date is
   `Bearish`.
   - Live: the null has > 0 such fills at a salt and `msB` has 0 at that salt.
   - `msB` > 0 at any salt → report each such fill (symbol, dates, ticket placement); it is a mechanism
     defect to trace before any P&L reading.
   - The null at 0 on a window at every salt → the knob has nothing to act on there; report "not
     exercised", whatever the P&L.
   - Also report, per salt, the entries in `msB` not in `ms0` (re-issued tickets that filled later) and
     their P&L.
4. **Per window.** The four outcomes as in the 09-29 rule 3 ("adds" / "mixed" / "dilutes" / "no reading"),
   `msB` vs `ms0`: Calmar ≥ the null at the required number of valid salts, and max DD never > 5 pp worse.
5. **Per-trade check for every "adds".** Join to the null on (entry date, symbol): the shared trades'
   `pnl_percent` change, the unshared trades' counts, P&L and wins. Name the top unshared trade and its share
   of the delta. A delta carried by one trade is reported as such (the #3081 lesson).
6. **Phase-2 trigger.** `msB` goes to a 26y phase (3 salts, separately pre-registered) if it is "adds" at 5d
   **and** not "dilutes" at 5r. Otherwise there is no phase 2, and the record says why.
7. **Exposure statements** carry the regime split per period (`backtest-result-review.md` RV2). The review
   packs for `ms0` and `msB` are built, rendered and looked at (RV1/RV3) for each window.
8. **Verdict calibration.** No default flip from this experiment. A ledger entry follows only phase 2.
   "Adds" in both windows plus phase 2 at the required threshold gives Accept(mechanism), promotable only
   through the confirmation grid (`promotion-confirmation.md`).

**Expected, stated in advance.** Few Bearish-week fills on the null (the 10-02 ia0 5d pack: 6, 8 % of entries,
salt 0), so a small P&L delta at 5d, possibly within salt noise. Some suspended tickets re-issue and fill after
the gate reopens, at the same level, so `msB` keeps most of the null's trade list. A larger effect is possible on
5r, where the 2022 bear had repeated Bullish/Bearish flips.

## Files

- `specs/` — the four specs.
- `results/chain-msusp.sh`, `results/launch.sh` — the chain (copy of the anchor chain, paths moved) and launcher.
- `results/` — per-arm artifacts and the chain log, committed with the results.

## Log

- 2026-10-04 — pre-registered.
