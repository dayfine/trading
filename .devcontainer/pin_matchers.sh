#!/bin/sh
# Pin the dayfine/matchers packages (status, matchers, status_matchers,
# ppx_test_matcher) at one exact commit and install them into the active opam
# switch. Idempotent: a re-run at the same commit changes nothing.
#
# This file is the single place the commit is named. It is run by
#   * .devcontainer/Dockerfile (ci stage, so the images carry the packages),
#   * .github/workflows/ci.yml (so a PR is tested before the published
#     trading-ci image is rebuilt; a quick no-op once the image has them),
#   * a local dev container (`sh .devcontainer/pin_matchers.sh` inside it).
# To bump the pin, change MATCHERS_SHA here and nowhere else.
set -eu

MATCHERS_SHA=99a0352d8cea267d2399091b520086e7d8a43fb2
MATCHERS_URL="git+https://github.com/dayfine/matchers.git#${MATCHERS_SHA}"

# Dependency order: status_matchers needs matchers and status.
PACKAGES="status matchers status_matchers ppx_test_matcher"

for pkg in $PACKAGES; do
  opam pin add --no-action --yes "$pkg" "$MATCHERS_URL"
done
# shellcheck disable=SC2086 # PACKAGES is a word list on purpose
opam install --yes $PACKAGES
