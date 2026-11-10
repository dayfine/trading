# Next-session priorities — 2026-11-10 (supersedes 2026-11-08)

Session 2026-11-08 → 11-10 (one continuous session), handoff written 09:45 PT 11-10. Open issues: **14**. Main CI green.
No open PRs.

## 0. Ground rules (changed)

- **Backtests run in cloud sessions by default** (`docs/howtos/claude_cloud_sessions.md`, since 11-09). Pull the
  warehouse `v12wk-9236` and corporate actions `corpact-2026-10-27` from R2 as the howto says. A build from before
  #3510 needs the lower-case `*_old` shard step; a build from before #3547 needs the warehouse mounted at
  `/tmp/snap_top3000_pit_v12wk`.
- **Local container is 5 GB / 6 CPUs** (was 7.75 GB / 10). It is for QC waves (≤ 3), interactive debugging and
  the book. A 26y run goes to the cloud; locally only after raising the VM back.
- Run `r2_bars.sh` on the host; from inside `trading-1-dev` R2 answers 403.
- `trading-1-dev` has restart policy "no": after any Docker restart, `docker start trading-1-dev`.

## 1. What settled since 11-08

| item | result |
|---|---|
| #3535 rk-k0 cloud parity | **closed**. Attempt 3 byte-identical (actual.sexp, trades.csv, equity_curve.csv). Attempt 2's 1311.40 % was the pre-#3510 build reading lower-case `*_old` shards |
| #3535 twin dedupe | user decision: `v12wk` (9,236 symbols) is the canonical construction |
| #3554, #3557, #3558 | howto + container rule updated; #3556 (wrong lower-case rewrite) superseded by #3557, R2 set restored to upper case |
| weekly perf / issue / usage read | #3567: all perf cells PASS (wall +0–3 %, RSS < 1 %); first usage row (partial) |
| #3381 slow local 26y | host load: same cell 6,527–6,870 s in the cloud vs 12,605 s locally |
| #2973 split corpus | #3559, #3561 merged by another session |
| #3562 weekly-start sweep | closed: only `run_date` moved, see §3 item 4 |

## 2. In flight

None.

## 3. Queue

1. **Paired 26y cloud runs**, one cloud chain (each ~2 h): #3136 (`true_dollar_volume` off vs on, V6-gated),
   #3109 (default-flip golden pair with #3104), #3183 (per-vintage membership vs pit-v12). All three issues are
   `env/cloud`.
2. **Docker 4 GB check**: read `docker stats` peak during the next 3-agent QC wave; if it stays well under 4 GB,
   lower the VM to 4 GB (user's Docker Desktop setting).
3. **Local budget backfill** for 11-03, 11-04, 11-07, 11-08, 11-09, 11-10: `budget_local_record.sh --date D` at a
   session end with no other session live (it failed mid-read while this session was writing).
4. **Committed SPY bars end 2026-09-28**, so the weekly-start sweep is clamped and its PRs carry no new numbers
   (#3513, #3562). Refresh `trading/test_data/S/Y/SPY` past 09-28 (ops-data) before the next Monday run.
5. #2973 split corpus: owned by another session.

## 4. Decisions waiting

None.
