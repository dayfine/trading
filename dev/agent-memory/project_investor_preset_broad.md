---
name: project_investor_preset_broad
description: "Broad investor preset (09-26): current record config is a HYBRID (investor base + trader dials); inv5 investor vs hybrid 5y chain auto-launches after obvious-fixes chain A; queue in dev/experiments/investor-preset-2026-09-26/QUEUE.md"
metadata:
  type: project
---

User 09-26 asked "are the current runs investor or trader?" → neither: 30-wk MA + base
breakouts (investor) with trader dials (4 % automatic fallback stop on 78 % of trades,
full size, stage3 force exit 1 wk, extension stop, 10 % catastrophic stop, never-expiring
tickets). Only SPY-only presets existed (`spy-investor.sexp` / `spy-trader.sexp`).

Built `dev/experiments/investor-preset-2026-09-26/`: specs `inv5-investor` (hybrid minus
trader dials: `require_structural_stop` on; stage3 force exit, extension stop, catastrophic
stop off; rest weeks default 52; laggard rotation KEPT — book Ch. 4 "lighten up on
laggards… move the proceeds into a new Stage 2 stock") and control `inv5-hybrid` (= f2
overrides exactly), window 2021-06-01→2026-06-26, PIT top-3000. Chain
`/tmp/investor-run/chain-investor.sh` (token `spec:salt[:pair]`, V6 vs pair), pinned
worktree `.claude/worktrees/sweep-investor` @ 1c2647743, auto-launched by
`/tmp/investor-run/launch-after-A.sh` when `LANE A DONE`. Scale-in is not built (known
gap). Queue + dial table: `QUEUE.md` there. Then: investor golden in tier 3; 26y investor.
Links: [[project_trader_investor_modes]], [[project_decision_walkthrough_next]].

**09-28 result (PR #3016, `results-2026-09-28.md`):** investor 29.0/29.9/29.9 % Calmar 0.22–0.23 DD ~23 % vs hybrid −25.9/−8.0/−31.2 % DD 37–43 %, 5y broad s0–s2. **Pre-registered V6 gate FAILED all 3 salts** (investor holds GOOG+GOOGL — share-class pair, not a rename twin; #3015) → rule gives NO reading; descriptive only. **Why:** the hybrid's 4 % `Buffer_fallback`-stop entries (median entry uses it) lose $285–390k/salt (−29 to −39 pp); investor's `require_structural_stop` skips exactly those. Stage3/extension exits barely fire at 5y. **Next:** `require_structural_stop` alone on 26y hybrid (queue item 5) predicted to carry most of the edge; fix #3015 + rerun investor cells for a rule reading.

**09-29 V6-clean reading (PR #3036, `results-2026-09-29.md`):** `max_one_share_class_per_issuer` (#3022) on in BOTH arms → V6 agree 3/3; rule = **"investor preset promising"**: investor 30.6/11.0/30.1 % Calmar 0.24/0.09/0.24 DD ~22 % vs hybrid unchanged (−25.9/−8.0/−31.2 %, identical to flag-off to the digit). Investor s1 −19 pp vs flag-off = ONE path reroute (skipping FWONK 2023-03-27 → lost ADMA +$271k), shared entries +$17k → level is a path lottery, ranking robust. Also: V6 never flagged the FWONA+FWONK overlap in flag-off s1 → #3035. **Next per rule:** queue item 4 (26y investor, flag on) + a broad-vs-broad grid cell; item 5 (`require_structural_stop` alone, 26y hybrid).

**09-30 26y s0 (PR #3048, `results-2026-09-30-26y.md`, descriptive, n=1, cross-build vs f2):** investor +623.6 % / DD 31.1 % / Calmar 0.250 / 506 trades vs f2 hybrid 132.8 % / 54.6 % / 0.059 / 724; V6 agree. **Does NOT beat SPY on return** (SPY adj +700 %, CAGR 8.2 % vs 7.8 %) — beats it on DD (55 %) → Calmar 0.25 vs 0.15. 2008 +0.8 % (SPY −37 %); max DD from 2022–23. **Why:** hybrid 68 % of entries on <4.5 % (fallback) stops, stopped out 66 % at median −4.6 %; investor 78 % of entries on 8–16 % structural stops; win rate rises with stop width (29 → 50 %). Winners exit by laggard rotation (+$12.2M, p90 +44 %). Only 113 shared trades → gap is path. Top-2 (ADMA, MMYT) = 54 % of net; 2024 alone +51.7 %. **Next:** s1/s2; #3038 matrix; item 5.

**10-01 26y 3 salts (PR #3068, `results-2026-10-01-26y-salts.md`):** s1 +401.3 % / s2 +621.3 % (s0 +623.6 %, re-run on 6d84ff1c3 byte-identical). DD 31.0–31.1 % all salts, Calmar 0.20–0.25 > SPY 0.147; CAGR 6.3–7.8 % < SPY 8.1 %. s1 gap = one trade (ADMA +$1.6M not taken). **Why it trails SPY: avg exposure 42 %** — wins bears (2000/02/08), misses recovery first legs (2009 −24, 2019 −26, 2023 −21 pp vs SPY), 2025 −15 % (MMYT gain marked 2024; stop-outs). Stops already fill at the resting level (`sim_stop_exit_fill_on_trigger_bar true` = #2961 fix is ON): ~82 % fill within 1 % of the stop; only 12–13 real gaps / ~$1M per salt — `gap_down` label is a misnomer, #2961 is NOT a lever (corrected 10-01). **Barbell already closed on broad** (06-27 ledger `2026-06-27-barbell-floor-sweep`: timing floor no free lunch; buy-hold SPY sleeve positive but USER DECLINED on faithfulness — idle-cash sleeve = same passive allocation, needs a new user decision, do not re-propose as a test; [[project_barbell_on_stocks]]); NOT ticket resizing ([[project_concentration_deploy_probe_reject]]).

**10-02 regime split + review pack:** artifact https://claude.ai/artifact/YPxRVNbDqpmWJMJjTxJEJN. In SPY UP regimes (67 % of days) the preset beats SPY (+11.3 vs +10.3 %/yr, 63 % exposure); in MIXED +0.3 vs −4.5. The SPY gap is all DOWN regimes: SPY makes +10.3 %/yr there because lagging DOWN labels cover V-rebounds (2003, 2011, 2015, 2019, 2020, 2022, 2025), and the preset is ~14 % invested. That whole-window read is superseded BY PERIOD: s0 was 1.30× SPY at end-2024 and 0.90× by mid-2026. 2025–26 UP days: SPY +23.1 % vs −19.9 % (53 % exposure). There were 36 stop exits with 4 winners (−$2.11M); AD −29 % and TNXP −25 % gapped through ~5 % stops (−$564k). MMYT's +$1.1M realised in 2025 had already been marked in 2024. 2018–23 eroded 1.91 → 1.07 inside UP regimes. Equal-weight benchmark (RSP/IWM) not yet in the data store ([[feedback-exposure-vs-market-condition]]).

**10-03 recovery re-entry gap:** the local-range anchor (4/13/26 w) dilutes the investor preset 6/6 (5d + 5r); the 2009 gap on THIS preset is `No_structural_stop` skips (floor > 15 % away after a crash), and filled recovery entries whipsaw. Base-bounded anchor ruled out by screen; 2025 lag = picks. See [[project_recovery_reentry_gap]].
