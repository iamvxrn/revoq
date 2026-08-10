---
title: "Manifest & Lockfile Specification"
---

The absolute structural specification for `revoq.toml` and `revoq.lock`, drawn
directly from the serde data model in [manifest.rs](../src/manifest.rs) and
the layout rules in [engine.rs](../src/engine.rs).

## `revoq.toml` Spec

The root deserialization target is `Manifest`:

```rust
pub struct Manifest {
    pub workspace: Option<Workspace>,
    pub package: Option<Package>,
    pub features: BTreeMap<String, Vec<String>>,
    pub profile: Profiles,
    pub dependencies: BTreeMap<String, Dependency>,
}
```

Every top-level table is optional at the parse level (`#[serde(default)]` on
all but `package`, and `package` itself is `Option<Package>`) — a manifest
with none of these tables still parses successfully. `package` is only
required at the point a package is actually *built*: `require_package` in
[engine.rs](../src/engine.rs) turns a missing `[package]` table into
`RevoqError::ManifestParse { message: "missing [package] table (name/version
required to build)" }`. This split lets a workspace root manifest declare
only `[workspace]` with no `[package]` of its own.

### `[package]`

```toml
[package]
name = "my_project"
version = "0.2.0"
description = "optional"
authors = ["optional", "list"]
toolchain = "clang-18.1"   # optional
target = "aarch64-unknown-linux-gnu"   # optional

# Legacy support — all optional, all default to the strict behavior:
source_dir      = "src"                       # where sources live       (0.6)
include_dirs    = ["legacy/include"]          # extra -I paths           (0.6)
defines         = ["HAVE_CONFIG_H", "N=64"]   # project-wide -D          (0.6)
ignore_warnings = false                       # true injects -w          (0.6)
kind            = "lib"                        # "bin"/"lib"; skip entry  (0.7)
include         = ["*.c"]                      # scan-narrowing globs     (0.7)
exclude         = ["tests/**", "fuzzing/**"]  # pruned from the scan     (0.7)
```

```rust
pub struct Package {
    pub name: String,         // required
    pub version: String,      // required
    pub description: Option<String>,  // default: None
    pub authors: Vec<String>,         // default: []
    pub toolchain: Option<String>,    // default: None
    pub target: Option<String>,       // default: None
    // --- legacy support (0.6.0) ---
    pub source_dir: String,           // default: "src"
    pub include_dirs: Vec<String>,    // default: []
    pub defines: Vec<String>,         // default: []
    pub ignore_warnings: bool,        // default: false
    // --- legacy support (0.7.0) ---
    pub kind: Option<String>,         // default: None ("bin"/"lib")
    pub include: Vec<String>,         // default: []
    pub exclude: Vec<String>,         // default: []
}
```

`name` and `version` have no `#[serde(default)]` — both are mandatory once a
`[package]` table is present at all. Every legacy-support field has a serde
default, so a pre-0.6.0 manifest parses and builds identically.

### Legacy support — `source_dir`, `include_dirs`, `defines`, `ignore_warnings`

These four fields let revoq build C/C++ trees that don't follow its strict
layout, without moving any files. Every default reproduces the 0.5.0 behavior.

- **`source_dir`** (default `"src"`) — the directory revoq scans for sources and
  the entry point. `revoq build --from <path>` overrides it for a single
  invocation; precedence is `--from` > `source_dir` > `"src"`. The entry point
  still has to be `main.<ext>` or `lib.<ext>` — only the directory changes.
- **`include_dirs`** (default `[]`) — extra header search paths (relative to the
  package root), emitted as `-I<path>` and searched before dependency headers.
- **`defines`** (default `[]`) — project-wide preprocessor defines applied to
  **both** C and C++ units as `-D<entry>`, additive to the per-language
  `[profile]` `defines`.
- **`ignore_warnings`** (default `false`) — inject `-w` to disable every warning.
  `revoq build --ignore-warnings` does the same from the CLI. `-w` overrides the
  profile's `-W` groups but not `extra_flags`, and is never applied to
  `revoq check`.

The scanner and entry-point discovery accept `.c`, `.cpp`, `.cc`, `.cxx`, and
`.C`; a capital `.C` is **C++** (Unix/Clang convention). `.c` compiles with
`clang`, every C++ extension with `clang++`.

### Legacy support (0.7) — `kind`, `include`, `exclude`

