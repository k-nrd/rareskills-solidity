// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Pair} from "./Pair.sol";

contract Factory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(
        address indexed token0, address indexed token1, address pair, uint256
    );

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(
        string memory name,
        string memory symbol,
        address tokenA,
        address tokenB,
        uint128 swapFeeBasisPoints,
        uint128 loanFeeBasisPoints
    ) external returns (address) {
        require(tokenA != tokenB, "FACTORY: IDENTICAL_TOKENS");

        // Smaller address goes first
        (address token0, address token1) =
            tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "FACTORY: INVALID_TOKEN_ADDRESS");
        require(getPair[token0][token1] == address(0), "FACTORY: PAIR_EXISTS");

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
