;; Fast-crash-stop screen universe (2026-06-22).
;;
;; ~27 large-cap US equities across all 11 GICS sectors, curated so that a
;; default Weinstein run holds longs INTO the 2020 fast-V crash. Used by the
;; experiments/fast-crash-stop-screen-2026-06-22 scenario set to screen
;; [stops_config.catastrophic_stop_pct] (default-off fast-crash absolute stop,
;; armed only when Decline_character.classify labels the index Fast_v).
;;
;; The primary index (GSPC.INDX), the 11 SPDR sector ETFs, and the 3 global
;; indices the macro gate / decline-character read are NOT listed here — the
;; runner stages those automatically (_all_runner_symbols in runner.ml). They
;; were fetched into the local store alongside these equities.
;;
;; CAVEAT (survivorship): these are continuing-listing names with full history,
;; so the universe is survivor-biased. For a regime-gated insurance stop the
;; bias cuts equally across baseline and catastrophic variants (the RELATIVE
;; comparison holds); the absolute return level is not the deliverable.
(Pinned (
  ((symbol AAPL)  (sector "Information Technology"))
  ((symbol MSFT)  (sector "Information Technology"))
  ((symbol NVDA)  (sector "Information Technology"))
  ((symbol ADBE)  (sector "Information Technology"))
  ((symbol CRM)   (sector "Information Technology"))
  ((symbol V)     (sector "Information Technology"))
  ((symbol MA)    (sector "Information Technology"))
  ((symbol GOOGL) (sector "Communication Services"))
  ((symbol META)  (sector "Communication Services"))
  ((symbol DIS)   (sector "Communication Services"))
  ((symbol AMZN)  (sector "Consumer Discretionary"))
  ((symbol HD)    (sector "Consumer Discretionary"))
  ((symbol NKE)   (sector "Consumer Discretionary"))
  ((symbol MCD)   (sector "Consumer Discretionary"))
  ((symbol JPM)   (sector "Financials"))
  ((symbol BAC)   (sector "Financials"))
  ((symbol XOM)   (sector "Energy"))
  ((symbol CVX)   (sector "Energy"))
  ((symbol JNJ)   (sector "Health Care"))
  ((symbol UNH)   (sector "Health Care"))
  ((symbol PG)    (sector "Consumer Staples"))
  ((symbol KO)    (sector "Consumer Staples"))
  ((symbol WMT)   (sector "Consumer Staples"))
  ((symbol COST)  (sector "Consumer Staples"))
  ((symbol CAT)   (sector "Industrials"))
  ((symbol BA)    (sector "Industrials"))
  ((symbol GE)    (sector "Industrials"))
))
