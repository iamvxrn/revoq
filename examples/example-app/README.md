# Example App

A minimalist C++ demonstration app showcasing the power, speed, and strict layout architecture of the **Deft** build system.

> Part of the [deft](https://github.com/xntas/deft) monorepo. deft is an
> experiment in what an AI can build for C/C++ tooling — "Cargo, but for C and
> C++" — not a production tool.

## Third-party code

This example depends on [nlohmann/json](https://github.com/nlohmann/json) —
declared as `"gh:xntas/json" = "3.12.0"` and fetched by deft into its cache at
build time (it is not vendored into this tree). That library is **MIT-licensed**,
Copyright © 2013–2026 Niels Lohmann; its license and per-file SPDX copyright
headers travel with the source in the [`xntas/json`](https://github.com/xntas/json)
repository. It is the property of its authors and is not covered by this
project's own license.