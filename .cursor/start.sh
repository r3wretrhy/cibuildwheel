#!/usr/bin/env bash
# Per-boot startup for cibuildwheel Cloud Agents: bring up the Docker daemon
# (needed to build Linux wheels) and wait until it is ready. Idempotent.
set -euo pipefail

# Start the daemon only if it is not already responding.
if ! sudo docker info >/dev/null 2>&1; then
  sudo service docker start 2>/dev/null || sudo sh -c 'dockerd >/tmp/dockerd.log 2>&1 &'
fi

# Wait up to ~60s for the daemon to accept connections.
for _ in $(seq 1 30); do
  if sudo docker info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! sudo docker info >/dev/null 2>&1; then
  echo "Docker daemon failed to start" >&2
  exit 1
fi

# Let the agent user use the socket without sudo/re-login.
sudo chmod 666 /var/run/docker.sock || true

echo "Docker is ready ($(docker --version))."
