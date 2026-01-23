FROM docker.io/ocaml/opam:ubuntu-22.04-ocaml-5.3

# =============================================================================
# System Dependencies
# =============================================================================
# Each dependency is annotated with which OCaml package requires it.
#
# Core build tools:
#   pkg-config          - Required by many packages for finding system libraries
#   build-essential     - C compiler for native code
#   curl                - Downloading ta-lib source
#
# For async_ssl (TLS/SSL support):
#   libssl-dev          - OpenSSL development headers
#
# For ctypes (Foreign Function Interface):
#   libffi-dev          - libffi development headers (must be installed BEFORE opam packages)
#
# For owl (Scientific computing):
#   libopenblas-dev     - Optimized BLAS implementation
#   liblapack-dev       - Linear algebra routines
#   liblapacke-dev      - C interface to LAPACK
#
# For owl-plplot (Plotting):
#   libplplot-dev       - PLplot library headers
#   plplot-driver-cairo - Cairo rendering backend
#
# For ta-lib (built from source):
#   autoconf, automake, libtool - Build system for ta-lib
#
# Optional:
#   vim                 - Editor for in-container development
# =============================================================================
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
    vim \
    && sudo rm -rf /var/lib/apt/lists/*

# =============================================================================
# TA-Lib (Technical Analysis Library)
# =============================================================================
# Required by: ta_ocaml (OCaml bindings for technical indicators)
# Not available via apt, must be built from source.
# =============================================================================
RUN cd /tmp && \
    curl -L https://github.com/ta-lib/ta-lib/releases/download/v0.6.4/ta-lib-0.6.4-src.tar.gz -o ta-lib.tar.gz && \
    tar xzf ta-lib.tar.gz && \
    cd ta-lib-0.6.4 && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    sudo make install && \
    cd / && \
    rm -rf /tmp/ta-lib*

# =============================================================================
# Project Setup
# =============================================================================
WORKDIR /workspaces/trading-1/trading
COPY --chown=opam:opam trading/ /workspaces/trading-1/trading/

# =============================================================================
# Opam Repository Setup
# =============================================================================
# The base image includes a LOCAL snapshot of the opam repository that may be
# outdated. We switch to the remote repository to get latest package versions.
# =============================================================================
RUN opam repository set-url default https://opam.ocaml.org && opam update

# =============================================================================
# OCaml Dependencies
# =============================================================================
# Install dependencies from local opam files. The monorepo has multiple
# packages, so we iterate through all of them.
# =============================================================================
RUN find /workspaces/trading-1/trading -name "*.opam" -type f ! -path "*/_build/*" \
    -exec dirname {} \; | sort -u | while read dir; do \
        echo "Installing deps from: $dir"; \
        opam install "$dir" --deps-only --with-test --yes || true; \
    done

# =============================================================================
# Pinned Dependencies
# =============================================================================
# Some packages require explicit version pinning for OCaml 5.x compatibility:
#
# owl.1.2, owl-plplot.1.1, plplot.5.12.0:
#   The opam solver may select older versions with OCaml < 5.x constraints.
#   These specific versions are known to work with OCaml 5.3.
#
# All other packages use the latest compatible versions from opam.
# =============================================================================
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

# =============================================================================
# Development Tools
# =============================================================================
RUN opam install --yes ocaml-lsp-server odoc ocamlformat utop

# =============================================================================
# Build Verification
# =============================================================================
# Verify the project builds successfully with all dependencies.
# =============================================================================
RUN eval $(opam env) && dune build
