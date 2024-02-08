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

contract MockFlashLoanReceiverOtherToken is IERC3156FlashBorrower {
    bytes32 public constant FLASH_LOAN_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");
    Pair public pair;
    MockERC20 public token0;
    MockERC20 public token1;
    uint256 zeroForOneRatio;

    constructor(
        Pair _pair,
        MockERC20 _token0,
        MockERC20 _token1,
        uint256 _zeroForOneRatio
    ) {
        pair = _pair;
        token0 = _token0;
        token1 = _token1;
        zeroForOneRatio = _zeroForOneRatio;
    }

    function onFlashLoan(
        address,
        address tokenAddress,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external override returns (bytes32) {
        require(
            tokenAddress == address(token0) || tokenAddress == address(token1),
            "Invalid token for flash loan"
        );

        MockERC20 outputToken =
            tokenAddress == address(token0) ? token1 : token0;

        // Calculate the fee if we were loaning the secondary token
        uint256 loanReturns = (amount + fee) * zeroForOneRatio;

        // In a real scenario, this might involve calling another contract or performing some action
        // Here, it's simplified to just minting the equivalent amount of the other token
        // Simulate conversion and repay in token1
        outputToken.mint(address(this), loanReturns);
        outputToken.transfer(address(pair), loanReturns);

        return FLASH_LOAN_SUCCESS;
    }
}
