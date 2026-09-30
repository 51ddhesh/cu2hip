# cu2hip build/proof toolchain — mirrors the Ubuntu CI `proof` + `ocaml`
# jobs so the verified core (Rocq 9.2.0) and the OCaml core/printer can be
# built and checked off a CUDA-less host (e.g. macOS) via a mounted repo.
#
# This image intentionally does NOT include Clang-22 + the CUDA toolkit
# (the C++ frontend `cu2mini`), which the full E2E gate needs; that path
# stays on the x86_64 Linux CI runner. See docker/build/README.md.
#
# Build:  docker build -t cu2hip-build docker/build
# Use:    docker run --rm -v "$PWD":/work -w /work cu2hip-build \
#           bash -lc 'make proofs ocaml && python3 tests/check_fixtures.py'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -q && apt-get install -qy --no-install-recommends \
      opam build-essential m4 pkg-config libgmp-dev git rsync ca-certificates \
      python3 && \
    rm -rf /var/lib/apt/lists/*

# Match SRS/CI pins: OCaml 5.3.0 + Rocq 9.2.0 in switch `cuda-rocm-rocq`.
RUN opam init --disable-sandboxing --bare -y && \
    opam switch create cuda-rocm-rocq ocaml-base-compiler.5.3.0 -y && \
    opam install -y rocq-prover rocq-core=9.2.0 dune yojson && \
    opam clean -a

# Make the switch environment available to login, interactive, and
# non-interactive `bash -c` shells (BASH_ENV) alike.
RUN printf 'eval $(opam env --switch=cuda-rocm-rocq)\n' \
      | tee /etc/profile.d/opam.sh >> /root/.bashrc
ENV BASH_ENV=/etc/profile.d/opam.sh

WORKDIR /work
CMD ["bash", "-l"]
