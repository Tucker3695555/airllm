# GTA Project — Refined Plan

*Working doc. Committed so the plan survives session resets. The original
project code lives locally at `C:\Users\Joseph\wokr1\pdai-project\` and still
needs to be pushed to its own GitHub repo from a local session.*

## Where this came from

Original concept: a GTA-themed play-to-earn web3 game plus a script pack for
the FiveM ("5M") script store, promoted by a YouTube channel, with a new
vanity-address token closely resembling OG pDAI, fully owner-held, targeting a
$1 peg maintained by in-game adoption.

## What was cut, and why

1. **Crypto inside FiveM scripts** — Cfx.re/FiveM (Rockstar-owned since 2023)
   permits monetization only via its approved store system and prohibits
   crypto/NFT integration. A web3 script pack cannot be approved and risks
   bans. Scripts and token must be separate products.
2. **The pDAI-lookalike token** — a near-copy of an existing token's identity
   has no upside without buyer confusion, and carries impersonation/scam-flag
   risk (auto-flagging by scanners, exchange blacklists). Replaced with an
   original token brand (if a token is kept at all).
3. **Owner-held supply + "$1 peg via adoption"** — a peg requires
   redeemability against collateral, not demand. 100% owner-held supply means
   the price is nominal until third-party liquidity exists. Replaced with:
   fair distribution, locked liquidity, floating price, player-to-player
   economy (rake model) instead of emissions.
4. **YouTube as token buy-pressure funnel** — undisclosed promotion of a
   held asset risks channel strikes (Take-Two is aggressive on crypto+GTA
   content), demonetization, and regulatory exposure. The channel stays
   clean content; any project mention is disclosed.

## The three lanes

### Lane 1 — FiveM script pack (revenue now)
- Build a quality script pack (RP/economy systems) for FiveM servers.
- Sell through the approved store path (Tebex) under Cfx.re monetization
  terms. No crypto components.
- Goal: real revenue in weeks/months, reputation before the GTA6 era.

### Lane 2 — YouTube channel (audience)
- GTA6-wave content: devlogs of the script pack, showcases, server economy
  design breakdowns.
- Monetize via ads/sponsors/memberships. No token promotion.
- Goal: distribution channel for every future product.

### Lane 3 — Standalone web3 game (long game, optional)
- Original IP, GTA-*vibe* only, zero Rockstar assets/branding. Multichain OK.
- Token (if kept): original name, fair launch, locked liquidity, no peg
  promises. Earning = player-to-player economy with a house rake, not
  emissions.
- Gate: only proceed if the game is fun with the token removed.

## Open decisions

- [ ] Which lane ships first (recommendation: Lane 1 + 2 together, Lane 3 later)
- [ ] Whether Lane 3 keeps a token at all, and its new name/brand
- [ ] What's actually inside the existing `pdai-complete-project` folder
      (audit once it's pushed from the local machine)

## Immediate next steps

1. From a local session on the home PC: push
   `C:\Users\Joseph\wokr1\pdai-project` to a new private GitHub repo.
2. Audit what's in it — salvage anything useful for Lanes 1–3.
3. Pick the first lane and scope a 2-week deliverable.
