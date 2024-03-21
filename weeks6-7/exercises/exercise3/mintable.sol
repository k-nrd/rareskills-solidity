// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./token.sol";

contract MintableToken is Token {
    uint256 public totalMinted;
    uint256 public totalMintable;

    constructor(uint256 totalMintable_) {
        totalMintable = totalMintable_;
    }

    function mint(uint256 value) public onlyOwner {
        require(value + totalMinted < totalMintable);
        totalMinted += value;

        balances[msg.sender] += value;
    }
}
