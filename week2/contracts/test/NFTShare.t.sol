// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/trio/NFTShare.sol";
import "../src/lib/ERC20Private.sol";

contract NFTShareTest is Test {
    NFTShare nftShare;
    address vault;
    address user;

    // Set up the testing environment
    function setUp() public {
        vault = address(1); // Mock vault address
        user = address(2); // Mock user address

        // Deploy the NFTShare contract with the vault as the owner
        nftShare = new NFTShare(vault);
    }

    // Test initial contract setup
    function testInitialSetup() public {
        assertEq(nftShare.name(), "CryptoHipposShare");
        assertEq(nftShare.symbol(), "CHPS");
        assertEq(nftShare.owner(), vault);
    }

    // Test minting functionality
    function testMinting() public {
        uint256 mintAmount = 1000 * 1e18; // 1000 tokens with 18 decimals

        // Mint tokens to the user from the vault
        vm.prank(vault); // Impersonate the vault
        nftShare.mint(user, mintAmount);

        // Check the user's balance
        assertEq(nftShare.balanceOf(user), mintAmount);
    }

    // Test burning functionality
    function testBurning() public {
        uint256 mintAmount = 1000 * 1e18; // 1000 tokens
        uint256 burnAmount = 500 * 1e18; // Burn 500 tokens

        // Mint tokens to the user
        vm.prank(vault);
        nftShare.mint(user, mintAmount);

        // Burn some of the tokens
        vm.prank(vault); // Impersonate the vault again
        nftShare.burn(user, burnAmount);

        // Check the remaining balance
        assertEq(nftShare.balanceOf(user), mintAmount - burnAmount);
    }

    // Test unauthorized minting attempt
    function testFailUnauthorizedMinting() public {
        uint256 mintAmount = 1000 * 1e18;

        // Attempt to mint tokens from a non-owner address
        vm.prank(user); // Impersonate a regular user
        nftShare.mint(user, mintAmount); // This should fail
    }

    // Test unauthorized burning attempt
    function testFailUnauthorizedBurning() public {
        uint256 mintAmount = 1000 * 1e18;
        uint256 burnAmount = 500 * 1e18;

        // Mint tokens first
        vm.prank(vault);
        nftShare.mint(user, mintAmount);

        // Attempt to burn tokens from a non-owner address
        vm.prank(user); // Impersonate a regular user
        nftShare.burn(user, burnAmount); // This should fail
    }
}
