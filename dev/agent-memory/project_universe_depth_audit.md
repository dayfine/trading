---
name: project-universe-depth-audit
description: "11-23 audit — store can't rank past ~4.8–5.7k; top-3000 lists miss 100–260 names/yr; rank 5000 ≈ $0.1–0.4M ADV, 4001–5000 band 33 % defective; plan = fetch to top-4000 (~9k calls)"
metadata:
  node_type: memory
  type: project
  originSessionId: 4d3e3170-bdbe-449b-b0b1-b2b366fa3e92
  modified: 2026-11-23T19:58:41.242Z
---

User 11-23 (after NAV-scale read, #3704): "expand the universe (the limit is fidelity?), with no structural floor etc".

Audit (feat-data agent, scratch `scratchpad/universe-depth/` of session 4d3e3170, not committed):
- Store pool eligible per anchor year is only 4.8–5.7k names, so top-5000 does not exist pre-2005 and rank 5000 ≈ $0 later.
- Joint store+EODHD bulk ranking (3 dates per anchor): rank 5000 ADV $0.11–0.43M, rank 6000 $0.03–0.13M. Names ≥ $1M ADV: 3.3–4.2k/yr, so top-4000 ≈ "everything the $1M floor admits".
- **Current top-3000 lists have holes:** 99–262 names/yr missing from the store (32–100 major-exchange commons, e.g. WFT 2008, RDS-B, CDAY, DSW).
- Defect rate (any hard defect): ranks 1–3000 0.7 %, 3001–4000 2.4 %, 4001–5000 33 % (dead / sub-penny / zero-volume, not vendor corruption). CMRE ×5.1 and BFH ×4.0 (run entry vs local raw close) are a store-vs-warehouse disagreement (#3705), NOT explained by their later reverse splits: 45 of 47 later-reverse-split pairs enter at ~1× raw.
- Fetch cost: ~3k names to top-4000 (~9k calls), 5–6k to top-5000, 9–10k to top-6000; `symbol_types.sexp` (May) must be refreshed first (1,836 missing names absent from it). EODHD delisted bars patchy.

Structural-stop prior: `require_structural_stop false` = old hybrid (4 % fallback stops, 26y +133 %/DD 55 % vs +624 %/31 %); spine item 5, not promotable. User still wants the arm.

**How to apply:** fetch to top-4000 first (also fixes top-3000 holes), rebuild PIT lists + warehouse, then pre-register S/U/N/UN at $100k live-size K=5. Related: [[project-nav-scale-participation]], [[project-trait-y-low-price]], [[project-warehouse-vintage-coverage]].

**11-23 done (uncommitted):** fetched 2,683 major + 1,649 OTC/PINK-now names (~19.7k calls; store 16,203 symbols; symbol_types merged 58,341). pit-v13 lists top-{3000,4000}-{1998..2026} at `trading/test_data/backtest_scenarios/pit-v13/composition/` (untracked), built with `--true-dollar-volume`, NOT twin-aliased. v13 top-3000 adds 156–717 names/yr vs v12 (30–65 % now OTC/PINK = fallen names). Open before use: (1) twin scans/alias dedupe; (2) v12 vs v13 ranking basis differs (true-dollar) — confound for an S-on-v12 comparison; (3) 4 junk ADV names left (DNGFF, HLAN, MDFI, SYNI); 12 quarantined in scratch v3/quarantine.