0.6 handles trees that are *almost* canonical. 0.7 adds the two knobs that let
you build a real third-party project without moving a single file.

- **`kind`** (`"bin"` or `"lib"`) drops the requirement for a canonically named
  entry file. A library's sources are called `cJSON.c` or `format.cc`, never
  `lib.c`; declare `kind` and revoq builds the directory as that artifact,
  inferring the language from the sources. Leave it unset and the strict
  `main.*`/`lib.*` discovery is exactly as before.
- **`include` / `exclude`** are glob patterns (relative to `source_dir`) that
  narrow the scan. `exclude` prunes whole directories, so `source_dir = "."`
  plus `exclude = ["tests/**", "fuzzing/**"]` builds only a repo's library
  sources, not its test suite. Patterns support `*`, `?`, and `**`.

The single-language rule holds throughout — a package mixing C and C++ is still
rejected. Migrating cJSON, sources and tests intermixed at the repo root, is
then a five-line manifest:

```toml
[package]
name       = "cjson"
version    = "1.7.18"
kind       = "lib"
source_dir = "."
exclude    = ["tests/**", "fuzzing/**"]
```

### `toolchain` — pinning the active compiler

`toolchain` is an optional `"<compiler>-<version>"` string, e.g.
`"clang-18.1"`. `ToolchainSpec::parse` ([manifest.rs](../src/manifest.rs))
splits on the first `-`, so `compiler = "clang"` and `version = "18.1"`.
Both halves are required and must be non-empty; an unparsable spec (no `-`,
or an empty compiler/version half) fails fast with `RevoqError::Config`
*before* any compiler is invoked.

When present, `toolchain` is validated in two places:

- **`revoq doctor`** — `check_toolchain_pin` ([doctor.rs](../src/doctor.rs))
  loads `revoq.toml` from the current directory; if it declares a pin, doctor
  invokes `<compiler> --version` and adds one more row (`toolchain`) to the
  report. No project here, or no pin declared, means no row at all — doctor
  stays project-agnostic by default, same as every other check.
- **The pre-build phase of `revoq build`** — `build_single` ([main.rs](../src/main.rs))
  calls `ToolchainSpec::validate()` immediately after loading `[package]`,
  before dependency resolution or compilation begins. A mismatch aborts the
  build with a descriptive `RevoqError::Config`, e.g.:
  ```
  environment unvalidated: manifest pins toolchain 'clang-18.1' but found 'clang 17.0.6'
  (run `revoq doctor` for details)
  ```

**Version matching is a dotted-prefix match, not exact equality.** `validate`
runs `<compiler> --version`, extracts the first dotted version-looking token
from its output (`extract_compiler_version`, handles both `"clang version
18.1.3"` and `"Apple clang version 15.0.0 (...)"` forms), and accepts it when
it equals the pinned `version` *or* starts with `"<version>."`. So a pin of
`"18.1"` accepts an installed `"18.1.3"` but rejects `"17.x"` or `"19.x"` —
and, importantly, rejects `"18.10.x"` too, since the prefix check requires
the separator dot (`"18.1."`), not just a string prefix.

