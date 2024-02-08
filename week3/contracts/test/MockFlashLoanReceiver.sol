// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IERC3156FlashBorrower} from "openzeppelin/interfaces/IERC3156.sol";
import {MockERC20} from "./MockERC20.sol";
import {Pair} from "../src/Pair.sol";

contract MockFlashLoanReceiver is IERC3156FlashBorrower {
    using FixedPointMathLib for uint256;

    bytes32 public constant FLASH_LOAN_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");
    MockERC20 public token;
    Pair public pair;

    constructor(MockERC20 _token, Pair _pair) {
        token = _token;
        pair = _pair;
    }

    function onFlashLoan(
        address,
        address tokenAddress,
        uint256 amount,
        uint256,
        bytes calldata
    ) external override returns (bytes32) {
        require(tokenAddress == address(token), "Invalid token for flash loan");

        // Calculate amount to return (principal + fee)
        uint256 fee = pair.flashFee(tokenAddress, amount);

        // Simulate some action, e.g., minting extra tokens
        token.mint(address(this), fee);

        // Send it back
        token.transfer(address(pair), amount + fee);

        return FLASH_LOAN_SUCCESS;
    }
}
