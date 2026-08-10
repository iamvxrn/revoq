# CLI Reference

Complete command and flag reference for the `revol` binary, derived from the
`clap` definitions in [cli.rs](../src/cli.rs) and the dispatch logic in
[main.rs](../src/main.rs).

```
revol [-v|--verbose]... [-q|--quiet] <COMMAND>
```

## Global Constraints

Two global flags are declared on the top-level `Cli` struct with
`global = true`, meaning they are accepted before *or* after the subcommand:

```rust
#[arg(short, long, action = clap::ArgAction::Count, global = true)]
pub verbose: u8,

#[arg(short, long, global = true, conflicts_with = "verbose")]
pub quiet: bool,
```

- **`-v` / `--verbose` (repeatable counting flag).** Uses
  `clap::ArgAction::Count`, so `verbose` is a `u8` incremented once per
  occurrence: `-v` → `1`, `-vv` → `2`, `-vvv` → `3`, etc. Internally, however,
  every call site only ever checks `cli.verbose > 0` (see `main()` in
  [main.rs](../src/main.rs): `let verbose = cli.verbose > 0;`) — there is
  currently no behavioral distinction between `-v` and `-vv`; both enable the
  same single verbose mode (extra `[engine]`/`[resolver]`/`[revol]` diagnostic
  lines prefixed in dim gray). The counting arity exists in the parser today
  primarily for forward compatibility with finer-grained verbosity levels.

- **`-q` / `--quiet`.** A plain boolean. Declared with
  `conflicts_with = "verbose"` — clap will reject any invocation that mixes
  `-q` with `-v`/`--verbose` at the argument-parsing stage, before revol's own
  code ever runs. Quiet mode suppresses the green/cyan progress lines
  (`Compiling`, `Linking`, `Locking`, `Updated`, `Created`, `Migrated`,
  `Syncing`, etc.) that every command prints by default, but does **not**
  suppress hard errors (printed via `eprintln!` to stderr regardless of
  `quiet`) or the unconditional `revol migrate` unmapped-source warning (see
  [migration.md](migration.md)).

Both flags are parsed once at the top of `main()` and threaded explicitly
through every command handler as `(verbose: bool, quiet: bool)` parameters —
there is no global/thread-local state.

- **`--json`.** Also `global = true`, so it parses before or after any
  subcommand. Only `revol build` and `revol doctor` currently act on it; other
  commands accept the flag without erroring but ignore it. When set, the
  command's entire human-readable output (the `Compiling`/`Linking`/`Finished`
  progress lines, the `doctor` table, etc.) is replaced by exactly one
  compact JSON object printed to stdout — see [`--json` Output](#--json-output)
  below for the payload shapes. Implemented with a small dependency-free
  encoder, [json.rs](../src/json.rs), rather than `serde_json`, to keep
  revol's three-dependency footprint unchanged (see
  [architecture.md](architecture.md)).

## Command Matrix

### `revol build`

```
revol build [--release] [-o NAME] [-j N] [--manifest-path DIR]
            [--features A,B,C] [--no-default-features] [--trace] [--target TRIPLE]
            [--from PATH] [--ignore-warnings]
```

