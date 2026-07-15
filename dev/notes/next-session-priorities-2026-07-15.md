# Next-session priorities — 2026-07-15

**Supersedes** `next-session-priorities-2026-07-14.md` (its P0/P0b/P1 are ALL
DONE; P2 carried below). Main green.

## What the 07-14 session shipped (context)

Eleven merged PRs + three labeled 28y runs + two NO-BUILD screens:

1. **P0 arming package (#1960)**: ledger insurance-ACCEPT for
   extension_stop(2.0,0.25) + record-convention staged scenario + live
   `--config-overrides` (new generator flag) + sp500 do-no-harm cell
   (bit-identical, 0 firings — broad-tail-only mechanism).
2. **#1955 owl-SIGILL lottery KILLED**: root cause = weekly CI-image rebuild
   baking `-march=native` owl on an AVX-512 host; fix #1961 (OWL_CFLAGS
   x86-64-v2 pin + image objdump gate, NO PAT needed). Watchdog #1958 closed.
3. **P0b long-exposure cap (#1965)**: `max_long_exposure_pct_entry`
   (entry-denominated, no-op default) at the entry walk; margin convention
   pinned. Run-E re-run: cap verified (3,427 skips), shorts ≈$0 direct AGAIN,
   E-capped's +13,730% vs D +7,914% decomposed = small throttle (+591pp,
   NO-surface per W2 — equity-curve trigger unfaithful) + sizing lottery
   (same AXTI entry, 1.7× ticket from 26y path divergence). **Long-short ≈
   long-only + noise; Run D remains the record.**
   `dev/notes/rune-capped-2026-07-14.md`.
4. **Run D COMMITTED as record of record** (user 07-14): +7,914% MTM /
   $70.9M realized / Sharpe 0.83 / CAGR 18.0% / MaxDD 32.3% (dedup-v2, armed
   convention). DEEP_RESULTS §RECORD OF RECORD.
5. **P1 resistance-history feed (#1966)** + armed 28y run: **the false
   virgins were LOAD-BEARING** — honest 520-bar grades systematically demote
   crash-recovery breakouts (DDD/SKYW/BFX $12.1M in D → ≈$0 armed; AXTI
   ticket $25.8M vs $67.3M), armed run +3,584% / MaxDD 49.1%. Honest virgin
   ≈ no signal. Backtest record stays UNARMED; live stays armed for text
   honesty (flagged). `dev/notes/resist520-armed-run-2026-07-14.md`.
6. **Audit report v2 (#1971)**: per-trade chart cards (price+WMA30+stops,
   entry−1y→exit+6mo) + composite quality score (grade chips, components).
   Artifact: `trading/dev/backtest/audit_runD_charts.html`.
7. **MA horizon-slope gate: NO-BUILD** (P1.5 screen on the full record
   cohort): every horizon×threshold cell forfeits $65-91M of the $95M winner
   mass to avoid $5-20M of losses (≥4:1 against). F/D cohort = clean whipsaw
   (conformance flat across grades). CLOSES the trend-context-gate class on
   realized data. `dev/notes/f-cohort-slope-screen-2026-07-14.md`.
8. Branch cleanup (36 stale deleted; 7 orphan budget records rescued via
   #1964); memory snapshot refreshed; margin plan committed
   (`dev/plans/levered-longshort-margin-realism-2026-07-14.md`).

## P0 — resistance-v2: continuous supply score on precomputed PIT top-sketches

The night's main directive (user-aligned). Motivation: finding (5) — the
binary virgin grade fed honest data taxes the tail; the arbitration is a
CONTINUOUS score whose weight WF-CV can search, plus a perf substrate that
kills the 5h wall.

1. **Warehouse sketch columns** (snapshot-format extension, build-time): per
   symbol-week (a) rolling max-high family (520w/260w/130w → virgin horizon
   gradient), (b) ~20-bucket log-price trailing histogram of the 130w window.
   Format-version bump + builder + reader.
2. **Score**: `supply(breakout) = Σ zones above × bars × age_decay ×
   proximity` — from the sketches, O(1) per query. Letter grades derivable
   (back-compat); score/display SPLIT resolves the live-arming tension
   (honest text, searchable ranking weight).
3. **WF-CV the score-weight axis** (including weight=0 = today's behavior) —
   where "were the false virgins luck or structure" gets a fold-honest
   answer.

Write the plan doc FIRST — multi-PR track (format bump needs care).

## P1 — levered long-short margin realism (plan committed)

`dev/plans/levered-longshort-margin-realism-2026-07-14.md` — M1 long buying
power (generalize the #1965 cap seam; priced margin interest), M2 long-side
maintenance force-reduce, M3 short squeeze gaps (borrow availability, HTB
rate/maintenance tiers, buy-ins), M4 validation (parity → squeeze windows →
WF-CV surface + bear-cell grid). User framing: short leg needs HONEST COSTS,
not standalone edge (hedge-shaped value suffices).

## P2 — research queue (carried from 07-14, unchanged)

- Trader-preset bundle audit + WF-CV (presets as wholes, W3).
- Floor-quality P1b step 3: SPY-sleeve lens screen vs TR-SPY
  (`Breaker_spy_sleeve` merged; `(strategy (Breaker_spy_sleeve (symbol SPY)))`
  vs `(Bah_benchmark (symbol SPY))`, spy-only universe, per-episode table).
- decision_audit Phase-2 forward-return counterfactual.
- P3 grind-weeks exposure; P4 faithful per-week universes (carried).

## Lower-priority / follow-ups

- Advisory QC nits from #1971 (loser-credit slope test; 7-day join constant
  triply duplicated — expose one constant; same-symbol-within-7d join
  bijection guard).
- Verify the armed-run grade-shift claim directly from audit records (was
  inferred from the trade-set diff).
- ci.yml owl objdump smoke line (PAT-gated, optional — image gate covers it).
- V6 allowlist, CY stale re-entry, ATB.curated live universe, sector feed
  (carried from 07-14).

## Standing constraints (additions from tonight)

- Trend-context entry gates (MA horizon slope, weeks-above-MA) are CLOSED on
  realized-cohort evidence — new entry-side proposals must first report
  their blocked-winner $ share on the record cohort (jq over the audit HTML).
- `max_long_exposure_pct_entry` stays an accounting convention (long-short
  runs at 1.0), NEVER a return lever (W2: equity-curve trigger unfaithful).
- `resistance_lookback_bars` stays OFF in backtest conventions until
  resistance-v2's WF-CV arbitrates; live keeps it armed for text honesty.
- progress.sexp `trades_so_far` counts LEGS (~2× round trips) — don't read
  it as round trips mid-run.
- Container long runs solo (re-learned: an orphaned dune from a killed task
  shared the container with a 28y run; TaskStop kills the docker-exec
  client, NOT the in-container process — pkill the pid inside).
