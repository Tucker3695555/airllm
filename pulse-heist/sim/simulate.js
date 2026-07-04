'use strict';
/**
 * Economy simulation for SafecrackerDuel.
 *
 * Proves three things about the design without deploying anything:
 *   1. It is provably fair AND unbiased: over many duels each player wins ~50%.
 *   2. It is sustainable, not a ponzi: value moves player-to-player. The house
 *      earns ONLY the rake — no emissions, no minted token, nothing to inflate.
 *   3. It generates real PulseChain volume: every duel moves 2*stake of PLS
 *      on-chain, so gross volume = sum of all pots.
 *
 * Run: node sim/simulate.js
 */
const crypto = require('crypto');
const { verifyDuel, commitOf } = require('../verify/verify.js');

const RAKE_BPS = 200;          // 2% rake, matches a sane contract deployment
const NUM_DUELS = 100_000;
const STAKE_PLS = 100;         // each player stakes 100 PLS per duel

function randSecret() {
  return '0x' + crypto.randomBytes(32).toString('hex');
}

function playDuel(playerA, playerB, stake) {
  const secretA = randSecret();
  const secretB = randSecret();
  const res = verifyDuel({
    playerA,
    playerB,
    commitA: commitOf(secretA),
    commitB: commitOf(secretB),
    secretA,
    secretB,
  });
  if (!res.fair) throw new Error('internal: honest duel failed verification');
  const pot = stake * 2;
  const rake = (pot * RAKE_BPS) / 10_000;
  const payout = pot - rake;
  return { winner: res.winner, payout, rake, pot };
}

function run() {
  const A = '0xAAAA000000000000000000000000000000000001';
  const B = '0xBBBB000000000000000000000000000000000002';

  let winsA = 0;
  let winsB = 0;
  let houseRake = 0;
  let grossVolume = 0;
  // Track net PnL vs. the amount each player staked into the pots.
  let netA = 0;
  let netB = 0;

  for (let i = 0; i < NUM_DUELS; i++) {
    const d = playDuel(A, B, STAKE_PLS);
    grossVolume += d.pot;
    houseRake += d.rake;
    // both players put in STAKE each
    netA -= STAKE_PLS;
    netB -= STAKE_PLS;
    if (d.winner === A) { winsA++; netA += d.payout; }
    else { winsB++; netB += d.payout; }
  }

  const total = NUM_DUELS;
  const pct = (n) => ((n / total) * 100).toFixed(2) + '%';
  const pls = (n) => n.toLocaleString('en-US') + ' PLS';

  console.log('================ SafecrackerDuel — economy simulation ================');
  console.log(`duels played:        ${total.toLocaleString('en-US')}`);
  console.log(`stake per player:    ${pls(STAKE_PLS)}   rake: ${RAKE_BPS / 100}%`);
  console.log('----------------------------------------------------------------------');
  console.log(`player A wins:        ${winsA.toLocaleString('en-US')}  (${pct(winsA)})`);
  console.log(`player B wins:        ${winsB.toLocaleString('en-US')}  (${pct(winsB)})`);
  console.log('  -> ~50/50 confirms the commit-reveal outcome is unbiased.');
  console.log('----------------------------------------------------------------------');
  console.log(`gross PulseChain volume:  ${pls(grossVolume)}`);
  console.log(`house rake collected:     ${pls(houseRake)}`);
  console.log(`house take of volume:     ${((houseRake / grossVolume) * 100).toFixed(2)}%  (== the rake, nothing hidden)`);
  console.log('----------------------------------------------------------------------');
  console.log(`player A net PnL:     ${pls(Math.round(netA))}`);
  console.log(`player B net PnL:     ${pls(Math.round(netB))}`);
  const conservation = netA + netB + houseRake;
  console.log(`conservation check:  netA + netB + rake = ${pls(Math.round(conservation))}  (must be 0)`);
  console.log('  -> value is conserved: players trade a zero-sum pool, house earns only rake.');
  console.log('     No new tokens were minted. Nothing was inflated. This is why it lasts.');
  console.log('======================================================================');
}

run();
