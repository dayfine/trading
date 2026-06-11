# Universe-composition policy (explicit, flag-driven, additive) — 2026-06-11

Source priority: `dev/notes/next-session-priorities-2026-06-11-PM.md` §P1.

## Problem

The real tradeable US universe is ~3,500-4,500 operating companies (Ritter/CRSP:
~3,650 operating companies). The ticker-count gap up to ~5,600 (looser ~8,000) is
**dual-class duplicates + ADRs + REITs + SPACs/warrants/units/preferreds/CEFs** —
mostly not stage-tradeable.

Our current PIT top-{500,1000,3000} compositions (`Build_from_individuals`) already
drop ETFs / Mutual_funds / Funds / Bonds via `Asset_type.is_equity_like` (keeps
Common_stock / Preferred_stock / ADR / GDR). But they:

1. **Do NOT dedup dual-class** — GOOG+GOOGL and BRK-A+BRK-B can both be ranked into
   the universe, so the screener can hold both classes as two positions of one
   economic entity (latent over-concentration bug).
2. **Include all REITs** (SPG / O / PLD / AMT) with no explicit policy flag.
3. **Include all ADRs** (TSM / ASML and the small illiquid tail) — no liquidity floor.
4. Keep `Preferred_stock` as "equity-like" — that is junk for a stage strategy and
   should be auditable / excludable.

## Goal

A **composition-policy** module in `trading/analysis/data/universe/` that takes a
candidate universe (ranked symbols + per-symbol metadata) and applies policy flags,
producing (a) a policy-filtered candidate list and (b) a per-filter **drop report**
so we can see exactly what each policy removed.

**Every flag defaults to current behaviour** — so all existing goldens / universes
stay bit-identical until a flag is explicitly flipped. This is the data-layer analog
of `.claude/rules/experiment-flag-discipline.md` (default-off on merge).

## Design

The policy is **pure** and operates on a self-contained `candidate` record, so it
does not depend on the build internals (keeps it testable and decoupled). The
candidate carries exactly the metadata each filter needs:

```
type candidate = {
  symbol : string;
  asset_type : Eodhd.Asset_type.t;   (* ADR / Preferred / Common / ... *)
  sector : string;                   (* GICS sector; "Real Estate" => REIT *)
  avg_dollar_volume : float;         (* the dollar-volume score already computed *)
  rank : int;                        (* 0-based rank within the candidate pool *)
}
```

Candidates arrive in rank order (most-liquid first). The policy applies, in order:

1. **Dual-class dedup** — keep one class per economic entity. Detection =
   known-pairs table (GOOG/GOOGL, BRK-A/BRK-B, ...) plus a root-symbol heuristic
   (strip a trailing class suffix like `-A`/`-B`; same root => same entity). When two
   candidates collapse to one entity, keep the higher-ranked (more liquid) one. Limits
   documented in the `.mli` (heuristic has false positives; known-pairs table is the
   authoritative override).
2. **REIT include/exclude** — `reit_policy : Include | Exclude`, default `Include`.
   REIT detected by `sector = "Real Estate"` (config-driven label).
3. **ADR policy** — `adr_min_dollar_volume : float option`, default `None` (keep all).
   When `Some floor`, drop ADR/GDR candidates whose `avg_dollar_volume < floor`.
4. **Junk-exclusion audit** — `exclude_preferred : bool` (default `false` =
   current behaviour, preferred kept). Always emits an audit count of any
   non-stage-tradeable types that leaked in (SPAC/warrant/unit/preferred/CEF —
   the latter already dropped upstream, so the audit is mostly a guard that emits
   a report even when the count is zero).

Output:

```
type drop = { symbol : string; reason : drop_reason }
type filter_report = { filter : string; dropped : drop list; kept_count : int }
type result = { kept : candidate list; reports : filter_report list }
```

## Increments (stacked PRs under `feat/universe-composition-policy`, each < 500 LOC)

- **PR-A — types + dual-class detection.** `composition_policy_types.ml/.mli`
  (candidate, policy config with default-current-behaviour flags, drop_reason,
  report types) + `dual_class.ml/.mli` (known-pairs table + root-symbol heuristic).
  Tests pin: known-pair collapse keeps the more-liquid class; heuristic root match;
  non-matches pass through.
- **PR-B — filters + report.** `composition_policy.ml/.mli` applying
  dedup → REIT → ADR-floor → junk-audit and emitting the per-filter drop report.
  Tests pin: default config is a no-op (bit-identical pass-through); each flag drops
  exactly the intended symbols and records them in the right report.
- **PR-C — builder/CLI wiring + report emitter.** Wire the policy into a thin
  adapter that turns a `Build_from_individuals` scored pool into `candidate`s, and a
  CLI that runs the policy over an existing snapshot's symbols + emits the drop
  report. Status update.

## Out of scope

- The weekly >1%-of-ADV liquidity gate in the screener (separate weinstein-side
  dispatch).
- Re-running any backtests (the rerun is the dependency P0/P2 own, after this lands).

## Invariants

- OCaml only; pure functions; thresholds config-driven (no magic numbers).
- A2: all code under `trading/analysis/data/universe/` — no imports into
  `trading/trading/`.
- Default config = current behaviour, verified by a bit-identical pass-through test.
