#!/usr/bin/env bash
#
# Quick health/sync check for the whole stack.
#
set -uo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then set -a; . ./.env; set +a; fi
EL="http://${RPC_BIND_ADDR:-127.0.0.1}:8545"
CL="http://${RPC_BIND_ADDR:-127.0.0.1}:5052"

rpc() { curl -sf -m 5 -X POST -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":[],\"id\":1}" "$EL" 2>/dev/null; }
jget() { python3 -c "import sys,json;d=json.load(sys.stdin);print(eval(sys.argv[1]))" "$2" 2>/dev/null <<<"$1"; }

echo "=== containers ==============================================="
docker compose ps --format 'table {{.Name}}\t{{.Status}}' 2>/dev/null || docker compose ps

echo
echo "=== execution (go-pulse @ $EL) ==============================="
SYNC=$(rpc eth_syncing)
if [[ -z "$SYNC" ]]; then
  echo "UNREACHABLE — is the execution container up? (docker compose logs execution)"
else
  if [[ "$(jget "$SYNC" "d['result']")" == "False" ]]; then
    BLK=$(rpc eth_blockNumber)
    echo "SYNCED — head block: $(jget "$BLK" "int(d['result'],16)")"
  else
    CUR=$(jget "$SYNC" "int(d['result']['currentBlock'],16)")
    HI=$(jget "$SYNC" "int(d['result']['highestBlock'],16)")
    echo "SYNCING — block $CUR / $HI"
  fi
  PEERS=$(rpc net_peerCount)
  echo "peers: $(jget "$PEERS" "int(d['result'],16)")"
fi

echo
echo "=== consensus (lighthouse @ $CL) ============================="
CSYNC=$(curl -sf -m 5 "$CL/eth/v1/node/syncing" 2>/dev/null)
if [[ -z "$CSYNC" ]]; then
  echo "UNREACHABLE — is the consensus container up? (docker compose logs consensus)"
else
  IS_SYNCING=$(jget "$CSYNC" "d['data']['is_syncing']")
  HEAD=$(jget "$CSYNC" "d['data']['head_slot']")
  DIST=$(jget "$CSYNC" "d['data']['sync_distance']")
  [[ "$IS_SYNCING" == "False" ]] && echo "SYNCED — head slot: $HEAD" || echo "SYNCING — head slot $HEAD, $DIST slots behind"
  CPEERS=$(curl -sf -m 5 "$CL/eth/v1/node/peer_count" 2>/dev/null)
  echo "peers: $(jget "$CPEERS" "d['data']['connected']")"
fi

echo
echo "=== validator ================================================"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^pulse-validator$'; then
  if [[ -z "${FEE_RECIPIENT:-}" ]]; then
    echo "WARNING: validator running but FEE_RECIPIENT is empty in .env!"
  fi
  docker logs pulse-validator --tail 5 2>&1 | sed 's/^/  /'
else
  echo "not running (enable with COMPOSE_PROFILES=validator — see validator/README.md)"
fi
