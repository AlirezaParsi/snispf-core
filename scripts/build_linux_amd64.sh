#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

RELEASE_DIR="${REPO_ROOT}/release"
mkdir -p "${RELEASE_DIR}"

echo "Running tests..."
go test ./...

echo "Running vet..."
go vet ./...

echo "Building Linux amd64 core binary..."
VERSION="${VERSION:-}"
if [[ -z "${VERSION}" ]]; then
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo "dev")"
  else
    VERSION="dev"
  fi
fi
GOOS=linux GOARCH=amd64 go build -ldflags "-X main.version=${VERSION}" -o "${RELEASE_DIR}/snispf_linux_amd64" ./cmd/snispf

echo "Build complete:"
ls -lh "${RELEASE_DIR}/snispf_linux_amd64"
