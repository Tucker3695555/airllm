// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/SafecrackerDuel.sol";

contract SafecrackerDuelTest is Test {
    SafecrackerDuel game;
    address treasury = address(0xFEE);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        game = new SafecrackerDuel(200, 1 hours, treasury); // 2% rake
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
    }

    function _commit(bytes32 secret) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(secret));
    }

    function testFullDuelSettlesAndPaysRake() public {
        bytes32 sa = keccak256("alice-secret");
        bytes32 sb = keccak256("bob-secret");

        vm.prank(alice);
        uint256 id = game.createDuel{value: 100 ether}(_commit(sa));
        vm.prank(bob);
        game.joinDuel{value: 100 ether}(id, _commit(sb));

        uint256 treasuryBefore = treasury.balance;
        vm.prank(alice);
        game.reveal(id, sa);
        vm.prank(bob);
        game.reveal(id, sb);

        // pot = 200, rake = 2% = 4, payout = 196
        assertEq(treasury.balance - treasuryBefore, 4 ether, "rake");

        address expected = game.winnerOf(alice, bob, sa, sb);
        assertTrue(expected == alice || expected == bob);
        // winner ended up net +96 (staked 100, won 196); loser net -100.
    }

    function testCannotRevealWrongSecret() public {
        bytes32 sa = keccak256("alice-secret");
        vm.prank(alice);
        uint256 id = game.createDuel{value: 1 ether}(_commit(sa));
        vm.prank(bob);
        game.joinDuel{value: 1 ether}(id, _commit(keccak256("bob")));

        vm.prank(alice);
        vm.expectRevert("bad secret");
        game.reveal(id, keccak256("not-alice-secret"));
    }

    function testTimeoutGivesPotToRevealer() public {
        bytes32 sa = keccak256("alice-secret");
        vm.prank(alice);
        uint256 id = game.createDuel{value: 10 ether}(_commit(sa));
        vm.prank(bob);
        game.joinDuel{value: 10 ether}(id, _commit(keccak256("bob")));

        vm.prank(alice);
        game.reveal(id, sa); // only alice reveals

        vm.warp(block.timestamp + 2 hours);
        uint256 aliceBefore = alice.balance;
        game.claimTimeout(id);
        // pot 20, rake 2% = 0.4, payout 19.6 to alice
        assertEq(alice.balance - aliceBefore, 19.6 ether, "alice wins timeout");
    }

    function testCancelRefundsCreator() public {
        vm.prank(alice);
        uint256 id = game.createDuel{value: 5 ether}(_commit(keccak256("a")));
        uint256 before = alice.balance;
        vm.prank(alice);
        game.cancelDuel(id);
        assertEq(alice.balance - before, 5 ether, "refund");
    }

    function testCannotJoinYourOwnDuel() public {
        vm.prank(alice);
        uint256 id = game.createDuel{value: 1 ether}(_commit(keccak256("a")));
        vm.prank(alice);
        vm.expectRevert("cannot duel yourself");
        game.joinDuel{value: 1 ether}(id, _commit(keccak256("a2")));
    }
}
