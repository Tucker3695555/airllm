#!/usr/bin/env bash
#
# Generate PulseChain validator keys with the official staking-deposit-cli.
#
#   ./scripts/generate-keys.sh [mainnet|testnet] [new|existing]
#
#   new       create a new mnemonic + keys (default)
#   existing  derive more keys from a mnemonic you already have
#
# Output: ./keys/validator_keys/
#   - keystore-m_12381_3600_*.json  (encrypted signing keys -> import to validator)
#   - deposit_data-*.json           (upload to https://launchpad.pulsechain.com)
#
# SECURITY: for mainnet, run this on an OFFLINE (air-gapped) machine and move
# only keystore + deposit_data files to the validator host. The mnemonic is the
# master key to your stake — write it on paper, never store it digitally.
#
set -euo pipefail
cd "$(dirname "$0")/.."

NETWORK="${1:-mainnet}"
MODE="${2:-new}"

case "$NETWORK" in
  mainnet) CHAIN="pulsechain" ;;
  testnet) CHAIN="pulsechain-testnet-v4" ;;
  *) echo "Usage: $0 [mainnet|testnet] [new|existing]" >&2; exit 1 ;;
esac
case "$MODE" in
  new)      CMD="new-mnemonic" ;;
  existing) CMD="existing-mnemonic" ;;
  *) echo "Usage: $0 [mainnet|testnet] [new|existing]" >&2; exit 1 ;;
esac

if [[ "$NETWORK" == "mainnet" ]]; then
  echo "==============================================================="
  echo " MAINNET KEY GENERATION"
  echo " Strongly recommended: run this on an offline, freshly-booted"
  echo " machine. Anyone who sees the mnemonic can steal your stake."
  echo "==============================================================="
  read -r -p "Continue on THIS machine? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || exit 1
fi

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git is required" >&2; exit 1; }

# Official PulseChain fork — no binaries/docker images are published for it,
# so we run it from source.
if [[ ! -d staking-deposit-cli ]]; then
  git clone https://gitlab.com/pulsechaincom/staking-deposit-cli.git
fi

mkdir -p keys
cd staking-deposit-cli
./deposit.sh install
./deposit.sh "$CMD" --chain="$CHAIN" --folder=../keys

echo
echo "Done. Files are in ./keys/validator_keys/"
echo "  1. BACK UP your mnemonic (paper, offline)."
echo "  2. Deposit 32,000,000 PLS per validator via https://launchpad.pulsechain.com"
echo "     using the deposit_data-*.json file."
echo "  3. Import signing keys on the validator host: ./scripts/import-keys.sh"
