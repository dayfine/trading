# Next-session priorities — 2026-07-17

**Supersedes** `next-session-priorities-2026-07-16.md`. The 07-16→17
continuation session finished the ENTIRE resistance-v2 program through its
confirmation grid, shipped margin M1a, and certified the v3 warehouse.
Main green, 0 open PRs at handoff time (this docs PR excepted).

## What the 07-16→17 session shipped

- **#1989 live path** (Live_resistance_sketch + weekly-review score/display
  split, default-off) and **#1990 margin M1a** (Long_buying_power ceiling +
  priced margin interest, R1 no-ops) — both 3-gate merged, built by two
  parallel feat agents in isolated workspaces.
- **v3 warehouse CERTIFIED**: baseline 28y on dedup-v3 = **+7,914.318…% =
  Run D to 13 decimals** (`scenarios-2026-07-16-131756`). dedup-v2 dir
  deletable.
- **PR-E home surface** (07-16, ledger
  `2026-07-16-resistance-supply-weight-surface`): Inconclusive, boundary
  winner, false-virgins-were-luck.
- **Confirmation grid** (07-17, ledger
  `2026-07-17-resistance-supply-confirmation-grid`): **3/3 CONFIRM,
  mechanism ACCEPT.** Home curve concave, peak w≈45 (.897), rolloff at 60;
  sp500 cell confirms (w15 .623 vs .396); 2011 cell confirms (w30 .825 vs
  .619, fold-σ .566→.223). **Robust value w=30.** Full analysis:
  `dev/notes/resistance-supply-grid-2026-07-17.md`.
- **AXTI forensic** (the why): 28y single-path w30 +1,991% vs +7,914% —
  the penalty correctly demotes crash-recovery breakouts (AXTI 2025:
  97/130 recent weeks overhead at $2.18), and redeemed names are
  stale-inadmissible by the time they clear supply. Supplied monsters:
  denied at birth, stale at redemption.

## P0 — margin M1b (user-directed: margin is the next build focus)

`dev/status/margin-realism.md` Follow-ups + plan §M1: the entry-walk
cash-gate relaxation that lets a fractional `initial_long_margin_req`
actually create a debit balance, + per-tick simulator interest accrual.
Then M2 (maintenance force-reduce), M3 (short squeeze mechanics), M4
(validation: parity → squeeze windows → WF-CV + bear grid). All default-off.

## P1 — resistance-v2: promotion decision (HUMAN-GATED) + designed levers

Mechanism ACCEPT is recorded; **do not flip `w_overhead_supply` without
the user.** The flag: fold means all favor w=30 but the 28y terminal
wealth is ¼ of the record (the crash-recovery lottery cohort). Decision
inputs: (a) rolling-start terminal-wealth distribution (many paths, not
one draw); (b) possibly build the **virgin-crossing re-admission** lever
first (restores AXTI-class access; book-faithful new-high entry). Five
levers designed default-off in `dev/status/resistance-v2.md` §Next-steps 3.

## P2 — research queue (carried)

- Trader-preset bundle audit + WF-CV (presets as wholes, W3).
- Floor-quality P1b step 3: SPY-sleeve lens screen vs TR-SPY.
- decision_audit Phase-2 forward-return counterfactual.
- P3 grind-weeks exposure; P4 faithful per-week universes.

## Standing constraints (operational lessons of 07-16/17)

- Warehouses of record: `/tmp/snap_top3000_dedup_v3_sketch` (top-3000) +
  `/tmp/snap_sp500_2000_2026_v3_sketch` (sp500). Old-schema warehouses are
  unreadable by current binaries (schema gate) — no cheap cross-version
  diff; certify by golden reproduction instead.
- Long container jobs: DETACHED + file log + `exit:$?` marker; reaped
  docker-exec clients wedge dune (0% CPU) and `kill -9` on dune corrupts
  `_build/.db` (rm it + rebuild). `dune exec --no-build` breaks after a
  db reset — prebuild explicitly in chain scripts.
- Chained stage scripts: verify the WORKING COPY the container sees holds
  the spec files before launch (a jj commit switch emptied a stage's spec
  once); markers can be lost if the writing wrapper dies — a manual
  `echo exit:0 >>` unsticks a stage-0 waiter after verifying completion.
- PRs: DIRTY mergeState runs no workflows; `gh pr update-branch` loop for
  moving main; `jj describe --reset-author` for "no committer" push
  rejections; linker `collect2` failures on untouched exes = rerun-once
  infra flakes.
- `w_overhead_supply`/`overhead_supply` stay default-off pending the human
  promotion decision; live keeps `resistance_lookback_bars 520` armed for
  text honesty.
