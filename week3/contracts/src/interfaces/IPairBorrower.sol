// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IPairBorrower {
    function onFlashLoan(
        address caller,
        uint256 assets0,
        uint256 assets1,
        bytes calldata data
    ) external;
}
