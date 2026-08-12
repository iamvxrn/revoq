# Changelog

All notable changes to **Revoq** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.8.0] - 2026-08-12

### Added (Feature Release)
- **Cross-Platform Target Execution**: Full cross-platform verification for Windows (`.exe`), Linux (`.so`), and macOS (`.dylib`).
- **Agent-Native Diagnostics**: Machine-readable `--json` output format across build, doctor, check, and vendor subcommands.
- **Release Automation**: Cargo manifest path resolution (`cli/Cargo.toml`) in GitHub Actions workflow.

## [v0.7.0] - 2026-08-11

### Added
- Crates.io publication (`cargo install revoq`).
- Native Revoq C/C++ compilation engine support in Lown builder.
- 3-column documentation layout & step-by-step lesson tracks.
