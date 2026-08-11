---
title: "Overview & Philosophy"
date: 2026-08-11
prev_title: ""
prev_link: ""
next_title: "Installation Track"
next_link: "/docs/installation/"
---

## Cargo-Style Build System for C & C++

Revoq is a deterministic, manifest-driven build engine for C and C++ projects designed to replace complex CMake scripts with Cargo-like ergonomics.

### Key Capabilities

- **Zero-CMake Bloat**: Single manifest file (`revoq.toml`) and lockfile (`revoq.lock`).
- **Strict Layout Conventions**: Enforces `src/main.cpp` / `src/main.c` for binaries and `src/lib.cpp` / `src/lib.c` for libraries.
- **Parallel Compilation Queue**: Automatically scales build tasks across available CPU cores.
