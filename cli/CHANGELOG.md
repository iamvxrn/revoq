# Changelog

All notable changes to this project.

> revol is an experiment in what an AI can build for the C/C++ tooling world —
> "Cargo, but for C and C++." Useful, not production-hardened.

## [0.7.2] - 2026-07-22

### Fixed

- **`.C` entry files on case-insensitive filesystems (Windows, and macOS by
  default).** Entry-point discovery probed `src.join("main.c").is_file()`, which
  on those systems matches a real `main.C` — so a C++ entry named `.C` was
  mis-routed as C (and the CI test for it failed on Windows). Discovery now
  matches the directory's *actual* filenames case-sensitively
  (`find_canonical_entry` in `src/engine.rs`), so `.C` stays C++ everywhere.
  Case-sensitive Linux was unaffected either way.

### Repo / CI (not shipped in the binary)

- Release workflow builds both macOS targets on `macos-14` (Apple Silicon can
  produce the x86_64 artifact too); `macos-13` runners never got scheduled and
  left the whole release queued for hours. Added job `timeout-minutes` so a
  wedged runner fails fast instead of hanging.
- Website: removed all donation/funding content; the Downloads page now detects
  the visitor's OS and surfaces the matching install command; site version label
  tracks the release.

## [0.7.1] - 2026-07-22

A correctness release around dependency versioning.

### Fixed

- **Version tags with a `v` prefix now resolve.** A manifest pinning
  `= "3.12.0"` matches a `v3.12.0` tag (and vice-versa) — the resolver tries
  both spellings (`tag_candidates` in `src/resolver.rs`). Previously the bare
  spelling was passed to `git` verbatim, so a project tagged `vX.Y.Z` wouldn't
  match.
- **No more silent "latest" fallback.** When a pinned version matches no tag,
  the resolve now fails with a clear error instead of full-cloning the default
  branch and leaving the build on whatever HEAD happened to be. A version you
  can't find is an error, not an accidental upgrade.

### Changed

- **`json` moved to its own repository, `github.com/xntas/json`.** A versioned
  `gh:` dependency needs its own version tags, which a monorepo subdirectory
  can't carry — so `libs/json/` is removed from the monorepo and the example app
  depends on the standalone repo the normal way (`"gh:xntas/json" = "3.12.0"`),
  with its `revol.lock` pinned to that tag's commit. (The example no longer
  vendors json into `third_party/`.)
- **The registry index now lives at `website/static/revol-libs`.** `revol sync`'s
  default URL is `raw.githubusercontent.com/xntas/revol/main/website/static/revol-libs`
  (still overridable via `REVOL_LIBS_URL`). One file, two consumers: the CLI
  fetches it, and the website serves it (at `/revol-libs`) and renders its entries
  on the **Packages** page — so the registry and the site can never drift.

## [0.7.0] - 2026-07-22

The **migration** release. 0.6 let revol build "almost-canonical" trees; 0.7
removes the two barriers that still forced you to restructure a real CMake
project by hand. Tested against cJSON and fmt: both now build from a handful of
manifest lines, no files moved. Strict defaults are unchanged — a stock
`revol init` project builds byte-for-byte as before.

### Added

- **`[package] kind`** (`"bin"` / `"lib"`) — drop the requirement for a
  canonically named `main.*`/`lib.*` entry file. With `kind` set, revol builds a
  directory of arbitrarily-named sources (a real library's `cJSON.c`,
  `format.cc`) as the declared artifact, inferring the language from the sources.
  Unset keeps the strict entry-file behavior. Accepts `bin`/`exe`/`executable`
  and `lib`/`library`.
- **`[package] include` / `exclude`** — glob patterns (relative to
  `source_dir`) that narrow the scan, so pointing `source_dir` at a repo root no
  longer drags its `tests/`, `examples/`, and fuzzers into your library.
  `exclude` prunes whole directories; `include`, when set, keeps only matching
  files. A small dependency-free matcher (`src/glob.rs`) supports `*`, `?`, and
  `**` — no new crate, in keeping with revol's zero-dependency stance.

