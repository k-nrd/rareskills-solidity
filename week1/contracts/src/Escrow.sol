// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract UntrustedEscrow {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => EscrowData)) public escrows;

    struct EscrowData {
        uint256 amount;
        uint256 releaseTime;
        address seller;
    }

    event Deposit(address indexed token, address indexed seller, uint256 amount);
    event Withdraw(address indexed token, address indexed buyer, uint256 amount);

    function deposit(address token, uint256 amount, address seller) external {
        require(amount > 0, "Amount must be greater than 0");
        require(seller != address(0), "Seller address cannot be zero");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        escrows[token][msg.sender] = EscrowData({amount: amount, releaseTime: block.timestamp + 3 days, seller: seller});

        emit Deposit(token, seller, amount);
    }

    function withdraw(address token, address buyer) external {
        EscrowData memory escrow = escrows[token][buyer];
        require(msg.sender == escrow.seller, "Only the designated seller can withdraw");
        require(block.timestamp >= escrow.releaseTime, "Tokens are still locked");

        delete escrows[token][buyer];
        IERC20(token).safeTransfer(msg.sender, escrow.amount);

        emit Withdraw(token, buyer, escrow.amount);
    }

    function getEscrowData(address token, address buyer) external view returns (EscrowData memory) {
        return escrows[token][buyer];
    }
}
