# Container run queue (started 2026-09-26)

One backtest at a time (`container-capacity-scheduling.md`). Updated as items start and finish.
Times PT. Status: RUNNING / QUEUED / DONE / PROPOSED (needs a decision).

| # | Status | Item | Cells | Est. wall | Why |
|---|---|---|---|---|---|
| 1 | RUNNING | obvious-fixes chain A: `f2-fills-faithful` s1 DONE (106.54 %, 6h16m), s2 running since 15:39, then `f1-stoplimit-fresh` s0 (26y) | 2 left × 5.3–6.3 h | ends ~03:30–04:30 09-27 | salt band for both fixes; f1 separates Fix A from Fix B |
| 2 | QUEUED (auto-launch when #1 ends) | build pinned `sweep-investor` @ 1c2647743 (has #2966) | build | ~10 min | `require_structural_stop` is not in the #1 build |
| 3 | QUEUED (auto) | 5y broad investor preset vs hybrid control, 2021-06 → 2026-06, salts 0/1/2, V6-paired | 6 × ~1 h | ~6 h, to ~10:00–11:00 09-27 | first investor-only number on the broad universe (user 09-26) |
| 4 | PROPOSED | 26y investor preset, s0 | 1 × ~5.5 h | | long-window investor number (periodic) |
| 5 | PROPOSED | single delta on the 26y hybrid: `require_structural_stop` only | 1–3 × ~5.5 h | | isolates the stop rule inside the hybrid |
| 6 | PROPOSED | re-measure `enable_entry_ticket_rescreen` on the fixed sim (#2976) | 3 × ~5.5 h | | resting tickets fill in Bearish weeks (14 % of fills); REJECTED 08-18 on the old sim |
| 7 | PROPOSED | investor-preset golden in `goldens-custom-universe-scenarios` (weekly tier 3) | CI | | keep a 5y investor number tracked over time |
| 8 | FREE (read from #1 + #3) | scaling read: s/yr of the `inv5-hybrid` 5y cells vs the `f2` 26y cells (same settings, near-identical code; the first PIT 5y measurement) | 0 | | is 26y ≈ 5.3× 5y on the PIT schedule? (user 09-26) |

Not container work (no queue slot) — the full issue list is §3 of
`../obvious-fixes-2026-09-25/salt0-analysis.md`:

| issue | what | kind |
|---|---|---|
| #2974 | trailing stops rarely rise: trace faithful 8 % rule vs defect | read-only analysis |
| #2975 | installed stop ≈ half of the audit's `suggested_stop` | code trace |
| #2976 | resting tickets fill in Bearish weeks | queue item 6 |
| #2977 | record weekly stop decisions in `trade_audit` | harness |
| #2978 | `review_pack.sh --no-container` sed noise | harness, small |
| #2973 | split corpus + one basis test suite | harness |
| — | walk 2000–20 and 2024–26 | read-only, `walk.sh` |
| — | laggard-rotation exits of names that keep rising | open question |

## Investor preset = the f2 hybrid minus its trader dials

| dial | hybrid (record) | investor preset | authority |
|---|---|---|---|
| initial stop with no support low | automatic 4 % (`Buffer_fallback`) | skip the entry (`require_structural_stop`) | Ch. 6 "investors should never use automatic percentages"; "prefer other candidates" past ~15 % risk |
| Stage-3 exit | `enable_stage3_force_exit`, 1-week hysteresis | off: hold to the trailing stop (Stage 3→4) | presets plan: trader gets out as the Stage-3 top forms |
| overextension sell | `extension_stop_config` 2.0× MA / 25 % trail | off | Ch. 6 lists it under the *mixed* approach, not the investor's way |
| fast-crash stop | `catastrophic_stop_pct 0.10` | off | an automatic percentage |
| resting entry orders | never expire (`max_rest_weeks 0`) | default 52 w | ledger ACCEPT #2587 |
| laggard rotation | on | **on** | Ch. 4 "lighten up on that position even if the sell-stop isn't hit. Move the proceeds into a new Stage 2 stock" |
| 30-week MA, base breakouts, full size on breakout | same | same | scale-in (half on pullback) is not built (NO-BUILD memory) — known gap |
