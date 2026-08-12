# Changelog

All notable changes to **Revoq** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.7.4] - 2026-08-12

### Added
- **Cross-Platform Target Execution**: Full cross-platform verification for Windows (`.exe`), Linux (`.so`), and macOS (`.dylib`).
- **Agent-Native Diagnostics**: Machine-readable `--json` output format across build, doctor, check, and vendor commands.

## [v0.7.3] - 2026-08-11

### Security & CI/CD
- **Release Automation**: Fixed Cargo manifest path resolution (`cli/Cargo.toml`) in GitHub Actions release workflow.
- **Cross-Platform Binaries**: Automatic release builds for Linux, macOS, and Windows.

## [v0.7.2] - 2026-08-11

### Added
- Crates.io publication (`cargo install revoq`).
- Native Revoq C/C++ compilation engine support in Lown builder.
- 3-column documentation layout & step-by-step lesson tracks.
