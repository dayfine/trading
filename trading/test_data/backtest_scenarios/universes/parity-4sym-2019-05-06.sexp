;; Second list of the dated schedule in [smoke/panel-golden-2019-schedule.sexp]:
;; the 4 survivors, governing every screening date from 2019-05-06 onward.
;;
;; [universes/parity-7sym-2019-05-01.sexp] minus AAPL, JPM and JNJ. Those three
;; are exactly the symbols the unscheduled golden
;; ([panel_goldens/panel-golden-2019-full.sexp]) round-trips, so the drop is
;; known to bite rather than being a no-op on this window:
;;
;;   - JNJ  enters 2019-06-22, AFTER the drop date — the candidate gate rejects
;;     it and its round trip disappears from the scheduled golden.
;;   - AAPL enters 2019-05-04 / exits 2019-05-08, and JPM enters 2019-05-04 /
;;     exits 2019-05-10 — both entered BEFORE the drop date and exit after it,
;;     so decision D4 (a held position whose symbol leaves the universe is held
;;     to its normal exit) keeps their round trips bit-equal to the baseline.
;;
;; Mirrors [_dropped] / [_drop_date] in
;; [trading/backtest/scenarios/test/test_universe_schedule_e2e.ml].
(Pinned (
  ((symbol MSFT)   (sector "Information Technology"))
  ((symbol CVX)    (sector Energy))
  ((symbol KO)     (sector "Consumer Staples"))
  ((symbol HD)     (sector "Consumer Discretionary"))
))
