'use strict';
/**
 * Player-run verifier for the Vault Crack casino.
 *
 * After the server rotates and REVEALS its serverSeed, a player runs this with:
 *   - the commitment they were shown BEFORE betting  (sha256 of serverSeed)
 *   - the revealed serverSeed
 *   - their clientSeed
 *   - the list of bets they made (nonce, target, bet)
 *
 * It confirms:
 *   1. sha256(serverSeed) === commitment   -> the house didn't swap seeds
 *   2. every roll recomputes to what they were paid on
 *
 * If both pass, the house provably did not cheat. If the commitment fails, the
 * house tampered — walk away.
 */
const crypto = require('crypto');
const { commitment } = require('../server/provablyFair.js');
const { settle } = require('../games/vaultCrack.js');

function verifySession({ shownCommitment, serverSeed, clientSeed, bets, houseEdge }) {
  const recomputed = commitment(serverSeed);
  const seedOk = recomputed === shownCommitment;

  const rows = bets.map((b) => {
    const r = settle({ serverSeed, clientSeed, nonce: b.nonce, target: b.target, bet: b.bet, houseEdge });
    const matchesPaid = b.paidPayout === undefined ? null : Math.abs(b.paidPayout - r.payout) < 1e-6;
    return { ...r, target: b.target, bet: b.bet, matchesPaid };
  });

  const allPaymentsMatch = rows.every((r) => r.matchesPaid === null || r.matchesPaid === true);
  return { seedOk, recomputed, allPaymentsMatch, rows };
}

module.exports = { verifySession };

if (require.main === module) {
  // End-to-end demo: play a session honestly, then verify it, then prove tampering fails.
  const { newServerSeed } = require('../server/provablyFair.js');
  const houseEdge = 0.02;

  const serverSeed = newServerSeed();
  const shownCommitment = commitment(serverSeed); // published BEFORE bets
  const clientSeed = 'joseph-picks-this-' + crypto.randomBytes(3).toString('hex');

  const bets = [
    { nonce: 0, target: 49.5, bet: 100 },
    { nonce: 1, target: 20.0, bet: 250 },
    { nonce: 2, target: 90.0, bet: 50 },
    { nonce: 3, target: 5.0, bet: 500 },
  ].map((b) => ({ ...b, paidPayout: settle({ serverSeed, clientSeed, ...b, houseEdge }).payout }));

  console.log('=== Vault Crack — session verification ===');
  console.log('commitment shown before betting:', shownCommitment.slice(0, 24) + '...');
  console.log('clientSeed (player chose):      ', clientSeed);
  console.log('serverSeed (revealed after):    ', serverSeed.slice(0, 24) + '...\n');

  const res = verifySession({ shownCommitment, serverSeed, clientSeed, bets, houseEdge });
  res.rows.forEach((r) =>
    console.log(
      `  nonce ${r.nonce}: target<${r.target}%  roll=${r.roll.toFixed(2)}  ` +
        `${r.won ? 'WIN ' : 'lose'}  paid=${r.payout}  verified=${r.matchesPaid}`
    )
  );
  console.log(`\n  seed commitment matches? ${res.seedOk}`);
  console.log(`  all payouts recompute?   ${res.allPaymentsMatch}`);

  // Tamper: house tries to reveal a DIFFERENT serverSeed to fake a loss into a win.
  const fakeSeed = newServerSeed();
  const tampered = verifySession({ shownCommitment, serverSeed: fakeSeed, clientSeed, bets, houseEdge });
  console.log(`\n  tamper test (house swaps serverSeed): seed matches? ${tampered.seedOk}  <- must be false`);
}
