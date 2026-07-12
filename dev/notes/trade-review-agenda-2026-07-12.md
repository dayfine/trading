# Trade-by-trade review agenda (interactive session prep, 2026-07-12)

Prepared for the user's deployment-readiness ask #3: an interactive
trade-by-trade audit of the record run (honest-tradeable ext, top-3000 PIT
2000-2026, end 2026-06-26; `scenarios-2026-07-11-195158`).

**Browsing tool**: Claude artifact "Trade Audit" —
https://claude.ai/code/artifact/64d859d6-920a-448e-a870-11a47098fe41
All 1,140 closed trades + 2 open positions, sortable, with the agenda
cohorts below as one-click preset filters (counts shown per chip).

## Cohorts + the question each must answer

1. **Monsters ≥$500k** — the edge itself (top-5 ≈ 85% of PnL). Per monster:
   liquid at entry AND exit? split/dividend-clean bars? fundable at signal
   (cash)? Would the live pipeline have surfaced it that week?
2. **Big losses ≤−$150k** — which exit channel let each run? gap_down fill
   realism; slow-grind holds that weekly-close stops held to Friday.
3. **Whipsaws (≤21d loss)** — the ~30-39/yr insurance premium. Confirm they
   cluster in chop; spot-check initial stop distances vs normal weekly noise.
4. **Blank exit-trigger (41 rows)** — believed = ordinary Stage-transition
   sells (unlabeled channel). CONFIRM none is an engine edge case. If
   confirmed, follow-up: label the channel in trades.csv.
5. **NLS/BFX rename dup** — one company double-held via ticker rename.
   Question: are there other rename twins in the run? (universe dedupe
   follow-up.)
6. **Liquidity exits (6)** — genuine ADV death vs data gap, each.
7. **Stage-3 force exits (only 10 in 26y)** — channel nearly inert at
   hysteresis 1; expected or mis-wired?
8. **Gap-down stop fills** — sample against raw bars: fills should be at the
   gap price, not the stop level.
9. **Open positions** — AXTI ($45.8M mark, the give-back exposure #1934's
   insurance dial exists for) + VSAT.
10. **Melt-up lag years (2019/2023/2024)** — the no-monster + churn
    signature (`dev/notes/melt-up-lag-anatomy-2026-07-11.md`).

## Known answers going in (don't re-derive live)

- Whipsaw premium is structural (stop-tuning closed; multiple WF-CV rejects).
- Melt-up lag is structural (mega-caps: cash-blocked when they signal
  cleanly — NVDA ×6; no volume-expansion signature when they grind —
  NVDA-2023). Answer = P1b sleeve, not screener edits.
- MTM-vs-realized: realized ≈ $17.7M is the honest bank; terminal OPV is
  AXTI-dominated.
- Give-back: extension-stop insurance dial built default-off (#1934);
  arming decision is a deployment-config question.

## Session flow suggestion

Tiles → cohort chips in the order above → per finding: classify
(data issue / engine issue / strategy-structural / accepted-cost) → new
issues become follow-ups; structural items get linked to the
deployment-readiness doc's weak-spot table
(`dev/notes/deployment-readiness-2026-07-12.md`).
