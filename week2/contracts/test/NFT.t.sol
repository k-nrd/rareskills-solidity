// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {NFT} from "../src/trio/NFT.sol";

contract NFTTest is Test {
    NFT nft;
    address owner;

    // Example Merkle proof and root, replace with actual values
    address[2] whitelist = [
        0x0000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000002
    ];
    bytes32[2] proofs;
    bytes32 exampleRoot =
        0xd05ebe621c58b8d21cff161492a4e299afdc33a69ff95669fa509b6acabdb28a;

    function setUp() public {
        owner = address(3);
        vm.deal(whitelist[0], 50000 ether);
        vm.deal(whitelist[1], 0.47 ether);
        vm.prank(owner);
        nft = new NFT();
        proofs[0] = bytes32(
            0x9feccf6caa602894c8105bdda7f81b2a7bb7de7dba1f18af92d8d057b708cb41
        );
        proofs[1] = bytes32(
            0x3f9553dc324cd1fd24b54243720c42e18e5c20165bc5e523e42b440a8654abd1
        );
    }

    function testMintWhenSupplyNotMaxxedOut() public {
        uint256 index = 0;
        vm.prank(whitelist[index]);
        nft.mint{value: 0.5 ether}(whitelist[index]);
        assertEq(nft.ownerOf(1), whitelist[index]);
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
        assertEq(nft.ownerOf(1), whitelist[index]);
    }

    function testMintWithDiscount() public {
        uint256 index = 1;
        vm.prank(whitelist[index]);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(proofs[index]);
        nft.mintWithDiscount{value: 0.45 ether}(whitelist[index], index, proof);
        assertEq(nft.ownerOf(1), whitelist[index]);
    }

    function testRoyalties() public {
        nft.mint{value: 0.5 ether}(whitelist[0]);
        uint256 tokenId = nft.tokenId() - 1;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(
            tokenId,
            10000
        );
        assertEq(receiver, address(nft));
        assertEq(royaltyAmount, 250); // 2.5% of 10000
    }

    function testFailMintWithFakeProof() public {
        uint256 index = 0;
        bytes32[] memory fakeProof = new bytes32[](1);
        fakeProof[0] = bytes32(0x0);
        vm.prank(whitelist[index]);
        nft.mintWithDiscount{value: 0.45 ether}(
            whitelist[index],
            index,
            fakeProof
        ); // This should fail
    }

    function testFailMintWithClaimedProof() public {
        uint256 index = 1;
        vm.prank(whitelist[index]);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(proofs[index]);
        nft.mintWithDiscount{value: 0.45 ether}(whitelist[index], index, proof);
        vm.prank(whitelist[index]);
        nft.mintWithDiscount{value: 0.45 ether}(whitelist[index], index, proof); // This should fail
    }
}
