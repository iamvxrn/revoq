---
title: "Downloads"
---

## Install script

The quickest way in. This grabs the right prebuilt binary for your machine,
drops it in `~/.local/bin`, and runs `deft doctor` to check your toolchain.

**macOS, Linux, WSL, or Git Bash:**

```sh
curl -fsSL https://deft-cli.com/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://deft-cli.com/install.ps1 | iex
```

Piping a script into your shell is convenient but you're trusting it — read it
first if you like ([install.sh](https://deft-cli.com/install.sh),
[install.ps1](https://deft-cli.com/install.ps1)). Want a specific version? Set
`DEFT_VERSION=v0.6.0` before running. Want it somewhere else? Set
`DEFT_BIN_DIR`.

## Build from source

Prefer to build it yourself? Nothing to trust but the code:

```sh
cargo build --release
# binary at target/release/deft
```

## What you'll need

Either way, deft leans on tools you probably already have: `clang`/`clang++` and
`git` on your `PATH`, an archiver (`ar` on Unix; `llvm-ar` or `lib.exe` on
Windows), and a fetch tool (`curl`/`wget` on Unix, PowerShell on Windows). Run
`deft doctor` any time — it checks the whole toolchain end to end, right down to
a real probe compile against `<stdio.h>`.
