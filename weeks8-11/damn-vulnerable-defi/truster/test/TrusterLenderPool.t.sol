// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {TrusterLenderPool} from "../src/TrusterLenderPool.sol";

uint256 constant TOKENS_IN_POOL = 1000000 * 10 ** 18;

contract TrusterLenderPoolTest is Test {
    DamnValuableToken public token;
    TrusterLenderPool public pool;
    address public player;

    function setUp() public {
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(address(token));
        player = address(1);

        token.transfer(address(pool), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    function test_Attack() public {
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
