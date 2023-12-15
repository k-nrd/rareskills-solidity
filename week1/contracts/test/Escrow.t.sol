// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {UntrustedEscrow} from "../src/Escrow.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract ERC20Wrapper is ERC20("Test Token", "TT") {
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

contract UntrustedEscrowTest is Test {
    UntrustedEscrow escrow;
    ERC20Wrapper token;
    address buyer;
    address seller;

    function setUp() public {
        escrow = new UntrustedEscrow();
        token = new ERC20Wrapper();
        buyer = address(0x1);
        seller = address(0x2);

        token.mint(buyer, 1000 ether);
    }

    function testDeposit() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(buyer);
        token.approve(address(escrow), depositAmount);
        escrow.deposit(address(token), depositAmount, seller);
        vm.stopPrank();

        UntrustedEscrow.EscrowData memory data = escrow.getEscrowData(address(token), buyer);
        assertEq(data.amount, depositAmount, "Deposit amount mismatch");
        assertEq(data.seller, seller, "Seller address mismatch");
        assertTrue(data.releaseTime > block.timestamp, "Release time should be set in the future");
    }

    function testWithdraw() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(buyer);
        token.approve(address(escrow), depositAmount);
        escrow.deposit(address(token), depositAmount, seller);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.prank(seller);
        escrow.withdraw(address(token), buyer);

        assertEq(token.balanceOf(seller), depositAmount, "Seller should receive the deposited amount");
    }

    function testWithdrawTooEarly() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(buyer);
        token.approve(address(escrow), depositAmount);
        escrow.deposit(address(token), depositAmount, seller);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert("Tokens are still locked");
        vm.prank(seller);
        escrow.withdraw(address(token), buyer);
    }

    function testWithdrawByWrongSeller() public {
        uint256 depositAmount = 100 ether;
        address wrongSeller = address(0x3);

        vm.startPrank(buyer);
        token.approve(address(escrow), depositAmount);
        escrow.deposit(address(token), depositAmount, seller);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.expectRevert("Only the designated seller can withdraw");
        vm.prank(wrongSeller);
        escrow.withdraw(address(token), buyer);
    }
}
