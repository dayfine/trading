---
name: leverage-dawn-reject
description: "Leverage-dawn surface REJECT 2026-07-26 — regime-conditional leverage fails like unconditional; fat tail can't be scaled even conditionally; P1b program closed"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4cb68daf-8364-43f5-b404-95d50ecc30eb
---

Leverage-dawn WF-CV surface (2026-07-26, ledger `leverage-dawn-surface`,
memo `dev/notes/leverage-dawn-surface-results-2026-07-26.md`): **REJECT
all 6 cells** (dawn req {0.90,0.85,0.75} × age {52,78}w, broad 13-fold
2000-2026, funded mechanism #2077). Sharpe monotone-degrades .766 → .62 →
.54 → .51 as dawn aggressiveness rises; MaxDD 17.7 → 24-42; return μ up 2×
but as variance (σ 37→160). Gate 3-4/13 wins everywhere.

- **Falsifier fold-012 (2024-25) FIRED as the P1b memo predicted**: 5/6
  arms decisively negative (worst −19.8%/DD 56.8) — the 2023 MA flip-up
  labeled 2024 a dawn and levered into melt-up chop.
- **Even fold-010 (2020-21, the wealth concentrator) loses risk-adjusted**:
  297-579% return vs 134 but Sharpe 1.49-1.66 vs 2.01, DD 32-46 vs 13.

**LAW (extends [[edge-is-the-fat-tail]]):** a lagging regime label cannot
separate dawn-TAIL from dawn-CHOP — within-dawn tape has the same
whipsaw-premium+monster mix as the whole sample, so conditional leverage
inherits unconditional leverage's asymmetric amplification, only diluted.
The fat tail cannot be scaled even regime-conditionally. Regime-conditioned
deployment intensity joins the reject family (M4 unconditional leverage,
cash-reserve, regime-switch barbell). The P1b regime program is CLOSED —
no surviving payload; mechanism stays default-off as an axis.

**Open integrity item:** baseline drift between M4 surface (.827/36.2/14.1)
and this run (.766/34.6/17.7) on same spec+warehouse, code 7ef57ed2→96c4c5f
— identify source (suspects #2085/#2081) before reusing cached baselines.

Related: [[regime-payload-screens]], [[margin-m4-leverage-reject]].
