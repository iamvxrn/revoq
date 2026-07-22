<div align="center">
<h1>deft</h1>
<h6>Cargo, but for C and C++ — an experiment in what AI can build.</h6>
</div>

> **deft is an experiment, not a product.** It started from one question: point
> an AI at "Cargo, but for C and C++," and see how far it gets. The build system,
> the resolver, the library port, the website — all of it came out of chasing
> that. It works and it's fun to use, but it hasn't earned your production build.
> Treat it as a study of what AI can do in the C/C++ tooling space.

This is the deft **monorepo**. It brings together what used to be four separate
repositories, each preserving its own history:

| Path | What it is | Was |
|------|------------|-----|
| [`cli/`](cli/) | The `deft` CLI — package manager + build system (Rust) | `deft-cli/deft` |
| [`website/`](website/) | The deft website (Hugo) — deployed to Cloudflare Pages | `deft-cli/website` |
| [`examples/example-app/`](examples/example-app/) | A minimal example project built with deft | `deft-cli/example-app` |
| [`libs/json/`](libs/json/) | An nlohmann/json port packaged for deft | `deft-cli/json` |

## Build the CLI

```sh
cd cli
cargo build --release
```

## Run the website locally

```sh
cd website
hugo server
```

## Release notes

See [`cli/CHANGELOG.md`](cli/CHANGELOG.md). The current release is **0.6.0**
(the Legacy Support release).

## License

MIT. See each component's `LICENSE`.
