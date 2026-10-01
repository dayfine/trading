; Findings registry -- one row per backtest finding, naming the guard that
; pins it (issue #3001). Checked by
; trading/devtools/checks/findings_registry_check.sh (dune runtest).
; Rules and status meanings: .claude/rules/findings-registry.md
;
; Row: ((issue N) (ref "...") (finding "...") (guard G) (reason "...") (status S))
;   issue  optional integer; a row needs an issue or a ref
;   guard  none | ((unit (FILE "test name")) (validator Vn) ...)
;   reason required when guard is none
;   status open | fixed | fixed-behind-flag | wontfix | observation
; Validator ids must be registered in
; trading/trading/backtest/validation/lib/validator_checks.ml.
;
; Seeded 2026-09-29 from dev/experiments/obvious-fixes-2026-09-25/salt0-analysis.md
; section 3 plus issues #2961..#2989. Test names re-derived by grep on the tree.

; ---- salt0-analysis section 3, in its own numbering ----

((issue 2961) (ref "salt0-analysis s3 #1")
 (finding "stop exits filled at next open instead of on the trigger bar")
 (guard ((unit ("trading/trading/simulation/test/test_sim_stop_exit_trigger_bar.ml"
                "ON fills the stop exit on the trigger bar"))))
 (status fixed-behind-flag))

((issue 2963) (ref "salt0-analysis s3 #2")
 (finding "Saturday entries filled on Friday's bar")
 (guard ((unit ("trading/trading/simulation/test/test_sim_entry_stoplimit_fresh_bar.ml"
                "on waits for the fresh Monday bar"))
         (validator V13)))
 (status fixed-behind-flag))

((ref "salt0-analysis s3 #3")
 (finding "same-bar stop fill costs -0.6% per shared stop exit")
 (guard none)
 (reason "cost of the faithful fix, measured in a #2961 comment; no mechanism to pin")
 (status observation))

((issue 2966) (ref "salt0-analysis s3 #4-5")
 (finding "automatic 4% stop on 78% of trades; stops inside 2 ATR")
 (guard ((unit ("trading/trading/weinstein/strategy/test/test_entry_audit_capture.ml"
                "require_structural_stop: on skips Buffer_fallback"))))
 (status fixed-behind-flag))

((issue 2975) (ref "salt0-analysis s3 #6")
 (finding "installed stop is about half of the audit's suggested_stop (screener proxy read as installed)")
 (guard ((unit ("trading/trading/backtest/test/test_trade_audit.ml"
                "entry_decision sexp writes the screener_proxy_stop key"))
         (validator V21)))
 (status fixed))

((issue 2974) (ref "salt0-analysis s3 #7")
 (finding "trailing stops rarely rise (675 of 724 trades never raised)")
 (guard ((unit ("trading/trading/weinstein/stops/test/test_stop_anchor_rules.ml"
                "correction_must_follow_peak on: pure advance never raises"))
         (unit ("trading/trading/backtest/test/test_stop_log.ml"
                "installed stop, then one raise"))
         (validator V22)))
 (status fixed-behind-flag))

((ref "salt0-analysis s3 #8")
 (finding "shakeouts: stopped names recover")
 (guard none)
 (reason "consequence of #4-7 (findings above); pinned through those rows")
 (status observation))

((ref "salt0-analysis s3 #9")
 (finding "resting tickets never expire in the record spec")
 (guard none)
 (reason "spec-level: entry_order_max_rest_weeks 0 in the record spec; the investor preset uses the 52 week default")
 (status observation))

((issue 2976) (ref "salt0-analysis s3 #10")
 (finding "resting tickets fill in Bearish weeks (bypass the macro gate)")
 (guard ((unit ("trading/trading/weinstein/strategy/test/test_entry_ticket_suspend.ml"
                "On: withdraw, then re-issue unchanged"))
         (validator V23)))
 (status fixed-behind-flag))

((ref "salt0-analysis s3 #11")
 (finding "Neutral macro admits buys in bear rallies")
 (guard none)
 (reason "record only; index-stage veto measured REJECT-as-default 2026-09-21")
 (status observation))

((ref "salt0-analysis s3 #12")
 (finding "idle cash while tickets rest")
 (guard none)
 (reason "record only; no mechanism proposed")
 (status observation))

((ref "salt0-analysis s3 #13")
 (finding "result is a few monsters")
 (guard none)
 (reason "salt band pending (chain A); a distributional fact, not a defect")
 (status observation))

((ref "salt0-analysis s3 #14-15")
 (finding "2020-26 invested but flat; picks about equal to alternatives")
 (guard none)
 (reason "explained by #4-8; pinned through those rows")
 (status observation))

((ref "salt0-analysis s3 #16")
 (finding "4-8 positions at 14% each")
 (guard none)
 (reason "record only; see the concentration surface memory")
 (status observation))

((ref "salt0-analysis s3 #17")
 (finding "laggard rotation exits names that keep rising")
 (guard none)
 (reason "open question, no action; rotation is still the profit engine (+$6.0M)")
 (status open))

((ref "salt0-analysis s3 #18")
 (finding "record config is a hybrid of investor and trader dials")
 (guard none)
 (reason "investor preset queued (QUEUE items 3, 4, 7); preset-level, no unit pin")
 (status open))

((issue 2973) (ref "salt0-analysis s3 #19")
 (finding "split basis keeps recurring (audit close raw vs MA adjusted)")
 (guard ((unit ("trading/trading/weinstein/split_corpus/test/test_split_corpus_entry_audit.ml"
                "entry_audit_reports_close_vs_ma_on_one_basis"))
         (validator V20)))
 (status fixed))

((issue 2977) (ref "salt0-analysis s3 #20")
 (finding "weekly stop decisions not recorded")
 (guard ((unit ("trading/trading/weinstein/strategy/test/test_stop_decision_capture.ml"
                "sibling positions each get a record"))))
 (status fixed))

((issue 2978) (ref "salt0-analysis s3 #21")
 (finding "review_pack.sh --no-container sed noise on an absent audit report")
 (guard ((unit ("trading/devtools/checks/review_pack_test.sh"
                "no-container: stderr holds only progress lines"))))
 (status fixed))

((ref "salt0-analysis s3 #22")
 (finding "runtime scaling 5y vs 26y")
 (guard none)
 (reason "tracked as QUEUE item 8; long-cell timings recorded in dev/status/perf-long-cells.csv, no pin")
 (status open))

; ---- recent findings not in salt0 section 3 ----

((issue 2982)
 (finding "stop raise mixes split-adjusted MA with raw bars")
 (guard ((unit ("trading/trading/weinstein/strategy/test/test_stop_ma_same_basis.ml"
                "later-split tape: flag on raises to the correction low"))
         (validator V22)))
 (status fixed-behind-flag))

((issue 2983)
 (finding "late-Stage-2 stop tighten never fired")
 (guard ((unit ("trading/trading/weinstein/strategy/test/test_late_stage2_stop_runner.ml"
                "tightened_level_triggers_exit"))
         (unit ("trading/trading/weinstein/strategy/test/test_late_stage2_stop_runner.ml"
                "writes_tightened_level_into_state"))
         (unit ("trading/trading/weinstein/strategy/test/test_late_stage2_stop_runner.ml"
                "compares_against_state_not_risk_params"))))
 (status fixed))

((issue 2984)
 (finding "no broker stop emitted on entry fill or on stop-level change")
 (guard ((unit ("trading/trading/weinstein/order_gen/test/test_order_gen.ml"
                "sync_entry_fill_emits_initial_stop"))))
 (status fixed))

((issue 2989)
 (finding "re-issued suspended entry tickets not linked to their original placement")
 (guard ((unit ("trading/trading/weinstein/strategy/test/test_entry_ticket_suspend.ml"
                "a re-issue event names the first placement"))
         (validator V19)))
 (status fixed))

; ---- share-class twins and short-stop side (#3055) ----

((issue 3015)
 (finding "investor preset held GOOG+GOOGL, two share classes of one issuer")
 (guard ((unit ("trading/trading/weinstein/strategy/test/test_share_class_gate.ml"
                "flag on skips second class while first held"))
         (validator V6)))
 (status fixed-behind-flag))

((issue 3035)
 (finding "V6 missed held share-class pairs such as FWONA+FWONK")
 (guard ((unit ("trading/trading/backtest/validation/test/test_validator_twin_check.ml"
                "fwon overlap is a violation"))
         (validator V6)))
 (status fixed))

((issue 3039)
 (finding "short Support_floor installed stop below the entry in pre-#2986 artefacts")
 (guard ((unit ("trading/trading/weinstein/stops/test/test_short_floor_stop_side.ml"
                "short Support_floor stop above entry (#3039)"))))
 (status fixed))

((issue 3043)
 (finding "split_safe_floors on: adjusted floor vs raw entry puts a short stop below entry")
 (guard none)
 (reason "open; default-off flag, no spec arms it; fix and its tests tracked in #3043")
 (status open))

((issue 3045)
 (finding "V6 share-class map resolved from -data-dir, missing when data lives elsewhere")
 (guard ((unit ("trading/trading/backtest/validation/test/test_validator_twin_check.ml"
                "run reads map from separate dir"))))
 (status fixed))
