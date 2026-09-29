---
name: token-usage-week-2026-09-24
description: "⭐ Token week 09-17→24 = 794M (94 % cache reads): QC 47 % (cost ~flat regardless of OCaml — per-call preamble dominates), main 41 %; compact at ~250k not 150k (floor 112k); resumes 14 % (<20 %)."
metadata:
  type: project
---

Measured 2026-09-24 with `dev/scripts/token_usage_report.sh` (#2927) over local transcripts; tooling for items 2–4 of
#2922 in PR #2943, threshold rule in PR #2946.

- **Week 09-17→24: 794M tokens**, 94–96 % cache reads. QC reviews 373M (72 dispatches, 47 %), main context 328M (41 %),
  harness agents 77M (4 dispatches, 8 resumes, median 19.5M each), feat 17M.
- **QC cost does not depend on the diff (hypothesis b):** median structural 3.4M no-OCaml (n=27) vs 4.6M OCaml (n=6);
  behavioral 5.4M vs 8.1M; means ~equal (3.8/4.0, 6.8/6.9). ~35 calls × ~100k preamble re-read. Lever = fewer calls per
  review or a smaller reviewer preamble, NOT skipping the build.
- **Compaction (c):** main sessions start at 100–125k (median 112k), post-compact ~130k; ~4 real compactions in 24 sessions,
  contexts ride to 500k–1M. Replay of 8,060 calls: saving vs never compacting 150k 71 % (695 compactions) / 200k 69 % (163)
  / **250k 65 % (89)** / 300k 60 % (60) / 400k 52 %. Rule → ~250k (300k OK in chain-wait sessions). Floor ≈ 25 % of main
  spend. Weekly main-context total fell 1.1B (W35/36) → 324M (W39).
- **Resumes (a):** 14 % of subagent tokens — under the 20 % threshold; concentrated in harness-maintainer.
- 18/70 QC verdicts NEEDS_REWORK (26 %); each loop ~10M+.
- Codex (d): no data; account at quota until 2026-09-27 15:16. [[project_token_usage_audit_2026_09_08]]