### Changed

- Source discovery now runs through a single `ScanConfig` and a glob-aware
  scanner. The canonical-entry fast path is untouched (and still wins when no
  `kind` is declared), so existing projects resolve exactly as before; the
  entry file is now optional rather than required.

### Notes

- The one-language-per-package rule still holds: a `kind`-driven package that
  mixes C and C++ sources is rejected, with the same guidance to split it or
  narrow the scan with `include`/`exclude`.

## [0.6.0] - 2026-07-22

The **Legacy Support** release. revol stays strict by default, but a handful of
opt-in `[package]` fields now let it build real-world trees that don't follow
the layout — without you rearranging a single file. Every default reproduces
0.5.0 behavior byte-for-byte.

### Added

- **`[package] source_dir`** — the directory revol scans for sources. Defaults to
  `"src"`, so existing manifests are unaffected. For legacy trees whose code
  lives elsewhere.
- **`revol build --from <path>`** — override `source_dir` from the command line
  for a one-off build (also inherited by `revol run`). Precedence:
  `--from` > `[package] source_dir` > `"src"`.
- **`[package] include_dirs`** — extra header search directories (relative to
  the package root), emitted as `-I<path>` to every translation unit, searched
  before dependency headers.
- **`[package] defines`** — project-wide preprocessor defines applied to *both*
  C and C++ units as `-D<entry>`, additive to the per-language
  `[profile.c]`/`[profile.cpp]` `defines`.
- **`[package] ignore_warnings`** and **`revol build --ignore-warnings`** — inject
  `-w` to silence every compiler warning; a blunt escape hatch for noisy code
  you don't own. Either the manifest field or the CLI flag turns it on.
- **Extended source/entry extensions.** The scanner and entry-point discovery
  now accept `.c`, `.cpp`, `.cc`, `.cxx`, and `.C` (the entry point can be
  `main`/`lib` with any of these). A capital `.C` is treated as **C++**, per
  Unix/Clang convention. `.c` still routes to `clang`, everything else to
  `clang++`.

### Changed

- **New home: the project is now a monorepo at `github.com/xntas/revol`.** The
  former `revol-cli/{revol,website,example-app}` repositories are consolidated
  (history preserved) under `cli/`, `website/`, and `examples/example-app/`. The
  website's Cloudflare Pages deployment now builds from the `website/`
  subdirectory. (The `json` library keeps its own repo — see 0.7.1.)
- **Package index moved into the monorepo.** `revol sync`'s default index URL
  points at the `revol-libs` file inside `xntas/revol`, still overridable via
  `REVOL_LIBS_URL`. (Its exact path is refined in 0.7.1.)

### Notes

- The single-language rule is unchanged: a package containing both C and C++
  sources is still rejected. Legacy support widens *where* and *what* revol
  looks for, not the one-package-one-language invariant.

## [0.5.0] - 2026-07-02

### Added

- **Automatic `compile_commands.json` generation.** Every successful `revol
  build` now writes a clangd-compatible compilation database to the project
  root — no flag required. `clangd` (VS Code, Neovim, CLion, ...) picks it up
  automatically, giving accurate autocomplete, go-to-definition, and diagnostics
  that exactly match revol's own compile flags (standard, warnings, defines,
  include paths). Covers the root package and every dependency built in the
  same invocation; workspace builds merge every member's entries into one
  file. Entries are populated even when a library is served from the global
  build cache, since the compile flags are fully determined without actually
  invoking the compiler (`src/compdb.rs`).
