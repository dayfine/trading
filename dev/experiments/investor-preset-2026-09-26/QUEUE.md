# Container run queue (started 2026-09-26)

One backtest at a time (`container-capacity-scheduling.md`). Updated as items start and finish.
Times PT. Status: RUNNING / QUEUED / DONE / PROPOSED (needs a decision).

| # | Status | Item | Cells | Est. wall | Why |
|---|---|---|---|---|---|
| 1 | RUNNING → PAUSE | obvious-fixes chain A: `f2-fills-faithful` s1 DONE (106.54 %, 6h16m); s2 running since 15:39 (week 858/1,434 at 19:08), ends ~21:30–22:00 09-26. A watcher then stops the chain BEFORE `f1-stoplimit-fresh` s0 (user 09-26: land code changes + unit tests first) | s2 only | ends ~22:00 09-26 | salt band for both fixes |
| 1b | QUEUED (after the code wave merges) | `f1-stoplimit-fresh` s0 (26y): on the old `sweep-fixes` build, or the new main if #2977 is goldens-identical | 1 × ~5.5 h | | f1 separates Fix A from Fix B |
| 2 | QUEUED (manual, after the code wave) | new pinned worktree at post-merge main; `BUILD=1 PREFLIGHT=1 EXPECT_HEAD=<new sha> WTREL=<new wt> sh chain-investor.sh I …` (`launch-after-A.sh` is superseded by the pause) | build + preflight | ~20 min | PREFLIGHT runs each spec on 2026-04..06 and aborts on a missing actual.sexp |
| 3 | QUEUED (after 2) | 5y broad investor preset vs hybrid control, 2021-06 → 2026-06, salts 0/1/2, V6-paired | 6 × ~1 h | ~6 h | first investor-only number on the broad universe (user 09-26) |
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

## Item 3 — pre-registered reading rule (written before launch)

Item 3 is a **preset comparison, not a promotion test**: no default changes whatever it shows
(a default flip would need an ACCEPT plus the confirmation grid, `promotion-confirmation.md`).

- **Gate:** every investor cell must pass `validator_diff -check V6` against its hybrid pair at the
  same salt. A failing salt is reported and left out of the reading.
- **Metrics, per salt:** Calmar (primary), max drawdown, total return, trades; plus the paired
  per-salt difference investor − hybrid.
- **"Investor preset promising"** if the investor Calmar ≥ the hybrid's in **at least 2 of 3** salts
  **and** its max drawdown is never more than 5 pp worse than the hybrid's at the same salt.
  → next step: queue item 4 (26y investor) and a broad-vs-broad grid cell.
- **"Investor preset worse"** if the investor Calmar is lower in at least 2 of 3 salts.
  → keep it as a preset, record why (which dial: skipped entries without a structural stop, or no
  Stage-3 / extension exits), and do not queue item 4 on this basis alone.
- **Otherwise "no difference at this power"** (3 salts, a 5y window): record it descriptively.
- Whatever the outcome, decompose it: entries skipped by `require_structural_stop` (count and what
  the hybrid made on them), and exits the hybrid took via Stage-3 / extension / catastrophic stops
  that the investor held.

Runtime: `chain-investor.sh` logs GNU-time peak RSS and the snapshot-cache line per cell (queue
item 8). The obvious-fixes chain (`chain-fixes.sh`) was already running when this was added, so
its cells record wall time only.
