// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title UntrustedEscrow
/// @dev Contract to facilitate escrow for ERC20 tokens, including tokens with fee-on-transfer.
contract UntrustedEscrow {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => EscrowData)) public escrows;

    /// @dev Structure to store escrow data.
    struct EscrowData {
        uint256 amount;
        uint256 releaseTime;
        address seller;
    }

    /// @notice Emitted when tokens are deposited into escrow.
    event Deposit(address indexed token, address indexed seller, uint256 amount);

    /// @notice Emitted when tokens are withdrawn from escrow.
    event Withdraw(address indexed token, address indexed buyer, uint256 amount);

    /// @notice Deposit ERC20 tokens into escrow.
    /// @param token The ERC20 token address.
    /// @param amount The amount of tokens to deposit.
    /// @param seller The address of the seller who can withdraw the tokens after 3 days.
    function deposit(address token, uint256 amount, address seller) external {
        require(amount > 0, "Amount must be greater than 0");
        require(seller != address(0), "Seller address cannot be zero");

        IERC20 tokenContract = IERC20(token);

        uint256 beforeBalance = tokenContract.balanceOf(address(this));
        tokenContract.safeTransferFrom(msg.sender, address(this), amount);
        uint256 afterBalance = tokenContract.balanceOf(address(this));

        uint256 actualAmount = afterBalance - beforeBalance;

        escrows[token][msg.sender] =
            EscrowData({amount: actualAmount, releaseTime: block.timestamp + 3 days, seller: seller});

        emit Deposit(token, seller, actualAmount);
    }

    /// @notice Withdraw deposited ERC20 tokens from escrow.
    /// @param token The ERC20 token address.
    /// @param buyer The address of the buyer who deposited the tokens.
    function withdraw(address token, address buyer) external {
        EscrowData memory escrow = escrows[token][buyer];
        require(msg.sender == escrow.seller, "Only the designated seller can withdraw");
        require(block.timestamp >= escrow.releaseTime, "Tokens are still locked");

        delete escrows[token][buyer];

        IERC20(token).safeTransfer(msg.sender, escrow.amount);

        emit Withdraw(token, buyer, escrow.amount);
    }

    /// @notice Retrieve escrow data for a specific deposit.
    /// @param token The ERC20 token address.
    /// @param buyer The address of the buyer who deposited the tokens.
    /// @return The escrow data.
    function getEscrowData(address token, address buyer) external view returns (EscrowData memory) {
        return escrows[token][buyer];
    }
}