- **`revol build --trace`: Clang time-trace profiling.** Injects `-ftime-trace`
  into every translation unit, then aggregates each unit's individual
  `-ftime-trace` output into one `target/<profile>/revol_profile.json` —
  loadable directly at `chrome://tracing` or
  [speedscope.app](https://www.speedscope.app) — and prints a terminal
  summary of the slowest headers and template instantiations across the
  package. The per-unit trace files clang leaves behind are folded into the
  merged profile and removed (`src/trace.rs`). Dependencies are never traced;
  `--trace` profiles the package you're actively working on.
- **Cross-compilation via `--target`.** A new optional `target` string field
  in `[package]` (e.g. `target = "aarch64-unknown-linux-gnu"`), and a
  matching `revol build --target <triple>` / `revol check --target <triple>`
  CLI flag, inject `--target=<triple>` into every compile step *and* the
  final link step — leveraging Clang's native cross-compiler support with no
  separate toolchain to install. The CLI flag always overrides the manifest
  field; omitting both compiles natively with no `--target` flag reaching
  clang at all, byte-for-byte identical to a pre-0.5.0 build. Every
  dependency is force-compiled for the same resolved target as the root
  package, since linking mismatched-architecture object files doesn't work.
  Library builds (which go through `ar`/`llvm-ar`, not clang) never receive
  the flag, matching how sanitizer/LTO flags are already excluded from the
  archiver path.
- **`revol check`: static analysis without a build.** A new subcommand that
  runs Clang's analyzer (`--analyze`) over the package's own sources — no
  object files, no linker invocation, no artifact. Findings are streamed
  through the same colorized diagnostic renderer `revol build` already uses,
  per file, as each one finishes. Only a file the analyzer couldn't even
  parse (a real syntax error, a missing header) fails the command; analyzer
  findings on an otherwise-clean parse are printed and the command still
  exits `0`, the same "warnings don't fail the build" contract `revol build`
  has. Dependencies are resolved just far enough to expose their headers on
  the include path — never compiled or analyzed themselves. Runs across the
  same parallel thread-pool shape as a real build (`-j` to tune).
- `Json::parse` and `Json::render_pretty` in `src/json.rs`: a small,
  dependency-free JSON *reader* (recursive-descent, covering objects, arrays,
  strings with escapes, numbers, bools, and null) added alongside the
  existing writer, plus an indented pretty-printer for human-facing
  artifacts. Used internally to read Clang's `-ftime-trace` output and to
  write `compile_commands.json` — revol's zero-dependency footprint
  (`clap`/`serde`/`toml` only, no `serde_json`) is unchanged; see
  [docs/guides/architecture.md](docs/guides/architecture.md).
- `RevolError::Analysis { failures }` (`error.rs`): a dedicated error variant
  for `revol check` failures, so the top-line message reads `check failed: N
  file(s) could not be analyzed` instead of the misleading `build failed:
  ...` a shared variant would have produced.

### Changed

- `Compiler::new` and `Engine::new` both gained a `trace: bool` parameter.
  `-ftime-trace` is folded into the same flag set used for the global build
  cache's fingerprint, so a `--trace` build and a non-`--trace` build of the
  same library never collide in the cache.
- `Engine::build_package`'s `BuiltArtifact` now carries the package's
  `compile_commands.json` entries; `main.rs`'s dependency/workspace build
  paths aggregate them across every package built in one invocation.
- `Compiler::new` gained a `target: Option<String>` parameter. Flag
  injection was refactored into `push_diagnostics_and_includes` — a smaller
  helper shared by real compiles, `revol check`'s analysis pass, and (via
  `cache_fingerprint`) the global build cache's fingerprint, so `--target`,
  once set, is automatically reflected everywhere a compile flag needs to be
  consistent, including cache-key correctness (a cross-compiled build's
  cache key can never collide with a native build's).
- `Compiler::analyze_unit` (new) builds a deliberately smaller flag set than
  a real compile: standard, warnings, includes, defines, and `--target` are
  kept; optimization level, LTO, sanitizers, `-g`/`-DNDEBUG`, and
  `-ftime-trace` are dropped entirely, since none of them affect what
  `--analyze` reports and `--analyze` never reaches codegen.
- `Engine::check_package` (new) reuses `run_compile` and
  `parse_clang_diagnostics` verbatim from the existing build engine — Clang's
  analyzer emits findings in the identical `file:line:col: severity:
  message` format as ordinary warnings, so no diagnostics-parsing changes
  were needed to support it.
- `jobs(args: &BuildArgs)` was split into a shared `resolve_jobs(explicit:
  Option<usize>)`, used by both `revol build`/`revol run` and `revol check`.

## [0.4.0] - 2026-07-01

### Added

- Native Clang sanitizer support: a `sanitizers` array in `[profile.c]` and
  `[profile.cpp]` (e.g. `sanitizers = ["address", "undefined"]`) propagates
  the matching `-fsanitize=address|thread|undefined|leak` flags to both the
  compilation and linking phases of the build.
- Strict compile-time safety matrix (`Compiler::validate`, run before any
  compilation begins): aborts the build with a descriptive error if `lto`
  is enabled together with the address or leak sanitizer, or if the thread
  sanitizer is combined with the address or leak sanitizer — combinations
  that clang accepts syntactically but that are unsafe or unsupported at
  runtime.
- Automatic `-g` (debug symbols) injection whenever a profile's `sanitizers`
  array is non-empty, including under `--release`, so sanitizer stack
  traces resolve to file/line info instead of raw addresses; a one-time
  warning is printed when this overrides a release profile's own choice.
- `lto` boolean field in `[profile.c]` and `[profile.cpp]` (default
  `false`), emitting `-flto` at both compile and link time.

### Changed

- The manifest schema (`CProfile`/`CppProfile` in `src/manifest.rs`)
  gained `sanitizers` and `lto` fields, both `#[serde(default)]`-backed —
  an absent key parses to `[]`/`false`, so every v0.3.0 manifest continues
  to parse and build unchanged.

## [0.3.0] - 2026-06-26

### Added

- Global build cache at `~/.revol/cache/prebuilt/{hash}`: library packages
  (dependencies, and the root package when it's a library) whose sources,
  compiler flags, and target OS/arch hash identically to a previous build
  are copied straight from the cache, skipping the compile thread-pool
  entirely. Hashing is a small dependency-free module (`src/hash.rs`) built
  on `std::hash::Hasher`.
- `--json` global flag for `revol build` and `revol doctor`, emitting one
  compact, structured JSON object on stdout instead of human-readable text —
  build status/duration/cache-hit counts/compiler diagnostics, and an
  environment check matrix, respectively. Serialized with a small
  dependency-free encoder (`src/json.rs`) rather than `serde_json`.
- `revol vendor` subcommand: copies every dependency in `revol.lock` into a
  local `third_party/` tree. Once populated, `revol build` resolves
  dependencies from it directly — no git, no network, no global cache
  lookups — for fully offline/autonomous builds.
- `toolchain` field in `[package]` (e.g. `toolchain = "clang-18.1"`):
  `revol doctor` and the pre-build phase of `revol build` invoke the pinned
  compiler and abort with a descriptive error if its reported version
  doesn't match.

### Changed

- `revol doctor`'s report (human and `--json`) now includes a `toolchain`
  check when the current directory's manifest declares a pin; otherwise the
  report is unchanged.
- `build_dependencies` no longer takes an unused `Resolver` parameter.

## [0.2.1] - 2026-06-23

### Added

- CI workflow for testing across multiple OS environments.
- Tests for `sync` and `update` subcommands.

## [0.2.0] - 2026-06-22

### Added

- Full-featured CLI with `build`, `sync`, `update`, `doctor`, and `migrate` commands.
- Core build engine with parallel compilation.
- Dependency resolver and package index sync.
- Manifest and lockfile data models.
- C/C++ build argument generation.
- Centralized error handling.
- `migrate --from=cmake` command to import existing CMake projects.

### Changed

- Everything 

## [0.1.0] - 2026-06-16

- Initial release with core functionality.