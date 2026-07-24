#!/usr/bin/env bash
#
# Pull latest client images and restart the stack.
# Client updates matter: run this regularly (or watch the PulseChain telegram/
# gitlab for release announcements, especially before hard forks).
#
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose pull
docker compose up -d --remove-orphans
docker image prune -f

echo
echo "Updated. Check: ./scripts/health.sh"
echo "Note: after a validator client restart, doppelganger protection idles"
echo "the validator for ~2-3 epochs before it resumes attesting. Normal."
