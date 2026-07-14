# Armed-run matrix on the dedup-v2 basis (2026-07-13/14)

Follow-through on the user directive ("work through all of them; record
multiple labeled versions"): six 28y record runs on the returns-basis
deduped warehouse (`/tmp/snap_top3000_1998_2026_dedup_v2`), each with a
trade-audit report + full-coverage validator run, all artifacts labeled.

## The matrix

| run | config delta vs baseline | MTM | realized | Sharpe | CAGR | MaxDD | trades |
|---|---|---:|---:|---:|---:|---:|---:|
| baseline | (all dials off) | +3,407% | $10.4M | 0.68 | 14.4% | 40.9% | 1,171 |
| A EXTSTOP | extension_stop 2.0×WMA30 / 25% trail | +7,455% | $66.8M | 0.82 | 17.7% | 32.3% | 1,190 |
| B MAGATE | reject_declining_ma_long_entry | +3,621% | $11.0M | 0.69 | 14.6% | 40.9% | 1,168 |
| C MINHIST | resistance_min_history_bars 520 | +1,720% | — | — | — | 40.6% | 1,132 |
| D ALLARMED | A + B | **+7,914%** | **$70.9M** | **0.83** | **18.0%** | **32.3%** | 1,187 |
| E LONGSHORT | D + enable_short_side | (+22,097%)* | ($183.9M)* | (0.97)* | (22.6%)* | (30.6%)* | 1,285 |

\* PRELIMINARY / NOT COMPARABLE — see §Run E.

Run dirs: `trading/dev/backtest/scenarios-2026-07-13-{052958,170900,182717,205919,194522,221224}/`.
Reports: session scratchpad `audit_report_*` / `validator_*` (labeled), plus
interactive artifacts (baseline + Run D).

## A — extension_stop: insurance acceptance PASSES

Fired 8×/26y; **every firing banked a parabolic top** (+89% to +5,196%):
AXTI 2026-05-30 **$59.0M** (vs riding $140→$70 to a $24M mark in baseline),
DDD at its Feb-2021 peak, BFX Nov-2020, four dot-com-era names Mar-Apr 2000.
Zero premature on-ramp kills (2.0× trigger only arms parabolics; the 25%
trail survived the AXTI April shakeout as the screen pinned). Realized/mark
composition flips from $10.4M/$24.6M to $66.8M/$9.0M; MaxDD 40.9→32.3;
Sharpe 0.68→0.82. Utilization trace shows the mechanism's signature: ~94%
deployed → 18.8% the week after the AXTI exit → redeploying 38-58% into
period end. Caveats stated: single path, AXTI ≈88% of the realized delta —
but the sanctioned insurance basis (left-tail/event-level, never fold Sharpe
at a ~1% event rate) is met in every cell. **Recommend ARM for record
convention + live**; promotion PR should cite this note (flag-discipline R3,
insurance precedent #1695).

## B — declining-MA gate: surgical, small positive

Trade-set diff vs baseline (and D vs A — identical result on both bases):
removes exactly 4 entries — AIR 2020-03-14 (−$0.38/−$0.49M COVID-waterfall
buy), DO_old 2018, AKS 2018, MOD 2019 — direct ≈ +$0.4M, path effects small.
Validator V8 goes 4→PASS when armed (mechanism/validator cross-confirm).
Consistent with #1775's ARM-FOR-BROAD. **Recommend ARM together with A.**

## C — min_history_bars 520: NOT armable (important negative)

Return HALVES (+3,407→+1,720%). Why: backtest panels carry only ~52-110
weekly bars, so a 520-bar floor marks EVERY name Insufficient_history —
it deletes the virgin/clean resistance signal wholesale instead of fixing
false virgins (V7 goes 102→PASS trivially: nothing can claim virgin).
Removing the signal costs far more than the false-virgin subset it targets.
**The real fix is feeding history, not the label floor**: (a) live
weekly-review warehouse → ~520 weekly bars (cheap, fixes CWST-class live
text with real data); (b) backtest panels → a resistance-specific deeper
window (NOT global lookback_bars ×10), perf-spiked first. Tracked as the
resistance-history follow-up. The label floor stays default-off everywhere.

## D — A+B combined: the record-convention candidate

Effects additive (D ≈ A + B deltas; 1,061 of 1,085 shared trades vs B
changed PnL purely from post-AXTI-banking position sizing). V5/V8 PASS,
V6 = its 2 known false positives, audit join 1,187/1,187. **This config —
extension_stop(2.0, 0.25) + reject_declining_ma — is the proposed new
record convention pending user sign-off.**

## E — long-short: PRELIMINARY, leverage artifact dominates

Headline +22,097% is NOT short alpha: the 43 short round-trips netted
**$0.0M**. The delta vs D comes from the long book LEVERING on short
proceeds/margin: marked LONG exposure exceeds NAV in 269 sampled weeks
(median 92%, peak 158%). The `max_long_exposure_pct 0.70` override in the
scenario does nothing (known dead envelope knob,
`project_envelope_knobs_dead`). A fair long-short comparison needs a real
long-exposure cap or margin convention pinned first — follow-up before any
conclusion is drawn from this run. Validator: V5/V8 PASS, join 1285/1285.

## Validator cross-checks (every run)

Audit join 100% on all six runs (C6b fix), V5 PASS everywhere (#1942 fix),
V6 stable at its 2 known trade-level false positives, V7/V8 respond exactly
to their corresponding dials — the validator now discriminates configs, not
just runs.

## CI note

The day's ~50-90% build-and-test failure rate was diagnosed: owl-linked
tuner tests die on part of GitHub's heterogeneous runner fleet (SIGILL, plus
one `Owl_lapacke.potrf` variant). Tracked in #1955 (needs human PAT for the
workflow/cache fix — portable owl build flags or pinned runners); repo-side
find-race noise hardened in #1954. Interim: rerun on the documented
signature.
