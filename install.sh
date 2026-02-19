#!/bin/sh
set -eu

REPO="rcastellotti/kr"
PROJECT="kr"

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  log "Error: $*"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

need_cmd curl
need_cmd tar
need_cmd uname
need_cmd install

OS_RAW=$(uname -s)
ARCH_RAW=$(uname -m)

case "$OS_RAW" in
  Darwin) OS_TOKEN="Darwin" ;;
  Linux) OS_TOKEN="Linux" ;;
  *) fail "unsupported OS '$OS_RAW' (macOS and Linux only)" ;;
esac

case "$ARCH_RAW" in
  x86_64|amd64) ARCH_PATTERN="x86_64|amd64" ;;
  arm64|aarch64) ARCH_PATTERN="arm64|aarch64" ;;
  *) fail "unsupported architecture '$ARCH_RAW'" ;;
esac

API_BASE="https://api.github.com/repos/$REPO/releases"
if [ "${VERSION:-}" != "" ]; then
  RELEASE_URL="$API_BASE/tags/$VERSION"
else
  RELEASE_URL="$API_BASE/latest"
fi

AUTH_HEADER=""
if [ "${GITHUB_TOKEN:-}" != "" ]; then
  AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
fi

log "Fetching release metadata..."
if [ "$AUTH_HEADER" != "" ]; then
  RELEASE_JSON=$(curl -fsSL -H "$AUTH_HEADER" "$RELEASE_URL") || fail "unable to fetch release metadata"
else
  RELEASE_JSON=$(curl -fsSL "$RELEASE_URL") || fail "unable to fetch release metadata"
fi

ASSET_URL=$(
  printf '%s' "$RELEASE_JSON" \
    | tr -d '\r' \
    | grep -Eo '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | cut -d '"' -f 4 \
    | grep -E "/${PROJECT}_.+_${OS_TOKEN}_(${ARCH_PATTERN})\\.tar\\.gz$" \
    | head -n 1
)

[ "$ASSET_URL" != "" ] || fail "no matching release asset found for ${OS_TOKEN}/${ARCH_RAW}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

ARCHIVE="$TMPDIR/${PROJECT}.tar.gz"
log "Downloading $ASSET_URL"
curl -fL "$ASSET_URL" -o "$ARCHIVE" || fail "download failed"

log "Extracting archive..."
tar -xzf "$ARCHIVE" -C "$TMPDIR" || fail "failed to extract archive"

BINARY="$TMPDIR/$PROJECT"
[ -f "$BINARY" ] || fail "archive did not contain '$PROJECT' binary"

if [ "${INSTALL_DIR:-}" = "" ]; then
  if [ -w /usr/local/bin ]; then
    INSTALL_DIR=/usr/local/bin
  else
    INSTALL_DIR="$HOME/.local/bin"
  fi
fi

mkdir -p "$INSTALL_DIR" || fail "unable to create install dir: $INSTALL_DIR"
install -m 0755 "$BINARY" "$INSTALL_DIR/$PROJECT" || fail "install failed"

log "Installed $PROJECT to $INSTALL_DIR/$PROJECT"
if [ "$INSTALL_DIR" = "$HOME/.local/bin" ]; then
  log "If needed, add to PATH: export PATH=\"$HOME/.local/bin:\$PATH\""
fi
