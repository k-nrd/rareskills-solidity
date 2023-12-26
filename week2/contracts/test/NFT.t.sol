// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {NFT} from "../src/trio/NFT.sol";

contract NFTTest is Test {
    NFT nft;
    address owner;

    // Example Merkle proof and root, replace with actual values
    address[2] whitelist = [0x0000000000000000000000000000000000000001, 0x0000000000000000000000000000000000000002];
    uint256[2] proofs = [
        0x6e9d5a5fa819101f78484ebf901fa5f934804919ec49851f0c344e7b9636738a,
        0xe99467d027c1d99b544d929e378c5ecfc6b0e521f7cc79d93719111138a166eb
    ];
    bytes32 exampleRoot = 0x4ed4471cd8f7a44e083f002092f17334fc1ca52eff3c1b40ff0552ebafa3305b;

    function setUp() public {
        owner = address(3);
        vm.deal(whitelist[0], 50000 ether);
        vm.deal(whitelist[1], 0.47 ether);
        vm.prank(owner);
        nft = new NFT();
    }

    function testMintWhenSupplyNotMaxxedOut() public {
        uint256 index = 0;
        vm.prank(whitelist[index]);
        nft.mint{value: 0.5 ether}(whitelist[index]);
        assertEq(nft.ownerOf(0), whitelist[index]);
    }

    function testFailMintWhenSupplyMaxxedOut() public {
        uint256 index = 0;
        for (uint256 i = 0; i < 1000; i++) {
            vm.prank(whitelist[index]);
            nft.mint{value: 0.5 ether}(whitelist[index]);
        }
        vm.prank(whitelist[index]);
        nft.mint{value: 0.5 ether}(whitelist[index]); // This should fail
    }

    function testMintWithoutDiscount() public {
        uint256 index = 0;
        vm.prank(whitelist[index]);
        nft.mint{value: 0.5 ether}(whitelist[index]);
        assertEq(nft.ownerOf(0), whitelist[index]);
    }

    function testMintWithDiscount() public {
        uint256 index = 1;
        vm.prank(whitelist[index]);
        bytes32[] memory proof;
        proof[0] = bytes32(proofs[index]);
        nft.mintWithDiscount{value: 0.45 ether}(whitelist[index], index, proof);
        assertEq(nft.ownerOf(0), whitelist[index]);
    }

    function testRoyalties() public {
        nft.mint{value: 0.5 ether}(whitelist[0]);
        uint256 tokenId = nft.tokenId() - 1;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(tokenId, 10000);
        assertEq(receiver, address(nft));
        assertEq(royaltyAmount, 250); // 2.5% of 10000
    }

    function testFailMintWithFakeProof() public {
        uint256 index = 0;
        bytes32[] memory fakeProof;
        fakeProof[0] = bytes32(0x0);
        vm.prank(whitelist[index]);
        nft.mintWithDiscount{value: 0.45 ether}(whitelist[index], index, fakeProof); // This should fail
    }

    function testFailMintWithClaimedProof() public {
        uint256 index = 1;
        vm.prank(whitelist[index]);
        bytes32[] memory proof;
        proof[0] = bytes32(proofs[index]);
        nft.mintWithDiscount{value: 0.45 ether}(whitelist[index], index, proof);
        vm.prank(whitelist[index]);
        nft.mintWithDiscount{value: 0.45 ether}(whitelist[index], index, proof); // This should fail
    }

    receive() external payable {}
}
