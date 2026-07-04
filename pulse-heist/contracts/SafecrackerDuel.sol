// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SafecrackerDuel — a provably-fair 1v1 PLS duel on PulseChain
/// @notice Two players each stake the same amount of PLS. Each commits to a
///         secret up front (commit), then both reveal. The winner is decided by
///         keccak256(secretA, secretB) — a value NEITHER player can bias, because
///         each is locked into their commitment before seeing the other's secret.
///         The winner takes the pot minus a small, fixed, transparent rake.
///
/// Fairness properties:
///  - Commit-before-reveal: you pick your secret without knowing your opponent's,
///    so you cannot grind a secret that steers the outcome in your favor.
///  - Fully verifiable: anyone can recompute the winner from the two revealed
///    secrets (see verify/verify.js). The chain is the source of truth.
///  - No house RNG: the contract never generates randomness itself, so there is
///    no hidden seed the operator could manipulate.
///
/// Economy:
///  - Value flows player-to-player. The house only ever earns the rake (bps).
///  - The stake asset is native PLS, so every duel is real PulseChain volume.
///  - No minted game token, no emissions, no peg promises. Nothing to inflate.
contract SafecrackerDuel {
    // ----------------------------------------------------------------- config
    uint16 public constant MAX_RAKE_BPS = 500; // hard cap: rake can never exceed 5%
    uint16 public immutable rakeBps;           // e.g. 200 = 2%
    uint256 public immutable revealWindow;     // seconds each side has to reveal
    address public immutable treasury;         // where rake accrues

    // ------------------------------------------------------------------ state
    enum Status { Open, Locked, Settled, Refunded }

    struct Duel {
        address playerA;
        address playerB;
        uint128 stake;          // per-player stake; pot = 2 * stake
        uint64  revealDeadline; // set when the duel locks (both joined)
        Status  status;
        bytes32 commitA;
        bytes32 commitB;
        bytes32 secretA;        // 0 until revealed
        bytes32 secretB;        // 0 until revealed
        bool    revealedA;
        bool    revealedB;
    }

    uint256 public nextDuelId;
    mapping(uint256 => Duel) public duels;
    uint256 private _lock; // minimal reentrancy guard

    // ----------------------------------------------------------------- events
    event DuelCreated(uint256 indexed id, address indexed playerA, uint256 stake, bytes32 commitA);
    event DuelJoined(uint256 indexed id, address indexed playerB, uint64 revealDeadline, bytes32 commitB);
    event Revealed(uint256 indexed id, address indexed player, bytes32 secret);
    event DuelSettled(uint256 indexed id, address indexed winner, uint256 payout, uint256 rake);
    event DuelRefunded(uint256 indexed id);

    modifier nonReentrant() {
        require(_lock == 0, "reentrant");
        _lock = 1;
        _;
        _lock = 0;
    }

    constructor(uint16 _rakeBps, uint256 _revealWindow, address _treasury) {
        require(_rakeBps <= MAX_RAKE_BPS, "rake too high");
        require(_revealWindow >= 60, "reveal window too short");
        require(_treasury != address(0), "treasury=0");
        rakeBps = _rakeBps;
        revealWindow = _revealWindow;
        treasury = _treasury;
    }

    // ------------------------------------------------------------ commit phase

    /// @notice Open a duel by staking PLS and committing to a secret.
    /// @param commit keccak256(abi.encodePacked(secret)) for a random 32-byte secret.
    ///        Keep `secret` private until you reveal.
    function createDuel(bytes32 commit) external payable returns (uint256 id) {
        require(msg.value > 0, "stake=0");
        require(commit != bytes32(0), "empty commit");
        id = nextDuelId++;
        Duel storage d = duels[id];
        d.playerA = msg.sender;
        d.stake = uint128(msg.value);
        d.commitA = commit;
        d.status = Status.Open;
        emit DuelCreated(id, msg.sender, msg.value, commit);
    }

    /// @notice Join an open duel by matching the stake and committing your secret.
    function joinDuel(uint256 id, bytes32 commit) external payable {
        Duel storage d = duels[id];
        require(d.status == Status.Open, "not open");
        require(msg.sender != d.playerA, "cannot duel yourself");
        require(msg.value == d.stake, "stake mismatch");
        require(commit != bytes32(0), "empty commit");
        d.playerB = msg.sender;
        d.commitB = commit;
        d.status = Status.Locked;
        d.revealDeadline = uint64(block.timestamp + revealWindow);
        emit DuelJoined(id, msg.sender, d.revealDeadline, commit);
    }

    /// @notice Let the creator reclaim their stake if nobody joined.
    function cancelDuel(uint256 id) external nonReentrant {
        Duel storage d = duels[id];
        require(d.status == Status.Open, "not open");
        require(msg.sender == d.playerA, "only creator");
        d.status = Status.Refunded;
        _pay(d.playerA, d.stake);
        emit DuelRefunded(id);
    }

    // ------------------------------------------------------------ reveal phase

    /// @notice Reveal your secret. When both are revealed the duel auto-settles.
    function reveal(uint256 id, bytes32 secret) external nonReentrant {
        Duel storage d = duels[id];
        require(d.status == Status.Locked, "not locked");

        if (msg.sender == d.playerA) {
            require(!d.revealedA, "already revealed");
            require(keccak256(abi.encodePacked(secret)) == d.commitA, "bad secret");
            d.secretA = secret;
            d.revealedA = true;
        } else if (msg.sender == d.playerB) {
            require(!d.revealedB, "already revealed");
            require(keccak256(abi.encodePacked(secret)) == d.commitB, "bad secret");
            d.secretB = secret;
            d.revealedB = true;
        } else {
            revert("not a player");
        }
        emit Revealed(id, msg.sender, secret);

        if (d.revealedA && d.revealedB) {
            _settle(id, d);
        }
    }

    /// @notice If your opponent stalls past the deadline, claim the win.
    /// @dev Whoever revealed wins. If neither revealed, both are refunded (no rake).
    function claimTimeout(uint256 id) external nonReentrant {
        Duel storage d = duels[id];
        require(d.status == Status.Locked, "not locked");
        require(block.timestamp > d.revealDeadline, "not expired");

        if (d.revealedA && !d.revealedB) {
            _payout(id, d, d.playerA);
        } else if (d.revealedB && !d.revealedA) {
            _payout(id, d, d.playerB);
        } else {
            // neither revealed -> honest refund, no rake taken
            d.status = Status.Refunded;
            _pay(d.playerA, d.stake);
            _pay(d.playerB, d.stake);
            emit DuelRefunded(id);
        }
    }

    // ---------------------------------------------------------------- internal

    function _settle(uint256 id, Duel storage d) private {
        // The outcome bit neither player could predict at commit time.
        uint256 roll = uint256(keccak256(abi.encodePacked(d.secretA, d.secretB)));
        address winner = (roll & 1) == 0 ? d.playerA : d.playerB;
        _payout(id, d, winner);
    }

    function _payout(uint256 id, Duel storage d, address winner) private {
        d.status = Status.Settled; // effects before interactions
        uint256 pot = uint256(d.stake) * 2;
        uint256 rake = (pot * rakeBps) / 10_000;
        uint256 payout = pot - rake;
        if (rake > 0) _pay(treasury, rake);
        _pay(winner, payout);
        emit DuelSettled(id, winner, payout, rake);
    }

    function _pay(address to, uint256 amount) private {
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "transfer failed");
    }

    /// @notice Off-chain helper mirror: recompute the winner from two secrets.
    /// @dev Pure and public so anyone can verify a settled duel on-chain too.
    function winnerOf(address a, address b, bytes32 secretA, bytes32 secretB)
        external
        pure
        returns (address)
    {
        uint256 roll = uint256(keccak256(abi.encodePacked(secretA, secretB)));
        return (roll & 1) == 0 ? a : b;
    }
}
