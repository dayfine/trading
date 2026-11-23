---
name: project-nav-scale-participation
description: "USER 11-22 NAV-scaled liquidity run DONE 11-23 (#3704): P-100k and P-1M INCONCLUSIVE, P-10M −0.74 capacity; cap off by default"
metadata:
  node_type: memory
  type: project
  originSessionId: 4d3e3170-bdbe-449b-b0b1-b2b366fa3e92
  modified: 2026-11-23T09:32:05.025Z
---

User 2026-11-22: "run two variants of sims, 1000k vs 100k starting fund (and maybe 10kk) … different position size and thus different impact threshold", then "the rules are not fixed based on starting fund, but should scale with current portfolio value".

**Built (11-22/23):**
- #3695: `max_entry_adv_participation`, default off; blocks, never resizes. Sized from CURRENT NAV (test "walk: cap scales with current NAV"). The picks' `Participation_gate` sizes from `--portfolio`.
- #3698: `WEEKLY_PROFILE=live-size` (universe ADV floor $100k, participation 0.10, entry dust floor $100k, hold floor $50k) in `dev/weekly-picks/live-size-overrides.sexp`.
  - The picks never ran the $1M entry floor. The universe floor in weekly.sh was the real cheap-name blocker.
  - The hold gate is not position-scaled yet (`max_hold_adv_participation` is the remaining item on #3693).
  - 10-23 under live-size added only GRDX.
- #3697: scenario `initial_cash` (default 1M).

**Experiment** `dev/experiments/nav-scale-participation-2026-11-23/` (prereg #3699, merged 44f1ba28e):
- 6 arms × rk-k0..4. P arms append the live-size lines AFTER the record overrides (later wins; prepending would make P ≡ F).
- 5-verdict rule: PASS / PAYS-WITH-RISK / HARM / INCONCLUSIVE / DEAD-INVALID.
- Cloud triggers nav-scale-k0..k4: trig_01SoBuVpyWCkFCAwbXzMVeke, trig_01FBQpKpkipePZo4pP94ZaUE, trig_01Hno8Zn7zRzCN9jFsMBPyYk, trig_01JYjdRpvXpzuhHtAZqugxqc, trig_01PrBxDdya1RAFKHMZKTEnK1.
- Each session takes ~10–12 h and pushes its public half to branch `experiment/nav-scale-kK`, price-bearing files to trading-results.

**How to apply:**
- After all five sessions finish, assemble one results PR.
- `results-analyst` drafts the read: measures 4 and 5 are computed from trades.csv + bars, P and F trades are joined by symbol and entry date, and P-1M DEAD/INVALID ≠ INCONCLUSIVE.
- `qc-results` reviews the PR. Close the #3681 and #3693 verify items from it (done in #3704; #3693 with the 2000–08 live-size caveat).
- Related: [[project-trait-y-low-price]], [[project-weekly-picks-backfill]].

**RESULT 11-23 (#3704, READ.md, ledger 2026-11-23-nav-scale-participation):** P-100k INCONCLUSIVE (median Δ +0.002, 3/5), P-1M INCONCLUSIVE (−0.024, 2/5) → closes #3681 verify "no effect at backtest NAV". P-10M −0.62…−0.98 all seeds (capacity: ADMA at 54–88 % ADV). At $100k the cap removed no trade; the $100k floor added ~6 non-doubler names/seed; No_structural_stop takes back 238/249 sub-$1M-ADV rows. #3693 verify closes with caveat: P-100k positions live-sized (median $9.3–13.2k) only over 2000–08 (~140 trades/seed); 2009+ grow to $22–94k. Next: universe depth ([[project-universe-depth-audit]]).
