# pulsechain-stack

Run your own PulseChain infrastructure with Docker Compose:

- **Full node** — go-pulse (execution) + lighthouse-pulse (consensus), the
  official PulseChain clients, with checkpoint sync
- **Validators** — lighthouse validator client with doppelganger protection,
  plus scripts for key generation and import
- **RPC endpoints** — private by default; optional nginx edge with rate
  limiting for serving others
- **Monitoring** — optional Prometheus + Grafana

Everything runs from one `docker-compose.yml` using profiles, configured via
one `.env` file. Supports mainnet and testnet v4.

## Hardware

| | Minimum | Recommended |
|---|---|---|
| CPU | 4 cores | 8+ cores |
| RAM | 8 GB | 16–32 GB |
| Disk | 1 TB free **SSD** | 2 TB NVMe (headroom for growth) |
| Network | 8 Mbit/s | 25+ Mbit/s, no data cap |

Spinning disks will not keep up. Validators additionally want a UPS, stable
internet, and boring reliability over raw specs.

## Quickstart (full node)

```bash
git clone <this-repo> && cd pulsechain-stack
./setup.sh                 # or: ./setup.sh testnet
docker compose up -d
./scripts/health.sh        # repeat until both clients show SYNCED
docker compose logs -f     # watch it work
```

`setup.sh` creates the data directories, generates the JWT secret the two
clients use to authenticate to each other, and writes your `.env`.

First sync: the consensus client checkpoint-syncs in minutes; the execution
client snap-syncs the state — typically **1–3 days** depending on disk and
peers. `eth_syncing` staying `true` that long is normal.

## Then pick your roles

| Goal | Do this |
|---|---|
| Stake & validate | [validator/README.md](validator/README.md) |
| Serve RPC to apps/others | [rpc/README.md](rpc/README.md) |
| Dashboards & alerts | [monitoring/README.md](monitoring/README.md) |

Roles are enabled via `COMPOSE_PROFILES` in `.env`, e.g.
`COMPOSE_PROFILES=validator,rpc,monitoring`, then `docker compose up -d`.

## Ports

| Port | Proto | Service | Exposure |
|---|---|---|---|
| 30303 | TCP+UDP | execution P2P | **open in firewall** |
| 9000 | TCP+UDP | consensus P2P | **open in firewall** |
| 8545 / 8546 | TCP | JSON-RPC http/ws | localhost by default (`RPC_BIND_ADDR`) |
| 5052 | TCP | beacon API | localhost by default |
| 8080 | TCP | nginx RPC edge | only with `rpc` profile |
| 9090 / 3000 | TCP | prometheus / grafana | localhost only |

Example ufw setup:

```bash
ufw allow 30303 && ufw allow 9000
ufw allow from <your-ip> to any port 22 proto tcp
ufw enable
```

## Network reference

| | Mainnet | Testnet v4 |
|---|---|---|
| Chain ID | 369 | 943 |
| go-pulse flag | `--pulsechain` | `--pulsechain-testnet-v4` |
| lighthouse `--network` | `pulsechain` | `pulsechain_testnet_v4` |
| Checkpoint sync | https://checkpoint.pulsechain.com | https://checkpoint.v4.testnet.pulsechain.com |
| Public RPC | https://rpc.pulsechain.com | https://rpc.v4.testnet.pulsechain.com |
| Explorer | https://scan.pulsechain.com | https://scan.v4.testnet.pulsechain.com |
| Beacon explorer | https://beacon.pulsechain.com | — |
| Launchpad | https://launchpad.pulsechain.com | — |
| Faucet | — | https://faucet.v4.testnet.pulsechain.com |

Official client sources: [go-pulse](https://gitlab.com/pulsechaincom/go-pulse) ·
[lighthouse-pulse](https://gitlab.com/pulsechaincom/lighthouse-pulse) ·
[erigon-pulse](https://gitlab.com/pulsechaincom/erigon-pulse) ·
[prysm-pulse](https://gitlab.com/pulsechaincom/prysm-pulse) ·
[staking-deposit-cli](https://gitlab.com/pulsechaincom/staking-deposit-cli)

## Layout

```
├── docker-compose.yml     # all services; profiles: validator, rpc, monitoring
├── .env(.example)         # single place for all configuration
├── setup.sh               # one-time init (dirs, JWT secret, .env)
├── scripts/
│   ├── generate-keys.sh   # validator keygen (staking-deposit-cli)
│   ├── import-keys.sh     # import keystores into lighthouse
│   ├── health.sh          # sync/peer/validator status
│   └── update.sh          # pull latest images + restart
├── validator/README.md    # staking guide: 32M PLS → attesting validator
├── rpc/                   # nginx edge config + RPC serving guide
├── monitoring/            # prometheus config + grafana provisioning
├── data/                  # chain data (gitignored)
├── jwt/                   # EL↔CL auth secret (gitignored)
└── keys/                  # generated validator keys (gitignored)
```

## Day-2 operations

```bash
./scripts/health.sh                     # am I ok?
docker compose logs -f consensus        # per-service logs
./scripts/update.sh                     # update clients (do this regularly!)
docker compose down                     # stop (data persists in ./data)
```

**Disk full?** Chain grows continuously — watch it (monitoring profile alerts
help). **Machine died?** Reinstall docker, clone this repo, restore your
`.env` + `jwt/`, `docker compose up -d` — it resyncs from where the data
volume left off, or from scratch via checkpoint sync if the disk was lost.
Validator keys: restore from mnemonic/keystores per
[validator/README.md](validator/README.md) — never from a datadir backup.

## Security checklist

- [ ] RPC bound to localhost or behind the rate-limited nginx edge
- [ ] Only `eth,net,web3,txpool` APIs enabled (no `admin`/`debug`/`personal`)
- [ ] Firewall: only 30303, 9000 (and 8080/443 if serving RPC) open publicly
- [ ] SSH: keys only, no password auth
- [ ] `jwt/`, `keys/`, `.env` never committed (already gitignored)
- [ ] Validator mnemonic on paper, offline
- [ ] Same validator keys never on two machines
- [ ] Grafana password changed from default

## Disclaimer

Infrastructure tooling only — nothing here is investment advice. Validating
locks 32M PLS per validator at protocol level; understand slashing and exit
mechanics (see [validator/README.md](validator/README.md)) before depositing.
