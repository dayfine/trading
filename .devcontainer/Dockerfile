# =============================================================================
# Multi-stage build:
#   Stage `ci`           — lean. Built and published as
#                          ghcr.io/dayfine/trading-ci:latest by
#                          .github/workflows/image.yml; consumed by
#                          .github/workflows/ci.yml on every PR.
#   Stage `devcontainer` — extends ci with editor tools + jj/jst + warm _build.
#                          Built locally by .devcontainer/devcontainer.json
#                          (target: devcontainer). Also published as
#                          ghcr.io/dayfine/trading-devcontainer:latest so the
#                          planned orchestrator-automation workflow can pull
#                          it (needs jj, jst, opam env to run the daily
#                          lead-orchestrator session).
#
# Why the split: a single image previously served both purposes and bundled
# ~3.8 GB of CI-irrelevant content (ocaml-lsp-server, odoc, utop, jj, jst,
# pre-warmed _build). CI's "Initialize containers" step pulled all of it on
# every PR run. Splitting trims the CI image (used by ci.yml) to roughly half
# its previous size while keeping the devcontainer image (used by local dev
# and the orchestrator job) unchanged in capability.
# =============================================================================

# =============================================================================
# Stage: ci — everything needed to compile + test from a fresh PR checkout
# =============================================================================
FROM docker.io/ocaml/opam:ubuntu-22.04-ocaml-5.3 AS ci

# -----------------------------------------------------------------------------
# System Dependencies
# -----------------------------------------------------------------------------
# Each dependency is annotated with which OCaml package requires it.
#
#   pkg-config, build-essential, curl  - core build tools
#   libssl-dev          - async_ssl
#   libffi-dev          - ctypes (must precede the opam packages that use it)
#   libopenblas-dev,
#   liblapack-dev,
#   liblapacke-dev      - owl
#   libplplot-dev,
#   plplot-driver-cairo - owl-plplot
#   autoconf, automake,
#   libtool             - ta-lib build system
# -----------------------------------------------------------------------------
RUN sudo apt-get update && sudo apt-get install -y \
    pkg-config \
    build-essential \
    curl \
    libssl-dev \
    libffi-dev \
    libopenblas-dev \
    liblapack-dev \
    liblapacke-dev \
    libplplot-dev \
    plplot-driver-cairo \
    autoconf \
    automake \
    libtool \
    time \
    && sudo rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# TA-Lib (Technical Analysis Library)
# -----------------------------------------------------------------------------
# Required by ta_ocaml. Not in apt; built from source.
# -----------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://github.com/ta-lib/ta-lib/releases/download/v0.6.4/ta-lib-0.6.4-src.tar.gz -o ta-lib.tar.gz && \
    tar xzf ta-lib.tar.gz && \
    cd ta-lib-0.6.4 && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    sudo make install && \
    cd / && \
    rm -rf /tmp/ta-lib*

# -----------------------------------------------------------------------------
# Project source — needed only at image-build time so the find-based
# `opam install --deps-only` loop below has *.opam files to read. CI itself
# checks out the PR source under $GITHUB_WORKSPACE/trading and runs dune
# there; the source baked into this image is unused at CI runtime.
# -----------------------------------------------------------------------------
WORKDIR /workspaces/trading-1/trading
COPY --chown=opam:opam trading/ /workspaces/trading-1/trading/

# -----------------------------------------------------------------------------
# Opam repository — switch to the live remote (the base image's local snapshot
# may lag behind upstream).
# -----------------------------------------------------------------------------
RUN opam repository set-url default https://opam.ocaml.org && opam update

# -----------------------------------------------------------------------------
# OCaml Dependencies
# -----------------------------------------------------------------------------
# Iterate every *.opam file in the source and install its --deps-only.
# -----------------------------------------------------------------------------
RUN find /workspaces/trading-1/trading -name "*.opam" -type f ! -path "*/_build/*" \
    -exec dirname {} \; | sort -u | while read dir; do \
        echo "Installing deps from: $dir"; \
        opam install "$dir" --deps-only --with-test --yes || true; \
    done

# -----------------------------------------------------------------------------
# Pinned Dependencies
# -----------------------------------------------------------------------------
# owl.1.2 / owl-plplot.1.1 / plplot.5.12.0 are the versions known to work with
# OCaml 5.3 — the solver may otherwise pick an older line constrained to < 5.x.
# -----------------------------------------------------------------------------
RUN opam install --yes \
    async async_ssl async_unix \
    base bos \
    cohttp-async core core_unix csv ctypes ctypes-foreign \
    fpath \
    ounit2 \
    plplot.5.12.0 owl.1.2 owl-plplot.1.1 \
    ppx_deriving ppx_jane ppx_let \
    sexplib sexp_pretty \
    uri yojson

# -----------------------------------------------------------------------------
# ocamlformat — pinned to match trading/.ocamlformat (version = 0.29.0). The
# CI fmt gate runs `dune fmt --check`, which fails if the formatter version
# drifts. Pin here so the image cannot silently upgrade and break CI.
# This is the ONLY tool the ci stage installs beyond runtime libraries.
# -----------------------------------------------------------------------------
RUN opam install --yes ocamlformat.0.29.0

# Drop any _build artifacts from opam install hooks so the ci stage stays lean.
RUN rm -rf /workspaces/trading-1/trading/_build

# =============================================================================
# Stage: devcontainer — extends ci with editor tools, VCS, jst, warm _build
# =============================================================================
FROM ci AS devcontainer

# -----------------------------------------------------------------------------
# Editor / dev tools — none of these are invoked by CI.
# -----------------------------------------------------------------------------
RUN opam install --yes ocaml-lsp-server odoc utop

# -----------------------------------------------------------------------------
# vim — useful for in-container editing during interactive sessions.
# -----------------------------------------------------------------------------
RUN sudo apt-get update && sudo apt-get install -y vim \
    && sudo rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Jujutsu (jj) — VCS used by agents and the dev workflow. CI uses git
# directly via actions/checkout and never invokes jj.
# -----------------------------------------------------------------------------
ARG JJ_VERSION=0.39.0
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
      amd64) JJ_ARCH="x86_64" ;; \
      arm64) JJ_ARCH="aarch64" ;; \
      *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/jj-vcs/jj/releases/download/v${JJ_VERSION}/jj-v${JJ_VERSION}-${JJ_ARCH}-unknown-linux-musl.tar.gz" \
      | sudo tar xz -C /usr/local/bin --strip-components=0 ./jj

# -----------------------------------------------------------------------------
# jj-stack (jst) — stacked-PR submission tool used by agents at session end.
# Pulls in nodejs as a transitive dependency.
# -----------------------------------------------------------------------------
ARG JST_VERSION=1.2.1
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && \
    sudo apt-get install -y nodejs && \
    sudo npm install -g jj-stack@${JST_VERSION} && \
    sudo rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Pre-warm dune _build so devcontainer startup is fast on first session.
# -----------------------------------------------------------------------------
RUN eval $(opam env) && dune build
