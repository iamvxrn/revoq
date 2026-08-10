---
title: "Documentation"
---

## Getting started

This walks you from an empty directory to a running C/C++ project in about a
minute. You'll need `clang` installed and the `revol` binary on your `PATH`. Not
sure your setup is good? Run `revol doctor` any time — it checks the whole
toolchain for you.

### 1. Start a project

No build script to hand-write. Make a directory and initialize it:

```bash
mkdir my_project
cd my_project

# Defaults to a C++ executable
revol init
```

Want a C project or a static library instead? Use `revol init --c` or
`revol init --lib`.

### 2. The layout

revol borrows Cargo's idea of a fixed, predictable layout, so there's nothing to
configure about where files go. A fresh project looks like this:

```text
my_project/
├── src/
│   └── main.cpp  # the entry point for a C++ executable
├── .gitignore    # generated, ignores target/
└── revol.toml     # the manifest
```

And `revol.toml` starts small:

```toml
[package]
name = "my_project"
version = "0.2.0"

[profile.cpp]
standard = "c++20"
warnings = ["all", "extra"]
optimization = "0"
```

> **One language per package.** revol won't let a package mix C and C++. Drop a
> `.c` file into a C++ package and the build stops with a `LayoutViolation`
> rather than quietly compiling it with the wrong flags. (Building a legacy tree
> that doesn't fit? See the manifest guide's Legacy Support section.)

### 3. Build

From the project root:

```bash
revol build
```

revol finds every source under `src/`, spreads the work across an internal thread
pool, and calls the compiler. One nice consequence of how it's built: a
successful build never pays for environment checks — revol only runs its `doctor`
diagnostics when a build actually *fails*, so the happy path stays lean.

Everything it produces lands in `target/`:

* **Unix:** `target/debug/my_project`
* **Windows:** `target/debug/my_project.exe`

For an optimized build — `-O3`, no debug symbols, `-DNDEBUG` — add `--release`:

```bash
revol build --release
```

### 4. Run

Build and run in one step:

```bash
revol run
```

Need to pass arguments to *your* program rather than to revol? Put them after
`--`:

```bash
revol run -- --port 8080 --verbose
```

Everything after `--` is forwarded to your executable untouched.

### 5. Add a dependency

revol pulls dependencies without git submodules or vendored headers. Add a GitHub
shorthand to the `[dependencies]` table:

```toml
[dependencies]
"gh:user/network_lib" = "1.5"
```

Then fetch and lock it:

```bash
revol update
```

Under the hood, revol clones the repo into its global cache (`~/.revol/cache/`),
resolves the tag you asked for, and pins the exact commit in `revol.lock` so the
build is the same on every machine. From the next `revol build` on, the dependency
is compiled to a static library (`.a` / `.lib`) and linked into your binary
automatically.
