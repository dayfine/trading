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

# Already pinned at this commit and installed (e.g. the published image carries
# them): nothing to do. Without this, a re-pin from a different user than the
# one that created the switch (CI runs the image as root, the image built it as
# opam) makes opam's `git clean` in the source cache exit 128 on git's
# dubious-ownership check, and the step fails.
all_current=1
for pkg in $PACKAGES; do
  if ! opam pin list 2>/dev/null | grep "^${pkg}\." | grep -qF "$MATCHERS_URL" \
    || [ -z "$(opam list --installed --short "$pkg" 2>/dev/null)" ]; then
    all_current=0
  fi
done
if [ "$all_current" = 1 ]; then
  echo "pin_matchers: all packages already pinned at ${MATCHERS_SHA} and installed"
  exit 0
fi

# A real (re-)pin: let git operate on the switch's source cache even when it is
# owned by another user.
git config --global --add safe.directory '*'

for pkg in $PACKAGES; do
  opam pin add --no-action --yes "$pkg" "$MATCHERS_URL"
done
# shellcheck disable=SC2086 # PACKAGES is a word list on purpose
opam install --yes $PACKAGES
