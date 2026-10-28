#!/bin/sh
# Installs MoltZip from the latest release, or updates it. Linux and macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/morningstar-code/moltzip/main/install.sh | sh
#
# It downloads the build for this machine, checks it against the published
# checksum, and puts `moltzip` in ~/.local/bin, with its man page and shell
# completions. No root, and nothing outside your home folder is touched.
#
#   sh install.sh --uninstall    removes it again
#
# Environment:
#   MOLTZIP_INSTALL_DIR   where the program goes (default ~/.local/bin)
#   MOLTZIP_VERSION       a release tag like v0.1.0 (default: the latest)

set -eu

REPO="morningstar-code/moltzip"
BIN_DIR="${MOLTZIP_INSTALL_DIR:-$HOME/.local/bin}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
MAN_DIR="$DATA_HOME/man/man1"
BASH_DIR="$DATA_HOME/bash-completion/completions"
ZSH_DIR="$DATA_HOME/zsh/site-functions"
FISH_DIR="$CONFIG_HOME/fish/completions"

if [ -t 1 ]; then
    bold=$(printf '\033[1m')
    red=$(printf '\033[31m')
    reset=$(printf '\033[0m')
else
    bold=""
    red=""
    reset=""
fi

say() { printf '%s\n' "$*"; }
step() { printf '%s\n' "${bold}$*${reset}"; }
fail() {
    printf '%s\n' "${red}moltzip: $*${reset}" >&2
    exit 1
}
has() { command -v "$1" >/dev/null 2>&1; }

download() {
    case "$1" in
        # Only for testing this script against a local build.
        file://*) cp "${1#file://}" "$2" ;;
        *)
            if has curl; then
                curl -fsSL --proto '=https' --tlsv1.2 -o "$2" "$1"
            elif has wget; then
                wget -q --https-only -O "$2" "$1"
            else
                fail "needs curl or wget to download"
            fi
            ;;
    esac
}

sha256() {
    if has sha256sum; then
        sha256sum "$1" | cut -d' ' -f1
    elif has shasum; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        fail "needs sha256sum or shasum to check the download"
    fi
}

uninstall() {
    step "Removing MoltZip"
    rm -f "$BIN_DIR/moltzip" "$MAN_DIR/moltzip.1" \
        "$BASH_DIR/moltzip" "$ZSH_DIR/_moltzip" "$FISH_DIR/moltzip.fish"
    # Only our own mz: a symlink pointing at moltzip.
    if [ "$(readlink "$BIN_DIR/mz" 2>/dev/null)" = moltzip ]; then
        rm -f "$BIN_DIR/mz" "$MAN_DIR/mz.1" "$BASH_DIR/mz" "$ZSH_DIR/_mz" "$FISH_DIR/mz.fish"
    fi
    say "Removed. Half-finished extractions keep their .moltzip files next to the archive."
}

install_moltzip() {
    case "$(uname -s)" in
        Linux) os=linux ;;
        Darwin) os=macos ;;
        *) fail "this installer is for Linux and macOS; on Windows use install.ps1" ;;
    esac
    case "$(uname -m)" in
        x86_64 | amd64) arch=x86_64 ;;
        aarch64 | arm64) arch=aarch64 ;;
        *) fail "no build for $(uname -m) yet; build from source with cargo instead" ;;
    esac
    # An Intel shell on an Apple Silicon Mac (Rosetta) still wants the native build.
    if [ "$os" = macos ] && [ "$arch" = x86_64 ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = 1 ]; then
        arch=aarch64
    fi

    name="moltzip-$arch-$os"
    if [ -n "${MOLTZIP_BASE_URL:-}" ]; then
        base="$MOLTZIP_BASE_URL"
    elif [ -n "${MOLTZIP_VERSION:-}" ]; then
        base="https://github.com/$REPO/releases/download/$MOLTZIP_VERSION"
    else
        base="https://github.com/$REPO/releases/latest/download"
    fi

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    step "Downloading MoltZip for $os $arch"
    download "$base/$name.tar.gz" "$tmp/$name.tar.gz"
    download "$base/$name.tar.gz.sha256" "$tmp/$name.tar.gz.sha256"
    expected=$(cut -d' ' -f1 "$tmp/$name.tar.gz.sha256")
    actual=$(sha256 "$tmp/$name.tar.gz")
    [ "$expected" = "$actual" ] || fail "the download does not match its checksum; nothing was installed"

    tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
    src="$tmp/$name"

    step "Installing to $BIN_DIR"
    mkdir -p "$BIN_DIR" "$MAN_DIR" "$BASH_DIR" "$ZSH_DIR" "$FISH_DIR"
    # Replaced through a rename, so a copy that is running keeps working.
    cp "$src/moltzip" "$BIN_DIR/.moltzip.new"
    chmod 755 "$BIN_DIR/.moltzip.new"
    mv -f "$BIN_DIR/.moltzip.new" "$BIN_DIR/moltzip"
    cp "$src/man/moltzip.1" "$MAN_DIR/moltzip.1"
    cp "$src/completions/moltzip.bash" "$BASH_DIR/moltzip"
    cp "$src/completions/_moltzip" "$ZSH_DIR/_moltzip"
    cp "$src/completions/moltzip.fish" "$FISH_DIR/moltzip.fish"

    # `mz` is the short name, unless some other program already answers to it.
    other_mz=$(command -v mz 2>/dev/null || true)
    if [ -n "$other_mz" ] && [ "$other_mz" != "$BIN_DIR/mz" ]; then
        say "Skipping the short name mz: $other_mz already uses it."
    else
        ln -sf moltzip "$BIN_DIR/mz"
        ln -sf moltzip.1 "$MAN_DIR/mz.1"
        "$BIN_DIR/mz" completions bash > "$BASH_DIR/mz"
        "$BIN_DIR/mz" completions zsh > "$ZSH_DIR/_mz"
        "$BIN_DIR/mz" completions fish > "$FISH_DIR/mz.fish"
    fi

    say ""
    say "$("$BIN_DIR/moltzip" --version) installed. Run it as moltzip or mz; man moltzip has the manual."
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *)
            say ""
            say "$BIN_DIR is not on your PATH yet. Add this line to your shell's startup file:"
            say "  export PATH=\"$BIN_DIR:\$PATH\""
            ;;
    esac
    say ""
    say "Try: moltzip check some-archive.zip"
}

# Nothing above has done anything yet. Piped from curl, the shell runs the
# script as it arrives, so a download cut off halfway stops before this line.
if [ "${1:-}" = "--uninstall" ]; then
    uninstall
else
    install_moltzip
fi
