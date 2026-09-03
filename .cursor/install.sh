#!/usr/bin/env bash
# Idempotent repository bootstrap for cibuildwheel Cloud Agents.
# Installs uv + project deps, the nox/prek dev tools, and Docker with the
# fuse-overlayfs storage driver required to build Linux wheels inside the
# nested-container Cloud Agent VM.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

export PATH="$HOME/.local/bin:$PATH"

# 1. uv (Python package/dependency manager pinned by this project).
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# 2. Project virtualenv (.venv) + all dependency groups.
uv sync

# 3. Maintainer tooling used by the developer commands in AGENTS.md.
uv tool install --quiet nox || true
uv tool install --quiet prek || true

# 4. Docker: cibuildwheel builds Linux wheels inside manylinux/musllinux
#    containers, so a working container engine is required.
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
fi

# 5. fuse-overlayfs storage driver. The VM's kernel cannot extract overlayfs
#    whiteout files in the default nested overlay driver, so image pulls fail
#    with "operation not permitted". fuse-overlayfs avoids this.
if ! command -v fuse-overlayfs >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::=--force-confold fuse-overlayfs
fi

# 6. Point the Docker daemon at fuse-overlayfs.
sudo mkdir -p /etc/docker
echo '{ "storage-driver": "fuse-overlayfs" }' | sudo tee /etc/docker/daemon.json >/dev/null

# 7. Allow the agent user to talk to the Docker socket without re-login.
sudo groupadd -f docker
sudo usermod -aG docker "$(id -un)" || true

echo "cibuildwheel install complete."
