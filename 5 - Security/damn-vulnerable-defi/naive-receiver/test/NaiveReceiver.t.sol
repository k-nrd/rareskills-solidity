// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NaiveReceiverLenderPool} from "../src/NaiveReceiverLenderPool.sol";
import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";
import {NaiveReceiverAttacker} from "../src/NaiveReceiverAttacker.sol";

contract NaiveReceiverTest is Test {
    uint256 constant ETHER_IN_POOL = 1_000 ether;
    uint256 constant ETHER_IN_RECEIVER = 10 ether;

    NaiveReceiverLenderPool public pool;
    FlashLoanReceiver public receiver;
    NaiveReceiverAttacker public attacker;

    function setUp() public {
        pool = new NaiveReceiverLenderPool();
        receiver = new FlashLoanReceiver(address(pool));
        attacker = new NaiveReceiverAttacker();

        vm.deal(address(pool), ETHER_IN_POOL);
        vm.deal(address(receiver), ETHER_IN_RECEIVER);
    }

    function test_Attack() public {
        attacker.attack(pool, receiver);
        assertEq(address(receiver).balance, 0);
        assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
    }
}
