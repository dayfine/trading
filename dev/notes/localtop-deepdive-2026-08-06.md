# Local-top re-measure + deep-dive — three load-bearing findings (2026-08-06)

Continues `dev/notes/honest-ladder-2026-08-05.md` (user decision (b)). Two
local-top arms run on pinned worktree @`f293e2ea` (main incl. #2217), same
split-safe basis, control/estop comparisons carried (R1 bit-identity).

## Re-measure result

| Arm (band 2pp unless noted) | Realized | ≈MTM | Sharpe | MaxDD | Trades |
|---|---:|---:|---:|---:|---:|
| control (market fill) | +8,367% | +9,380% | 0.90 | 37.1% | 1,122 |
| estop2 (graded 520w top) | +965%* | +1,100%* | 0.30 | 29.5% | 1,102 |
| localtop26 (26w top) | +474% | +627% | 0.57 | 39.3% | 1,122 |
| localtop52 (52w top) | +177% | +189% | 0.38 | 29.5% | 1,109 |

*estop2 CONTAMINATED — see finding 2.

Headline as measured: the local-top lever does NOT beat the graded top on
wealth. But the deep-dive re-attributes both sides:

## Finding 1 — AXTI: one trade is 76% of the record, and the stop arms
## rejected it via a MISPAIRED rule, not the trigger

Control: AXTI 2025-06-28 @ $2.18 → 2026-05-30 @ $115.45 (extension_stop),
**+$64.3M = 76% of control's terminal**; it IS the +59%/+193% 2025/2026 YoY
rows. In localtop26 AXTI was ranked **#1 (score 100, A+)** on the same Friday
and across 30 signal-weeks — **skipped 24× `Stop_too_wide`, 6×
`Insufficient_cash`, entered 0×**. Mechanism: the initial stop comes from the
deep support-floor machinery (anchored near crash lows) and does NOT re-anchor
when the ticket entry moves up to E → risk% = (E − floor)/E balloons → the
G15 risk gate correctly rejects an absurdly-paired ticket. Systemic:
**11,178 Stop_too_wide skips (lt26) / 13,765 (lt52)** over 26y — the
E-anchored arms structurally exclude crash-recovery monsters (the fat tail).
Per book §5.1 the breakout buy's stop belongs just under the breakout base,
not under the multi-year crash floor — the honest arms as built are
**unfaithful on the stop side**. Fix in flight: default-off
`stop_anchor_at_entry_base` knob (branch feat/stop-anchor-entry-base), then
ladder re-run #3 with the properly-paired rule.

## Finding 2 — ELI: estop2's graded-top "win" is propped by one corrupt bar

estop2's 2014 (+$4.0M year) = ONE trade: ELI 2014-05-21 @ $1.18 → next day
@ $19.45, +1,544%, +$4.26M. Warehouse bars show ELI's feed interleaves a real
~$1.00 series with phantom $19-21 prints on ZERO-VOLUME days; the resting
stop triggered into a phantom high and the path model manufactured the fill.
Control never touched it. **Stop-fill models are uniquely corrupt-bar
sensitive** (a fake high IS a trigger; market-at-open models skip it).
Contamination scan (held ≤3d AND |pct|>80) across all five arms: ELI is the
ONLY hit. Corrected, estop2's honest terminal ≈ the +400-500% zone —
graded-top vs local-top is approximately a WASH, overturning the previous
"graded top earns its keep" read. Follow-ups: arm `spike_bar_threshold_pct`
(exists, default-off) for stop-model runs or add an engine zero-volume-bar
guard; clean estop2 re-run.

## Finding 3 — YoY mechanism map (equity-curve MTM, control vs lt26/lt52)

Control's 8× lives in ~7 explosive years (2000, 2003-04, 2009, 2020-21,
2025-26½ incl. AXTI's +193% half-year); stop arms track it in ordinary years,
miss the explosive ones (2009: ~0 vs +26; 2020: +10 vs +54 — BFX/BANB
COVID-bottom market fills), and protect in bears (lt52 2008: −0.1 vs −9.6;
both beat control 2022). estop2's realized profile is two monster years
(2014 = the fake ELI; 2021 MSTR +330%/LOGI +129%) against a flat rest.
Full YoY table in the session log; equity curves archived.

## Artifacts

`dev/experiments/stoplimit-entry-wfcv-2026-08-04/localtop-ladder/`
(2× actual/trades/equity + control equity curve). NOTE: estop2/estop15
equity curves were lost with the honest-ladder worktree (cleanup before
archival — process lesson recorded); their trades.csv survive in
`honest-ladder/`.