| Flag | Mechanics |
|---|---|
| `--release` | Boolean. Passed through to `Compiler::new(..., release)` and `Engine::build_package(..., release)`. Two concrete effects: (1) `Compiler::effective_opt` **unconditionally returns `OptLevel::O3`**, ignoring whatever `optimization` string is set in `[profile.c]`/`[profile.cpp]` — release always means `-O3`, full stop, regardless of manifest config; (2) `push_common` appends `-DNDEBUG` and omits `-g`. Debug builds (`release = false`) do the opposite: honor the manifest's `optimization` field via `OptLevel::parse`, and always append `-g`. |
| `-o`, `--output NAME` | `Option<String>`. Overrides the artifact's base filename (before the platform-specific extension is applied: `.exe`/bare on Unix for executables, `.lib`/`lib*.a` for libraries). Defaults to the package name. |
| `-j`, `--jobs N` | `Option<usize>`. Resolved by `resolve_jobs()` in [main.rs](../src/main.rs) (shared with `revol check`): `explicit.unwrap_or_else(default_jobs).max(1)`. This is the **clamping**: an explicit `-j` is floored to a minimum of `1` (so `-j 0` cannot spawn zero workers), and an absent `-j` falls back to `std::thread::available_parallelism()`. `Engine::new` applies a second floor (`jobs.max(1)`) and `compile_all`/`check_package` further clamp the *actual* worker count to `self.jobs.min(total)` — never more threads spawned than there are translation units to process. |
| `--manifest-path DIR` | `Option<PathBuf>`. May point at a directory or directly at a `revol.toml` file (`project_root` strips the filename in the latter case). Defaults to the current working directory. Resolution fails fast with `LayoutViolation` if no `revol.toml` is found at the resolved root. |
| `--features A,B,C` | `Vec<String>`, comma-delimited (`value_delimiter = ','`). Unioned with the manifest's `default` feature set (unless suppressed) and transitively expanded — see [manifest.md](manifest.md#feature-flag-resolution). |
| `--no-default-features` | Boolean. Suppresses automatic inclusion of the `[features] default` set; explicitly-passed `--features` are still honored. |
| `--trace` | Boolean. Threaded into both `Compiler::new(..., trace)` and `Engine::new(..., trace)`. See [Build profiling (`--trace`)](#build-profiling---trace) below. |
| `--target TRIPLE` | `Option<String>`. Overrides `[package] target` when both are set. See [Cross-compilation (`--target`)](#cross-compilation---target) below. |
| `--from PATH` | `Option<PathBuf>` (legacy support). The directory revol scans for sources and the entry point, overriding `[package] source_dir` for this invocation. `effective_source_dir` ([main.rs](../src/main.rs)) resolves **`--from` > `source_dir` > `"src"`**. Inherited by `revol run`. See [manifest.md](manifest.md#legacy-support--source_dir-include_dirs-defines-ignore_warnings). |
| `--ignore-warnings` | Boolean (legacy support). Injects `-w` to silence every compiler warning, regardless of the `[package] ignore_warnings` field — either source turns it on. `-w` lands after the profile's `-W` groups (so it wins) but before `extra_flags`. Never applied to `revol check`. |

**Toolchain pin.** If `[package] toolchain` is set (e.g. `"clang-18.1"`),
`build_single` validates it — invoking the named compiler and checking its
reported version — immediately after loading the manifest's `[package]`
table, before dependency resolution or any compilation. A mismatch aborts
the build with a descriptive error. See
[manifest.md](manifest.md#toolchain--pinning-the-active-compiler) for the
parsing/matching rules. Unset by default, so this costs nothing for projects
that don't opt in.

**Offline/vendored dependency resolution.** Before reaching for the
resolver at all, `build_single` checks whether `<root>/third_party/` exists
and has at least one entry. If so, dependencies are resolved entirely from
those local copies plus `revol.lock` metadata — no `git`, no network, no
global resolver cache lookups (`vendored_dependencies` in
[main.rs](../src/main.rs)). See [`revol vendor`](#revol-vendor) below for how
that directory gets populated.

**Profile mapping.** `build_single` loads `manifest.profile.c` /
`manifest.profile.cpp` (each `Option<CProfile>`/`Option<CppProfile>`,
defaulting via `.unwrap_or_default()` if the table is absent from
`revol.toml`) and constructs one `Compiler` for the whole package — the same
`Compiler` instance answers `compile_unit` for every translation unit,
dispatching internally to `c_args`/`cpp_args` per source file's detected
language (see [architecture.md](architecture.md#compiler-boundary-isolation)).

**Workspace builds.** If `manifest.is_workspace()` (a non-empty
`[workspace] members` list), `cmd_build` delegates to `build_workspace`,
which builds every member directory in declaration order via `build_single`
and returns the **last member's** `BuildOutcome` as the overall result —
there is no parallelism across workspace members, only within each member's
own translation units.

**Dependency build-before-root ordering.** Resolved dependencies are always
compiled — as libraries, regardless of whether their own layout would
otherwise resolve to an executable (`Layout { crate_kind: Crate::Library,
..dep_layout }` forcibly overrides the kind) — before the root package, so
their archives and `src/`/`include/` headers exist as `-I` include paths by
the time the root package's units are planned.

**Global build cache.** Before compiling any *library* package (the root
package when its entry is `src/lib.*`, and every dependency, which is always
built as a library — see above), `Engine::build_package` ([engine.rs](../src/engine.rs))
computes a deterministic cache key over the package's sources (path, content,
and mtime of each) and its resolved compiler flag fingerprint (standard,
optimization, warnings, defines — everything except source/object paths, so
the key is portable across checkouts), plus the target OS/arch
(`hash::package_key`, [hash.rs](../src/hash.rs)). If a static archive already
exists at `~/.revol/cache/prebuilt/{key}/lib{name}.a` (`.lib` on Windows), the
thread-pool is never spun up at all: the cached archive is copied straight
into the project's local `target/{debug,release}/` and a `Cache hit` line is
logged. A successful fresh build populates that same cache entry afterward
(best-effort — a write failure there never fails the build). Executables are
out of scope for this cache, since their output is project-specific rather
than a reusable artifact. Hashing uses only `std::hash::Hasher`
(`DefaultHasher`) — no extra crate.

### Cross-compilation (`--target`)

Clang is natively a cross-compiler — one clang binary can target any triple
its built-in backends support, unlike GCC's traditional one-toolchain-per-target
model. `--target`/`[package] target` exposes that directly, with no
new toolchain-management machinery in revol itself.

**Resolution.** `effective_target(cli_target, manifest)` in
[main.rs](../src/main.rs) is the single place the two sources are reconciled:
CLI wins if given, otherwise the manifest's `[package] target` (see
[manifest.md](manifest.md#target--cross-compilation)), otherwise `None`
(native build, zero-overhead — no `--target` flag reaches clang at all,
matching pre-0.5.0 argument vectors byte-for-byte). `build_single` computes
this once for the root package and threads the same resolved value into
`build_dependencies` (see below) and into the root `Compiler`.

**Flag injection.** `Compiler::push_diagnostics_and_includes` — the helper
shared by every compile path, including `revol check`'s analysis pass —
injects `--target=<triple>` right after the color-diagnostics flags, before
any `-I`/`-D`. `Compiler::link_command` injects the identical flag into the
executable link step. Library builds go through the archiver
(`ar`/`llvm-ar`), which never sees `--target` at all — archiving doesn't
invoke clang, so there's no target-agreement concern there (same reasoning
already documented for `-fsanitize=`/`-flto`, see
[manifest.md](manifest.md#sanitizers-and-lto--clang-sanitizer-support)).

**Dependencies are forced onto the same target.** `build_dependencies`
takes the root's already-resolved `cross_target: Option<&str>` and passes it
to *every* dependency's `Compiler::new`, ignoring that dependency's own
`[package] target` entirely. Linking object files compiled for two
different architectures/ABIs into one artifact doesn't work, so the root
package's effective target always wins — see
[manifest.md](manifest.md#target--cross-compilation) for why this is a
deliberate asymmetry with feature resolution (which does *not* propagate to
dependencies).

**Cache correctness.** Because target injection happens inside the same
`push_diagnostics_and_includes` helper `cache_fingerprint` calls, a
cross-compiled library's global-cache key (see [Global build
cache](#revol-build) above) always differs from a native build of the same
library — the two can never collide in `~/.revol/cache/prebuilt/`.

**No triple validation.** revol does not maintain or check against a list of
known-good triples; an unrecognized or unsupported one simply surfaces as a
normal clang error (`unknown target triple '...'` or similar) the first time
clang is actually invoked. This matches how `extra_flags` is handled
elsewhere — a raw pass-through, not a validated closed set like
`optimization` or `sanitizers`.

### Compilation database (`compile_commands.json`)

Every successful `revol build` writes a
[clangd-compatible compilation database](https://clang.llvm.org/docs/JSONCompilationDatabase.html)
to `<root>/compile_commands.json` — unconditionally, with no flag to opt in
or out. The mechanics live in `Engine::build_package`
([engine.rs](../src/engine.rs)) and `compdb.rs`:

- **Entries are planned before the cache-hit check.** `build_package` builds
  every `CompileUnit` (source, object path, full argument vector) *before*
  checking the global build cache, purely by calling `compiler.compile_unit`
  — no filesystem or process work. This means a library served entirely from
  `~/.revol/cache/prebuilt/{hash}` (see [Global build
  cache](#revol-build) above) still contributes accurate
  `compile_commands.json` entries: the compile flags are fully determined by
  the manifest and CLI args, independent of whether clang actually runs.
- **One entry per translation unit**, matching the schema field-for-field:
  `directory` (the revol process's own `cwd`, via `std::env::current_dir()` —
  every clang invocation inherits it, since revol never calls
  `Command::current_dir`), `file` (the source path exactly as passed to
  clang), and `arguments` (`clang`/`clang++` followed by every flag
  `compile_unit` generated — standard, optimization, warnings, `-I`s,
  defines, `-g`/`-DNDEBUG`, then `-o <object>` and the source path last).
- **Aggregation scope.** `main.rs` collects entries from the root package
  *and* every resolved dependency built in the same invocation
  (`build_dependencies` now returns `(includes, cache_hits,
  compile_commands)`), and `build_workspace` merges every member's entries
  into one combined set before `cmd_build` writes the file. A workspace or a
  package with dependencies still gets exactly one
  `compile_commands.json` at the project root.
- **Rendering.** `compdb::write` serializes with `Json::render_pretty()` (2-space
  indent) rather than the compact `render()` used for `--json` payloads —
  this file is meant to be read and diffed by humans as well as tools.
- Written by `cmd_build` after `build_single`/`build_workspace` returns
  successfully, via `compdb::write(&root, &outcome.compile_commands)?` — a
  write failure (e.g. an unwritable project root) propagates as a normal
  `RevolError`, same as any other artifact write in revol.

### Build profiling (`--trace`)

`--trace` turns on Clang's [`-ftime-trace`](https://clang.llvm.org/docs/UsersManual.html#profiling-clang)
frontend/backend profiler and has revol make sense of its output. Two pieces,
both new in v0.5.0:

1. **Flag injection** (`compiler.rs`). `Compiler::new` takes a `trace: bool`
   parameter; when set, `push_common` appends `-ftime-trace` to every
   compile — for both C and C++, since the flag is common to both. This
   deliberately runs through `push_common`, the same function
   `cache_fingerprint` calls, so a `--trace` build's cache key differs from a
   non-`--trace` build of the same library: they never collide in
   `~/.revol/cache/prebuilt/`, and a stale cache hit can never silently
   suppress trace output. Dependencies are always built with `trace: false`
   — `--trace` profiles the package you're actively building, not its
   (already-stable) dependencies.
2. **Aggregation and reporting** (`trace.rs`, invoked from
   `Engine::build_package` immediately after `compile_all` succeeds, only
   when `Engine`'s own `trace` field is set). Clang writes `-ftime-trace`'s
   output next to each object file, reusing its basename with a `.json`
   extension — revol relies on that convention (via `-o`) rather than passing
   `-ftime-trace=<path>` explicitly. `trace::aggregate_and_report`:
   - Scans the package's `obj_dir` for `*.json` files.
   - Parses each with `Json::parse` (see [Zero-dependency
     footprint](architecture.md#philosophy) — this is the same hand-rolled
     `Json` enum used for `--json` output and `compile_commands.json`,
     extended with a read path).
   - Merges every file's `traceEvents` array into one, injecting a synthetic
     `process_name` metadata event (`ph: "M"`) per source file so
     chrome://tracing / speedscope group each translation unit onto its own
     track instead of colliding pid/tid values.
   - Writes the merged document to
     `target/<debug|release>/revol_profile.json` — standard [Chrome Trace
     Event Format](https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU),
     loadable directly at `chrome://tracing` or
     [speedscope.app](https://www.speedscope.app).
   - Deletes the original per-unit `.json` files — they're now redundant.
   - Unless `--quiet`, prints the top 10 duration events **that carry an
     `args.detail` field** (a header path, a template instantiation's
     symbol, ...) sorted descending by duration. This filter is deliberate:
     it excludes umbrella events like `ExecuteCompiler`/`Frontend`/`Backend`
     that just sum up everything beneath them and would otherwise dominate a
     naive top-N-by-duration ranking without pointing at anything
     actionable.
   - Every step is best-effort: a missing `obj_dir`, an unreadable or
     malformed trace file, or a failed write is silently skipped rather than
     failing the build — profiling is a diagnostic aid, not a build
     correctness concern, so `aggregate_and_report` has no `Result` return
     type at all.

### `revol run`

```
revol run [build flags...] [-- ARGS...]
```

```rust
pub struct RunArgs {
    #[command(flatten)]
    pub build: BuildArgs,
    #[arg(last = true, value_name = "ARGS")]
    pub bin_args: Vec<String>,
}
```

`RunArgs` flattens the entire `BuildArgs` struct (`#[command(flatten)]`), so
every `revol build` flag documented above is also a valid `revol run` flag with
identical semantics — `revol run` is implemented as "build, then exec" with no
separate flag surface.

- **Validation against library crates.** After `build_with_diagnostics`
  returns a `BuildOutcome`, `cmd_run` checks `outcome.crate_kind !=
  Crate::Executable` and, if the package resolved to a `Library` (i.e. its
  entry point was `src/lib.cpp`/`src/lib.c`), returns
  `RevolError::LayoutViolation("\`revol run\` requires an executable
  (src/main.cpp or src/main.c)")` **after** the build has already succeeded —
  a library still gets fully compiled and archived; only the "now execute it"
  step is rejected.
- **Verbatim argument forwarding.** `#[arg(last = true)]` is clap's "greedy
  positional after `--`" marker: everything after a literal `--` token on the
  command line is captured into `bin_args` untouched — not reinterpreted as
  revol flags, not split/escaped/re-quoted. These are passed straight through
  to the child process via `Command::new(&outcome.artifact).args(&args.bin_args)`.
  This is why `revol run --release -- --release` correctly applies `--release`
  to the *build* once and forwards the literal string `--release` as the
  binary's own argv — clap stops parsing revol's own flags at the first bare
  `--`.
- The child's exit status is propagated: a non-zero exit causes
  `std::process::exit(status.code().unwrap_or(1))` from the revol process
  itself, so shell scripts checking `$?` after `revol run` see the *binary's*
  exit code, not revol's.

### `revol init`

```
revol init [PATH] [--name NAME] [--lib | --bin] [--c]
```

- `PATH` defaults to `.` (current directory); created with
  `create_dir_all` if absent, along with `PATH/src`.
- `--name` defaults to the canonicalized directory's file name (falling back
  to the literal string `"my_project"` if canonicalization fails, e.g. for a
  not-yet-existing relative path).
- **Language/kind selection.** `--lib` and `--bin` are mutually exclusive
  (`conflicts_with = "bin"` on `--lib`); `is_lib = args.lib && !args.bin`
  means the *default* (neither flag) is an executable. `--c` switches the
  generated language from C++ (default) to C. The four combinations select
  one of four hardcoded template pairs:

  | `--lib` | `--c` | Entry file | Template constant |
  |---|---|---|---|
  | no | no | `src/main.cpp` | `CPP_MAIN` (`#include <iostream>`, prints "Hello from revol!") |
  | no | yes | `src/main.c` | `C_MAIN` (`#include <stdio.h>`, `printf`) |
  | yes | no | `src/lib.cpp` | `CPP_LIB` (a `revol_add(int, int)` function) |
  | yes | yes | `src/lib.c` | `C_LIB` (same, C-flavored comment style) |

- **Overwrite protection.** Before writing, `cmd_init` checks
  `entry_path.exists()` and returns `RevolError::LayoutViolation("... already
  exists; refusing to overwrite")` — init never clobbers an existing entry
  file. The manifest (`revol.toml`) and `.gitignore` get the same treatment but
  via simple existence checks that silently skip writing rather than erroring
  (`if !manifest_path.exists() { ... }`), so re-running `revol init` in an
  already-initialized directory is a safe no-op for those two files as long
  as the entry source file itself is untouched.
- The generated manifest embeds a matching `[profile.c]` or `[profile.cpp]`
  block (`C_PROFILE`/`CPP_PROFILE` constants) so a freshly-`init`'d package
  builds immediately without further configuration.
- A `.gitignore` containing `/target` is written if absent.

### `revol doctor`

```
revol doctor
```

Takes no package-specific arguments — it diagnoses the *environment*, not a
particular project. Runs exactly seven checks, every one of them inline in
`doctor::run` ([doctor.rs](../src/doctor.rs)):

1. `clang --version` present (C compiler).
2. `clang++ --version` present (C++ compiler).
3. `ar --version` present (archiver — note this checks Unix `ar`
   specifically even on Windows, where the *build* path would actually try
   `llvm-ar`/`lib.exe`; `doctor`'s `ar` check is a baseline binutils probe).
4. `git --version` present (required for `gh:` dependency resolution).
5. A native fetch tool is present: `powershell` on Windows
   (`$PSVersionTable.PSVersion`), else `curl --version` falling back to
   `wget --version`.
6. **The end-to-end compilation probe.** `check_system_headers` writes a
   throwaway file to the OS temp directory, named uniquely per-process
   (`revol-doctor-<pid>.c`), containing exactly:
   ```c
   #include <stdio.h>
   int main(void){return 0;}
   ```
   then invokes `clang -c <probe>.c -o <probe>.o` and checks the exit status.
   This catches failures that "is clang on PATH" alone cannot — a broken
   sysroot, a missing or misconfigured libc headers package, or a clang
   installation that can't find its own resource directory. Both the probe
   source and the resulting object file are deleted (`remove_file`,
   best-effort) regardless of outcome.
7. `$REVOL_HOME` (or `$HOME/.revol` if unset) is locatable. This check always
   reports `ok: true` even when the directory doesn't exist yet — it only
   fails hard if *neither* `$REVOL_HOME` nor `$HOME` is set at all, since the
   directory itself is lazily created on first build/resolve.

**OS-aware fix suggestions.** Every failing check carries an optional
`fix: Option<String>` rendered under a `fix:` line in the report. Compiler and
archiver fixes branch on `std::env::consts::OS`:

```rust
fn install_hint_clang() -> String {
    match std::env::consts::OS {
        "macos" => "install LLVM: `brew install llvm`",
        "windows" => "install LLVM: `winget install LLVM.LLVM`",
        _ => "install clang: `sudo apt install clang` (or your distro's equivalent)",
    }
}
```

`install_hint_binutils` follows the same three-way branch
(`brew install binutils` / "install LLVM, which ships `llvm-ar`, or MSYS2
binutils" / `sudo apt install binutils`).

`doctor::run` always returns `Ok(())` — it is a **report, not a gate**: even
with every check failing, the process exit code stays `0` (the doctor module's
own doc comment is explicit: "Returns `Ok(())` even when checks fail —
`doctor` is a report, not a gate"). The pass/fail tally is purely a printed
summary line (`"{passed} passed, {failed} failed."`).

`doctor` is invoked two ways: explicitly via `revol doctor`, and automatically
(non-fatally — `let _ = doctor::run(verbose);`) by `build_with_diagnostics`
whenever a `revol build` or `revol run` invocation fails, right before revol
re-raises the original build error. See
[architecture.md](architecture.md#hot-path-strategy) for why this is split
out from the build's own hot path.

### `revol sync`

```
revol sync
```

Refreshes the **flat-text package index** at `~/.revol/revol-libs` (or
`$REVOL_HOME/revol-libs`) — the shorthand-to-URL mapping table used to resolve
`gh:user/lib`-style dependency keys that aren't already covered by the
built-in `gh:` → `https://github.com/<user>/<lib>.git` heuristic.

`cmd_sync` constructs a `Resolver` and calls `resolver.sync_index(quiet)`
([resolver.rs](../src/resolver.rs)). This is **strictly an index refresh** —
it loads no project manifest, resolves no dependency graph, and never reads
or writes a project's `revol.lock`. The doc comments in both
[cli.rs](../src/cli.rs) and [resolver.rs](../src/resolver.rs) call this out
explicitly to distinguish it from `revol update`.

**Zero-dependency manifest indexing.** The index's source URL defaults to:

```
https://raw.githubusercontent.com/xntas/revol/main/website/static/revol-libs
```

overridable via the `REVOL_LIBS_URL` environment variable (for self-hosted or
air-gapped registries). The fetch itself uses only host-native tools, chosen
by `fetch_to_file`:

- **Windows** (`cfg!(target_os = "windows")`): `fetch_with_powershell` shells
  out to `powershell -NoProfile -NonInteractive -Command
  "Invoke-WebRequest -Uri '<url>' -OutFile '<dest>'"`.
- **Unix**: `fetch_with_curl_or_wget` tries
  `curl --silent --show-error --fail --location --max-time 30 -o <dest> <url>`
  first; if curl's `Command::status()` either errors (binary missing) or
  returns non-success, it falls back to
  `wget --quiet --timeout=30 -O <dest> <url>`. Only if *both* fail does it
  surface a `RevolError`.

**Atomicity.** The fetch writes to a sibling `revol-libs.tmp` file first, then
`fs::rename(&tmp, &dest)` performs the visible swap — a fetch that dies
partway through (network drop, disk full) never corrupts the live index,
since the rename is the only operation that touches the real `revol-libs`
path.

### `revol update`

```
revol update [PACKAGE] [--manifest-path DIR]
```

Re-resolves the **current project's** dependency graph from scratch and
rewrites `revol.lock` — the inverse operation to `revol sync` (which never
touches `revol.lock`) and complementary to `revol build` (which, by design,
*reads* the lock and never silently re-resolves on its own — see
[manifest.md](manifest.md#revollock-spec)).

- **Full update** (`PACKAGE` omitted): `cmd_update` loads the existing lock
  only to pass as `pin = None` regardless of whether it exists — every
  dependency is resolved fresh, fetching current HEAD SHAs for each tag via
  `resolver.resolve_all(&manifest, None)`. Every entry in the rewritten lock
  reflects a fresh `git fetch`/`rev-parse HEAD`, even dependencies whose
  declared version string didn't change.
- **Scoped update** (`PACKAGE` given): the existing lock *is* passed as `pin`
  for the initial `resolve_all` call, so every dependency except the
  named target stays pinned to its previously-locked SHA. The named target is
  then explicitly re-resolved a second time with `pin = None`
  (`resolver.resolve_all(&manifest, None)`) and spliced into the result list,
  replacing the pinned entry. `package_name()` strips the shorthand down to
  its bare trailing path segment for the name comparison (e.g. `gh:user/lib`
  → `lib`), so `revol update lib` matches regardless of which shorthand prefix
  was used.
- **Dependency cache state.** Re-resolution does not necessarily mean
  re-cloning: `Resolver::ensure_cached` reuses an existing checkout under
  `~/.revol/cache/<name>-<tag>` if it already contains a `.git` directory,
  running only `git fetch --depth 1 origin tag <tag>` followed by
  `git checkout --quiet <tag>` rather than a fresh clone. A fresh clone only
  happens when the cache directory is absent or doesn't look like a git repo.
- The rewritten lockfile is written via the same atomic `.tmp` + `rename`
  pattern as `revol sync`'s index (see [manifest.md](manifest.md#revollock-spec)).
- Non-quiet output prints one `Updated N dependenc{y,ies} in revol.lock` line
  followed by one `name vVERSION @ <10-char SHA prefix>` line per resolved
  dependency (`short_sha` truncates to the first 10 characters, or the full
  string if shorter).

### `revol vendor`

```
revol vendor [--manifest-path DIR]
```

Copies every dependency recorded in `revol.lock` into a local
`<root>/third_party/<name>/` tree, for complete offline autonomy — once that
directory is populated, every subsequent `revol build` resolves dependencies
from it directly (see [Offline/vendored dependency
resolution](#revol-build) above), with no `git`, no network, and no global
`~/.revol/cache` lookups at all.

`cmd_vendor` ([main.rs](../src/main.rs)):

1. Requires an existing `revol.lock` (`revol build` or `revol update` must have
   run at least once) — refuses with `RevolError::Config` otherwise, rather
   than silently re-resolving.
2. Resolves dependencies via `Resolver::resolve_all(&manifest, Some(&lock))`
   — the same *pinned* path `revol build` takes, so vendoring never drifts
   from what's actually locked.
3. For each resolved dependency, recursively copies its global-cache
   checkout (`dep.cache_path`) into `third_party/<name>/`, skipping any
   `.git` directory (`copy_tree_excluding_git`) — the vendored copy is a
   source snapshot, not a live git checkout. Any pre-existing
   `third_party/<name>/` is removed first, so re-running `revol vendor` is
   idempotent.
4. Non-quiet output prints one `Vendored <name> vVERSION -> <path>` line per
   dependency, then a `Finished vendoring N dependenc{y,ies}` summary.

### `revol check`

```
revol check [--manifest-path DIR] [-j N] [--features A,B,C]
           [--no-default-features] [--target TRIPLE]
```

Runs Clang's static analyzer (`--analyze`) over the package's own sources —
no object files, no linker invocation, no artifact. `CheckArgs`
([cli.rs](../src/cli.rs)) is deliberately a smaller surface than
`BuildArgs`: there is no `--release` (analysis never reaches codegen, so
optimization level is irrelevant), no `-o` (nothing is produced to name),
and no `--trace` (nothing is compiled to profile).

**Dependency handling.** `cmd_check` ([main.rs](../src/main.rs)) resolves
dependencies exactly like `revol build` does — respecting a populated
`third_party/` the same way (see [Offline/vendored dependency
resolution](#revol-build) above) — but only to expose their `src/`/`include/`
directories on the include path via `-I`. Dependencies are never compiled,
analyzed, or even type-checked by `revol check`; it audits the package you're
actively working on, not its already-vetted dependencies.

**Argument construction.** `Compiler::analyze_unit` ([compiler.rs](../src/compiler.rs))
builds a `--analyze` invocation per translation unit, reusing the existing
`CompileUnit` struct purely for its `language`/`source`/`args` fields (its
`object` field is an unused empty `PathBuf` — analysis never produces one,
and nothing downstream reads it: `run_compile` in [engine.rs](../src/engine.rs),
reused verbatim for both `revol build` and `revol check`, never touches
`unit.object`). The argument vector is deliberately smaller than a real
compile's:

| Kept | Dropped |
|---|---|
| `--analyze` (replaces `-c` + `-o <obj>`) | optimization level (`-O*`) |
| `-std=<standard>` | `-flto` |
| profile `warnings` (`-Wall`, `-Wextra`, ...) | `sanitizers` (`-fsanitize=...`) |
| `-frtti`/`-fno-rtti`, `-fexceptions`/`-fno-exceptions` (C++ only) | `-g`, `-DNDEBUG` |
| `-I` include paths, `-D` defines, `--target=<triple>` | `-ftime-trace` |
| | profile `extra_flags` |

The kept/dropped split is exactly "what the analyzer needs to parse the
translation unit the same way a real build would" (language dialect,
warnings, headers, target) versus "what only matters for the codegen that
`--analyze` never performs." Both the kept and dropped sets come from
`push_diagnostics_and_includes`, the same helper a real compile's
`push_common` calls — see [Cross-compilation](#cross-compilation---target)
above for why `--target` is in the shared, not the compile-only, half.

**Execution and failure semantics.** `Engine::check_package`
([engine.rs](../src/engine.rs)) runs every unit across the same
`std::thread` + `Mutex<VecDeque>` + `mpsc` work-queue shape as
`compile_all` ([architecture.md](architecture.md#parallel-compilation-engine)),
but with two deliberate differences:

- **Every unit's diagnostics are printed, regardless of severity or
  success.** `compile_all`'s `report_unit` only echoes warnings on a
  *successful* unit; `check_package` streams everything, because surfacing
  analyzer findings is the entire point of the command.
- **Only a non-zero clang exit counts as a failure.** Analyzer findings
  (`warning: ...` diagnostics, e.g. `[deadcode.DeadStores]`,
  `[core.NullDereference]`) on an otherwise-successful parse are printed and
  the command still exits `0` — the same "warnings don't fail the build"
  contract `revol build` already has. A file clang couldn't even parse
  (genuine syntax error, missing header, ...) does fail the command.

A failure returns `RevolError::Analysis { failures }` — a variant distinct
from `RevolError::Compilation` ([error.rs](../src/error.rs)) purely so the
top-line message reads `check failed: N file(s) could not be analyzed`
rather than the misleading `build failed: ...`, since `revol check` never
builds anything. Unlike `Compilation`, it carries no structured
`CompileDiagnostic` list — every diagnostic was already streamed to the
terminal as it arrived, and (unlike `revol build --json`) `revol check` has no
`--json` payload to feed from a stored copy.

### `--json` Output

`--json` (declared `global = true` on `Cli`, see [Global
Constraints](#global-constraints)) replaces a command's human-readable
output with one compact JSON object on stdout. Implemented by
[json.rs](../src/json.rs) — a closed, dependency-free `Json` enum
(`Null`/`Bool`/`Number`/`String`/`Array`/`Object`) with a `render()` method,
rather than pulling in `serde_json`. Since v0.5.0 the same enum also has a
`parse()` method (used to read Clang's `-ftime-trace` output — see [Build
profiling](#build-profiling---trace) above) and a `render_pretty()` method
(used for `compile_commands.json` — see [Compilation
database](#compilation-database-compile_commandsjson) above); `--json`
payloads on this page still use the original compact `render()`.

**`revol build --json`.** `cmd_build_top_level` ([main.rs](../src/main.rs))
times the whole build, forces `quiet`/`json` through to every internal
`println!`/diagnostic-print call site (so no interim text reaches stdout —
see `Engine`'s `json` field in [engine.rs](../src/engine.rs)), and renders
exactly one of:

```json
{"status":"success","duration_ms":842,"cache_hits":2,"artifact":"target/debug/app","errors":[]}
```

```json
{"status":"failure","duration_ms":210,"cache_hits":0,"errors":[
  {"file":"src/main.c","line":4,"column":2,"severity":"error","message":"undeclared identifier 'foo'"}
]}
```

`cache_hits` sums every library package (dependencies, plus the root package
itself if it's a library) served from the global build cache instead of
recompiled — see the [Global build cache](#revol-build) section above.
`errors` carries the structured `CompileDiagnostic`s attached to
`RevolError::Compilation` when the failure came from the compiler; for any
other error kind (a layout violation, a missing manifest, a toolchain
mismatch, ...) it falls back to one synthetic entry built from the error's
`Display` text, with `file: null`.

**`revol doctor --json`.** `doctor::run` ([doctor.rs](../src/doctor.rs)) runs
the exact same checks as the human-readable report (see [`revol
doctor`](#revol-doctor) above, including the conditional `toolchain` check)
and renders:

```json
{"checks":[
  {"name":"clang","ok":true,"detail":"clang version 18.1.3","fix":null},
  {"name":"ar","ok":false,"detail":"not found on PATH ...","fix":"install binutils: ..."}
],"passed":1,"failed":1}
```

Every check always carries all four keys — `fix` is JSON `null`, never an
omitted key, when a check passed and has nothing to fix.
