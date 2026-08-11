---
title: "Manifest Specification"
date: 2026-08-11
prev_title: "5-Minute Quickstart"
prev_link: "/docs/quickstart/"
next_title: "CLI Command Reference"
next_link: "/docs/commands/"
---

## revoq.toml Schema

```toml
[package]
name = "my-cpp-app"
version = "0.1.0"
edition = "2024"

[dependencies]
cJSON = "gh:DaveGamble/cJSON"
```

## Atomic Lockfiles (`revoq.lock`)

`revoq.lock` pins dependencies to exact Git commit SHAs, guaranteeing reproducible builds.
