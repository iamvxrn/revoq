---
title: About
---

**revol is an experiment, not a product.** It began as a single question — if you
pointed an AI at "Cargo, but for C and C++," how far would it get? The resolver,
the Clang integration, this site: all of it came out of chasing that question.
revol works, and it's genuinely useful on small projects, but it hasn't earned a
production build yet. Read it as a study of what AI can build in the C/C++
tooling space, and try it in that spirit.

C and C++ tooling is a pile of half-answers that don't talk to each other. revol
gives you one manifest and a workflow you already know from other languages, and
it does that without hauling in a stack of its own dependencies. No bundled HTTP
client, no VCS library, no archiver crate — it just calls the `clang`, `git`,
`curl`/`wget`/PowerShell, and `ar`/`llvm-ar`/`lib.exe` you already have. The
reasoning is written up in [the architecture guide](../docs/guides/architecture).
