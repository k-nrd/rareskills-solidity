// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FlashLoanerPool} from "../src/FlashLoanerPool.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {TheRewarderPool} from "../src/TheRewarderPool.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {AccountingToken} from "../src/AccountingToken.sol";
import {TheRewarderAttacker} from "../src/TheRewarderAttacker.sol";

contract TheRewarderAttackerTest is Test {
    uint256 constant TOKENS_IN_LENDER_POOL = 1_000_000 ether;
    uint256 constant DEPOSIT_AMOUNT = 100 ether;

    address[4] public users = [address(1), address(2), address(3), address(4)];

    DamnValuableToken public dvt;
    FlashLoanerPool public flashLoanerPool;
    TheRewarderPool public rewarderPool;
    AccountingToken public accountingToken;
    RewardToken public rewardToken;

    TheRewarderAttacker public attacker;

    function setUp() public {
        dvt = new DamnValuableToken();
        flashLoanerPool = new FlashLoanerPool(address(dvt));

        rewarderPool = new TheRewarderPool(address(dvt));
        rewardToken = rewarderPool.rewardToken();
        accountingToken = rewarderPool.accountingToken();

        // Check roles in accounting token
        assertEq(accountingToken.owner(), address(rewarderPool));
        assertTrue(
            accountingToken.hasAllRoles(
                address(rewarderPool),
                accountingToken.MINTER_ROLE() | accountingToken.SNAPSHOT_ROLE() | accountingToken.BURNER_ROLE()
            )
        );

        attacker = new TheRewarderAttacker();

        dvt.transfer(address(flashLoanerPool), TOKENS_IN_LENDER_POOL);

        // Alice, Bob, Charlie and David deposit tokens
        for (uint256 i = 0; i < users.length; i++) {
            dvt.transfer(users[i], DEPOSIT_AMOUNT);

            vm.startPrank(users[i]);
            dvt.approve(address(rewarderPool), DEPOSIT_AMOUNT);
            rewarderPool.deposit(DEPOSIT_AMOUNT);
            vm.stopPrank();

            // User has the corresponding accounting tokens
            assertEq(accountingToken.balanceOf(users[i]), DEPOSIT_AMOUNT);
        }

        // Advance time 5 days so that depositors can get rewards
        vm.warp(block.timestamp + 5 days);

        // Each depositor gets reward tokens
        uint256 rewardsInRound = rewarderPool.REWARDS();
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            rewarderPool.distributeRewards();
            assertEq(rewardToken.balanceOf(users[i]), rewardsInRound / users.length);
        }
        assertEq(accountingToken.totalSupply(), DEPOSIT_AMOUNT * users.length);
        assertEq(rewardToken.totalSupply(), rewardsInRound);
        // Player starts with zero DVT tokens in balance
        assertEq(dvt.balanceOf(address(attacker)), 0);
        // Two rounds must have occurred so far
        assertEq(rewarderPool.roundNumber(), 2);
    }

    function test_Attack() public {
        // Success conditions
        assertEq(rewarderPool.roundNumber(), 3);
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            rewarderPool.distributeRewards();
            uint256 userRewards = rewardToken.balanceOf(users[i]);
            uint256 delta = userRewards - rewarderPool.REWARDS() / users.length;
            assertLt(delta, 10 ** 16);
        }

        assertGt(rewardToken.totalSupply(), rewarderPool.REWARDS());
        uint256 attackerRewards = rewardToken.balanceOf(address(attacker));
        assertGt(attackerRewards, 0);
        assertLt(rewarderPool.REWARDS() - attackerRewards, 10 ** 17);
        assertEq(dvt.balanceOf(address(attacker)), 0);
        assertEq(dvt.balanceOf(address(flashLoanerPool)), TOKENS_IN_LENDER_POOL);
    }
}
