; Live portfolio state for the weekly-picks execution protocol.
;
; EDIT THIS FILE to reflect your real holdings. The weekly generator
; (`generate_weekly_snapshot --portfolio dev/weekly-picks/portfolio.sexp`)
; prices these positions, reports them, and sizes new long candidates against
; `cash` + current long market value (fixed-risk sizing, mirroring the
; backtest — NOT equal-sized).
;
; >>> SET `cash` to your real cash balance before first use. <<<
; The 100000.0 below is a placeholder.
;
; Shape:
;   cash      : float   — cash balance available to fund entries
;   as_of     : date    — the day you last updated this file (YYYY-MM-DD)
;   positions : list of
;     symbol      : ticker
;     shares      : int   — share count held (long)
;     entry_price : float — fill price
;     entry_date  : date  — date opened (YYYY-MM-DD)
;     stop_price  : float — the working stop
;
; Example position (delete when you record real fills):
;   ((symbol AAPL) (shares 100) (entry_price 180.0)
;    (entry_date 2026-06-13) (stop_price 168.0))
((cash 100000.0)
 (as_of 2026-07-24)
 (positions ()))
