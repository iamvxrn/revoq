<div align=center>
<h1>deft</h1>

<h6>Cargo, but for C and C++. Strict project layout, Clang doing the heavy
lifting, and builds you can actually reproduce.</h6>

[![Deft Version](https://img.shields.io/badge/version-0.7.0-e.svg?style=for-the-badge&labelColor=000000&color=ffffff)](https://github.com/xntas/deft/releases/tag/v0.7.0)
[![Platform Support](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg?style=for-the-badge&labelColor=000000&color=ffffff)](#)

</div>

> **First things first: deft is an experiment, not a product.** It started from a
> single question — hand an AI the idea "Cargo, but for C and C++," and see how
> far it gets. The resolver, the Clang integration, these docs: all of it came
> out of chasing that. It works, and it's genuinely pleasant on small projects,
> but it hasn't earned your production build yet. Read it as a study of what AI
> can do in the C/C++ tooling space, and kick the tires.

## Why deft?

C and C++ tooling is a pile of half-answers that don't talk to each other. deft
gives you one manifest and a workflow you already know from other languages, and
it does that without dragging in a heap of its own dependencies. There's no
bundled HTTP client, no VCS library, no archiver crate — it just calls the
`clang`, `git`, `curl`/`wget`/PowerShell, and `ar`/`llvm-ar`/`lib.exe` your
system already has. If you want the reasoning behind that, it's written up in
[docs/guides/architecture.md](docs/guides/architecture.md).

What you get:

- **One place for your code.** deft doesn't go hunting for sources. Your entry
  point is `src/main.cpp` or `src/main.c` for an executable, `src/lib.cpp` or
  `src/lib.c` for a library. If it's not there, the build stops and tells you —
  right away, not three steps later.
- **C and C++ don't mix.** A package speaks one language. The build engine keeps
  them as separate types, and a package that smuggles in the other language is
  rejected rather than quietly compiled with the wrong flags.
- **Clang settings live in `deft.toml`.** Optimization level, warnings, language
  standard, RTTI, exceptions — all in the manifest, none of it in some
  ever-growing flag string you copy between projects.
- **Sanitizers that just work.** Put `sanitizers = ["address", "undefined"]` in
  `[profile.c]`/`[profile.cpp]` and deft wires the right `-fsanitize=` flags into
  both compilation and linking, keeps `-g` on so stack traces stay readable, and
  refuses combinations that don't actually work (LTO with ASan/LSan, or TSan with
  ASan/LSan) before it ever calls clang. More in [Sanitizers](#sanitizers).
- **Builds you can reproduce.** `deft.lock` pins every dependency to an exact git
  commit and is written atomically. `deft build` always respects the lock;
  `deft update` is the one command allowed to rewrite it.
- **Parallel out of the box.** A work queue built on `std::thread`,
  `Mutex<VecDeque>`, and `mpsc` compiles across all your cores (`-j` to dial it
  in), and diagnostics come back the moment each unit finishes.
- **Diagnostics that read like alerts.** deft parses clang's stderr and reprints
  it as clean, colorized messages instead of a wall of text.
- **Static linking on every platform.** Archiving reaches for `ar` on Unix, or
  `llvm-ar` then `lib.exe` on Windows, only moving on when a tool genuinely isn't
  there. Details in [docs/guides/architecture.md](docs/guides/architecture.md).
- **Your editor stays in sync.** Every successful `deft build` drops a
  clangd-compatible `compile_commands.json` in the project root. No flag, no
  setup. See [IDE integration](#ide-integration-compile_commandsjson).
- **Find your slow headers.** `deft build --trace` shows where clang's time
  actually goes — which headers and template instantiations are dragging — using
  Clang's `-ftime-trace`. See [Profiling builds](#profiling-builds---trace).
- **Cross-compiling is one flag.** `deft build --target <triple>` (or `target`
  in `deft.toml`) passes `--target=<triple>` through every compile and link,
  dependencies included. Clang is already a cross-compiler, so there's nothing
  extra to install. See [Cross-compilation](#cross-compilation).
- **Analyze without building.** `deft check` runs Clang's analyzer over your
  sources — no objects, no linking, no binary — and prints findings through the
  same renderer `deft build` uses. See [Static analysis](#static-analysis-deft-check).

## Installation

deft is early, so for now you build it from source — you get to see exactly what
you're running, and there's nothing to trust but the code in front of you.

```sh
cargo build --release
# binary at target/release/deft
```

You'll need `clang`/`clang++` and `git` on your `PATH`, an archiver (`ar` on
Unix; `llvm-ar` or `lib.exe` on Windows), and a fetch tool (`curl`/`wget` on
Unix, PowerShell on Windows). Once it's built, run `deft doctor` — it checks the
whole toolchain end to end, right down to a real probe compile against
`<stdio.h>`.

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

Flags you'll reach for: `--release`, `-o <name>`, `-j <N>`, `--features a,b`,
`--no-default-features`, `--trace`, `--target <triple>`, `-v`, `-q`.

Want the exact mechanics — what `--release` actually changes, how `-j` gets
clamped, how `[-- ARGS...]` forwarding works? That's all in
[docs/guides/cli.md](docs/guides/cli.md).

## Quick start

```sh
deft init hello && cd hello
deft run
```

## Sanitizers

`[profile.c]` and `[profile.cpp]` take a `sanitizers` array of Clang sanitizer
names, plus an `lto` toggle:

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

Leave `sanitizers` out (or set it to `[]`) and nothing changes — same behavior
as a v0.3.0 manifest, no instrumentation.

deft checks a few things before it ever calls clang, so you fail fast instead of
mid-build:

- `lto = true` alongside `"address"` or `"leak"` is rejected. LTO and ASan/LSan
  don't mix: link-time reordering and inlining across the instrumentation
  boundary give you unreliable results and much slower links.
- `"thread"` alongside `"address"` or `"leak"` is rejected too — their runtime
  libraries install interceptors that fight each other, and can't share a binary.
- Any non-empty `sanitizers` array forces `-g` into the compile flags, even under
  `--release`, so a sanitizer stack trace points at a real file and line instead
  of a raw address. A release build with sanitizers on prints one warning to say
  it did this.

The same `-fsanitize=` and `-flto` flags used to compile the package also go to
the final link step, always *before* your `extra_flags`, so you can still layer
granular sub-flags like `-fno-omit-frame-pointer` on top. Library builds go
through the archiver instead of clang's linker, so sanitizer flags don't apply
there. Full mechanics in
[docs/guides/manifest.md](docs/guides/manifest.md#sanitizers-and-lto--clang-sanitizer-support).

## IDE integration (`compile_commands.json`)

Every successful `deft build` writes a
[JSON compilation database](https://clang.llvm.org/docs/JSONCompilationDatabase.html)
to `compile_commands.json` in your project root, automatically, no flag needed.
`clangd` — the language server behind VS Code's C/C++ extension, Neovim, CLion,
and most other C/C++ editor tooling — reads that file to learn exactly how deft
compiles each file. So your autocomplete, go-to-definition, and inline
diagnostics all match your real build: the same `-std`, warnings, defines, and
`-I` paths deft handed to clang, not an editor's best guess.

```sh
deft build          # writes ./compile_commands.json alongside deft.toml
```

There's nothing else to set up — point your editor's clangd at the project root
(most extensions find `compile_commands.json` on their own) and it picks up the
database on the next build. The file covers the root package and every dependency
built in that run, and a workspace build merges every member into one file.
Because a library's compile flags are fully determined ahead of time, entries get
written even for packages served straight from the build cache — full editor
coverage without forcing a recompile.

Don't want it tracked in git? Add it to `.gitignore`. `deft init` won't do that
for you, since some teams deliberately commit it to keep editor setup identical
across the whole team.

## Profiling builds (`--trace`)

Clang can tell you exactly where compile time goes — parsing headers, expanding
macros, instantiating templates — through `-ftime-trace`. Pass `--trace` and
deft turns it on and does the reading for you:

```sh
deft build --trace
```

deft injects `-ftime-trace` into every translation unit, merges each unit's trace
into one profile at `target/<debug|release>/deft_profile.json`, and prints the
worst offenders straight to your terminal:

```
   Compiling demo v0.1.0 (3 units, 8 jobs)
    Profile top 10 compilation bottlenecks
          842.10ms  Source               /usr/include/c++/14/vector  (in main.cpp)
          301.55ms  InstantiateFunction  std::vector<Widget>::push_back  (in main.cpp)
          ...
    Finished profile written to target/debug/deft_profile.json
               load it at chrome://tracing or https://www.speedscope.app
```

`deft_profile.json` is plain [Chrome Trace Event
Format](https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU),
so drop it into `chrome://tracing` or
[speedscope.app](https://www.speedscope.app) for an interactive flame graph, each
translation unit on its own track. `--trace` only profiles the package you're
building; dependencies compile normally and stay out of the picture.

## Cross-Compilation

Clang is already a cross-compiler — the same `clang`/`clang++` you have can build
for another architecture or OS with nothing more than a `--target=<triple>` flag.
deft just hands that to you: no second toolchain to download, no target-specific
`clang` symlinks to babysit.

Set it in `deft.toml`:

```toml
[package]
name = "my_project"
version = "0.2.0"
target = "aarch64-unknown-linux-gnu"   # optional; omit for a native build
```

or override it for a single run:

```sh
deft build --target aarch64-apple-darwin
deft build --target wasm32-unknown-unknown
```

The command-line `--target` always beats the manifest's `target`; leave both off
and you get a native build with no `--target` reaching clang at all. Whichever
triple wins goes into every compile step, the final link, and — this part
matters — every *dependency's* compile too, since you can't link objects built
for two different targets into one artifact. `deft check --target <triple>` (below)
analyzes against the same target-specific headers and predefined macros a real
cross build would see.

deft doesn't second-guess the triple. An unrecognized one just surfaces as
clang's own error the moment it runs, the same way a bad `extra_flags` entry
would. The full resolution and priority rules are in
[docs/guides/manifest.md](docs/guides/manifest.md#target--cross-compilation).

## Legacy Support

deft is opinionated on purpose: sources in `src/`, an entry point named
`main`/`lib`, one language per package. That's great when you're starting fresh
and painful when someone hands you a twenty-year-old tree on a Friday afternoon.
The `[package]` fields below are the escape hatches — they let you aim deft at
code you didn't write without moving a single file. Leave them out and nothing
changes; every default is the strict 0.5.0 behavior.

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

# Sources aren't named main.*/lib.*? Say what to build and deft stops
# needing a canonical entry file (0.7).
kind = "lib"

# Narrow the scan so tests/examples/fuzzers don't get compiled in (0.7).
exclude = ["tests/**", "fuzzing/**"]
```

A few things worth knowing:

- **`source_dir`** defaults to `"src"`. `deft build --from <path>` overrides it
  from the command line without touching the manifest — handy for a one-off build
  of a tree whose layout you'd rather not commit to.
- **`kind` frees you from the `main`/`lib` entry name.** A real library's files
  are called `cJSON.c` or `format.cc`, never `lib.c`. Set `kind = "lib"` (or
  `"bin"`) and deft builds the directory as that artifact, working out the
  language from the sources — no entry file, no renaming. Leave `kind` off and
  the strict entry-file discovery is exactly as it was.
- **`include` / `exclude` glob the scan.** Point `source_dir` at a whole repo
  and `exclude = ["tests/**", "fuzzing/**"]` keeps its test suite out of your
  build; `include` narrows it the other way. Patterns understand `*`, `?`, and
  `**`.
- **Entry extensions are flexible too:** `main`/`lib` entries may be `.c`,
  `.cpp`, `.cc`, `.cxx`, or `.C`. A capital `.C` is **C++** (Unix/Clang
  convention). Routing is unchanged: `.c` → `clang`, everything else → `clang++`.
- **`--ignore-warnings`** is the CLI twin of `ignore_warnings`; either one turns
  warnings off. It's blunt (`-w` disables *everything*), so reach for per-warning
  control in `[profile]` `warnings`/`extra_flags` when you can.

The one-language rule still holds: a package that mixes C and C++ sources is an
error. Mixing the two silently is exactly how ABI bugs are born.

**Migrating a real project?** For instance, vendoring cJSON — whose sources sit
at the repo root beside its tests — takes a five-line manifest and moves nothing:

```toml
[package]
name       = "cjson"
version    = "1.7.18"
kind       = "lib"
source_dir = "."
exclude    = ["tests/**", "fuzzing/**"]
```

## Static analysis (`deft check`)

`deft check` runs Clang's static analyzer over your package's own sources —
parsing and analysis only, no objects, no linker, no binary:

```sh
deft check
```

```
   Checking 3 files (8 jobs)
warning[deadcode.DeadStores]: Value stored to 'x' is never read
  --> src/main.cpp:12:5

    Finished static analysis: 3 files checked
```

Findings stream through the same colorized renderer `deft build` uses, printed as
each file finishes rather than dumped at the end. A file the analyzer can't even
parse — a real syntax error, a missing header — fails the command; analyzer
findings on an otherwise-clean parse print as warnings and don't. `deft check`
takes the same `--features`, `--no-default-features`, `--target`, `-j`, and
`--manifest-path` flags as `deft build`, minus everything that only matters for
producing a binary (`--release`, `-o`, `--trace`). Dependencies are resolved just
far enough to put their headers on the include path — never compiled or analyzed
themselves, since `deft check` is about the package you're working on.

## The deft home

deft keeps its global state under `~/.deft` (override it with `$DEFT_HOME`):

- `~/.deft/deft-libs` — the shorthand → URL map, one entry per line, refreshed by
  `deft sync`:
  ```
  gh:user/http_parser   https://github.com/user/http_parser.git
  ```
  `gh:user/lib` shorthands also resolve to GitHub on their own, no entry needed.
- `~/.deft/cache/` — the global clone cache, keyed by `<name>-<tag>` and reused
  across projects and updates.

## License

MIT — see [LICENSE.md](LICENSE.md).
