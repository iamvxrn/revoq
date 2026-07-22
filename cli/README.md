<div align=center>
<h1>deft</h1>

<h6>A modern package manager and build system for C and C++, with strict
project-layout enforcement and deep Clang integration.</h6>

[![Deft Version](https://img.shields.io/badge/version-0.6.0-e.svg?style=for-the-badge&labelColor=000000&color=ffffff)](https://github.com/xntas/deft/releases/tag/v0.6.0)
[![Platform Support](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg?style=for-the-badge&labelColor=000000&color=ffffff)](#)

</div>

> **Heads up — deft is an experiment, not a product.** It started as a question:
> if you handed an AI the idea "Cargo, but for C and C++," how far could it get?
> Everything here — the resolver, the Clang integration, the docs you're reading
> — came out of that. It works, and we use it on toy projects, but it hasn't
> earned your production build yet. Treat it as a study of what AI can build in
> the C/C++ tooling space, and kick the tires accordingly.

## Why deft?

C and C++ tooling is fragmented. `deft` brings a familiar, manifest-driven
package-manager workflow while staying dependency-free itself — it shells out
to tools your system already has (`clang`, `git`, `curl`/`wget`/PowerShell,
`ar`/`llvm-ar`/`lib.exe`) instead of bundling an HTTP client, VCS library, or
archiver crate. See [docs/guides/architecture.md](docs/guides/architecture.md) for the full
rationale.

- **Strict project layout.** No globbing, no guessing. The entry point is
  exactly `src/main.cpp` / `src/main.c` (executables) or `src/lib.cpp` /
  `src/lib.c` (libraries). Missing it fails the build immediately.
- **Strict C / C++ separation.** A package is single-language. C and C++ are
  distinct enums in the build engine, and a package containing both source
  languages fails the build rather than silently mixing flags.
- **Manifest-driven Clang.** Optimization levels, warnings, language
  standard, RTTI, and exceptions all live in `deft.toml`. No messy flag
  strings.
- **Native sanitizer support.** Declare `sanitizers = ["address", "undefined"]`
  in `[profile.c]`/`[profile.cpp]` and deft propagates the matching
  `-fsanitize=` flags to both compilation and linking, forces `-g` so stack
  traces stay readable, and rejects unsafe combinations (LTO with
  ASan/LSan, or TSan with ASan/LSan) before invoking clang. See
  [Sanitizers](#sanitizers) below.
- **Reproducible builds.** `deft.lock` pins every dependency to an exact git
  commit SHA, written atomically. `deft build` always honors the lock;
  `deft update` is the only command that rewrites it.
- **Parallel by default.** A `std::thread` + `Mutex<VecDeque>` + `mpsc` work
  queue compiles translation units across all cores (`-j` to tune), streaming
  diagnostics back as each unit finishes.
- **Human-readable diagnostics.** Clang's stderr is parsed and reformatted
  into clean, colorized terminal alerts.
- **Cross-platform static linking.** Archiving tries `ar` (Unix) or
  `llvm-ar` then `lib.exe` (Windows), falling through only when a tool is
  genuinely missing — see [docs/guides/architecture.md](docs/guides/architecture.md).
- **Automatic IDE integration.** Every successful `deft build` writes a
  clangd-compatible `compile_commands.json` to the project root, with no flag
  required. See [IDE integration](#ide-integration-compile_commandsjson)
  below.
- **Built-in compilation profiling.** `deft build --trace` surfaces exactly
  where clang's frontend/backend time goes — which headers and template
  instantiations are the slowest — via Clang's `-ftime-trace`. See
  [Profiling builds](#profiling-builds---trace) below.
- **Zero-friction cross-compilation.** `deft build --target <triple>` (or
  `target` in `deft.toml`) injects `--target=<triple>` into every compile and
  link step, dependencies included — Clang is natively a cross-compiler, so
  there's no separate toolchain to install. See
  [Cross-compilation](#cross-compilation) below.
- **Static analysis on demand.** `deft check` runs Clang's analyzer over your
  sources — no object files, no linking, no artifact — and streams findings
  through the same colorized diagnostic renderer `deft build` uses. See
  [Static analysis](#static-analysis-deft-check) below.

## Installation

Since Deft is currently in its early deployment phase, we distribute it directly via source compilation to ensure complete transparency and zero environmental friction.

```sh
cargo build --release
# binary at target/release/deft
```

Requires `clang`/`clang++` and `git` on `PATH`, plus an archiver (`ar` on
Unix; `llvm-ar` or `lib.exe` on Windows) and a fetch tool (`curl`/`wget` on
Unix, PowerShell on Windows). Run `deft doctor` after building to verify your
environment end-to-end, including a real probe compile against `<stdio.h>`.

## Commands

| Command       | Description                                                          |
| ------------- | --------------------------------------------------------------------- |
| `deft init`   | Scaffold a new package (`--lib`, `--bin`, `--c`, `--name`).            |
| `deft build`  | Compile the package (and its dependencies, and workspace members).    |
| `deft run`    | Build, then run the executable (`-- args` forwarded verbatim).         |
| `deft check`  | Run Clang's static analyzer — no object files, no linking, no artifact. |
| `deft update` | Re-resolve dependencies and rewrite `deft.lock`.                      |
| `deft sync`   | Refresh the global package index (`~/.deft/deft-libs`) from the registry. |
| `deft doctor` | Diagnose the local toolchain (compiler, archiver, git, headers, ...). |
| `deft migrate`| Generate a starter `deft.toml` from an existing `CMakeLists.txt`.      |

Common flags: `--release`, `-o <name>`, `-j <N>`, `--features a,b`,
`--no-default-features`, `--trace`, `--target <triple>`, `-v`, `-q`.

Full flag-by-flag mechanics (what `--release` actually overrides, how
`-j` is clamped, how `[-- ARGS...]` forwarding works, etc.) are documented in
[docs/guides/cli.md](docs/guides/cli.md).

## Quick start

```sh
deft init hello && cd hello
deft run
```

## Sanitizers

`[profile.c]` and `[profile.cpp]` accept a `sanitizers` array of Clang
sanitizer names, plus an `lto` toggle:

```toml
[profile.c]
standard = "c17"
optimization = "0"
sanitizers = ["address", "undefined"]
extra_flags = ["-fno-omit-frame-pointer"]
```

| Manifest string | Clang flag |
| --- | --- |
| `"address"` | `-fsanitize=address` (ASan) |
| `"thread"` | `-fsanitize=thread` (TSan) |
| `"undefined"` | `-fsanitize=undefined` (UBSan) |
| `"leak"` | `-fsanitize=leak` (LSan) |

Omitting `sanitizers` (or leaving it `[]`) is fully backwards-compatible with
v0.3.0 manifests — no instrumentation, no behavior change.

**Safety constraints, enforced before clang is ever invoked:**

- `lto = true` together with `"address"` or `"leak"` aborts the build — LTO
  and ASan/LSan are mutually exclusive (link-time reordering/inlining across
  the instrumentation boundary produces unreliable results and much slower
  links).
- `"thread"` together with `"address"` or `"leak"` aborts the build — their
  runtime libraries install conflicting interceptors and can't coexist in one
  binary.
- Any non-empty `sanitizers` array forces `-g` into the compile flags, even
  under `--release`, so sanitizer stack traces resolve to real file/line
  info instead of raw addresses. A release build with active sanitizers
  prints one warning noting this override.

The same `-fsanitize=` (and `-flto`) flags used to compile the package's
translation units are also passed to the final link step, and are always
injected *before* `extra_flags`, so granular sub-flags like
`-fno-omit-frame-pointer` can still be layered on afterward. Library builds
go through the archiver, not clang's linker, so sanitizer flags don't apply
there. See [docs/guides/manifest.md](docs/guides/manifest.md#sanitizers-and-lto--clang-sanitizer-support)
for the full mechanics.

## IDE integration (`compile_commands.json`)

Every successful `deft build` writes a
[JSON compilation database](https://clang.llvm.org/docs/JSONCompilationDatabase.html)
to `compile_commands.json` in the project root — automatically, with no flag
required. `clangd` (the language server behind VS Code's C/C++ extension,
Neovim, CLion, and most other C/C++ editor tooling) reads this file to learn
exactly how deft compiles each translation unit, so autocomplete, go-to-definition,
and inline diagnostics all match your real build: the same `-std`, warnings,
defines, and `-I` include paths deft passed to clang, not a guess.

```sh
deft build          # writes ./compile_commands.json alongside deft.toml
```

Nothing else to configure — point your editor's clangd at the project root
(most extensions auto-detect `compile_commands.json` there) and it picks up
the database on the next build. Entries cover the root package and every
dependency compiled in that invocation; a workspace build merges every
member's entries into the one file. Since a library's compile flags are
deterministic, entries are written even for packages served from the global
build cache — you get full IDE coverage without forcing a recompile.

If you don't want the file tracked in git, add it to `.gitignore` (`deft
init` doesn't do this for you, since some teams do commit it for reproducible
editor setup across a team).

## Profiling builds (`--trace`)

Clang can report exactly where compilation time goes — parsing headers,
expanding macros, instantiating templates — via `-ftime-trace`. Pass
`--trace` to have deft turn that on and make sense of the output for you:

```sh
deft build --trace
```

deft injects `-ftime-trace` into every translation unit, merges each unit's
individual trace file into one aggregate profile at
`target/<debug|release>/deft_profile.json`, and prints a summary of the
slowest headers and template instantiations straight to the terminal:

```
   Compiling demo v0.1.0 (3 units, 8 jobs)
    Profile top 10 compilation bottlenecks
          842.10ms  Source               /usr/include/c++/14/vector  (in main.cpp)
          301.55ms  InstantiateFunction  std::vector<Widget>::push_back  (in main.cpp)
          ...
    Finished profile written to target/debug/deft_profile.json
               load it at chrome://tracing or https://www.speedscope.app
```

`deft_profile.json` is standard [Chrome Trace Event
Format](https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU) —
drop it into `chrome://tracing` or [speedscope.app](https://www.speedscope.app)
for a full interactive flame graph across every translation unit in the
package, each shown on its own track. `--trace` is scoped to the package
you're actively building; dependencies are compiled normally and aren't
included in the profile.

## Cross-Compilation

Clang is natively a cross-compiler — the same `clang`/`clang++` binary you
already have can target a different architecture or OS with just a
`--target=<triple>` flag. deft exposes that directly: no separate toolchain
to download, no target-specific `clang` symlinks to manage.

Set it in `deft.toml`:

```toml
[package]
name = "my_project"
version = "0.2.0"
target = "aarch64-unknown-linux-gnu"   # optional; omit for a native build
```

or override it per invocation:

```sh
deft build --target aarch64-apple-darwin
deft build --target wasm32-unknown-unknown
```

`--target` on the command line always wins over the manifest's `target`
field; omitting both compiles natively, with no `--target` flag reaching
clang at all. Whichever triple wins is injected into **every** compile step
and the final link step — and, importantly, into every *dependency's*
compile too, since object files built for two different targets can't be
linked into one artifact. `deft check --target <triple>` (see below)
analyzes against the same target-specific headers and predefined macros a
real cross-compiled build would see.

deft doesn't validate the triple itself — an unrecognized one simply
surfaces as clang's own error the moment it's invoked, the same way an
invalid `extra_flags` entry would. See
[docs/guides/manifest.md](docs/guides/manifest.md#target--cross-compilation)
for the full resolution/priority rules.

## Legacy Support

deft is opinionated on purpose: sources live in `src/`, the entry point is
`main`/`lib`, one package speaks one language. That's great for new projects and
miserable for the twenty-year-old tree you were handed on a Friday afternoon. The
`[package]` fields below are the escape hatches that let you point deft at code
you didn't write without rearranging any of it. Leave them out and nothing
changes — every default reproduces the strict 0.5.0 behavior exactly.

```toml
[package]
name    = "vendored_thing"
version = "0.6.0"

# Sources aren't under src/? Say where they are.
source_dir = "source"

# Public headers live somewhere non-obvious? Add them to the include path.
# Resolved relative to the package root; searched before dependency headers.
include_dirs = ["legacy/include", "third_party/zlib"]

# Project-wide -D defines, applied to BOTH C and C++ units. Additive to the
# per-language `defines` under [profile.c] / [profile.cpp].
defines = ["HAVE_CONFIG_H", "MAX_CONN=64"]

# Building someone else's noisy code? Silence every warning with -w.
ignore_warnings = true
```

A few things worth knowing:

- **`source_dir`** defaults to `"src"`. `deft build --from <path>` overrides it
  from the command line without touching the manifest — handy for a one-off build
  of a tree whose layout you don't want to commit to.
- **The entry point still has to be `main.*` or `lib.*`**, but the extension can
  now be any of `.c`, `.cpp`, `.cc`, `.cxx`, or `.C` — not just `.cpp`/`.c`. So a
  legacy `src/main.cxx` or `src/main.C` is found and built.
- **`.C` (capital) is C++**, following the long-standing Unix/Clang convention.
  Extension routing is unchanged otherwise: `.c` compiles with `clang`,
  everything else with `clang++`.
- **`--ignore-warnings`** is the CLI twin of `ignore_warnings`; either one turns
  warnings off. It's a blunt instrument (`-w` disables *everything*) — reach for
  per-warning control in `[profile]` `warnings`/`extra_flags` when you can.

The single-language rule still holds: a C package containing a stray `.cpp` (or a
C++ package with a stray `.c`) is still an error, because mixing the two silently
is how ABI bugs are born.

## Static analysis (`deft check`)

`deft check` runs Clang's static analyzer over your package's own sources —
parsing and analysis only, no object files, no linker, no binary:

```sh
deft check
```

```
   Checking 3 files (8 jobs)
warning[deadcode.DeadStores]: Value stored to 'x' is never read
  --> src/main.cpp:12:5

    Finished static analysis: 3 files checked
```

Findings are streamed through the exact same colorized diagnostic renderer
`deft build` uses, as each file finishes — not batched until the end. A file
the analyzer couldn't even parse (a real syntax error, a missing header)
fails the command; analyzer findings on an otherwise-clean parse are printed
as warnings and don't. `deft check` accepts the same `--features`,
`--no-default-features`, `--target`, `-j`, and `--manifest-path` flags as
`deft build`, minus everything that only matters for producing a binary
(`--release`, `-o`, `--trace`). Dependencies are resolved just far enough to
put their headers on the include path — never compiled or analyzed
themselves, since `deft check` audits the package you're working on.

## The deft home

`deft` keeps global state under `~/.deft` (override with `$DEFT_HOME`):

- `~/.deft/deft-libs` — shorthand → URL mapping, one entry per line, refreshed
  by `deft sync`:
  ```
  gh:user/http_parser   https://github.com/user/http_parser.git
  ```
  `gh:user/lib` shorthands also resolve to GitHub automatically without an
  entry.
- `~/.deft/cache/` — global clone cache, keyed by `<name>-<tag>`, reused
  across projects and updates.

## License

Licensed under the MIT license — see [LICENSE.md](LICENSE.md).
