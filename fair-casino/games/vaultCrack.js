'use strict';
/**
 * "Vault Crack" — a dice-style game for an in-game casino.
 *
 * The player picks a target chance (e.g. 49.5%). A roll in [0, 100) is drawn
 * from the provably-fair engine. If roll < target, they crack the vault and win
 * their bet times the payout multiplier. The multiplier is set so the house has
 * a small, fixed, DISCLOSED edge — exactly like a real casino, except every roll
 * is verifiable and the currency is fake in-game money.
 *
 *   winChance   = target / 100
 *   fairPayout  = 1 / winChance           (0% house edge)
 *   payout      = fairPayout * (1 - edge) (house keeps `edge`)
 */
const { rollHex, toIntBelow } = require('../server/provablyFair.js');

const PRECISION = 10000; // roll resolution: 0.0000 .. 99.9999

/** Draw a roll in [0, 100) for a given seed triple. */
function rollValue(serverSeed, clientSeed, nonce) {
  const hex = rollHex(serverSeed, clientSeed, nonce);
  return toIntBelow(hex, PRECISION) / (PRECISION / 100); // -> [0, 100)
}

/**
 * Settle one bet.
 * @param {object} p
 * @param {number} p.target      win if roll < target (0 < target < 100)
 * @param {number} p.bet         wager in in-game currency
 * @param {number} p.houseEdge   e.g. 0.02 for 2%
 */
function settle({ serverSeed, clientSeed, nonce, target, bet, houseEdge }) {
  if (!(target > 0 && target < 100)) throw new Error('target must be in (0,100)');
  const roll = rollValue(serverSeed, clientSeed, nonce);
  const won = roll < target;
  const winChance = target / 100;
  const multiplier = (1 / winChance) * (1 - houseEdge);
  const payout = won ? +(bet * multiplier).toFixed(4) : 0;
  return { roll: +roll.toFixed(4), won, multiplier: +multiplier.toFixed(4), payout, nonce };
}

module.exports = { settle, rollValue, PRECISION };
