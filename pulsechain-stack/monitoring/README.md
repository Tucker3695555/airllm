# Monitoring

Prometheus + Grafana for the whole stack.

## Enable

In `.env`, add `monitoring` to the profiles and restart:

```bash
# .env
COMPOSE_PROFILES=monitoring          # or: validator,rpc,monitoring
```

```bash
docker compose up -d
```

- Grafana: http://localhost:3000 — login `admin` / `GRAFANA_PASSWORD` from `.env` (change it!)
- Prometheus: http://localhost:9090

The Prometheus datasource is provisioned automatically.

## What is scraped

| Job                   | Target           | Source                          |
|-----------------------|------------------|---------------------------------|
| `go-pulse`            | `execution:6060` | geth metrics                    |
| `lighthouse-beacon`   | `consensus:5054` | beacon node metrics             |
| `lighthouse-validator`| `validator:5064` | validator client metrics        |

## Dashboards to import

Import via Grafana → Dashboards → New → Import:

- **go-pulse (geth)**: the official geth dashboard JSON from
  <https://geth.ethereum.org/docs/monitoring/dashboards> works as-is.
- **Lighthouse beacon + validator**: dashboards from
  <https://github.com/sigp/lighthouse-metrics> (`dashboards/` directory) —
  `Summary.json` and `ValidatorClient.json` are the useful ones.

## What to alert on (if you add Alertmanager or Grafana alerts)

- Execution or beacon head not advancing for > 5 min
- Peer count < 5 on either client
- Validator: missed attestations, or the process simply not running
- Disk usage on `data/` > 85%
