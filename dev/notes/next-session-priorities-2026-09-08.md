# Next-session priorities — 2026-09-08 (evening handoff; supersedes 2026-09-07)

Written 14:35 PT at session end. The 09-07 doc's sequence is done through item 3; this file carries the live state.

## Merged this session (all via CI + qc-structural + qc-behavioral at the tip)

- Delisting data program code-complete on #2672: #2705 (guard 3 retired), #2708 + #2713 (build-time splice action; reuse = report-only, cut by exception — the blanket cut would have gutted 247/518 series), #2709 (fill-time ticket cancel, closes #2696), #2724 (`-incremental` merges the manifest, closes #2669).
- Record re-based on clean data as a BAND: 263% median, 181–562% across salts, DD 42–45% (#2704; `project_record_rebase_2026_09_07`).
- Vintage gap fetch: 1,359 names (1,247 dead at real dates), TMS quarantined; `_v9gap` 2009/2019 warehouses (2,886 / 2,936 names). **Survivorship cost measured as a paired band on 2019–23: −12 to −23pp** (#2717; the 09-07 2019 5y cell is superseded).
- Item 3 landed as a default-off axis `initial_stop_buffer_by_macro_state` (#2718). Surface salt 0 (#2728): null = record digit-for-digit (breadth read + build inert); map (12/8/4%) = 692% / DD 37.9 — **inflated by twin duplication (V6 6 violations, ≈$764k) and carried by six trades; never quote 692**.
- Harness: #2721 publisher, #2727 its test hardening, #2725 prune probe (structural APPROVED at 3b3d886b9; **behavioral re-run still owed** — the agent was rate-limited after verifying; re-dispatch first thing).

## Live processes (survive the session — nohup on the host)

- Item-3 cells: lane A `a2-map-neutral10-s0` (since 11:01), lane B `a1-map-neutral8-s1` (since 11:41) then `a0-breadth-on-null-s1` (queued in the same chain). Logs `/tmp/item3-run/chain-{A,B}.log`; artifacts `/tmp/sweeps/item3/<tag>-*` (docker cp into `dev/experiments/stop-width-by-state-2026-09-08/results/`). Build = `sweep-item3` @ e7dde095a (keep that worktree until the salts finish). Read per `.claude/rules/mechanism-validation-rigor.md`: **V6 count on every cell before any number** (issue #2730); a0-s1 must equal the record's s1 cell (561.61% / 755 / 0.52 / 45.15) if the build is inert at salt 1; a1-s1 vs the record s1 with the `symbol|entry_date` join. Then `SALT=2 sh /tmp/item3-run/chain.sh A a1-map-neutral8 a0-breadth-on-null` (the repo copy of `chain.sh` has the SALT arg too). Never a third concurrent 26y cell.
- Warehouses in the container: `_v7mark` (2000/2009/2019, the clean record basis), `_v9gap` (2009/2019, gap-filled), `_v8ctl` (2000, splice report-only control), old `dedup_v5thin_adj` / `snap_top3000_{2009,2019}` (kept for pairing). Pinned worktrees: `sweep-item3` (main e7dde095a — current), `sweep-wh0908` (077b48973 — can be removed).

## Queue (in order)

1. **Merge this handoff** (docs-only) and re-dispatch **#2725 behavioral** (brief in the session's last dispatch: marker + Fixture C2 mutations 35/5 ↔ 37/3).
2. **Read the item-3 salts** as above; write the paired band into `dev/experiments/stop-width-by-state-2026-09-08/README.md`; the staged mechanism correction (twins are FUNDED on the map arm, not stopped out on the null) is in this commit.
3. **#2730 — dedupe twins at build** for the vintage rebuild path (`build_snapshots.exe` lacks `-dedupe-rename-twins`; same gap shape as #2711), rebuild `_v10dedup`, make V6 a comparison gate, re-run the item-3 null + map on it. Until then every width-lever read on `_v7mark` is inflated by twins.
4. Item 4 (combined surface: per-state width × the 12%-weekly cadence candidate) only after the deduped band.
5. Follow-ups: #2729 residuals (publisher test gaps; fixture temp-dir leak; Step-8 repoint notes on #2721); the `stop_loss` label hiding the `Per_position` breaker (filed on #2717); `_v9gap` 2009 has no 5y spec; AWRE-type special distributions are not events in the store (the simulator gaps through them on unadjusted bars).

## Ops notes (new this session)

- GitHub minted no Actions check-suite for two SHAs on one PR; reopen / empty commit / fresh PR were inert — **rebase to new SHAs** (`feedback_agent_bookmark_needs_track_before_push`).
- QC agents: post the review FIRST, verify the count (`feedback_qc_review_format_must_parse`); one agent ended with a full verdict and no post.
- `jj new`/`jj edit` off a different parent drops files written into the previous wip — `jj diff --stat` first; recover with `jj restore --from <old wip>` (twice tonight).
- Container: two 26y cells + ONE scoped builder fits (≈6.5 GB); never two builders alongside cells.
- The `>200-row` fetch floor is not a reuse detector; the vintage-date check is (TMS).
