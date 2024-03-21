// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Pair} from "./Pair.sol";

contract Factory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    error IdenticalTokens();
    error InvalidToken();
    error PairExists();

    event PairCreated(
        address indexed token0, address indexed token1, address pair, uint256
    );

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(
        string memory name,
        string memory symbol,
        address token0,
        address token1,
        uint128 swapFeeBasisPoints,
        uint128 loanFeeBasisPoints
    ) external returns (address) {
        if (token0 == token1) revert IdenticalTokens();
        if (token0 == address(0) || token1 == address(0)) revert InvalidToken();
        if (getPair[token0][token1] != address(0)) revert PairExists();

        address pair = address(
            new Pair(
                name,
                symbol,
                token0,
                token1,
                swapFeeBasisPoints,
                loanFeeBasisPoints
            )
        );

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);

        return pair;
    }
}
