#!/usr/bin/env bash
#
# One-time host setup: directories, JWT secret, .env
#
#   ./setup.sh            # mainnet (default)
#   ./setup.sh testnet    # PulseChain testnet v4
#
set -euo pipefail
cd "$(dirname "$0")"

NETWORK="${1:-mainnet}"
case "$NETWORK" in
  mainnet|testnet) ;;
  *) echo "Usage: $0 [mainnet|testnet]" >&2; exit 1 ;;
esac

# --- prerequisites -----------------------------------------------------------
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is not installed. See https://docs.docker.com/engine/install/" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose v2 plugin missing. See https://docs.docker.com/compose/install/" >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl is required to generate the JWT secret" >&2; exit 1; }

# --- directories -------------------------------------------------------------
mkdir -p data/execution data/consensus data/validator data/prometheus data/grafana jwt keys

# prometheus runs as uid 65534, grafana as uid 472 — best effort, warn on failure
chown 65534:65534 data/prometheus 2>/dev/null || echo "NOTE: could not chown data/prometheus to 65534 (run as root/sudo if the monitoring profile fails to start)"
chown 472:472 data/grafana 2>/dev/null || echo "NOTE: could not chown data/grafana to 472 (run as root/sudo if the monitoring profile fails to start)"

# --- JWT secret (shared auth between execution and consensus clients) --------
if [[ ! -s jwt/jwt.hex ]]; then
  openssl rand -hex 32 | tr -d '\n' > jwt/jwt.hex
  chmod 600 jwt/jwt.hex
  echo "Generated jwt/jwt.hex"
else
  echo "jwt/jwt.hex already exists — keeping it"
fi

# --- .env --------------------------------------------------------------------
if [[ ! -f .env ]]; then
  cp .env.example .env
  if [[ "$NETWORK" == "testnet" ]]; then
    sed -i.bak \
      -e 's|^EL_NETWORK_FLAG=--pulsechain$|EL_NETWORK_FLAG=--pulsechain-testnet-v4|' \
      -e 's|^CL_NETWORK=pulsechain$|CL_NETWORK=pulsechain_testnet_v4|' \
      -e 's|^CHECKPOINT_URL=https://checkpoint.pulsechain.com$|CHECKPOINT_URL=https://checkpoint.v4.testnet.pulsechain.com|' \
      .env && rm -f .env.bak
  fi
  echo "Created .env for $NETWORK"
else
  echo ".env already exists — keeping it (network arg ignored)"
fi

echo
echo "Setup complete ($NETWORK). Next:"
echo "  1. Review .env"
echo "  2. Start the node:        docker compose up -d"
echo "  3. Watch it sync:         ./scripts/health.sh   (and: docker compose logs -f)"
echo "  4. Validators / RPC:      see validator/README.md and rpc/README.md"
