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
