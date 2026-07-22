---
title: "Downloads"
---

deft is early, so for now you build it from source. Nothing to trust but the
code, and no installer doing things behind your back.

```sh
cargo build --release
# binary at target/release/deft
```

You'll need `clang`/`clang++` and `git` on your `PATH`, an archiver (`ar` on
Unix; `llvm-ar` or `lib.exe` on Windows), and a fetch tool (`curl`/`wget` on
Unix, PowerShell on Windows). Once it's built, run `deft doctor` — it checks the
whole toolchain end to end, down to a real probe compile against `<stdio.h>`.
