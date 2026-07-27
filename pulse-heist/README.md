# Pulse Heist — Safecracker Duel

A **provably-fair 1v1 game on PulseChain** where two players stake native **PLS**,
and a commit-reveal scheme neither side can bias decides who cracks the vault.
Winner takes the pot minus a small, transparent rake.

This is the clean, sustainable core we can build on: real asset, real volume,
verifiable fairness, and an economy that lasts because nothing is inflated.

## Why this design is honest (and durable)

| Property | How it's achieved |
|---|---|
| **Provably fair** | Outcome = `keccak256(secretA ++ secretB)`. Each player commits to their secret *before* seeing the other's, so no one can grind a favorable result. Anyone can recompute the winner from public data. |
| **No house RNG** | The contract never generates randomness, so there's no hidden seed an operator could rig. |
| **Sustainable economy** | Value flows player-to-player. The house earns *only* the rake — no minted token, no emissions, no peg to defend. It can't ponzi because there's nothing to inflate. |
| **Real PulseChain volume** | The stake asset is native PLS. Every duel moves `2 × stake` of PLS on-chain, so gameplay *is* PulseChain volume. |

## Repo layout

```
contracts/SafecrackerDuel.sol   the game (commit -> join -> reveal -> settle)
verify/verify.js                player-run fairness verifier (matches on-chain keccak)
sim/simulate.js                 economy simulation proving fairness + value conservation
test/SafecrackerDuel.t.sol      Foundry tests (settle, timeout, cancel, bad-secret)
foundry.toml                    build + PulseChain RPC config
```

## Try it now (no deploy needed)

```bash
cd pulse-heist
npm install            # installs js-sha3 (keccak, matches Solidity exactly)
node verify/verify.js  # runs a duel, verifies it, and shows tampering is caught
node sim/simulate.js   # 100k-duel economy sim: ~50/50 wins, value conserved
```

The simulation prints a **conservation check** (`netA + netB + rake == 0`) — that
single line is the difference between this and a ponzi: money is only ever
*moved*, never *minted*.

## How a duel works

1. **Commit** — Player A calls `createDuel(commit)` with PLS, where
   `commit = keccak256(secret)` for a private random 32-byte secret.
2. **Join** — Player B matches the stake and commits their own secret.
3. **Reveal** — Both call `reveal(secret)`. The contract checks each secret
   against its commitment, then settles automatically.
4. **Settle** — `winner = keccak256(secretA ++ secretB) & 1 ? B : A`.
   Winner gets `pot − rake`; rake goes to the treasury.

Anti-grief: if an opponent stalls, `claimTimeout` awards the pot to whoever
revealed. If neither reveals, both are refunded with **no rake taken**.

## Deploying to PulseChain (when you're ready)

```bash
forge build
forge test                       # run the test suite
forge create contracts/SafecrackerDuel.sol:SafecrackerDuel \
  --rpc-url pulsechain \
  --constructor-args 200 3600 <TREASURY_ADDRESS> \
  --private-key <KEY>            # 200 = 2% rake, 3600 = 1h reveal window
```

Your existing CREATE2 vanity miner works here too — deploy this contract to a
clean vanity address under **its own** brand.

## ⚠️ The legal reality — read this before mainnet

The *code* is neutral, but a game where players stake money on a chance outcome
is, in most jurisdictions, **gambling** — and that's regulated regardless of the
blockchain. Being genuinely "totally legal" means picking one of these lanes on
purpose:

- **Free-to-play / social:** stakes are a non-cashable in-game credit, not PLS
  with real value. Widely legal, no license. (You lose the real-volume angle.)
- **Skill-based competition:** restructure so outcomes depend on player skill,
  not pure chance — many jurisdictions treat skill contests differently from
  gambling. Requires a real design change, not just a label.
- **Licensed real-money wagering:** keep PLS stakes, but obtain a gambling
  license, geoblock restricted regions, and run KYC/AML. This is the path that
  makes PLS-volume legal, and it's a real compliance project — talk to a
  gaming/crypto lawyer in your target markets *before* launch.

Don't skip this step. "It's on-chain" is not a legal defense. Pick a lane, and
if you want real-money PLS play, budget for the license and legal review — that's
the difference between a business and a lawsuit.

## What's next

- Decide the legal lane above (this drives everything).
- Add a game mode with more depth (best-of-N, tournaments with a prize pool +
  rake, or a skill layer) so it's *fun*, not just fair.
- Build a minimal web frontend (connect wallet, create/join/reveal, live verify).
- Deploy to PulseChain testnet, run real duels, iterate.
