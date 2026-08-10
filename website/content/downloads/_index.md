---
title: "Downloads"
lead: "One line to install — we'll highlight the one for your system."
---

The install script grabs the right prebuilt binary for your machine, drops it in
`~/.local/bin` (`%LOCALAPPDATA%\revol\bin` on Windows), and runs `revol doctor` to
check your toolchain.

Piping a script into your shell is convenient, but you're trusting it — read it
first if you like ([install.sh](/install.sh), [install.ps1](/install.ps1)). Want
a specific version? Set `REVOL_VERSION=v0.7.2` before running. Want it somewhere
else? Set `REVOL_BIN_DIR`.

## Build from source

Prefer to build it yourself? Nothing to trust but the code:

```sh
cargo build --release
# binary at target/release/revol
```

## What you'll need

Either way, revol leans on tools you probably already have: `clang`/`clang++` and
`git` on your `PATH`, an archiver (`ar` on Unix; `llvm-ar` or `lib.exe` on
Windows), and a fetch tool (`curl`/`wget` on Unix, PowerShell on Windows). Run
`revol doctor` any time — it checks the whole toolchain end to end, right down to
a real probe compile against `<stdio.h>`.
