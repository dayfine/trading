---
name: project-eodhd-terms-private-bucket
description: EODHD terms read 2026-10-30 — Non-Professional may store/analyze privately; a private cloud bucket for own research is OK, never share
metadata:
  type: project
---
EODHD terms (read 2026-10-30): a Non-Professional user may "store, manipulate, and analyze the data for private, non-commercial purposes"; "redistributing… or granting access to the Information" to others is forbidden. Cloud storage is not mentioned. A private bucket only the user (and their own cloud sessions) can read reads as storage, not redistribution — OK.

**Why:** gates #3476 (backtests on Claude cloud). The terms question is settled; what remains is the user creating the bucket + granting the cloud env access.
**How to apply:** don't re-research the terms; keep the bucket private, never put bar data in the repo, an artifact or a shared link; commercial use would need EODHD's professional licence. Related: [[project-env-cloud-label]].

**Cloud access (2026-10-31):** `EODHD_API_KEY` set in the Default env (env_011CV2KYxeXLs26U85qQo3rV) and `eodhd.com` allowed; a cloud session fetched SPY EOD and the delisted list (both http 200). Never print the key.
