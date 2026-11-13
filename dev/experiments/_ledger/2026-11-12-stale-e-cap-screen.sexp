((date 2026-11-12) (slug stale-e-cap-screen)
 (hypothesis
  "H2' of the entry-timing screen: cap the entry trigger at the current range top only when the code's E is stale, E' = min(E, 4-week high x 1.005), same stop and exit. Does it improve realised NAV-% over the code's own ticket (null) per trade, across record-kseed-2026-10-27 k0-k4? Proxy screen: may conclude only build (escalate) or no-build.")
 (base_scenario
  "entry-timing-screen-2026-11-12: host awk per-trade replay over record-kseed-2026-10-27 k0-k4; stale E (code E above the 4-week high x 1.005) on 500 of 2,688 replayable trades; never-filled stale tickets replayed with a 26-week proxy hold")
 (window_id top3000-pitv12-2000-2026-record-kseed5-trades) (baseline_label replay-null-code-E)
 (variants (((label H2prime-cap-stale-E-n4) (config_hash entry-screen-h2prime-cap-stale-e) (aggregate ()))))
 (verdict Inconclusive)
 (notes
  "PROMISING -> ESCALATE (screen only, nothing promoted). Delta vs null +11.6/+7.3/+6.8/+12.0/+9.7 NAV-% (5/5 seeds, 2-5 % of realised), 78-90 trades better vs 4-9 worse per seed, k0 90 % bootstrap CI [+2.2, +22.1], k0 per-trade median +0.07 p10 0.00 p90 +0.41. Never-filled stale tickets that the cap would fill: 18/24/18/18/17, proxy -0.9/-0.8/+5.7/+0.2/+5.1 -> no sign flip. Gap: no portfolio interactions (cash, exposure cap, rotation) -> needs a default-off flag and a K=5 paired 26y run with V6. No existing knob expresses min(E, range top): entry_anchor_local_range_weeks replaces E (= H2, negative). Book section 4.7 anchors the buy-stop at the top of the current range (W2 entry dial, spine intact). Does not save DIS itself (E' 36.93 vs 37.12, same fill). Writeup dev/experiments/entry-timing-screen-2026-11-12/README.md."))
