'use strict';
/**
 * Provably-fair RNG engine for an in-game (fake-money) casino.
 *
 * This is the industry-standard serverSeed / clientSeed / nonce model used by
 * major provably-fair casinos. It needs NO blockchain and NO oracle — it works
 * inside a game server (e.g. a GTA/FiveM roleplay server) using the server's
 * own in-game currency.
 *
 * Why it's fair (the guarantee, precisely stated):
 *   - Before any bet, the server publishes  commitment = sha256(serverSeed).
 *     The server is now LOCKED IN — it cannot change serverSeed later without
 *     the commitment failing to match.
 *   - The PLAYER chooses clientSeed (any string) AFTER seeing the commitment.
 *     So the server cannot have precomputed outcomes for this player.
 *   - Each bet uses an incrementing nonce, so every roll is a fresh PRF output.
 *   - outcome = HMAC_SHA256(key = serverSeed, msg = `${clientSeed}:${nonce}`).
 *   - When the seed is rotated, the server REVEALS serverSeed. The player runs
 *     verify() to (a) confirm sha256(serverSeed) == the commitment they saw, and
 *     (b) recompute every roll. If it all matches, the house never cheated.
 *
 * "Is it real randomness?" From the player's perspective, yes: serverSeed comes
 * from a CSPRNG (crypto.randomBytes) and HMAC-SHA256 is a pseudo-random function,
 * so outputs are indistinguishable from uniform random — AND neither party can
 * bias them. That combination (unpredictable + unbiasable + auditable) is exactly
 * what "provably fair" means. It is deterministic given the seeds, which is the
 * whole point: determinism is what lets the player re-verify.
 */
const crypto = require('crypto');

function newServerSeed() {
  return crypto.randomBytes(32).toString('hex');
}

function commitment(serverSeed) {
  return crypto.createHash('sha256').update(serverSeed).digest('hex');
}

/**
 * Deterministic per-bet HMAC. Returns the raw hex digest.
 */
function rollHex(serverSeed, clientSeed, nonce) {
  return crypto
    .createHmac('sha256', serverSeed)
    .update(`${clientSeed}:${nonce}`)
    .digest('hex');
}

/**
 * Convert an HMAC digest to a uniform float in [0, 1).
 * Uses the first 8 hex chars (32 bits) -> divide by 2^32. Standard approach.
 */
function toUnitFloat(hex) {
  const slice = hex.slice(0, 8);
  return parseInt(slice, 16) / 0x100000000;
}

/**
 * Uniform integer in [0, max) with no modulo bias, by rejection sampling
 * across successive 32-bit windows of the digest.
 */
function toIntBelow(hex, max) {
  if (max <= 0) throw new Error('max must be positive');
  const limit = Math.floor(0x100000000 / max) * max; // largest multiple of max <= 2^32
  for (let i = 0; i + 8 <= hex.length; i += 8) {
    const x = parseInt(hex.slice(i, i + 8), 16);
    if (x < limit) return x % max;
  }
  // Extremely unlikely fallback: fold the whole digest.
  return parseInt(hex.slice(0, 8), 16) % max;
}

module.exports = {
  newServerSeed,
  commitment,
  rollHex,
  toUnitFloat,
  toIntBelow,
};
