; Live-size profile (issue #3693): layered ON TOP of record-config-overrides.sexp.
; weekly.sh (WEEKLY_PROFILE=live-size) writes the record file followed by this
; one into the work dir and passes the result as --config-overrides; overlays
; apply in order, so each line here replaces the record's value of that one
; field and nothing else. Everything this file does not name is the record.
;
; A declared deviation from the 11-16 "picks = what the backtest trades"
; decision, asked for by the user on 11-18 ("initially if we can buy $10k it's
; good enough -- this should be configurable"). The README says which profile
; each published week used.
;
; Account size is NOT set here: no config field carries it. The generator
; sizes against the --portfolio file (dev/weekly-picks/portfolio.sexp, cash +
; held long value). At its $100k placeholder, the record's 1 % risk per trade
; and 14 % position cap give positions of about $10k (at most $14k), which is
; the size this profile is calibrated for. A larger real account scales the
; positions, and the participation cap below scales with them; the two fixed
; floors do not.
;
; 1. Entry participation cap (#3681): a long whose sized position exceeds
;    0.10 x its 20-day dollar ADV is dropped, with a warning line. A $10k
;    position needs $100k of ADV; a $14k one needs $140k.
((liquidity_config ((max_entry_adv_participation (0.10)))))
; 2. Dust floor: the record's fixed $1M entry floor drops to $100k, which is
;    0.10 x a $10k position. The backtest applies it on top of the cap (the
;    APPB / corrupt-bar class); the picks generator does not read it, so on
;    the live path the binding floor is weekly.sh's universe ADV floor, which
;    the live-size profile sets to the same $100k.
((liquidity_config ((min_entry_dollar_adv 100000.0))))
; 3. Hold floor: the record's $500k (half its entry floor) becomes $50k (half
;    the dust floor). This is a FIXED dollar floor, not scaled with the
;    position: Liquidity_exit_runner compares the trailing dollar ADV with
;    min_hold_dollar_adv and nothing else, so no field today makes the hold
;    gate scale with position size. Two further facts: the picks generator
;    never runs this exit (it reports held rows, it does not emit liquidity
;    exits), so on the live path it is inert, and the value only matters to a
;    backtest of this profile. The smallest change that would scale it is a
;    hold-side twin of the entry cap, max_hold_adv_participation (exit when
;    position market value > q x dollar ADV, q above the entry 0.10 for
;    hysteresis), in Liquidity_exit_runner; not built (issue #3693).
((liquidity_config ((min_hold_dollar_adv 50000.0))))
