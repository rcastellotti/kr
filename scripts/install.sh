#!/usr/bin/env sh
set -eu

BIN_NAME="kr"
REPO="${KR_REPO:-rcastellotti/kr}"
VERSION="${KR_VERSION:-}"
BINDIR="${KR_INSTALL_DIR:-}"
USE_SUDO=0

log() {
  printf '%s\n' "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

usage() {
  cat <<'EOF'
Install kr from GitHub Releases.

Usage:
  install.sh [--version <version>] [--bin-dir <dir>] [--repo <owner/repo>]

Options:
  -v, --version  Release version (example: v0.0.1 or 0.0.1). Defaults to latest.
  -b, --bin-dir  Destination directory for kr. Defaults to /usr/local/bin when possible.
  -r, --repo     GitHub repo in owner/name format. Defaults to rcastellotti/kr.
  -h, --help     Show this help.

Environment variables:
  KR_VERSION      Same as --version.
  KR_INSTALL_DIR  Same as --bin-dir.
  KR_REPO         Same as --repo.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -v|--version)
      [ $# -ge 2 ] || die "missing value for $1"
      VERSION="$2"
      shift 2
      ;;
    -b|--bin-dir)
      [ $# -ge 2 ] || die "missing value for $1"
      BINDIR="$2"
      shift 2
      ;;
    -r|--repo)
      [ $# -ge 2 ] || die "missing value for $1"
      REPO="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if ! command -v tar >/dev/null 2>&1; then
  die "tar is required"
fi

download() {
  _url="$1"
  _out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$_url" -o "$_out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$_out" "$_url"
    return
  fi

  die "curl or wget is required"
}

download_to_stdout() {
  _url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$_url"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO- "$_url"
    return
  fi

  die "curl or wget is required"
}

resolve_latest_tag() {
  api_url="https://api.github.com/repos/$REPO/releases/latest"
  tag="$(
    download_to_stdout "$api_url" \
      | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -n 1
  )"

  [ -n "$tag" ] || die "unable to resolve latest release from $api_url"
  printf '%s' "$tag"
}

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
  linux|darwin) ;;
  *)
    die "unsupported OS: $OS (expected linux or darwin)"
    ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *)
    die "unsupported architecture: $ARCH (expected amd64 or arm64)"
    ;;
esac

if [ -z "$VERSION" ]; then
  TAG="$(resolve_latest_tag)"
else
  case "$VERSION" in
    v*) TAG="$VERSION" ;;
    *) TAG="v$VERSION" ;;
  esac
fi
VERSION="${TAG#v}"

if [ -z "$BINDIR" ]; then
  if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    BINDIR="/usr/local/bin"
  elif [ -d "/usr/local/bin" ] && command -v sudo >/dev/null 2>&1; then
    BINDIR="/usr/local/bin"
    USE_SUDO=1
  else
    BINDIR="${HOME}/.local/bin"
  fi
fi

if [ "$USE_SUDO" -eq 0 ] && [ ! -w "$BINDIR" ] && command -v sudo >/dev/null 2>&1; then
  USE_SUDO=1
fi

if [ "$USE_SUDO" -eq 1 ]; then
  sudo mkdir -p "$BINDIR"
else
  mkdir -p "$BINDIR"
fi

TMPDIR="$(mktemp -d 2>/dev/null || mktemp -d -t kr-install)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

ARCHIVE="${BIN_NAME}_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/$REPO/releases/download/$TAG/$ARCHIVE"
ARCHIVE_PATH="$TMPDIR/$ARCHIVE"

log "Downloading $URL"
download "$URL" "$ARCHIVE_PATH"
tar -xzf "$ARCHIVE_PATH" -C "$TMPDIR"

BIN_PATH="$TMPDIR/$BIN_NAME"
[ -f "$BIN_PATH" ] || die "binary not found in archive: $ARCHIVE"

DEST="$BINDIR/$BIN_NAME"
if command -v install >/dev/null 2>&1; then
  if [ "$USE_SUDO" -eq 1 ]; then
    sudo install -m 0755 "$BIN_PATH" "$DEST"
  else
    install -m 0755 "$BIN_PATH" "$DEST"
  fi
else
  if [ "$USE_SUDO" -eq 1 ]; then
    sudo cp "$BIN_PATH" "$DEST"
    sudo chmod 0755 "$DEST"
  else
    cp "$BIN_PATH" "$DEST"
    chmod 0755 "$DEST"
  fi
fi

log "Installed $BIN_NAME to $DEST"
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *)
    log "warning: $BINDIR is not in PATH for this shell"
    ;;
esac
