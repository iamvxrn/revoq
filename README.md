# Revoq

> **Revoq** is a Cargo-style build engine and package manager for C and C++, featuring automatic compiler driver resolution (Clang, GCC, TCC, Zig CC), strict project-layout enforcement, Clang compilation database generation (`compile_commands.json`), `-ftime-trace` flamegraphs, and single-flag sanitizer injection.

[![Latest Release](https://img.shields.io/github/v/release/iamvxrn/revoq?color=4a7bc0&label=release)](https://github.com/iamvxrn/revoq/releases)
[![Documentation](https://img.shields.io/badge/docs-revoq.pages.dev-4a7bc0.svg)](https://revoq.pages.dev)
[![Deployment](https://img.shields.io/badge/deployment-active-4a7bc0.svg)](https://revoq.pages.dev)
[![OS Matrix](https://img.shields.io/badge/OS-Linux%20%7C%20macOS%20%7C%20Windows-4a7bc0.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-4a7bc0.svg)](LICENSE)
[![AI Pairing](https://img.shields.io/badge/AI%20Pairing-Antigravity%20Agent-4a7bc0.svg)](#)

```
                       src/ & include/ (Strict Layout)
                                      │
                              [ Revoq Engine ]
                                      │
                     ┌────────────────┴────────────────┐
                     ▼                                 ▼
             Binary Executable             compile_commands.json
```

## 🚀 Key Capabilities

- **Compiler Virtualization**: Auto-detects driver fallback chain: `clang`/`clang++` ➔ `gcc`/`g++` ➔ `tcc` ➔ `zig cc`/`zig c++` ➔ `cc`/`c++`.
- **Zero-Dependency Cross-Compilation**: Build for any target architecture/OS using `zig cc` (`revoq build --target aarch64-unknown-linux-gnu`).
- **Instant Sub-10ms Dev Builds**: Legacy C compilation powered by TCC (`tcc`).
- **Zero CMake Boilerplate**: Enforces a clean layout (`src/`, `include/`) with zero configuration files needed for basic builds.
- **Language Server Ready**: Auto-generates `compile_commands.json` for Neovim, VSCode, and Clangd.
- **Flamegraph Profiling**: Single-flag `-ftime-trace` profile output (`revoq build --trace`) to inspect C++ template instantiation bottlenecks.
- **Single-Flag Sanitizers**: `revoq build --sanitizer address,undefined` for instant ASan/UBSan instrumentation.
- **Agent-Native `--json` Flags**: Machine-readable outputs across all build, check, doctor, and vendor commands.

## 📦 Quick Start

### Installation

Install via **Lown** or **Cargo**:
```bash
lown install revoq
# or
cargo install revoq
```

Or download precompiled binary release archives for Linux, macOS (Intel & Apple Silicon), and Windows from [GitHub Releases](https://github.com/iamvxrn/revoq/releases).

### Creating a New Project

```bash
revoq new my_project --lang cpp
cd my_project
revoq build
revoq run
```

## 📖 Documentation & Releases

- **Documentation & Guides**: [https://revoq.pages.dev](https://revoq.pages.dev)
- **Changelog & Version History**: [https://revoq.pages.dev/changelog/](https://revoq.pages.dev/changelog/)
- **GitHub Release Assets**: [https://github.com/iamvxrn/revoq/releases](https://github.com/iamvxrn/revoq/releases)

## 📄 License

Released under the [MIT License](LICENSE). Built autonomously by AI agentic pairing under human direction.
