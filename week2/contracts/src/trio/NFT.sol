// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {ERC2981} from "openzeppelin/token/common/ERC2981.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {MerkleProof} from "openzeppelin/utils/cryptography/MerkleProof.sol";
import {BitMaps} from "openzeppelin/utils/structs/BitMaps.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Ownable2Step} from "openzeppelin/access/Ownable2Step.sol";

/// @title NFT Contract with ERC2981 Royalty and Merkle Tree Based Discounts
/// @author Gustasvo Konrad
/// @notice This contract allows minting of ERC721 tokens with a limited supply, and includes support for ERC2981 royalty.
contract NFT is ERC721, ERC2981, ReentrancyGuard, Ownable2Step {
    using BitMaps for *;
    using MerkleProof for *;

    /// @notice The Merkle root for verifying discount eligibility.
    bytes32 public constant MERKLE_ROOT = "yolo";

    /// @notice The maximum supply of NFTs.
    uint256 public constant MAX_SUPPLY = 1000;

    /// @dev Internal counter for token IDs.
    uint256 public tokenId = 0;

    /// @dev Bitmap to track claimed discounts.
    BitMaps.BitMap private claimedDiscounts;

    /// @notice Emitted when a discount is claimed.
    event DiscountClaimed(address indexed account, uint256 indexed index);

    /// @notice Initializes the contract by setting a name and a symbol to the token collection and setting default royalty information.
    constructor() ERC721("CryptoHippos", "CHPN") Ownable(msg.sender) {
        _setDefaultRoyalty(address(this), 250);
    }

    /// @notice Allows the owner to withdraw all funds from the contract.
    /// @dev Transfers the contract's entire Ether balance to the owner's address.
    function withdrawFunds() external onlyOwner {
        (bool ok,) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "Failed to withdraw funds");
    }

    /// @notice Public function to mint an NFT. Minting costs 0.5 ether.
    /// @dev Mints a new token to the specified address.
    /// @param to The address that will receive the minted token.
    function mint(address to) external payable nonReentrant {
        _mintToken(to, 0.5 ether);
    }

    /// @notice Allows minting with a discount for eligible addresses based on a Merkle tree proof.
    /// @dev Mints a new token to the specified address with a discounted price.
    /// @param to The address that will receive the minted token.
    /// @param index The index in the Merkle tree for discount eligibility.
    /// @param merkleProof An array of bytes32 hashes representing the Merkle path to prove discount eligibility.
    function mintWithDiscount(address to, uint256 index, bytes32[] memory merkleProof) external payable nonReentrant {
        require(!BitMaps.get(claimedDiscounts, index), "Discount was already claimed!");
        require(MerkleProof.verify(merkleProof, MERKLE_ROOT, keccak256(abi.encodePacked(index, to))), "Invalid proof.");
        _mintToken(to, 0.45 ether);
        BitMaps.set(claimedDiscounts, index);
        emit DiscountClaimed(to, index);
    }

    /// @notice Checks if a specific interface is supported by the contract.
    /// @dev Overrides ERC721 and ERC2981 supportsInterface.
    /// @param interfaceId The interface identifier, as specified in ERC-165.
    /// @return True if the contract supports the interface.
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Internal function to mint a new token. Checks if MAX_SUPPLY has been reached.
    /// @param to The address that will receive the minted token.
    /// @param price The cost of minting a token.
    function _mintToken(address to, uint256 price) internal {
        require(msg.value >= price, "Value insufficient for minting.");
        require(tokenId < MAX_SUPPLY, "Max supply reached.");
        _safeMint(to, tokenId);
        tokenId++;
    }

    receive() external payable {}
    fallback() external payable {}
}
