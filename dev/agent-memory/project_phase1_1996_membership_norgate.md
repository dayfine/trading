---
name: SP500 / Russell 3000 historical membership — EODHD + IWV scrape, NOT Norgate
description: Phase 1.1 (sp500 deep-history) and Phase 1.2 (Russell 3000) sourcing. Norgate is Windows-only (ops debt vs OCaml/Docker/Mac). 2026-05-16 vendor sweep concluded EODHD covers SP500 from 2000 + DIY IWV scrape covers Russell 3000 from 2006 + fja05680/sp500 patches 1996-1999. Skip Norgate.
type: project
originSessionId: 4d6537ae-8820-4dcd-bdf8-cf449e669439
---

## 2026-05-16 UPDATE — Norgate is NOT the path

User flagged that Norgate NDU client is Windows-only
(https://norgatedata.com/ndu-faq.php#oldwindows). Adding Windows VM / Wine
to the OCaml+Dune+Docker+Mac stack is significant ops debt for one data
import. Research agent swept non-Windows alternatives (full report:
`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`).

**Conclusion:**

| Need | Source | Status |
|---|---|---|
| SP500 2000-present with delisted + tenure | **EODHD** (we already subscribe) | `/api/fundamentals/GSPC.INDX?historical=1` returns `HistoricalTickerComponents` with `StartDate`/`EndDate`/`IsDelisted`. Bundled in Fundamentals Data Feed ($59.99/mo) or All-In-One. |
| Russell 3000 2006-present | **DIY iShares IWV scrape** | Public URL `https://www.ishares.com/us/products/239714/.../IWV_holdings...?asOfDate=YYYYMMDD`. Diff consecutive snapshots to reconstruct tenure. `talsan/ishares` GitHub repo is the canonical reference (Python — for reference only, port URL pattern to OCaml). |
| 1996-1999 SP500 tail (optional) | **`fja05680/sp500`** | MIT-licensed GitHub repo, ships `sp500_ticker_start_end.csv` since 1996. Author warns first ~5 years incomplete; reliable from 2001. Pin a commit. |

**What to verify before depending on EODHD:**
1. Current subscription tier — free EOD-only plan does NOT include Fundamentals; need Fundamentals Data Feed ($59.99/mo).
2. Spot-check 5 known events (LEH 2008-09-15 delist, KODK 2009-12 remove, FB 2013-12-23 add, TSLA 2020-12-21 add, GE 2018-06-26 remove) against S&P press releases.
3. Confirm `IsDelisted` symbols include OHLCV in our existing price subscription.

**Skipped vendors (with reason):**
- Polygon.io / massive.com: no index constituents (open feature request #17 since 2021)
- Tiingo: no index constituents
- FinancialModelingPrep: covers SP500 but no Russell 3000, no advantage over EODHD
- Sharadar via NasdaqDataLink: $150-300+/mo, 5-10× EODHD cost, no Russell 3000
- CRSP/WRDS: institutional only
- SPDR SPY scrape: no historical archive

**How to apply:**
- If a feat-data dispatch needs SP500 deep history: try EODHD Fundamentals endpoint first; the broader plan in the priorities doc should be re-scoped from "1996 via Norgate" to "2000 via EODHD".
- If a feat-data dispatch needs Russell 3000 history: implement IWV scrape — see report §"DIY iShares IWV scrape" for the URL pattern and edge cases.
- If 1996-1999 tail is desired: pin a `fja05680/sp500` commit and mark those entries `source=fja05680-best-effort` in the manifest.

---

## Historical (pre-2026-05-16) — superseded by above

[Original note retained for context only.]

When dispatching the P0 Phase 1.1 work
(`sp500-1996-01-01.sexp` membership data per
`dev/notes/next-session-priorities-2026-05-15.md`), remember:

`dev/notes/historical-universe-status-2026-05-13.md` documents that
Wikipedia SP500 changes data is **sparse pre-2007**. PR #813's
`Changes_parser` was built primarily against 2007+ changes. So the
1996 membership scenario almost certainly requires the Norgate
vendor (currently blocked on user signup — $32-66/mo).

**How to apply:** Before kicking off Phase 1.1 as a feat-data
dispatch, confirm one of:
1. The user has signed up for Norgate (check `dev/status/data-foundations.md`
   §"Blocked on" for whether the vendor-signup blocker is cleared).
2. Wikipedia data has been re-evaluated and found sufficient
   (cross-check `dev/notes/historical-universe-status-2026-05-13.md`
   for any 2026-05+ update on coverage).
3. Phase 1.1 scope is narrowed to "2007 onward" (give up the 1996
   start date and re-baseline against a 19-year window 2007-2026).

If neither (1) nor (2) holds, Phase 1.2 (`broad-3000-2010-01-01.sexp`
cohort) is the higher-ROI next step since it builds on Wikipedia
data we already have for the 2010+ window.

**Surfaced by:** qc-behavioral review of PR #1096 (strategic pivot
docs) — `dev/reviews/priorities-pivot-2026-05-15.md`. Author confirmed
the Wikipedia sparsity caveat in the agent's cross-reference notes.

**Confirmed quantitatively (2026-05-15, PR #1101):** dispatched feat-data
agent verified the blocker. Pinned 2026-05-03 Wikipedia changes-table
HTML contains only **22 events for 1996-2009** vs **~750 events
expected** (25 names/year turnover × 30y). Per-year breakdown: 1996-2006
= 21 events, 2007-2009 = 32, 2010-2026 = 361. `Membership_replay.replay_back`
silently no-ops un-doable drops → naive 1996 replay would produce
"2007 universe + 22 ad-hoc tweaks", not honest 1996 membership. Findings
in `dev/notes/phase1.1-1996-membership-blocker-2026-05-15.md`.
Recommended pivot: Phase 1.2 (broad-3000-2010-01-01) — runs entirely
on existing Wikipedia substrate for the dense window.
