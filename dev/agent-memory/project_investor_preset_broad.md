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
