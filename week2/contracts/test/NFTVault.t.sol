// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/trio/NFTVault.sol";
import "../src/trio/NFTShare.sol";
import "../src/trio/NFT.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTVaultTest is Test {
    NFTVault vault;
    NFTShare rewardToken;
    NFT nft;
    address user;

    function setUp() public {
        user = address(1);
        vm.deal(user, 10 ether);

        nft = new NFT();
        vault = new NFTVault(nft);
        rewardToken = new NFTShare(address(vault));
        vault.setRewardContract(rewardToken);
    }

    function testDepositNFT() public {
        nft.mint{value: 0.5 ether}(user);
        vm.prank(user);
        nft.approve(address(vault), 1);
        vm.prank(user);
        vault.deposit(user, 1);
        assertEq(nft.ownerOf(1), address(vault));
        assertTrue(vault.isOperator(user));
    }

    function testWithdrawNFT() public {
        nft.mint{value: 0.5 ether}(user);
        vm.prank(user);
        nft.approve(address(vault), 1);
        vm.prank(user);
        vault.deposit(user, 1);
        vm.prank(user);
        vault.withdraw(user, 1);
        assertEq(nft.ownerOf(1), user);
    }

    function testHarvestRewards() public {
        nft.mint{value: 0.5 ether}(user);
        vm.prank(user);
        nft.approve(address(vault), 1);
        vm.prank(user);
        vault.deposit(user, 1);

        // Fast forward time by 1 day
        vm.warp(block.timestamp + 1 days);
        vm.prank(user);
        vault.harvest(user);

        uint256 userBalance = rewardToken.balanceOf(user);
        assertGt(userBalance, 0, "User should have received some rewards");
    }

    function testPreviewHarvest() public {
        nft.mint{value: 0.5 ether}(user);
        vm.prank(user);
        nft.approve(address(vault), 1);
        vm.prank(user);
        vault.deposit(user, 1);

        // Fast forward time by 1 day
        vm.warp(block.timestamp + 1 days);
        uint256 expectedRewards = vault.previewHarvest(user);
        assertGt(expectedRewards, 0, "User should have some pending rewards");
    }

    function testFailDepositWithoutApproval() public {
        nft.mint{value: 0.5 ether}(user);
        vm.prank(user);
        vault.deposit(user, 1); // This should fail
    }

    function testFailWithdrawNotOwner() public {
        nft.mint{value: 0.5 ether}(user);
        vm.prank(user);
        nft.approve(address(vault), 1);
        vm.prank(user);
        vault.deposit(user, 1);

        vm.prank(address(2)); // Another user
        vault.withdraw(user, 1); // This should fail
    }
}
