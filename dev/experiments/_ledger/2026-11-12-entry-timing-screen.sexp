((date 2026-11-12) (slug entry-timing-screen)
 (hypothesis
  "Entry-timing screen prompted by the DIS-wein-85 chart walk (record k0 trade 1: E 37.12 = a 1999 high, fill 30 % over the 30-week MA, stopped -14.3 % on the pullback the book calls a second-chance buy). Over every closed trade of record-kseed-2026-10-27 (k0-k4), does (H1) skipping tickets whose screen close is more than X over the MA, (H2) anchoring E at the last-N-week high x 1.005 (what entry_anchor_local_range_weeks does), or (H3) replacing extended screens with a buy-limit at MA x (1+m) for 8 weeks with a book stop, improve realised NAV-% (sum of P&L / NAV at the screen)? Proxy screen: may conclude only build or no-build.")
 (base_scenario
  "entry-timing-screen-2026-11-12: host awk per-trade replay (run.sh) of 2,756 closed trades with store bars over record-kseed-2026-10-27 k0-k4 (top-3000 PIT v12 2000-2026, run tree fc78391dd); replay WMA-30 matches audit ma_value 2,756/2,756; null control (code's own E) reproduces the fill day 92.8 %")
 (window_id top3000-pitv12-2000-2026-record-kseed5-trades) (baseline_label record-kseed-actual)
 (variants
  (((label H1-skip-screen-ext-20) (config_hash entry-screen-h1-skip-ext) (aggregate ()))
   ((label H2-range-top-anchor-n4) (config_hash entry-screen-h2-local-range-anchor) (aggregate ()))
   ((label H3-ma-pullback-x20-m8) (config_hash entry-screen-h3-ma-pullback) (aggregate ()))))
 (verdict Reject)
 (notes
  "NO-BUILD DECISIONS (proxy screen, nothing built; leans on edge-is-the-fat-tail and the 07-12 entry-shape no-build). H1: negative at every X in 5/5 seeds (X=20 %: -53.3/-50.5/-53.7/-60.4/-47.9 NAV-%, 3-4 of 8-10 doubling trades lost); win rate 46 % -> 12.5 % and median trade -1.6 % -> -11.4 % with extension, but the >= 50 % bucket earns the most per trade (+2.16, 10 of 80 doubled; APPS 51.1 %, BBWI 50.8 %); the 30-50 % band (+7..+20) flips to -29..-42 at 30-60 % = knife edge on two names. H2: -57..-121 per seed at N in {2,4,8,13}, k0 N=4 90 % CI [-137.5, -19.0]; 2,188 of 2,688 code E's already sit below the 4-week high (the code buys lower), the anchor demands a new high and 753 never fill. H3 (X=20 %, m=8 %): real -> pullback 53.3->31.6 ... 47.9->36.0; fills beat their control (+40.2 pooled) but 405 of 494 flagged trades never pull back and carry the tail. WHY: all three change WHICH names fill, and the dropped names carry the right tail. The narrow variant that changes only the price (cap a stale E) is recorded separately as stale-e-cap-screen. Writeup dev/experiments/entry-timing-screen-2026-11-12/README.md."))
