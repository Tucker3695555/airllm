#!/usr/bin/env bash
#
# Import generated validator keystores into the lighthouse validator client.
# Run AFTER generate-keys.sh (keystores in ./keys/validator_keys/).
# You will be prompted for the keystore password chosen at generation time.
#
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then set -a; . ./.env; set +a; fi
CL_NETWORK="${CL_NETWORK:-pulsechain}"
KEYS_DIR="${1:-keys/validator_keys}"

if ! ls "$KEYS_DIR"/keystore-*.json >/dev/null 2>&1; then
  echo "ERROR: no keystore-*.json files in $KEYS_DIR" >&2
  echo "Generate keys first (scripts/generate-keys.sh) or pass the directory: $0 <dir>" >&2
  exit 1
fi

docker compose run --rm --no-deps \
  -v "$(pwd)/$KEYS_DIR:/keys:ro" \
  validator \
  lighthouse account validator import \
  --network "$CL_NETWORK" \
  --datadir /data \
  --directory /keys

echo
echo "Keys imported into ./data/validator."
echo "Before starting the validator:"
echo "  1. Set FEE_RECIPIENT=0xYourAddress in .env (required)"
echo "  2. Add 'validator' to COMPOSE_PROFILES in .env"
echo "  3. docker compose up -d"
echo
echo "Doppelganger protection is on: the validator idles for the first"
echo "2-3 epochs (~15-20 min) checking no other machine runs these keys."
echo "NEVER run the same keys on two machines — that gets you slashed."
