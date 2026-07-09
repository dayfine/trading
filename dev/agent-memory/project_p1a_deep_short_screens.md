---
name: project_p1a_deep_short_screens
description: "P1a deep screens 2026-07-09 (2000-2010, 364 basis): short leg IS deep-additive but UNGATED dominates — gates block early-bear hedges (hedge-shaped value); armon deep delta = single-2010-event noise, catstop 0.10 = real distributed deep value → catstop WF-CV next"
metadata: 
  node_type: memory
  type: project
  originSessionId: dbeb7536-3c56-4212-a532-4c2daa8dfc4b
---

`dev/notes/p1a-deep-short-screens-364-2026-07-09.md` (single deep cell
2000-2010 sp500-2000, real mechanisms, screen-calibrated — not WF-CV).

**Faithful-short gates (#1696):** ungated long-short 296%/DD30.7 dominates
long-only 251%/40.6 AND both gated arms (neutral 287.5/38.5, grind 272/36.6;
both-gates ≡ grind exactly — neutral is subsumed). WHY (transferable): the deep
value of shorts is **portfolio-level NAV hedging during early-bear bleeds**
(JNS 2001-02, TEL 01/2008, PM 10/2008), NOT per-trade P&L — gated arms have
BETTER short P&L on fewer trades yet lower total return. Per-gate attribution
(event-level, corrected): **grind gate = real cost** (8-week confirm blocks the
entire 2001 bear's hedges; grind arm ≈ long-only until 2008); **neutral gate =
near-inert deep** (blocked exactly 1 short in 11y — CF 2006, a loser, block
HELPED; the −8.6pp arm delta = post-divergence path noise, true edge cost ≈0
→ faithfulness flip is cheap both ways, mandate call). **Forward: crash protection should be
HEDGE-SHAPED (portfolio overlay / circuit breaker), never short-selection
gates** — feeds P1b ([[project_floor_quality_program]]).

**Arming speed (#1708) — CORRECTED by decomposition:** armon INERT 2000-2009
incl. 2008 (year-end equity identical, confirms 06-22 fold story); entire
+16.5pp = ONE 2010 divergence, sign flips vs 06-22 WF-CV 2010 fold (−0.77pp)
→ path noise, NOT deep edge. **catstop 0.10 = the real deep value,
DISTRIBUTED** (2001-02 +5.9%, 2008 +3.1% incr, +15.2pp total, −1.8pp DD).
catstop WF-CV RAN same session → **Reject(promotion)**
(2026-07-09-catstop-deep-wfcv): fold-honest WASH (−0.12pp/yr for −0.20pp DD,
7/26 folds fire, worst folds untouched); pays when decline CONTINUES (2002
+3.15, 2008 +2.11), costs V-recoveries (2020 −5.24, 2003 −2.44) = the
continue-vs-recover gap → P1b breaker's job. **Methodology: the screen's
+15.2pp was PATH-COMPOUNDING — compounded-path screens flatter crash-exit
mechanisms; always decompose per-fold/per-year before verdict** (this session
re-learned it TWICE: armon single-event + catstop compounding). Parity: first
nested stops_config.* key-path axis validated bit-identical 26/26.

**Bug found:** 1 SHORT leaked in enable_short_side=false run (LH 2001-06-13,
laggard_rotation exit) — laggard path bypasses the short flag; small, filed in
handoff.
