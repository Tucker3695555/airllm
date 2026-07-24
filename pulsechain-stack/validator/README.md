# Running PulseChain Validators

A validator attests to and proposes blocks, earning PLS rewards. This guide
takes you from zero to an attesting validator using this repo's stack.

## What it costs / what you earn

- **32,000,000 PLS staked per validator** (deposited via the launchpad),
  plus a little extra PLS for the deposit transaction gas.
- Rewards: attestation + proposal rewards on the consensus layer, plus
  priority fees from proposed blocks paid to your `FEE_RECIPIENT` address.
- Penalties: small leaks for being offline; **slashing** (large loss +
  forced exit) only for provable double-signing — which in practice means
  running the same keys in two places. Don't do that and you won't be slashed.

**Do a full dry run on testnet v4 first** (`./setup.sh testnet`, testnet PLS
from <https://faucet.v4.testnet.pulsechain.com>). Same steps, zero risk.

## Prerequisites

1. A fully synced node from this stack (`docker compose up -d`, then
   `./scripts/health.sh` shows both clients SYNCED). Attesting through an
   unsynced node earns nothing.
2. 32M PLS per validator in a wallet you control.
3. A second, ideally offline, machine for key generation (mainnet).

## Step 1 — Generate keys (offline for mainnet)

```bash
./scripts/generate-keys.sh mainnet new     # or: testnet
```

This runs the official PulseChain `staking-deposit-cli`. It will:

- create a **24-word mnemonic** — write it on paper; it is the ONLY way to
  regenerate your keys or (if no withdrawal address is set) withdraw
- ask how many validators (you can add more later with
  `./scripts/generate-keys.sh mainnet existing`)
- ask for a keystore password (needed again at import)
- write to `./keys/validator_keys/`:
  - `keystore-m_12381_3600_*.json` — encrypted signing keys
  - `deposit_data-*.json` — public deposit info for the launchpad

If the CLI offers a withdrawal address option (`--eth1_withdrawal_address`),
set it to a cold wallet you control — check `./deposit.sh new-mnemonic --help`.
With it set, rewards/withdrawals sweep to that address automatically and the
mnemonic can never be used to redirect funds.

## Step 2 — Deposit via the launchpad

1. Go to <https://launchpad.pulsechain.com> and work through the checklist.
2. Upload your `deposit_data-*.json`.
3. Connect the wallet holding the PLS and send 32M PLS per validator.
4. Wait for activation. The deposit takes time to be processed by the beacon
   chain, then your validator joins the **activation queue** — track status at
   <https://beacon.pulsechain.com> (search your validator's public key).

Only ever deposit through the official launchpad. Verify the URL character by
character — fake launchpads are the main way people lose 32M PLS.

## Step 3 — Import keys into the validator client

On the node machine, with the keystores copied to `keys/validator_keys/`:

```bash
./scripts/import-keys.sh
```

Enter the keystore password when prompted. Keys land in `data/validator/`.

## Step 4 — Configure and start

In `.env`:

```bash
FEE_RECIPIENT=0xYourWalletAddress   # REQUIRED — priority fees go here
GRAFFITI=yourtag                    # optional, public, keep it boring
COMPOSE_PROFILES=validator
```

```bash
docker compose up -d
docker compose logs -f validator
```

Expected on first start: **doppelganger protection** deliberately sits out
2–3 epochs (~15–20 min) watching for your keys attesting elsewhere before it
starts signing. Missing a few epochs costs pennies; a double-sign costs
slashing. Leave it enabled.

## Step 5 — Verify it's working

- `./scripts/health.sh` — validator container up, no errors in recent logs
- `docker compose logs validator | grep -i "connected to beacon"`
- After activation: <https://beacon.pulsechain.com> shows your validator
  attesting each epoch with increasing balance
- Enable the `monitoring` profile for dashboards (see `monitoring/README.md`)

## Safety rules (the ones that actually matter)

1. **Never run the same keys on two machines.** Not "briefly", not "as a
   backup". This is the only realistic way to get slashed.
2. Migrating hosts: stop + **delete** keys on the old host, wait at least a
   full epoch, then import on the new host (keep doppelganger on).
3. Never restore `data/validator/` from an old backup — it contains the
   slashing-protection DB; an outdated one can make the client double-sign.
   Backup = mnemonic on paper + keystores. Not the datadir.
4. Mnemonic: paper, offline, never typed into an online machine again except
   to derive more keys (offline) or restore.
5. Keep clients updated (`./scripts/update.sh`) — hard forks with old
   clients = offline = leaking.

## Exiting a validator

To stop validating and unlock the stake (irreversible):

```bash
docker compose run --rm --no-deps validator \
  lighthouse account validator exit \
  --network pulsechain \
  --datadir /data \
  --beacon-node http://consensus:5052 \
  --keystore /data/validators/<validator-pubkey-dir>/<keystore>.json
```

The exit enters a queue; after it finalizes the balance is withdrawn to your
withdrawal address automatically.
