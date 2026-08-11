---
title: "Parallel Build Engine"
date: 2026-08-11
prev_title: "CLI Command Reference"
prev_link: "/docs/commands/"
next_title: ""
next_link: ""
---

## Build Architecture

Revoq compiles C/C++ projects using a multi-threaded worker queue:

1. Manifest parsing (`revoq.toml`).
2. Dependency locking (`revoq.lock`).
3. Translation unit discovery (`src/*.cpp`).
4. Worker pool compilation via `g++` / `clang++`.
5. Link step output executable.
