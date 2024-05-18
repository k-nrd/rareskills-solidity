// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TrusterLenderPool} from "../src/TrusterLenderPool.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {TrusterLenderPoolAttacker} from "../src/TrusterLenderPoolAttacker.sol";

uint256 constant TOKENS_IN_POOL = 1000000 * 10 ** 18;

contract TrusterLenderPoolTest is Test {
    DamnValuableToken public token;
    TrusterLenderPool public pool;
    TrusterLenderPoolAttacker public attacker;
    address public player;

    function setUp() public {
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);
        player = address(1);
        attacker = new TrusterLenderPoolAttacker(player);

        token.transfer(address(pool), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    function test_Attack() public {
        attacker.attack(pool);
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
