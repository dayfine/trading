; universe_filter default rule-set.
;
; Rules: evaluated in declaration order.
;   - Keep_allowlist: symbols in the list are preserved regardless of any drop
;     rule. Rescue is final — cannot be overridden.
;   - Keep_if_sector: rows whose sector matches are preserved regardless of any
;     drop rule. Rescue is final — cannot be overridden.
;   - Symbol_pattern: Perl-style regex against [row.symbol]. Drops on match.
;   - Name_pattern: Perl-style regex against [row.name] (joined from
;     universe.sexp). Prepend [(?i)] for case-insensitive matching.
;   - Exchange_equals: exact (case-sensitive) match against [row.exchange]
;     (joined from universe.sexp).
;
; Iteration 2 (2026-04-16): the exchange-suffix rules (.U / .W / .WS / -P*
; / .INDX) fired zero rows on Finviz-sourced sectors.csv (Finviz strips
; these forms before we ingest), and the [warrant_len>3_endsW] heuristic
; caught only 12 rows — all legitimate common stocks (SCHW, SNOW, PANW, …).
; Replaced the symbol-suffix filters with name- and exchange-based filters
; that use universe.sexp metadata:
;   - Name_pattern drops "ETF" / "Fund" / "Trust" / "Notes" instruments
;     (bond ETFs, leveraged / inverse ETFs, unit trusts, closed-end funds
;     — the "Financials" bloat identified in Item 4).
;   - Exchange_equals "NYSE ARCA" is a strong ETF signal (NYSE Arca is
;     the primary US ETF listing venue).
;
; Item 4.1 (2026-04-16): collateral damage fix — option (a).
; The Name_pattern above swept up 51 Real Estate rows (legitimate REITs
; like "American Assets Trust", "Arbor Realty Trust") and ~5 Energy /
; Materials royalty trusts (MTR, NRT, PBT, PVL, MSB).  Add a
; Keep_if_sector rescue rule placed before the drop rules: anything with
; sector in {"Real Estate", "Energy", "Materials"} is preserved regardless
; of the name-pattern match.  Energy and Materials are included because
; their royalty-trust collateral is real (confirmed by dry-run spot-check)
; and both sectors are tradeable in the Weinstein strategy.
;
; Symbols in the broad / sector-ETF allow-list are live on NYSE ARCA and
; their names contain "ETF" / "Trust"; they are rescued first so neither
; filter drops them.
((rules (
  (Keep_allowlist (name "sector_and_broad_ETFs")
                  (symbols (
                    SPY QQQ VOO VTI IWM DIA
                    XLK XLF XLE XLV XLI XLP XLY XLU XLB XLRE XLC
                    QQQM FXAIX SWPPX)))
  (Keep_if_sector (name "reit_royalty_rescue")
                  (sectors (
                    "Real Estate"
                    "Energy"
                    "Materials")))
  (Name_pattern (name "etf_fund_trust_notes")
                (pattern "(?i)(\\bETF\\b|\\bFund\\b|\\bTrust\\b|\\bNotes\\b)"))
  (Exchange_equals (name "nyse_arca")
                   (exchange "NYSE ARCA")))))
