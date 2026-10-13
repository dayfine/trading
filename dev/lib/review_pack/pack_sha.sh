#!/bin/sh
# pack_sha.sh -- the review-pack code's commit for the page header (#3262): a pack built from a stale or
# edited tree says so.
#
# pack_sha REPO -> REPO's HEAD (9 hex), "-dirty" appended when dev/lib/review_pack or
#                  dev/scripts/review_pack.sh differ from it; "unknown" when REPO is not a git checkout
pack_sha() {
  v=$(git -C "$1" rev-parse --short=9 HEAD 2>/dev/null) || { echo unknown; return; }
  [ -z "$(git -C "$1" status --porcelain -- dev/lib/review_pack dev/scripts/review_pack.sh 2>/dev/null)" ] || v="$v-dirty"
  echo "$v"
}
