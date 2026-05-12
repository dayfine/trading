# Plan — Norgate / longer horizon / broader universe — 2026-05-12

Forward-looking note. NOT a decision; surfaces options + tradeoffs for the
data-foundations track.

## Where we are today

| Aspect | Today |
|---|---|
| Data source | EODHD only (38,050-symbol inventory) |
| Universe construction | Point-in-time snapshots (survivorship-biased) |
| Longest production scenario | 10y (`decade-2014-2023`, N=1,000) |
| Longest capacity-only scenario | 30y (`sp500-30y-capacity-1996`, N=1,000, survivorship-biased) |
| Bar loading | mmap'd Panel_snapshot; pre-built per scenario |
| Memory budget on dev container | ~7.9 GB; cells use ~1.7 GB each; `--parallel 3` ceiling |
| Norgate integration | Referenced in M5.3 placeholder; **not started** |
| Sharadar / CSI / other | Not catalogued |
| Historical SP500 membership | Design exists, **not implemented** (`dev/notes/historical-universe-membership-2026-04-30.md`) |

## Three axes, three decisions

### Axis 1 — Source switch (EODHD → Norgate)

**Drivers.**
1. Survivorship-bias-free universes (Norgate's NDU exposes "Russell 3000
   1980–today" with delisted constituents in-place).
2. Adjusted-bar quality: corporate-actions handling is reportedly more
   defensible than EODHD's split-day OHLC (we already filed `#656` for
   broker-model split handling).
3. Self-hosted vs API-rate-limited: NDU updates on a daily local cron, so
   no per-call quotas during sweeps.

**Costs.**
- $25–50 / month subscription.
- NDU runs only on Windows; we'd need a sidecar VM or a separate ingestion
  host.
- New `DATA_SOURCE` adapter (~300 LOC OCaml + a Bash wrapper to call NDU's
  CLI export). Decoupled by the existing
  `Storage.HistoricalDailyPriceStorage` module type, so the strategy +
  backtest engine don't change.

**Decision frame.**
- If the next major investment is **15y-30y full-universe backtests with
  survivorship-aware membership**, Norgate's cost-benefit becomes positive
  fast — EODHD's ~33 reassigned ex-SP500 tickers (`data-gaps.md` lines
  139–199) need manual `_old` suffixing per ticker, and ACE is unfetchable.
- If the next major investment is **live trading**, switch on Norgate's API
  reliability story alone (we shouldn't bet a live system on EODHD's
  free-tier outages).
- If the next investment stays **smoke / golden surfaces**, EODHD remains
  fit-for-purpose.

**Recommendation.** Don't switch yet. Land historical-SP500 membership +
survivorship-aware screening (Axis 2 below) on top of EODHD first — that
re-exposes the real value gap (clean adjusted bars on full long-window
universes). Re-evaluate Norgate post that landing.

### Axis 2 — Longer time horizon (10y → 15y → 30y)

**Status.**
- 10y `decade-2014-2023` is the current flagship; release-gate (perf-tier 4).
- 15y references in `next-session-priorities` are diagnostics on cell-E
  configurations, **not** production goldens. No 15y scenario is wired into
  the goldens directory.
- 30y `sp500-30y-capacity-1996` exists but is capacity-only —
  survivorship-biased and explicitly NOT compared to baselines.

**Path to a real 15y production goldens.**
1. Build the 2010-01-01 → 2025-04-30 universe from delisted+current
   constituents.
2. Re-run + pin baselines on the current `sp500-2010-2026` scenario
   (`goldens-sp500-historical/`) — it covers ~16y but uses a static
   2010-01-01 universe (survivors of that date). Closest existing thing
   to a real 15y production goldens.
3. Add `sp500-2010-2025` per the same pattern, with 510-symbol point-in-time
   universe. Done as a P0/P1 follow-on under the data-foundations track.

**Path to a real 30y goldens (survivorship-aware).**
1. Wire the design in `historical-universe-membership-2026-04-30.md`:
   - Pinnacle/EODHD-based point-in-time membership table (year-by-year
     deltas).
   - Screener pre-filter that drops a symbol from a Friday's candidate
     pool if it wasn't in the index on that date.
2. Re-run `sp500-30y-capacity-1996` with the survivorship-aware universe.
3. Pin new baselines. 30y goldens become production.

**Memory.** At N=1,000, T=10y, RSS ~5 GB peak. T=30y at the same N is
~12–15 GB (linear in T, per cost model). Doesn't fit GHA 8 GB ceiling.
Production 30y runs are local-only. Tier-4 release-gate stays local.

**Recommendation.** Bring 15y production into the goldens fold next
session — high payoff, no new infrastructure, just universe-pinning +
golden-regen. 30y survivorship-aware is the next phase after that.

### Axis 3 — Broader universe (SP500 → Russell 1000 / 3000)

**Constraint.** Snapshot memory is `O(N · T)`. Doubling N at fixed T
doubles RSS. Doubling T at fixed N doubles RSS. To run 30y × 3000 symbols
in one snapshot: ~45 GB. Not feasible on local hardware.

**Sharding paths.**
1. **Universe-chunked snapshots.** Split a 3000-symbol universe into 3
   chunks of 1000; run separately; merge trades into a single trade ledger.
   Strategy doesn't currently support cross-snapshot portfolio state — would
   need either a "merge portfolio across snapshots" step or a streaming
   bar-reader.
2. **Streaming bar-reader.** Replace mmap'd Panel_snapshot with a per-day
   streaming load. Removes the O(N·T) memory ceiling but adds I/O latency
   per bar lookup. The `Bar_reader` interface already wraps the snapshot,
   so the swap is internal.
3. **Time-chunked snapshots.** Run 30y as 3 × 10y chunks, threading
   portfolio state across chunks. Simpler than chunked-universe (portfolio
   state IS already serializable) but requires careful warmup-overlap +
   trade-deduplication.

**Recommendation.** Don't broaden universe yet. The screener-weight grid
result (2026-05-12 81-cell run) shows the strategy is bottlenecked on
**screener cascade design**, not universe breadth. Broadening the
universe without first re-tuning the cascade just gives the cascade more
similar-shaped Stage 2 candidates to rank, which the weight axis has
been shown to be inert on.

## Recommended sequence (next 1–2 weeks)

1. **Land historical-SP500 membership.** Per the existing design doc.
   Unblocks survivorship-aware 15y and 30y backtests.
2. **Cut 15y production goldens** on the 2010–2025 window, with PI
   membership pre-filter. Pin baselines.
3. **Park Norgate.** Re-evaluate when (a) live-trading prep starts OR
   (b) we genuinely need pre-1996 history.
4. **Park broader universe.** Re-evaluate when (a) screener cascade is
   re-tuned per the 81-cell grid finding OR (b) we run out of axes to
   sweep on SP500.

## Cross-references

- Data layer survey: this session, in-conversation; sources cited inline
  above.
- 81-cell grid result: `dev/experiments/grid-screening-weights-2026-05-12/report.md`
- Historical membership design: `dev/notes/historical-universe-membership-2026-04-30.md`
- Data gaps inventory: `dev/notes/data-gaps.md`
- Cost model: `goldens-broad/sp500-30y-capacity-1996.sexp` line 29
