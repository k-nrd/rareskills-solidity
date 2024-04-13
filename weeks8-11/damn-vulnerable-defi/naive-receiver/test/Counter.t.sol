// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NaiveReceiverLenderPool} from "../src/NaiveReceiverLenderPool.sol";
import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";

contract CounterTest is Test {
    uint256 constant ETHER_IN_POOL = 1_000 * 10 ** 18;
    uint256 constant ETHER_IN_RECEIVER = 10 * 10 * 18;

    NaiveReceiverLenderPool public pool;
    FlashLoanReceiver public receiver;
    address public player;

    function setUp() public {
        pool = new NaiveReceiverLenderPool();
        receiver = new FlashLoanReceiver();
        player = address(1);

        vm.deal(address(pool), ETHER_IN_POOL);
        vm.deal(address(receiver), ETHER_IN_RECEIVER);
    }

    function test_Attack() public {
        assertEq(address(receiver).balance, 0);
        assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
    }
}
