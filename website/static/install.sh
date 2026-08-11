#!/bin/sh
# revoq installer — macOS, Linux, WSL, and Git Bash.
#
#   curl -fsSL https://revoq.pages.dev/install.sh | sh
#
# Downloads the latest release binary for your OS/arch, drops it in
# ~/.local/bin (override with REVOQ_BIN_DIR), and runs `revoq doctor`.

set -eu

REPO="iamvxrn/revoq"
BIN_DIR="${LOWN_BIN:-${REVOQ_BIN_DIR:-$HOME/.local/bin}}"

say()  { printf '  %s\n' "$1"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# --- pick a downloader -----------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  dl() { curl -fsSL "$1" -o "$2"; }
  fetch() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
  dl() { wget -qO "$2" "$1"; }
  fetch() { wget -qO - "$1"; }
else
  die "need curl or wget on your PATH"
fi

# --- detect platform -------------------------------------------------------
os="$(uname -s)"
arch="$(uname -m)"
ext="tar.gz"
binname="revoq"

case "$os" in
  Linux)                         plat="unknown-linux-gnu" ;;
  Darwin)                        plat="apple-darwin" ;;
  MINGW*|MSYS*|CYGWIN*|Windows*) plat="pc-windows-msvc"; ext="zip"; binname="revoq.exe" ;;
  *) die "unsupported OS '$os' — build from source: https://github.com/$REPO" ;;
esac

case "$arch" in
  x86_64|amd64)  cpu="x86_64" ;;
  arm64|aarch64) cpu="aarch64" ;;
  *) die "unsupported architecture '$arch' — build from source: https://github.com/$REPO" ;;
esac

if [ "$plat" = "pc-windows-msvc" ] && [ "$cpu" != "x86_64" ]; then
  die "no Windows build for '$arch' yet — build from source: https://github.com/$REPO"
fi

target="${cpu}-${plat}"

# --- resolve version -------------------------------------------------------
if [ "${REVOQ_VERSION:-}" != "" ]; then
  tag="$REVOQ_VERSION"
else
  say "resolving latest release..."
  tag="$(fetch "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4 || true)"
  if [ -z "$tag" ]; then
    tag="$(fetch "https://api.github.com/repos/$REPO/releases" 2>/dev/null \
      | grep '"tag_name"' | head -1 | cut -d'"' -f4 || true)"
  fi
  if [ -z "$tag" ]; then
    tag="v0.7.2"
  fi
fi

asset="revoq-${tag}-${target}.${ext}"
url="https://github.com/$REPO/releases/download/${tag}/${asset}"

say "installing revoq ${tag} (${target})"

# --- download + extract ----------------------------------------------------
tmp="$(mktemp -d 2>/dev/null || mktemp -d -t revoq)"
trap 'rm -rf "$tmp"' EXIT INT TERM

say "downloading ${asset}"
if ! dl "$url" "$tmp/$asset"; then
  asset_alt="revoq-${target}.${ext}"
  url_alt="https://github.com/$REPO/releases/download/${tag}/${asset_alt}"
  dl "$url_alt" "$tmp/$asset" || die "download failed: $url"
fi

case "$ext" in
  tar.gz) tar xzf "$tmp/$asset" -C "$tmp" ;;
  zip)
    if command -v unzip >/dev/null 2>&1; then
      unzip -q "$tmp/$asset" -d "$tmp"
    else
      tar xf "$tmp/$asset" -C "$tmp" 2>/dev/null || die "need 'unzip' to extract $asset"
    fi
    ;;
esac

src="$tmp/$binname"
if [ ! -f "$src" ]; then
  src="$(find "$tmp" -type f -name "$binname" | head -1 || true)"
fi
[ -n "$src" ] && [ -f "$src" ] || die "archive did not contain the expected binary ($binname)"

# --- install ---------------------------------------------------------------
mkdir -p "$BIN_DIR"
install -m 0755 "$src" "$BIN_DIR/$binname" 2>/dev/null \
  || { cp "$src" "$BIN_DIR/$binname" && chmod 0755 "$BIN_DIR/$binname"; }

say "installed to $BIN_DIR/$binname"

# --- PATH check ------------------------------------------------------------
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) warn "$BIN_DIR is not on your PATH — add it, e.g.:"
     printf '    export PATH="%s:$PATH"\n' "$BIN_DIR" >&2 ;;
esac

# --- verify the toolchain --------------------------------------------------
printf '\n'
say "running 'revoq doctor' to check your environment..."
printf '\n'
"$BIN_DIR/$binname" doctor || warn "revoq is installed, but doctor flagged issues above — fix those before building."
