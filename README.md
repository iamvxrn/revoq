# Revoq

> **Revoq** is a modern package manager and build engine for C and C++, featuring strict project-layout enforcement, Clang compilation database generation, `-ftime-trace` flamegraphs, and single-flag sanitizer injection.

[![Rust](https://img.shields.io/badge/rust-stable-4a7bc0.svg)](https://www.rust-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-4a7bc0.svg)](LICENSE)
[![Nightly CI](https://github.com/iamvxrn/revoq/actions/workflows/nightly.yml/badge.svg)](https://github.com/iamvxrn/revoq/actions/workflows/nightly.yml)

```
                       src/ & include/ (Strict Layout)
                                      │
                              [ Revoq Engine ]
                                      │
                     ┌────────────────┴────────────────┐
                     ▼                                 ▼
             Binary Executable             compile_commands.json
```

## Quick Start

Install Revoq with Cargo or Lown:
```bash
cargo install revoq
# or
lown install revoq
```

Initialize a new C++ project:
```bash
revoq new my_project --lang cpp
cd my_project
revoq build
revoq run
```

## Features

- **Zero CMake Boilerplate**: Enforces a strict project layout (`src/`, `include/`) with zero configuration files needed for basic builds.
- **Clang Integration**: Generates `compile_commands.json` automatically for Neovim/VSCode language servers.
- **Flamegraph Profiling**: Single-flag `-ftime-trace` profile output to inspect C++ template instantiation speeds.
- **Single-Flag Sanitizers**: `revoq build --sanitizer address,undefined` for instant ASan/UBsan injection.
- **Agent-Native `--json` Flags**: Machine-readable outputs across all build, check, doctor, and vendor commands.

## Documentation

Full guides and C/C++ build tracks: https://revoq.pages.dev

## License

Released under the [MIT License](LICENSE).
