FROM docker.io/ocaml/opam:ubuntu-22.04-ocaml-5.3
RUN sudo apt update && \
sudo apt install pkg-config libssl-dev vim -y && \
opam install . --deps-only --with-test && \
opam update && \
opam install ocaml-lsp-server odoc ocamlformat utop dune --yes --unlock-base && \
# Install the project dependencies
# For async_ssl
sudo apt-get install libffi-dev
