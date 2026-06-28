# Drawdown drivers — largest $ losses, 2023-2025 (2026-06-27)

The trades that actually **drove the 2023-2025 max-drawdown** ($12.2M → $6.85M,
−43.8%) by realized dollar loss — i.e. the positions that *cost the most*, not the
most volatile. Top realized $ losses exited 2023-2025, broad top-3000 long-only.

Legend: 🔵 S1 · 🟢 S2 · 🟠 S3 · 🔴 S4 · ⚫ 30w MA · 🟢 entry · 🔴 exit ·
🟣 initial stop · 🔴 reconstructed structural trailing stop. (See sibling chart
dirs' READMEs for full legend.)

| chart | trade | realized loss | stop dist |
|---|---|---|---|
| `AZPN.png` | 2023-04 (6d) | **−$326k** (−18.5%) | 19% |
| `CACC.png` | 2024-07 (6d) | −$200k (−16.7%) | 15% |
| `DBD_old.png` | 2023-03 (5d) | −$189k | 69% |
| `CCL.png` | 2024-07 (27d) | −$182k (−13.5%) | 18% |
| `COO.png` | 2025-12 (3d) | −$162k (−12.8%) | 21% |
| `WBA.png` | 2025-01 (4d) | −$161k (−13.7%) | 49% |

**Pattern:** these are **fast whipsaw stop-outs** (mostly 3-6 day holds, −13% to
−18%), and the dollar size is large because they're **high-priced, full-size
positions** (AZPN ~$215, COO, CCL). Several entries are visibly poor — bought near
a top or on a bounce in a topping/rolling-over pattern (AZPN entered at ~$215 after
a $145→$250 run that had already started rolling into Stage-3). The stop fired fast
and correctly capped each at ~the stop distance; the loss is just the position size
× the whipsaw. This is the *other half* of the 2023-25 drawdown (the realized-loss
stream); the larger half was unrealized give-back on held winners — see
`../give-back-2026-06-27/` and `dev/notes/barbell-deep-verification-2026-06-27.md`.

Caveat: this deep run had the liquidity overlay **off** (default), so some entries
(e.g. low-$ names) are ones the armed-live strategy would gate — see the
universe-vs-gate note in `docs/design/margin-safety.md` §5.
