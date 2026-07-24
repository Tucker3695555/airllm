# Running a PulseChain RPC Endpoint

The base node already serves JSON-RPC — this doc covers using it yourself vs.
serving it to others safely.

## Private use (default — nothing to do)

`RPC_BIND_ADDR=127.0.0.1` in `.env` binds RPC to localhost only:

- HTTP: `http://127.0.0.1:8545`
- WebSocket: `ws://127.0.0.1:8546`
- Beacon API: `http://127.0.0.1:5052`

Point your wallet/bot/indexer on the same machine at those. For access from
your LAN, either SSH-tunnel (`ssh -L 8545:localhost:8545 node-host`) or set
`RPC_BIND_ADDR=0.0.0.0` **with a firewall allowing only your IPs**.

Quick test:

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://127.0.0.1:8545
# mainnet => {"jsonrpc":"2.0","id":1,"result":"0x171"}   (0x171 = 369)
```

## Serving RPC to others (profile: `rpc`)

Never expose 8545 directly to the internet. The `rpc` profile puts nginx in
front with per-IP rate limiting (20 req/s, burst 40 — tune in `nginx.conf`):

```bash
# .env
COMPOSE_PROFILES=rpc        # or validator,rpc,monitoring
RPC_PROXY_HTTP_PORT=8080
```

```bash
docker compose up -d
curl http://<host>:8080/health          # {"status":"ok"}
```

- HTTP RPC: `http://<host>:8080/`
- WebSocket: `ws://<host>:8080/ws`

The attack surface is limited by the API list in `.env`
(`HTTP_APIS=eth,net,web3,txpool`): the dangerous namespaces (`admin`,
`debug`, `personal`, `miner`) are simply not enabled on go-pulse, so nothing
needs to be filtered at the proxy. Don't add them on a public endpoint.
Drop `txpool` too if users don't need pending-tx queries.

### TLS (https/wss)

1. Get certs on the host, e.g. `certbot certonly --standalone -d rpc.example.com`
   (stop the proxy or use webroot mode while issuing).
2. `mkdir rpc/certs && cp /etc/letsencrypt/live/rpc.example.com/{fullchain,privkey}.pem rpc/certs/`
3. Uncomment the TLS server block in `rpc/nginx.conf` (set `server_name`),
   and the `443:443` port + certs volume lines in `docker-compose.yml`.
4. `docker compose up -d rpc-proxy`

Alternatively put Cloudflare (or any LB/CDN) in front of port 8080 and let it
terminate TLS + absorb abuse — the `/health` endpoint is made for LB checks.

## Archive data — erigon-pulse

go-pulse (snap sync) serves recent state; historical state queries
(`eth_call`/`eth_getBalance` at old blocks, `trace_*`) need an **archive
node**. PulseChain publishes an Erigon fork that is far more efficient at
this than geth archive mode:

```
registry.gitlab.com/pulsechaincom/erigon-pulse:latest
```

Budget several TB of fast NVMe. It can replace the `execution` service
(Erigon has a built-in RPC daemon on 8545; P2P uses 30303/30304 + 42069) —
kept out of this compose file since most operators don't need archive data.
Repo: <https://gitlab.com/pulsechaincom/erigon-pulse>

## Public endpoints (for comparison / fallback)

| Network    | RPC                                      | Chain ID |
|------------|------------------------------------------|----------|
| Mainnet    | `https://rpc.pulsechain.com`             | 369      |
| Testnet v4 | `https://rpc.v4.testnet.pulsechain.com`  | 943      |

Running your own gets you no rate limits, mempool access, privacy, and
independence — which is the point.
