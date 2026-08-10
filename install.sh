#!/bin/sh
# deft installer — macOS, Linux, WSL, and Git Bash.
#
#   curl -fsSL https://deft-cli.com/install.sh | sh
#
# Downloads the latest release binary for your OS/arch, drops it in
# ~/.local/bin (override with DEFT_BIN_DIR), and runs `deft doctor`.
#
# Knobs:
#   DEFT_BIN_DIR=/usr/local/bin   install location
#   DEFT_VERSION=v0.6.0           pin a version instead of the latest release
#
# Native Windows (PowerShell / cmd, no Git Bash)? Use install.ps1 instead:
#   irm https://deft-cli.com/install.ps1 | iex

set -eu

REPO="xntas/deft"
BIN_DIR="${LOWN_BIN:-${DEFT_BIN_DIR:-$HOME/.local/bin}}"

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
binname="deft"

case "$os" in
  Linux)                         plat="unknown-linux-gnu" ;;
  Darwin)                        plat="apple-darwin" ;;
  MINGW*|MSYS*|CYGWIN*|Windows*) plat="pc-windows-msvc"; ext="zip"; binname="deft.exe" ;;
  *) die "unsupported OS '$os' — build from source: https://github.com/$REPO" ;;
esac

case "$arch" in
  x86_64|amd64)  cpu="x86_64" ;;
  arm64|aarch64) cpu="aarch64" ;;
  *) die "unsupported architecture '$arch' — build from source: https://github.com/$REPO" ;;
esac

# Windows builds are x86_64-only for now.
if [ "$plat" = "pc-windows-msvc" ] && [ "$cpu" != "x86_64" ]; then
  die "no Windows build for '$arch' yet — build from source: https://github.com/$REPO"
fi

target="${cpu}-${plat}"

# --- resolve version -------------------------------------------------------
if [ "${DEFT_VERSION:-}" != "" ]; then
  tag="$DEFT_VERSION"
else
  say "resolving latest release..."
  tag="$(fetch "https://api.github.com/repos/$REPO/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)"
  [ -n "$tag" ] || die "couldn't determine the latest release (set DEFT_VERSION=vX.Y.Z to pin one)"
fi

asset="deft-${target}.${ext}"
url="https://github.com/$REPO/releases/download/${tag}/${asset}"

say "installing deft ${tag} (${target})"

# --- download + extract ----------------------------------------------------
tmp="$(mktemp -d 2>/dev/null || mktemp -d -t deft)"
trap 'rm -rf "$tmp"' EXIT INT TERM

say "downloading ${asset}"
dl "$url" "$tmp/$asset" || die "download failed: $url"

case "$ext" in
  tar.gz) tar xzf "$tmp/$asset" -C "$tmp" ;;
  zip)
    if command -v unzip >/dev/null 2>&1; then
      unzip -q "$tmp/$asset" -d "$tmp"
    else
      # bsdtar (ships with modern Windows / Git Bash) can read zips.
      tar xf "$tmp/$asset" -C "$tmp" 2>/dev/null || die "need 'unzip' to extract $asset"
    fi
    ;;
esac

src="$tmp/deft-${target}/$binname"
[ -f "$src" ] || die "archive did not contain the expected binary ($binname)"

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
say "running 'deft doctor' to check your environment..."
printf '\n'
"$BIN_DIR/$binname" doctor || warn "deft is installed, but doctor flagged issues above — fix those before building."
