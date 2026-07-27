'use strict';
/**
 * Provably-fair verifier for SafecrackerDuel.
 *
 * Anyone — winner or loser — can run this to confirm the duel result was NOT
 * tampered with. It reproduces the exact keccak256 math the smart contract runs
 * on-chain, so if the numbers here match the chain, the game was fair. Period.
 *
 * Inputs come straight from the chain's public events/state:
 *   - playerA, playerB       (addresses, from DuelCreated / DuelJoined)
 *   - commitA, commitB        (from DuelCreated / DuelJoined)
 *   - secretA, secretB        (from the two Revealed events)
 *
 * Checks performed:
 *   1. keccak256(secretA) === commitA   -> A couldn't swap their secret after the fact
 *   2. keccak256(secretB) === commitB   -> B couldn't either
 *   3. winner = keccak256(secretA ++ secretB) & 1 ? B : A
 */
const { keccak256 } = require('js-sha3');

function hexToBytes(hex) {
  const h = hex.startsWith('0x') ? hex.slice(2) : hex;
  if (h.length % 2 !== 0) throw new Error(`odd-length hex: ${hex}`);
  const out = Buffer.alloc(h.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(h.substr(i * 2, 2), 16);
  return out;
}

// keccak256(abi.encodePacked(bytes32 x)) — hash of the raw 32 bytes.
function commitOf(secretHex) {
  const b = hexToBytes(secretHex);
  if (b.length !== 32) throw new Error('secret must be 32 bytes');
  return '0x' + keccak256(b);
}

// keccak256(abi.encodePacked(bytes32 a, bytes32 b)) — hash of the 64-byte concat.
function rollOf(secretAHex, secretBHex) {
  const a = hexToBytes(secretAHex);
  const b = hexToBytes(secretBHex);
  if (a.length !== 32 || b.length !== 32) throw new Error('secrets must be 32 bytes');
  return '0x' + keccak256(Buffer.concat([a, b]));
}

/** Returns { fair, winner, reasons[] } exactly as the contract would settle. */
function verifyDuel({ playerA, playerB, commitA, commitB, secretA, secretB }) {
  const reasons = [];
  const gotCommitA = commitOf(secretA);
  const gotCommitB = commitOf(secretB);
  const okA = gotCommitA.toLowerCase() === commitA.toLowerCase();
  const okB = gotCommitB.toLowerCase() === commitB.toLowerCase();
  reasons.push(`commitA ${okA ? 'OK' : 'MISMATCH'}: keccak256(secretA)=${gotCommitA} vs on-chain ${commitA}`);
  reasons.push(`commitB ${okB ? 'OK' : 'MISMATCH'}: keccak256(secretB)=${gotCommitB} vs on-chain ${commitB}`);

  const roll = rollOf(secretA, secretB);
  // roll & 1: look at the last hex nibble's low bit.
  const lastNibble = parseInt(roll.slice(-1), 16);
  const bit = lastNibble & 1;
  const winner = bit === 0 ? playerA : playerB;
  reasons.push(`roll = keccak256(secretA ++ secretB) = ${roll}`);
  reasons.push(`roll & 1 = ${bit} -> winner is ${bit === 0 ? 'playerA' : 'playerB'} (${winner})`);

  return { fair: okA && okB, winner, roll, reasons };
}

module.exports = { verifyDuel, commitOf, rollOf, hexToBytes };

// CLI demo when run directly.
if (require.main === module) {
  const crypto = require('crypto');
  const secretA = '0x' + crypto.randomBytes(32).toString('hex');
  const secretB = '0x' + crypto.randomBytes(32).toString('hex');
  const duel = {
    playerA: '0xAAAA000000000000000000000000000000000001',
    playerB: '0xBBBB000000000000000000000000000000000002',
    commitA: commitOf(secretA),
    commitB: commitOf(secretB),
    secretA,
    secretB,
  };
  const res = verifyDuel(duel);
  console.log('=== SafecrackerDuel fairness check ===');
  res.reasons.forEach((r) => console.log('  ' + r));
  console.log(`\n  fair? ${res.fair}`);
  console.log(`  winner: ${res.winner}`);

  // Show that a loser CANNOT forge a secret: any tampered secret fails commit check.
  const tampered = { ...duel, secretA: '0x' + crypto.randomBytes(32).toString('hex') };
  console.log(`\n  tamper test (loser swaps their secret): fair? ${verifyDuel(tampered).fair}  <- must be false`);
}
