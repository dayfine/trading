; universe_filter default rule-set.
;
; Rules: evaluated in declaration order.
;   - Symbol_pattern: Perl-style regex matched against the *symbol* column.
;     A row whose symbol matches ANY Symbol_pattern is dropped, unless
;     rescued by a Keep_allowlist.
;   - Keep_allowlist: symbols in the list are preserved regardless.
;
; Starting point based on dev/status/sector-data.md §Item 4:
;   - exchange-suffix noise: .U (units), .W / .WS (warrants),
;     -P* (preferreds), .INDX (indexes)
;   - "length > 3 ending in W" as a tight warrant heuristic
;   - allow-list for the sector/broad-market ETFs the Weinstein strategy
;     depends on (so they survive any rule).
;
; Note: Finviz (our current sectors.csv source) appears to already strip
; most of these exchange-suffix forms, so the suffix rules may hit zero
; rows on the current file. That's expected and documented as a follow-up
; in Item 4 §Completed. Keep the rules — they still guard against future
; sources (EODHD, Yahoo) that emit raw exchange-suffix forms.
((rules (
  (Symbol_pattern (name "suffix_units_.U")     (pattern "\\.U$"))
  (Symbol_pattern (name "suffix_warrant_.W")   (pattern "\\.W$"))
  (Symbol_pattern (name "suffix_warrant_.WS")  (pattern "\\.WS$"))
  (Symbol_pattern (name "preferred_-P")        (pattern "-P"))
  (Symbol_pattern (name "index_.INDX")         (pattern "\\.INDX$"))
  (Symbol_pattern (name "warrant_len>3_endsW") (pattern "^.{3,}W$"))
  (Keep_allowlist (name "sector_and_broad_ETFs")
                  (symbols (
                    SPY QQQ VOO VTI IWM DIA
                    XLK XLF XLE XLV XLI XLP XLY XLU XLB XLRE XLC
                    QQQM FXAIX SWPPX))))))
