;; First list of the dated schedule in [smoke/panel-golden-2019-schedule.sexp]:
;; the full 7-symbol parity universe, governing every screening date up to
;; 2019-05-06.
;;
;; Byte-for-byte the same membership as [universes/parity-7sym.sexp] (same
;; symbols, same sectors) — kept as a separate file because a schedule entry
;; names a dated vintage, and the undated parity file is the *unscheduled*
;; scenario's universe. Editing one without the other is the intended way to
;; make the scheduled and unscheduled goldens diverge for a reason other than
;; the drop; don't "de-duplicate" them into one path.
;;
;; The second list is [universes/parity-4sym-2019-05-06.sexp].
(Pinned (
  ((symbol AAPL)   (sector "Information Technology"))
  ((symbol MSFT)   (sector "Information Technology"))
  ((symbol JPM)    (sector Financials))
  ((symbol JNJ)    (sector "Health Care"))
  ((symbol CVX)    (sector Energy))
  ((symbol KO)     (sector "Consumer Staples"))
  ((symbol HD)     (sector "Consumer Discretionary"))
))
