# Breadth-tier presets (universe-dependent strategy knobs)

**Status:** design note + first two members. Motivated by the 2026-06-27/28
finding that some strategy knobs are **breadth-dependent** — they help on a broad
universe and fade to inert (or hurt) on narrow large-cap universes — because the
phenomena they target live in the **small / deep / delisting tail** that only a
broad universe contains.

This extends the existing **preset** concept (the trader/investor presets in
`weinstein-trader-investor-presets-2026-05-31.md` are config bundles applied via
`config_overrides`) to a **universe-breadth dimension**. A breadth-tier preset is
the *same parameterized Weinstein strategy* — the **spine is identical**
(`weinstein-faithful-core.md`); only breadth-sensitive **dials** change by
universe tier. No new machinery: it's a documented `config_overrides` bundle.

## The preset table

| knob | broad (≈top-3000) | large-cap (≈sp500 / top-1000) | why it's breadth-dependent |
|---|---|---|---|
| `reject_declining_ma_long_entry` | **true** | false (no-op anyway) | Misclassified Stage-2 entries (Stage-4 dead-cat bounces, illiquid junk) only occur in the small/deep/delisting tail. WF-CV grid (`_ledger/2026-06-28-declining-ma-gate-grid`): do-no-harm everywhere; **helps only on top-3000** (2018-19 fold −0.25→+0.21 Sharpe), inert on sp500/top-1000. |
| `max_position_pct_long` (concentration) | **0.30** | lower (~0.14) | 0.30 dominates broad long windows + aggregate but **hurts narrow windows** (`project_deep_goldens_conservative_vs_default`: bull-crash 38→10%, six-year 19→4%). The fat-tail it amplifies needs breadth to exist. |
| *(future breadth-sensitive knobs)* | … | … | add as the experiment program finds them |

## Decision rule for adding a member
A knob joins the broad preset only when a **WF-CV universe grid**
(`promotion-confirmation.md`) shows it is **do-no-harm or better across cells** and
**meaningfully helps on the broad cell** — i.e. it failed the *global* default-flip
bar (benefit not in a strong majority of universe cells) **but** is validated as
safe-and-helpful specifically on broad. This is the precise profile of the
declining-MA gate: a global flip would re-pin all universes' goldens for an inert
change on the narrow ones, whereas arming it in the broad preset captures the
benefit where it's real.

## How it's applied
Broad-universe scenarios / the broad deployment config set the broad-tier
overrides; large-cap scenarios omit them (or set the large-cap values). The global
strategy `default_config` stays at the conservative/large-cap-safe defaults
(declining-MA gate **off**), so non-broad goldens and any large-cap deployment are
unchanged. The broad preset is opt-in, exactly like the trader/investor presets.

## Honest caveat on magnitude
The breadth-dependent knobs found so far give **modest, regime-concentrated**
benefits (the declining-MA gate is fast-crash tail-insurance; concentration is a
fat-tail amplifier with a return-for-robustness tradeoff). Single-window broad
*total-return* numbers are heavily terminal-MTM
(`project_broad_universe_790_mtm_inflated`) — the WF-CV fold-means are the honest
signal. The broad preset is "use the right dial for the universe you trade," not a
new alpha source.
