# Fair Casino — provably-fair in-game casino engine

A drop-in **provably-fair RNG** for a GTA/FiveM-style server casino that runs on
the server's **own in-game (fake) currency** — no blockchain, no oracle, no
crypto. "Provably fair" is the *selling point*: server owners and players can
both verify the house never rigged a roll.

> This is Lane 1 (a clean, sellable script), deliberately **separate** from the
> web3 game. It contains no cryptocurrency and must stay that way to be
> allowed on the Cfx.re/FiveM store.

## The randomness model (and its honest guarantees)

Uses the standard **serverSeed / clientSeed / nonce** scheme (HMAC-SHA256):

1. Server generates `serverSeed` from a CSPRNG and publishes
   `commitment = sha256(serverSeed)` **before** any bet. Now it's locked in.
2. Player picks a `clientSeed` (any string) **after** seeing the commitment, so
   the house can't have precomputed this player's outcomes.
3. Each bet: `outcome = HMAC_SHA256(serverSeed, "clientSeed:nonce")`, nonce++.
4. On seed rotation the server **reveals** `serverSeed`; the player runs the
   verifier to confirm the commitment matches and recompute every roll.

**Is it "real" randomness?** From the player's side, yes: `serverSeed` is
CSPRNG entropy and HMAC-SHA256 is a PRF, so outputs are indistinguishable from
uniform — *and* neither side can bias them. It's deterministic given the seeds
**on purpose**: determinism is what lets a player re-verify. That trio —
unpredictable + unbiasable + auditable — is what "provably fair" actually means.

This differs from the on-chain PvP game (`../pulse-heist`), which uses
commit-reveal because there the two players are the entropy source. Different
setting, different tool.

## Files

```
server/provablyFair.js   the RNG engine (seeds, commitment, HMAC rolls, unbiased ints)
games/vaultCrack.js      a dice-style game with a fixed, disclosed house edge
verify/verify.js         player-run session verifier (+ demo, catches tampering)
sim/houseEdge.js         proves the real edge == the disclosed edge
```

## Run it

```bash
cd fair-casino
node verify/verify.js    # plays a session, verifies it, shows tampering caught
node sim/houseEdge.js    # 500k bets: measured edge converges to disclosed edge
```

## Porting to a live FiveM server

FiveM resources are Lua (or JS via Node). This JS is the **reference engine** —
the HMAC-SHA256 logic ports directly to a Lua resource using any SHA-2 library.
Keep the exact same seed/nonce flow so the JS verifier here still validates rolls
your Lua server produced. Expose a `/verify` command in-game that hands players
their commitment, seeds, and nonces so they can self-audit.

## Keeping it sellable (and legal)

- **In-game currency only.** No PLS, no tokens, no real-money value. That's what
  keeps it inside Cfx.re/FiveM rules and out of gambling regulation.
- **Monetize through the approved store** (Tebex), like any other paid script.
- **Provably-fair as marketing:** advertise the `/verify` feature — trustworthy
  casinos are a real differentiator for RP server owners.

## Next

- Add more games on the same engine (roulette, blackjack shuffle, crash/limbo).
- Build the Lua FiveM resource + an in-game `/verify` command.
- A tiny web page where players paste their seeds and see the recompute.
