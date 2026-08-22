# Changelog

All notable changes to **Revoq** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.9.0] - 2026-08-13

### Added (Minor Feature Release)
- **Universal Compiler Driver Fallback Engine**:
  - `Language::driver()` fallback chain: `clang`/`clang++` ➔ `gcc`/`g++` ➔ `tcc` ➔ `zig cc`/`zig c++` ➔ `cc`/`c++`.
  - Enables zero-dependency cross-compilation via Zig CC and sub-10ms legacy dev builds via TCC.
- **Expanded Feature Matrix**: 6-feature comparison matrix vs CMake, Make, and Meson.
- **Legacy C/C++ Standards Support**: Support for `c89`, `c90`, `c99`, `c11`, `c17` and `c++98`, `c++03`, `c++11`, `c++14`, `c++17`, `c++20`, `c++23`.
- **AI Development Transparency**: Explicit disclosure notice in footer and docs.

## [v0.8.0] - 2026-08-12

### Added
- **Multi-OS Native Release Matrix**: Native binaries published for Linux (`ubuntu-latest`), macOS (`macos-latest`), and Windows (`windows-latest`).
- **`revoq completions`**: Shell auto-completion generator for Zsh, Bash, Fish, and PowerShell via `clap_complete`.
- **Hermetic Vendoring**: `revoq vendor` freezes third-party dependencies into `third_party/` for offline builds.
- **Clang Flamegraph Profiling**: Single-flag `-ftime-trace` profiling output (`revoq build --trace`).
