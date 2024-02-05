// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Pair} from "../src/Pair.sol";
import {MockERC20} from "./MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract PairTest is Test {
    using FixedPointMathLib for uint256;

    Pair pair;
    MockERC20 token0;
    MockERC20 token1;
    uint256 swapFeeBasisPoints = 30; // 0.3%
    uint256 loanFeeBasisPoints = 50; // 0.5%

    address alice = address(1);
    address bob = address(2);

    function setUp() public {
        token0 = new MockERC20("Token0", "TKN0");
        token1 = new MockERC20("Token1", "TKN1");

        pair = new Pair(
            "Pair Token",
            "PAIR",
            address(token0),
            address(token1),
            uint128(swapFeeBasisPoints),
            uint128(loanFeeBasisPoints)
        );

        token0.mint(alice, 10e18);
        token1.mint(alice, 10e18);
        token0.mint(bob, 6e18);
        token1.mint(bob, 6e18);

        vm.startPrank(alice);
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
        vm.stopPrank();
    }

    function testDeposit() public {
        uint256 token0Amount = 1e18;
        uint256 token1Amount = 2e18;
        vm.prank(alice);
        pair.deposit(alice, token0Amount, token1Amount, 0);

        // Check pair reserves
        uint256 balance0 = token0.balanceOf(address(pair));
        uint256 balance1 = token1.balanceOf(address(pair));
        assertEq(balance0, token0Amount);
        assertEq(balance1, token1Amount);

        // Check LP token balance
        uint256 expectedLPTokens = (token0Amount * token1Amount).sqrt() - 1e3; // MINIMUM_SHARES = 1000
        assertEq(pair.balanceOf(alice), expectedLPTokens);
    }

    function testSwap() public {
        // 10 times more token1s in the contract now, price is 1/10 or 10/1
        uint256 token0Amount = 5e17;
        uint256 token1Amount = 5e18;
        vm.prank(bob);
        pair.deposit(bob, token0Amount, token1Amount, 0);

        // Check pair reserves
        uint256 balance0 = token0.balanceOf(address(pair));
        uint256 balance1 = token1.balanceOf(address(pair));
        assertEq(balance0, token0Amount);
        assertEq(balance1, token1Amount);

        // 0.1 Token0 should be equal to 1 Token1 - fee
        // Since we're dealing with easy numbers, our rounding should work fine here
        uint256 swapAmount = 1e17;
        uint256 currentPrice = token1Amount.fullMulDiv(swapAmount, token0Amount);
        uint256 expectedOutputAmount =
            currentPrice - currentPrice.fullMulDivUp(swapFeeBasisPoints, 1e4);
        vm.prank(bob);
        pair.swap(bob, true, swapAmount, expectedOutputAmount);

        // After the swap, we expect the pair's token0 balance to have increased by swapAmount,
        // and token1 balance decreased by expectedOutputAmount
        uint256 pairToken0Balance = token0.balanceOf(address(pair));
        uint256 pairToken1Balance = token1.balanceOf(address(pair));

        // Asserting the expected balances
        assertEq(pairToken0Balance, token0Amount + swapAmount);
        assertEq(pairToken1Balance, token1Amount - expectedOutputAmount);
    }

    // Additional helper functions and test cases will go here...
}