This check is strictly opt-in: a manifest with no `toolchain` field pays
zero extra cost — `revoq build`'s hot path is unaffected (see
[architecture.md](architecture.md#hot-path-strategy)).

### `target` — cross-compilation

`target` is an optional cross-compilation target triple, e.g.
`"aarch64-unknown-linux-gnu"` or `"wasm32-unknown-unknown"`. Unlike
`toolchain`, it's a raw, unvalidated string: revoq passes it straight through
as `--target=<triple>` and lets clang itself reject an unrecognized or
unsupported triple, the same pass-through contract `extra_flags` already
has. Validating a triple up front would mean either hardcoding a triple list
(perpetually incomplete) or shelling out to `clang --print-targets` on every
invocation — the latter conflicts with the hot-path guarantee (see
[architecture.md](architecture.md#hot-path-strategy)), so revoq doesn't.

`--target=<triple>` is injected into **both** phases that need to agree on
architecture/ABI: every translation unit's compile command
(`Compiler::push_diagnostics_and_includes`, shared with `revoq check`'s
analysis path) and the final executable link command
(`Compiler::link_command`). It's deliberately *not* passed to the archiver —
`ar`/`llvm-ar` bundle object files without inspecting their target, so
library builds never see it there (the same reasoning that already excludes
`-fsanitize=`/`-flto` from the archiver path, see
[sanitizers and lto](#sanitizers-and-lto--clang-sanitizer-support) above).

**Priority.** `revoq build --target <triple>` (the CLI flag) always overrides
this manifest field when both are set (`effective_target` in
[main.rs](../src/main.rs)). Neither set means a fully native build — no
`--target` flag reaches clang at all, byte-for-byte identical to a pre-0.5.0
manifest.

**Dependencies do not get their own vote.** Unlike feature resolution, where
"a consuming package's `--features` selection does not yet propagate into
its dependencies' builds" (see [Feature Flag
Resolution](#feature-flag-resolution) below), the *effective* target
(whichever of CLI/manifest won for the root package) is force-applied to
every dependency's compile as well, overriding whatever that dependency's
own `[package] target` might say. This is not an oversight — linking object
files compiled for two different targets into one artifact simply doesn't
work, so consistency has to win over a dependency's own preference.

**Cache interaction.** `--target` is injected inside the same helper
`Compiler::cache_fingerprint` calls, so a cross-compiled build's global-cache
key (see [Global build cache](cli.md#revoq-build)) is always distinct from a
native build of the same library — the two can never collide and serve the
wrong architecture's cached archive.

### `[workspace]`

```toml
[workspace]
members = ["app", "lib/core"]
```

```rust
pub struct Workspace {
    pub members: Vec<String>,  // default: []
}
```

`Manifest::is_workspace()` returns `true` only when `workspace` is `Some`
**and** `members` is non-empty — a `[workspace]` table with an empty or
absent `members` list is treated as not a workspace at all. Each member path
is resolved relative to the workspace root and must itself be a complete
revoq-standard package (own `revoq.toml`, own `src/` layout) — see
[cli.md](cli.md#revoq-build) for the build-order semantics.

### `[features]`

```toml
[features]
default = ["ssl"]
ssl = ["tls"]
tls = []
```

Modeled directly as `BTreeMap<String, Vec<String>>` — there is no dedicated
`Feature` struct. Each key is a feature name; each value is the list of other
feature names it *implies*. The conventional `default` key, if present, is
the seed set activated unless `--no-default-features` is passed. See
[Feature Flag Resolution](#feature-flag-resolution) below for the expansion
algorithm.

### `[profile.c]` and `[profile.cpp]`

```toml
[profile.c]
standard = "c17"           # default: "c17"
warnings = ["all", "extra"] # default: []
optimization = "0"          # default: "0"
extra_flags = []             # default: []
defines = []                  # default: []
sanitizers = []                # default: []
lto = false                     # default: false

[profile.cpp]
standard = "c++20"          # default: "c++20"
rtti = false                  # default: true
exceptions = true             # default: true
warnings = ["all", "extra"] # default: []
optimization = "0"          # default: "0"
extra_flags = []             # default: []
defines = []                  # default: []
sanitizers = []                # default: []
lto = false                     # default: false
```

`Profiles` is `{ c: Option<CProfile>, cpp: Option<CppProfile>, ...
#[serde(default)] }` — a manifest may declare neither, either, or both
profile tables. A package only needs the profile matching its own entry
language; an absent table is filled in with `CProfile::default()` /
`CppProfile::default()` at build time (`manifest.profile.c.clone()
.unwrap_or_default()` in [main.rs](../src/main.rs)), so omitting `[profile.c]`
entirely from a C++ package's manifest is normal and harmless.

`optimization` is a free-form **string** at the manifest level, validated
lazily by `OptLevel::parse` ([compiler.rs](../src/compiler.rs)) only at build
time — accepted values are `"0"`, `"1"`, `"2"`, `"3"`, `"s"`/`"size"`,
`"z"`/`"tiny"`, `"g"`/`"debug"`, `"fast"`. An unrecognized value produces
`RevoqError::Config` *before* any compilation begins
(`Compiler::validate()` is called up front in `Engine::build_package`), not
mid-build.

`warnings` entries map through `warning_flag()` ([compiler.rs](../src/compiler.rs)):
`"all"` → `-Wall`, `"extra"` → `-Wextra`, `"error"` → `-Werror`,
`"pedantic"` → `-Wpedantic`, `"everything"` → `-Weverything`; any other
string `kw` passes through verbatim as `-W<kw>`, so any clang warning group
can be named without revoq needing an exhaustive table.

`extra_flags` is an escape hatch: each string is appended to the clang
invocation verbatim, after all other revoq-managed flags, normally left empty.

`defines` entries become `-D<entry>` flags, alongside the `-D` flags revoq
synthesizes itself for active features (see below) — both sets are merged in
`push_common`.

`rtti` and `exceptions` exist **only** on `CppProfile` — there is no C
equivalent, since these are C++ language features. `false` maps to
`-fno-rtti`/`-fno-exceptions`; `true` (the default for both) maps to
`-frtti`/`-fexceptions`. This field-level asymmetry between `CProfile` and
`CppProfile` is itself part of revoq's compiler boundary isolation — see
[architecture.md](architecture.md#compiler-boundary-isolation).

### `sanitizers` and `lto` — Clang sanitizer support

```toml
[profile.c]
sanitizers = ["address", "undefined"]
lto = false
```

`sanitizers` is a plain `Vec<String>`, `#[serde(default)]`-backed like every
other profile field — an absent key parses to `[]`, identical to a v0.3.0
manifest, with zero behavioral change. Each entry maps through
`Sanitizer::parse` ([compiler.rs](../src/compiler.rs)) to a closed enum:

| Manifest string | Enum variant | Clang flag |
|---|---|---|
| `"address"` | `Sanitizer::Address` | `-fsanitize=address` |
| `"thread"` | `Sanitizer::Thread` | `-fsanitize=thread` |
| `"undefined"` | `Sanitizer::Undefined` | `-fsanitize=undefined` |
| `"leak"` | `Sanitizer::Leak` | `-fsanitize=leak` |

An unrecognized string (anything else) fails with `RevoqError::Config` at
validation time, before any compilation begins — same fail-fast contract as
`optimization`.

**Pre-build safety matrix.** `Compiler::validate()` runs
`validate_sanitizer_matrix` against each profile independently (C's
`sanitizers`/`lto` and C++'s `sanitizers`/`lto` are checked separately, since
a package only ever builds one of the two) and aborts the build with a
`RevoqError::Config` before invoking clang at all if:

- **`lto = true`** together with `"address"` or `"leak"` in `sanitizers` — LTO
  and ASan/LSan are mutually exclusive: link-time optimization can reorder
  and inline across the instrumentation boundary, producing unreliable
  results and substantially slower links.
- **`"thread"`** is present together with `"address"` or `"leak"` — their
  runtime libraries install conflicting interceptors and cannot be linked
  into the same binary.

**Automatic debug symbols.** Whenever a profile's `sanitizers` array is
non-empty, `-g` is unconditionally added to that profile's compile flags
(`push_common` in [compiler.rs](../src/compiler.rs)), even in a
`--release` build that would otherwise omit it — sanitizer stack traces are
unreadable raw addresses without debug info. If this overrides a release
profile's own choice, `Compiler::validate()` prints one warning to stderr
before the build proceeds.

**Flag ordering.** `-fsanitize=<type>` (and `-flto`, when `lto = true`) are
appended to the compile command *before* the profile's own `extra_flags`, so
a manifest can still layer on granular sub-flags such as
`-fno-omit-frame-pointer` afterward:

```toml
[profile.c]
sanitizers = ["address"]
extra_flags = ["-fno-omit-frame-pointer"]
```

**Linking.** The exact same `-fsanitize=<type>` (and `-flto`) flags are
also passed to the final link command (`Compiler::link_command`) for
whichever language actually compiled the package's translation units — the
sanitizer runtime has to be linked in, or the instrumented object files
won't resolve. Library builds (which go through the archiver, not the
linker) never receive these flags — archiving doesn't invoke clang at all.

### `[dependencies]`

```toml
[dependencies]
"gh:user/http_parser" = "1.5"
"gh:another/ssl" = { version = "2.1", features = ["ssl"], tag = "v2.1.0" }
```

Keys are shorthand strings (conventionally `gh:user/lib` for GitHub, resolved
through `Resolver::map_shorthand` — see [resolver.rs](../src/resolver.rs)).
Values deserialize into `Dependency`:

```rust
pub struct Dependency {
    pub version: String,
    pub features: Vec<String>,
    pub tag: Option<String>,
}
```

**Untagged shorthand-vs-table deserialization.** `Dependency` implements
`Deserialize` by hand (not via derive) specifically to accept either a bare
string or a detailed table in the same map value position:

```rust
#[derive(Deserialize)]
#[serde(untagged)]
enum Raw {
    Simple(String),
    Detailed {
        version: String,
        #[serde(default)] features: Vec<String>,
        #[serde(default)] tag: Option<String>,
    },
}
```

serde's `#[serde(untagged)]` attempts each enum variant in declaration order
without a discriminant field, so a plain TOML string value
(`"gh:user/lib" = "1.5"`) matches `Raw::Simple` (it's just a string), while
an inline table (`{ version = "2.1", features = [...] }`) matches
`Raw::Detailed` (it has the shape of a map with a required `version` key).
Both variants are then normalized into the same `Dependency` struct — `Simple`
gets empty `features` and `tag: None`. This lets a manifest author write the
terse form for the common case (just a version) and only reach for the table
form when they need `features` or an explicit `tag` override (used when the
git tag differs from the semantic version string).

## Feature Flag Resolution

`Manifest::resolve_features(requested: &[String], no_default: bool) ->
Vec<String>` computes the final, transitively-expanded set of active
features and is the single place feature logic lives:

```rust
pub fn resolve_features(&self, requested: &[String], no_default: bool) -> Vec<String> {
    let mut enabled: Vec<String> = Vec::new();
    let mut stack: Vec<String> = Vec::new();

    if !no_default {
        if let Some(defaults) = self.features.get("default") {
            stack.extend(defaults.iter().cloned());
        }
    }
    stack.extend(requested.iter().cloned());

    while let Some(feature) = stack.pop() {
        if enabled.iter().any(|f| f == &feature) {
            continue;
        }
        enabled.push(feature.clone());
        if let Some(implied) = self.features.get(&feature) {
            stack.extend(implied.iter().cloned());
        }
    }

    enabled.sort();
    enabled.dedup();
    enabled
}
```

**Algorithm:** this is a depth-first, stack-based transitive closure over the
implication graph encoded by `[features]`. The seed stack is the union of
(a) the `default` feature's list, unless `--no-default-features` was passed,
and (b) the `--features a,b,c` list from the CLI. The loop pops one feature
name at a time; if it's already in `enabled`, it's skipped (cycle/duplicate
protection — the graph is allowed to have diamonds or even cycles without
infinite-looping, since each name is only ever pushed onto `enabled` once);
otherwise it's recorded, and *its own* implied features (its entry in the
`[features]` map) are pushed onto the stack to be expanded in turn. The final
result is sorted and deduplicated for deterministic, order-independent
output.

**Compile-time macros.** Each member of the resolved feature set becomes a
preprocessor define via `Compiler::new`:

```rust
let feature_defines = active_features
    .iter()
    .map(|f| format!("REVOQ_FEATURE_{}", f.to_ascii_uppercase().replace('-', "_")))
    .collect();
```

So a feature named `ssl-support` becomes `-DREVOQ_FEATURE_SSL_SUPPORT`,
injected into every translation unit's compile command alongside the
profile's own `defines` (`push_common` in
[compiler.rs](../src/compiler.rs)). There is no per-feature include path or
source-file gating beyond this macro — conditional compilation inside
sources (`#ifdef REVOQ_FEATURE_SSL_SUPPORT`) is the mechanism by which a
feature actually changes behavior.

Dependencies currently resolve their **own** default feature set
independently (`dep_manifest.resolve_features(&[], false)` in
[main.rs](../src/main.rs) `build_dependencies`) — a consuming package's
`--features` selection does not yet propagate into its dependencies' builds.

## `revoq.lock` Spec

```rust
pub struct Lockfile {
    #[serde(rename = "dependency")]
    pub dependencies: Vec<LockedDependency>,
}

pub struct LockedDependency {
    pub name: String,        // bare package name
    pub source: String,      // "git+<url>"
    pub checksum: String,    // exact resolved commit SHA
    pub version: String,     // requested version/tag string
    pub dependencies: Vec<String>,  // direct dependency names (graph edges)
}
```

On disk this serializes (via `#[serde(rename = "dependency")]`) as a flat
array of TOML tables:

```toml
# This file is auto-generated by revoq.
# It records exact resolved versions for reproducible builds.
# Do not edit by hand; run `revoq update` to regenerate.

[[dependency]]
name = "http_parser"
source = "git+https://github.com/user/http_parser.git"
checksum = "a1b2c3d4e5f6..."
version = "1.5"
dependencies = []
```

Entries are sorted by `name` before serialization (`Lockfile::save` sorts a
cloned copy), so the file's diff stays stable across re-locks regardless of
the manifest's `[dependencies]` declaration order (the manifest side is
already a `BTreeMap`, so it's naturally key-sorted; the explicit lock-side
sort makes the *lock's* ordering independent of any future change to that).

**Role in reproducible builds.** `revoq build` calls
`resolver.resolve_all(manifest, existing_lock.as_ref())`. When a lock entry
exists for a dependency *and* its recorded `version` still matches the
manifest's currently-declared version, `Resolver::resolve_one` takes the
"reproducible path": it hard-resets the cached checkout to the locked
`checksum` via `git checkout --quiet <sha>` (fetching `--unshallow` first if
the SHA isn't present locally) rather than reading the tag's current HEAD.
Only when there is no lock entry, or the manifest's version string has
changed, does resolution fall through to `head_sha()` (fresh HEAD of the
requested tag). This is the mechanism that makes `revoq build` immutable
across machines and over time as long as `revoq.lock` is committed: two
checkouts of the same repository with the same `revoq.lock` resolve every
dependency to the exact same commit, never a possibly-moved tag.

If no lock exists yet, the very first successful `revoq build` writes one
(`build_single` in [main.rs](../src/main.rs)): `if existing_lock.is_none() &&
!resolved.is_empty() { ... lock.save(root)?; }` — first-build lock creation is
implicit; subsequent builds never silently rewrite the lock on their own
(only `revoq update` does that intentionally).

**Atomic write pattern.** `Lockfile::save`:

```rust
let tmp = path.with_extension("lock.tmp");
fs::write(&tmp, format!("{header}{body}")).path_ctx(&tmp)?;
fs::rename(&tmp, &path).path_ctx(&path)?;
```

The full serialized contents (including the three-line auto-generated-file
header comment) are written to a sibling `revoq.lock.tmp` first, and only the
final `fs::rename` touches the real `revoq.lock` path. `rename` within the
same filesystem is atomic at the OS level, so a process interrupted mid-write
(crash, killed build, disk full) can only ever leave a stale-but-intact
`.tmp` file behind — the live `revoq.lock` is either the previous complete
version or the new complete version, never a half-written file. This exact
pattern (write `.tmp`, then `rename`) is reused for the `~/.revoq/revoq-libs`
package index in `revoq sync` — see [cli.md](cli.md#revoq-sync).

## Directory Layout Standards

`Layout::discover` ([engine.rs](../src/engine.rs)) enforces the **four
canonical entry file priority queue** — revoq never globs `src/` looking for
"a" main file; it checks for exactly these four paths, in this exact
precedence order, and uses the first one found:

| Priority | Path | Crate kind | Language |
|---|---|---|---|
| 1 | `src/main.cpp` | Executable | C++ |
| 2 | `src/main.c` | Executable | C |
| 3 | `src/lib.cpp` | Library | C++ |
| 4 | `src/lib.c` | Library | C |

An executable entry (`main.*`) always wins over a library entry
(`lib.*`) if, somehow, both exist in the same `src/` — the doc comment in
[engine.rs](../src/engine.rs) states the rationale plainly: "a package with
`main.*` is runnable." If none of the four exist, the build fails immediately
with a `RevoqError::LayoutViolation` enumerating all four expected paths — this
check happens before the manifest's `[profile.*]` is even consulted, since
there is nothing to compile without a discovered entry point.

**Strict single-language enforcement.** Once the entry file fixes the
package's `entry_language`, `Layout::collect_sources` recursively walks
`src/` and partitions every recognized source file (anything
`Language::from_extension` returns `Some` for) into either `sources`
(matching `entry_language`) or `foreign` (the other language). Headers and
unrecognized extensions are silently skipped — they're not translation units
either way. If `foreign` is non-empty, the **entire build is rejected** with
a `RevoqError::LayoutViolation` naming the offending language, the count of
foreign files, and one example path:

```
strict C/C++ separation violated: this is a Cpp package but found 2 C
source file(s) (e.g. 'src/legacy/util.c'). A revoq package is single-language.
```

There is no per-file override or escape hatch for this rule within a single
package — a project needing both languages must be split into separate
revoq-standard packages (e.g. a workspace with one C member and one C++
member), each independently satisfying the four-file/single-language rule.
See [migration.md](migration.md#dominant-language-resolution) for how
`revoq migrate` handles pre-existing mixed-language CMake projects under this
same constraint.
