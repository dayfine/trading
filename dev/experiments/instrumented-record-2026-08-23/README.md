# Instrumented record-convention paired run — 2026-08-23/24

One 26y broad run, paired arms, three analyses (#2486 / #2489 / #2490). Build:
main `2b11c60dd` (params.sexp per arm committed — the provenance gap that made
#2503 hard to pin is closed here). Warehouse `/tmp/snap_top3000_dedup_v5thin_adj`
(mtimes 07-28), universe `top-3000-2000.sexp`, `--parallel 1` sequential arms,
`--emit-candidates` on. Chain: `run_chain.sh` (pinned worktree
`.claude/worktrees/sweep-instr-0823`).

| arm | config | return | trades | Sharpe | MaxDD | Calmar |
|---|---|---:|---:|---:|---:|---:|
| instr-null | grid1-null verbatim (freeze active) | 243.06% | 1182 | 0.426 | 24.48 | 0.195 |
| instr-unfreeze | + `stops_config.reset_anchor_on_stalled_cycle=true` (#2492) | 381.46% | 1178 | 0.520 | 28.44 | 0.215 |

## Finding 1 — #2486 ratchet freeze CONFIRMED on real data (arm 1)

- Fallback stop = **88.7% of entries** (1,621/1,827 `Buffer_fallback`).
- Closed-trade ratchet rate: fallback **1.1%** vs support-floor **17.1%**.
- Held ≥13wk: **9% vs 49%**; ≥26wk: 17% vs 53% — same tape, correction
  scarcity ruled out; the anchor deadlock (#2492's invariant) ate the cycles.
- 861/1,018 fallback trades (85%) exit `stop_loss` clustered at the initial
  ~2% width (median −1.71%, IQR −3.0…−0.2). Only 11% of fallback trades
  survive 13 weeks (vs 34% support-floor).
- Book verdict (PR #2498): artifact, not faithful — anchor must advance per
  completed cycle.

## Finding 2 — the unfreeze's per-trade effect is ~NIL; the +138pp is the lottery

Paired per-event join (`symbol|entry_date`, 949 shared entries = ~80% of each
arm): **937/949 bit-identical pnl%**, 12 differ, mean Δ −0.005pp. The flag
raised stops on only 18 fallback positions (vs 11 in the null; ≥13wk rate
9%→16% — it helps only from the *second* completed cycle, structural stops
raise on cycle one), and those raises almost never changed the exit.

The +138pp top-line is **composition**, not mechanism: CLS 2023-07 (+$774k,
218%, 8 raises, laggard_rotation exit) exists only in the unfreeze arm —
entered because of upstream cash-path divergence, the same monster that flipped
the funding grid (`project_funding_grid_monster_lottery`). One monster ≈ 66pp;
the delta is inside/at the 132.5pp 26y noise floor once the lottery is removed.

**Verdict input, not a verdict:** the flag is book-faithful and per-trade
harmless; its top-line "gain" is not evidence. Promotion, if wanted, goes
through the normal surface → WF-CV → grid pipeline
(`experiment-flag-discipline` R3 / `promotion-confirmation`).

## Finding 3 — the record basis MOVED (issue #2503)

`instr-null` (identical config/data/warehouse to the recorded grid1-null
baseline) diverges from the first weeks of 2000: 305.25%→243.06%, 1270→1182
trades, MaxDD 39.10→24.48. From-day-one decision-path change between ~08-22
main and `2b11c60dd`; suspects #2492 (floor_stop refactor — prime), #2500,
#2501. Bisect plan in #2503 (6-month probes at three builds). Until resolved,
no absolute comparison across the 08-23 boundary; within-build pairs valid.

## Artifacts

- `results/<arm>-{actual,params,summary}.sexp`, `<arm>-trades.csv` (23 cols —
  incl. `max_stop`, `n_stop_raises`; join key `position_id` col 20).
- `results/<arm>-floorkind.tsv` — derived `position_id → stop_floor_kind` join
  table (from trade_audit entry_decision).
- NOT committed (size): `trade_audit.sexp` (~13MB/arm), `candidates.sexp`
  (~519MB/arm) — live in the pinned worktree
  `.claude/worktrees/sweep-instr-0823/trading/dev/backtest/scenarios-2026-08-24-013206/`
  **which must be preserved until #2489/#2490 analyses complete**.

## Open follow-ups

- #2503 bisect (P1) — container free now.
- #2489 representative-trade audit + #2490 monster capture funnel — all inputs
  on disk (candidates.sexp per week per candidate with cascade outcomes).
- #2486 decision items (§2.1 `initial_stop_buffer` flip; flag promotion path).
