// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {ERC2981} from "openzeppelin/token/common/ERC2981.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {MerkleProof} from "openzeppelin/utils/cryptography/MerkleProof.sol";
import {BitMaps} from "openzeppelin/utils/structs/BitMaps.sol";

contract NFT is ERC721, ERC2981, ReentrancyGuard {
    using BitMaps for *;
    using MerkleProof for *;

    bytes32 public constant MERKLE_ROOT = "yolo";
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public _tokenId = 0;

    BitMaps.BitMap private claimedDiscounts;

    event DiscountClaimed(address indexed account, uint256 indexed index);

    constructor() ERC721("CryptoHippos", "CHPN") {
        _setDefaultRoyalty(address(this), 50);
    }

    function _mintToken(address to) private {
        require(_tokenId < MAX_SUPPLY, "Max supply reached");
        _safeMint(to, _tokenId);
        _tokenId++;
    }

    function mint(address to) external payable nonReentrant {
        require(msg.value >= 0.5 ether, "Value insufficient for minting");
        _mintToken(to);
    }

    function mintWithDiscount(address to, uint256 discountIndex, bytes32[] memory merkleProof)
        external
        payable
        nonReentrant
    {
        require(msg.value >= 0.45 ether, "Value insufficient for minting at a discount");
        require(!BitMaps.get(claimedDiscounts, discountIndex), "Discount was already claimed!");
        require(
            MerkleProof.verify(merkleProof, MERKLE_ROOT, keccak256(abi.encodePacked(discountIndex, to))),
            "Invalid proof."
        );
        BitMaps.set(claimedDiscounts, discountIndex);
        _mintToken(to);
        emit DiscountClaimed(to, discountIndex);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
