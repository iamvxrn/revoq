---
title: About
---

**deft is an experiment, not a product.** It began as a single question — if you
pointed an AI at "Cargo, but for C and C++," how far would it get? The resolver,
the Clang integration, this site: all of it came out of chasing that question.
deft works, and it's genuinely useful on small projects, but it hasn't earned a
production build yet. Read it as a study of what AI can build in the C/C++
tooling space, and try it in that spirit.

C and C++ tooling is fragmented. `deft` brings a familiar, manifest-driven
package-manager workflow while staying dependency-free itself — it shells out
to tools your system already has (`clang`, `git`, `curl`/`wget`/PowerShell,
`ar`/`llvm-ar`/`lib.exe`) instead of bundling an HTTP client, VCS library, or
archiver crate. See [docs/architecture.md](../docs/guides/architecture) for the full
rationale.
