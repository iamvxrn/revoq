# Revoq

###### Cargo, but for C and C++ — an experiment in what AI can build.

[![License: MIT](https://img.shields.io/badge/License-MIT-4a7bc0.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-4a7bc0.svg)](#)

Revoq is a build toolchain for C and C++ that feels like Cargo. Point it at a directory with `src/main.cpp` or `src/lib.cpp`, run `revoq build`, and it compiles — no `CMakeLists.txt`, no Makefiles, no setup script.

> **Note:** Revoq was created as an experimental study in C/C++ tooling: if you pointed an AI at "Cargo, but for C and C++," see how far it gets. The build system, dependency graph resolution, and documentation were generated under maintainer guidance.

## Quick Installation

Via **Lown**:
```bash
lown install gh:iamvxrn/revoq
```

Via **Curl**:
```bash
curl -fsSL https://revoq-cli.com/install.sh | sh
```

## Features

- **Strict Project Layout**: Entry points are deterministic (`src/main.cpp`, `src/lib.cpp`).
- **Reproducible Dependency Graph**: `revoq.lock` pins dependencies to exact Git commit SHAs via atomic file swaps.
- **Parallel Compilation Queue**: Multi-threaded worker queue compiles translation units in parallel.

## License

Released under the [MIT License](LICENSE).
