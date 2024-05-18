// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DamnValuableTokenSnapshot} from "../src/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../src/SimpleGovernance.sol";
import {SelfiePool} from "../src/SelfiePool.sol";

import {SelfiePoolAttacker} from "../src/solution/SelfiePoolAttacker.sol";

contract SelfiePoolChallenge is Test {
    uint256 public constant TOKEN_INITIAL_SUPPLY = 2_000_000 ether;
    uint256 public constant TOKENS_IN_POOL = 1_500_000 ether;

    DamnValuableTokenSnapshot public token;
    SimpleGovernance public governance;
    SelfiePool public pool;

    SelfiePoolAttacker public attacker;

    function setUp() public {
        token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        governance = new SimpleGovernance(address(token));
        pool = new SelfiePool(address(token), address(governance));

        attacker = new SelfiePoolAttacker(pool, governance, token);

        token.transfer(address(pool), TOKENS_IN_POOL);
        token.snapshot();

        assertEq(governance.getActionCounter(), 1);
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    function test_Attack() public {
        attacker.prepare();
        // Wait
        vm.warp(block.timestamp + 2 days);
        attacker.attack();

        // Success conditions
        assertEq(token.balanceOf(address(attacker)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
