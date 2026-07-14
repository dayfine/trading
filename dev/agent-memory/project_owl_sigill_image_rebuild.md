---
name: owl-sigill-image-rebuild
description: "#1955 root cause: weekly CI-image rebuild bakes owl with -march=native from the build host; 07-13 rebuild on AVX-512 host → SIGILL lottery on non-AVX512 runners. Fix PR #1961 = OWL_CFLAGS x86-64-v2 pin (ta-lib/#1129 pattern), no PAT needed"
metadata: 
  node_type: memory
  type: project
  originSessionId: 14b6c0ea-ae3b-45af-a97b-59ce1e459f76
---

**#1955 owl-SIGILL runner lottery — root cause + fix (2026-07-14).**

- CI runs in prebuilt GHCR image `trading-ci:latest` (image.yml, rebuilds
  weekly Mon 06:00 UTC cron + on `.devcontainer/Dockerfile` / `*.opam` /
  image.yml push to main). owl is baked at image-build time.
- owl.1.2 configure defaults to `-march=native` on x86_64
  (`src/owl/config/configure.ml` ~line 150; `OWL_CFLAGS` env fully REPLACES
  the default list). The 2026-07-13T07:19Z weekly rebuild landed on an
  AVX-512 build runner → `dllowl_stubs.so` embedded AVX-512 → owl-linked
  tuner tests (`test_bayesian_opt`, `Owl_lapacke.potrf`) SIGILL on the
  majority non-AVX512 `ubuntu-latest` fleet. ~50-90% build-and-test lottery.
  NOT new owl calls — prior weekly rebuilds just landed on non-AVX512 hosts.
- **Fix PR #1961**: Dockerfile `ENV OWL_CFLAGS` = owl defaults with
  `-march=x86-64-v2 -mtune=generic` (same pattern as the ta-lib SIGILL fix
  #1129, 40 lines up in the same file) + image-build-time objdump gate
  (`grep 'zmm\|evex\|knc'` on dllowl_stubs.so). No workflow file → no
  workflow-scope PAT (the issue's "needs human PAT" assumption was wrong).
- Lottery signature (rerun, don't debug): `Command got signal ILL` in tuner
  test binaries + zero real `FAIL:` lines. Auto-reroll bash loop pattern used
  2026-07-14 (gh run rerun --failed on signature match, cap ~15 attempts).
- If this class recurs for another opam package: check what the weekly image
  rebuild changed, objdump the .so for zmm/evex, pin arch flags in Dockerfile.
  Optional PAT-gated follow-up: owl objdump line in ci.yml smoke step.
